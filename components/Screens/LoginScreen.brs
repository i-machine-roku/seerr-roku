sub init()
    m.serverUrlBtn = m.top.findNode("serverUrlBtn")
    m.usernameBtn = m.top.findNode("usernameBtn")
    m.passwordBtn = m.top.findNode("passwordBtn")
    m.saveCredentialsBtn = m.top.findNode("saveCredentialsBtn")
    m.loginButton = m.top.findNode("loginButton")
    m.statusLabel = m.top.findNode("statusLabel")
    m.authTask = m.top.findNode("authTask")

    ' Linear tab order for onKeyEvent's up/down handling below.
    m.focusOrder = [m.serverUrlBtn, m.usernameBtn, m.passwordBtn, m.saveCredentialsBtn, m.loginButton]

    sec = CreateObject("roRegistrySection", "SeerrAuth")
    m.serverUrl = ""
    if sec.Exists("serverUrl") then m.serverUrl = sec.Read("serverUrl")
    m.username = ""
    if sec.Exists("lastUsername") then m.username = sec.Read("lastUsername")
    m.password = ""

    if m.serverUrl <> "" then
        m.serverUrlBtn.text = "Server URL: " + m.serverUrl
    else
        m.serverUrlBtn.text = "Server URL: (tap to set)"
    end if
    if m.username <> "" then
        m.usernameBtn.text = "Username: " + m.username
    else
        m.usernameBtn.text = "Username: (tap to set)"
    end if
    m.passwordBtn.text = "Password: (tap to set)"

    m.saveCredentials = true
    if sec.Exists("saveCredentials") then m.saveCredentials = (sec.Read("saveCredentials") = "true")
    updateSaveCredentialsText()

    m.serverUrlBtn.observeField("buttonSelected", "onServerUrlSelected")
    m.usernameBtn.observeField("buttonSelected", "onUsernameSelected")
    m.passwordBtn.observeField("buttonSelected", "onPasswordSelected")
    m.saveCredentialsBtn.observeField("buttonSelected", "onSaveCredentialsToggled")
    m.loginButton.observeField("buttonSelected", "onLoginSelected")
    m.authTask.observeField("response", "onAuthResponse")
end sub

' Called explicitly by AppScene.showLogin() right after appendChild — i.e. after this
' node is actually attached to the live scene tree. setFocus() called any earlier (e.g.
' from init(), which runs during CreateObject() before attachment) doesn't reliably
' register with the platform focus manager. See CODING_NOTES.md's focus-timing note.
sub screenShown()
    if m.serverUrl = "" then
        m.serverUrlBtn.setFocus(true)
    else if m.username = "" then
        m.usernameBtn.setFocus(true)
    else
        m.passwordBtn.setFocus(true)
    end if
end sub

sub updateSaveCredentialsText()
    if m.saveCredentials then
        m.saveCredentialsBtn.text = "Save credentials on this device: ON"
    else
        m.saveCredentialsBtn.text = "Save credentials on this device: OFF"
    end if
end sub

sub onSaveCredentialsToggled()
    m.saveCredentials = not m.saveCredentials
    updateSaveCredentialsText()
end sub

sub onServerUrlSelected()
    dialog = CreateObject("roSGNode", "KeyboardDialog")
    dialog.title = "Enter Server URL (e.g. https://seerr.example.com)"
    dialog.text = m.serverUrl
    dialog.buttons = ["OK", "Cancel"]
    dialog.observeField("buttonSelected", "onServerUrlDialogComplete")
    m.top.getScene().dialog = dialog
end sub

sub onServerUrlDialogComplete(event)
    dialog = event.getRoSGNode()
    if dialog.buttonSelected = 0 then ' OK
        m.serverUrl = dialog.text
        ' Simple cleanup of trailing slash
        if Right(m.serverUrl, 1) = "/" then
            m.serverUrl = Left(m.serverUrl, Len(m.serverUrl) - 1)
        end if
        m.serverUrlBtn.text = "Server URL: " + m.serverUrl
    end if
    dialog.close = true
    m.usernameBtn.setFocus(true)
end sub

sub onUsernameSelected()
    dialog = CreateObject("roSGNode", "KeyboardDialog")
    dialog.title = "Enter Username"
    dialog.text = m.username
    dialog.buttons = ["OK", "Cancel"]
    dialog.observeField("buttonSelected", "onUsernameDialogComplete")
    m.top.getScene().dialog = dialog
end sub

sub onUsernameDialogComplete(event)
    dialog = event.getRoSGNode()
    if dialog.buttonSelected = 0 then ' OK
        m.username = dialog.text
        m.usernameBtn.text = "Username: " + m.username
    end if
    dialog.close = true
    m.passwordBtn.setFocus(true)
end sub

sub onPasswordSelected()
    dialog = CreateObject("roSGNode", "KeyboardDialog")
    dialog.title = "Enter Password"
    dialog.secureMode = true
    dialog.buttons = ["OK", "Cancel"]
    dialog.observeField("buttonSelected", "onPasswordDialogComplete")
    m.top.getScene().dialog = dialog
end sub

sub onPasswordDialogComplete(event)
    dialog = event.getRoSGNode()
    if dialog.buttonSelected = 0 then ' OK
        m.password = dialog.text
        m.passwordBtn.text = "Password: " + String(Len(m.password), "*")
    end if
    dialog.close = true
    m.saveCredentialsBtn.setFocus(true)
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
    if m.serverUrl = "" or m.username = "" or m.password = "" then
        m.statusLabel.text = "Please enter server URL, username, and password"
        return
    end if

    if LCase(m.serverUrl).StartsWith("http://") then
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
        url: m.serverUrl + "/api/v1/auth/jellyfin" ' TODO: only Jellyfin-backed auth is supported; plain Overseerr local auth needs its own flow.
        method: "POST"
        body: {
            username: m.username,
            password: m.password
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
        ' toggle instead controls whether main.brs wipes them when the channel actually
        ' closes (see forgetSessionIfNotSaved), not whether they're written at all.
        sec = CreateObject("roRegistrySection", "SeerrAuth")
        sec.Write("connectSid", cookieStr)
        sec.Write("serverUrl", m.serverUrl)
        sec.Write("lastUsername", m.username)
        if m.saveCredentials then
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
