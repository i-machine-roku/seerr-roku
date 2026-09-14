sub init()
    m.serverBox = m.top.findNode("serverBox")
    m.usernameBox = m.top.findNode("usernameBox")
    m.passwordBox = m.top.findNode("passwordBox")
    m.saveCredentials = m.top.findNode("saveCredentials")
    m.submitBtn = m.top.findNode("submit")
    m.statusLabel = m.top.findNode("statusLabel")
    m.authTask = m.top.findNode("authTask")

    ' Linear tab order for onKeyEvent's up/down handling below.
    m.focusOrder = [m.serverBox, m.usernameBox, m.passwordBox, m.saveCredentials, m.submitBtn]

    sec = CreateObject("roRegistrySection", "SeerrAuth")

    m.serverBox.text = ""
    if sec.Exists("serverUrl") then m.serverBox.text = sec.Read("serverUrl")

    m.usernameBox.text = ""
    if sec.Exists("lastUsername") then m.usernameBox.text = sec.Read("lastUsername")

    saveCredsDefault = true
    if sec.Exists("saveCredentials") then saveCredsDefault = (sec.Read("saveCredentials") = "true")
    m.saveCredentials.checkedState = [saveCredsDefault]

    m.serverBox.observeField("text", "onServerUrlSubmitted")
    m.usernameBox.observeField("text", "onUsernameSubmitted")
    m.passwordBox.observeField("text", "onPasswordSubmitted")
    m.submitBtn.observeField("buttonSelected", "onLoginSelected")
    m.authTask.observeField("response", "onAuthResponse")
end sub

' Called explicitly by AppScene.showLogin() right after appendChild — i.e. after this
' node is actually attached to the live scene tree. setFocus() called any earlier (e.g.
' from init(), which runs during CreateObject() before attachment) doesn't reliably
' register with the platform focus manager. See CODING_NOTES.md's focus-timing note.
sub screenShown()
    if m.serverBox.text = "" then
        m.serverBox.setFocus(true)
    else if m.usernameBox.text = "" then
        m.usernameBox.setFocus(true)
    else
        m.passwordBox.setFocus(true)
    end if
end sub

' TextEditBox's "text" field only updates when the on-screen keyboard's Done/checkmark
' commits it, not per keystroke — so observing it doubles as a "field submitted" event,
' letting each field auto-advance to the next like jellyfin-roku's FormList does.
sub onServerUrlSubmitted()
    serverUrl = m.serverBox.text
    if Right(serverUrl, 1) = "/" then
        serverUrl = Left(serverUrl, Len(serverUrl) - 1)
        m.serverBox.text = serverUrl
    end if
    if serverUrl <> "" then m.usernameBox.setFocus(true)
end sub

sub onUsernameSubmitted()
    if m.usernameBox.text <> "" then m.passwordBox.setFocus(true)
end sub

' Jumps straight to Submit, skipping the save-credentials checkbox — the user can still
' toggle it manually with up/down first, same UX call jellyfin-roku's SigninScene makes.
sub onPasswordSubmitted()
    if m.passwordBox.text <> "" then m.submitBtn.setFocus(true)
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    idx = -1
    for i = 0 to m.focusOrder.Count() - 1
        if m.focusOrder[i].hasFocus() then
            idx = i
            exit for
        end if
    end for
    if idx = -1 then return false

    if key = "down" and idx < m.focusOrder.Count() - 1
        m.focusOrder[idx + 1].setFocus(true)
        return true
    else if key = "up" and idx > 0
        m.focusOrder[idx - 1].setFocus(true)
        return true
    end if
    return false
end function

sub onLoginSelected()
    serverUrl = m.serverBox.text
    username = m.usernameBox.text
    password = m.passwordBox.text

    if serverUrl = "" or username = "" or password = "" then
        m.statusLabel.text = "Please enter server URL, username, and password"
        return
    end if

    if LCase(serverUrl).StartsWith("http://") then
        dialog = CreateObject("roSGNode", "Dialog")
        dialog.title = "Insecure Connection"
        dialog.message = "This server URL uses http://, not https://. Your username and password will be sent unencrypted. Continue anyway?"
        dialog.buttons = ["Continue", "Cancel"]
        dialog.observeField("buttonSelected", "onHttpWarningComplete")
        m.top.getScene().dialog = dialog
        return
    end if

    doLogin()
end sub

sub onHttpWarningComplete(event)
    dialog = event.getRoSGNode()
    proceed = (dialog.buttonSelected = 0) ' Continue
    dialog.close = true
    if proceed then doLogin()
end sub

sub doLogin()
    m.statusLabel.text = "Logging in..."
    m.authTask.requestData = {
        url: m.serverBox.text + "/api/v1/auth/jellyfin" ' TODO: only Jellyfin-backed auth is supported; plain Overseerr local auth needs its own flow.
        method: "POST"
        body: {
            username: m.usernameBox.text,
            password: m.passwordBox.text
        }
    }
    m.authTask.control = "RUN"
end sub

sub onAuthResponse()
    resp = m.authTask.response
    if resp.code = 200 then
        cookieStr = ""
        if resp.headers <> invalid then
            if resp.headers["set-cookie"] <> invalid then
                fullCookie = resp.headers["set-cookie"]
                ' Extract up to the first semicolon
                semicolonIndex = fullCookie.Instr(";")
                if semicolonIndex > 0 then
                    cookieStr = fullCookie.Left(semicolonIndex)
                else
                    cookieStr = fullCookie
                end if
            end if
        end if

        ' connectSid/serverUrl are always written — they're the only cross-screen session
        ' store this app has, so every other screen breaks mid-session without them. The
        ' checkbox instead controls whether main.brs wipes them when the channel actually
        ' closes (see forgetSessionIfNotSaved), not whether they're written at all.
        sec = CreateObject("roRegistrySection", "SeerrAuth")
        sec.Write("connectSid", cookieStr)
        sec.Write("serverUrl", m.serverBox.text)
        sec.Write("lastUsername", m.usernameBox.text)
        if m.saveCredentials.checkedState[0] then
            sec.Write("saveCredentials", "true")
        else
            sec.Write("saveCredentials", "false")
        end if
        sec.Flush()

        m.top.loginSuccess = true
    else
        m.statusLabel.text = "Login failed. Code: " + resp.code.toStr() + " Body: " + Left(resp.body, 200)
    end if
end sub
