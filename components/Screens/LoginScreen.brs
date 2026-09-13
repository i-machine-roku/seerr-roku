sub init()
    m.serverUrlBtn = m.top.findNode("serverUrlBtn")
    m.usernameBtn = m.top.findNode("usernameBtn")
    m.passwordBtn = m.top.findNode("passwordBtn")
    m.loginButton = m.top.findNode("loginButton")
    m.statusLabel = m.top.findNode("statusLabel")
    m.authTask = m.top.findNode("authTask")
    
    sec = CreateObject("roRegistrySection", "SeerrAuth")
    m.serverUrl = ""
    if sec.Exists("serverUrl") then m.serverUrl = sec.Read("serverUrl")
    m.username = ""
    m.password = ""

    if m.serverUrl <> "" then
        m.serverUrlBtn.text = "Server URL: " + m.serverUrl
    else
        m.serverUrlBtn.text = "Server URL: (tap to set)"
    end if
    m.usernameBtn.text = "Username: (tap to set)"
    m.passwordBtn.text = "Password: (tap to set)"
    
    m.serverUrlBtn.observeField("buttonSelected", "onServerUrlSelected")
    m.usernameBtn.observeField("buttonSelected", "onUsernameSelected")
    m.passwordBtn.observeField("buttonSelected", "onPasswordSelected")
    m.loginButton.observeField("buttonSelected", "onLoginSelected")
    m.authTask.observeField("response", "onAuthResponse")
    
    m.serverUrlBtn.setFocus(true)
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
    m.loginButton.setFocus(true)
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    handled = false
    if press then
        if key = "down" then
            if m.serverUrlBtn.hasFocus() then
                m.usernameBtn.setFocus(true)
                handled = true
            else if m.usernameBtn.hasFocus() then
                m.passwordBtn.setFocus(true)
                handled = true
            else if m.passwordBtn.hasFocus() then
                m.loginButton.setFocus(true)
                handled = true
            end if
        else if key = "up" then
            if m.loginButton.hasFocus() then
                m.passwordBtn.setFocus(true)
                handled = true
            else if m.passwordBtn.hasFocus() then
                m.usernameBtn.setFocus(true)
                handled = true
            else if m.usernameBtn.hasFocus() then
                m.serverUrlBtn.setFocus(true)
                handled = true
            end if
        end if
    end if
    return handled
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
        
        sec = CreateObject("roRegistrySection", "SeerrAuth")
        sec.Write("connectSid", cookieStr)
        sec.Write("serverUrl", m.serverUrl)
        sec.Flush()
        
        m.top.loginSuccess = true
    else
        m.statusLabel.text = "Login failed. Code: " + resp.code.toStr()
    end if
end sub
