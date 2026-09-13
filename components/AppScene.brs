sub init()
    m.contentGroup = m.top.findNode("contentGroup")
    sec = CreateObject("roRegistrySection", "SeerrAuth")

    if sec.Exists("connectSid") and sec.Exists("serverUrl") then
        showDashboard()
    else
        showLogin()
    end if
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
