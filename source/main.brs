sub RunUserInterface()
    screen = CreateObject("roSGScreen")
    m.port = CreateObject("roMessagePort")
    screen.setMessagePort(m.port)
    scene = screen.CreateScene("AppScene")
    screen.show()
    
    while(true)
        msg = wait(0, m.port)
        msgType = type(msg)
        if msgType = "roSGScreenEvent"
            if msg.isScreenClosed() then
                forgetSessionIfNotSaved()
                return
            end if
        end if
    end while
end sub

' LoginScreen writes SeerrAuth.saveCredentials = "false" when the user opts out of
' persisting login across app restarts. connectSid/serverUrl still have to stay in the
' registry for the rest of THIS run, though — every screen re-reads them from SeerrAuth
' per API call, since there's no separate in-memory session store. So the opt-out is
' enforced here, at actual channel close, instead of at login time.
sub forgetSessionIfNotSaved()
    sec = CreateObject("roRegistrySection", "SeerrAuth")
    if sec.Exists("saveCredentials") and sec.Read("saveCredentials") = "false" then
        sec.Delete("connectSid")
        sec.Delete("serverUrl")
        sec.Delete("lastUsername")
        sec.Delete("saveCredentials")
        sec.Flush()
    end if
end sub
