sub init()
    m.contentGroup = m.top.findNode("contentGroup")
    m.eggPresses = 0
    m.eggLastPress = 0
    sec = CreateObject("roRegistrySection", "SeerrAuth")

    if sec.Exists("connectSid") and sec.Exists("serverUrl") then
        showDashboard()
    else
        showLogin()
    end if
end sub

' Undocumented: mash "rewind" 5x within 2s of each other, from anywhere in the
' app, for a small thank-you. See CODING_NOTES.md "Easter Eggs".
function onKeyEvent(key as String, press as Boolean) as Boolean
    if press and key = "rewind" then
        now = CreateObject("roDateTime").AsSeconds()
        if now - m.eggLastPress > 2 then m.eggPresses = 0
        m.eggLastPress = now
        m.eggPresses = m.eggPresses + 1
        if m.eggPresses >= 5 then
            m.eggPresses = 0
            showEasterEgg()
            return true
        end if
    end if
    return false
end function

sub showEasterEgg()
    dialog = CreateObject("roSGNode", "Dialog")
    dialog.title = "You found it"
    dialog.message = "Thanks for actually reading the source. Go request something good."
    dialog.buttons = ["Nice"]
    dialog.observeField("buttonSelected", "onEasterEggDismissed")
    m.top.dialog = dialog
end sub

sub onEasterEggDismissed()
    m.top.dialog.close = true
end sub

sub showLogin()
    m.contentGroup.removeChildren(m.contentGroup.getChildren(-1, 0))
    m.loginView = CreateObject("roSGNode", "LoginScreen")
    m.loginView.observeField("loginSuccess", "onLoginSuccess")
    m.contentGroup.appendChild(m.loginView)
    m.loginView.setFocus(true)
end sub

sub showDashboard()
    m.contentGroup.removeChildren(m.contentGroup.getChildren(-1, 0))
    m.dashboardView = CreateObject("roSGNode", "DashboardScreen")
    m.dashboardView.observeField("logout", "onLogout")
    m.contentGroup.appendChild(m.dashboardView)
    m.dashboardView.setFocus(true)
end sub

sub onLogout()
    showLogin()
end sub

sub onLoginSuccess()
    showDashboard()
end sub
