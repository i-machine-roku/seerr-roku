sub init()
    m.top.functionName = "executeRequest"
end sub

sub executeRequest()
    reqData = m.top.requestData
    url = reqData.url
    method = reqData.method
    if method = invalid then method = "GET"
    
    request = CreateObject("roUrlTransfer")
    if reqData.query <> invalid then
        url = url + "?query=" + request.Escape(reqData.query)
    end if
    
    request.SetUrl(url)
    request.SetCertificatesFile("common:/certs/ca-bundle.crt")
    request.InitClientCertificates()
    
    port = CreateObject("roMessagePort")
    request.SetPort(port)
    request.RetainBodyOnError(true)
    
    request.AddHeader("Content-Type", "application/json")
    request.AddHeader("Accept", "application/json")
    
    ' Add cookie if available
    sec = CreateObject("roRegistrySection", "SeerrAuth")
    if sec.Exists("connectSid") then
        cookieStr = sec.Read("connectSid")
        if cookieStr <> "" then
            ' Might need to extract just connect.sid=xxx from the Set-Cookie string
            ' Simple hack: just pass the whole string if it's already a cookie header format, or we might need to parse.
            ' Let's just pass what we stored.
            request.AddHeader("Cookie", cookieStr)
        end if
    end if

    if method = "POST" then
        if reqData.body <> invalid then
            bodyStr = FormatJson(reqData.body)
            request.AsyncPostFromString(bodyStr)
        else
            request.AsyncPostFromString("")
        end if
    else
        request.AsyncGetToString()
    end if
    
    msg = wait(10000, port)
    if type(msg) = "roUrlEvent" then
        code = msg.GetResponseCode()
        body = msg.GetString()
        headers = msg.GetResponseHeaders()
        
        m.top.response = {
            code: code,
            body: body,
            headers: headers
        }
    else
        request.AsyncCancel()
        m.top.response = {
            code: 0,
            body: "Timeout",
            headers: {}
        }
    end if
end sub
