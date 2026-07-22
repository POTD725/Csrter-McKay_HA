sub init()
    m.top.functionName = "fetchPlaylist"
end sub

sub fetchPlaylist()
    transfer = CreateObject("roUrlTransfer")
    transfer.SetUrl(m.top.url)
    transfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.InitClientCertificates()

    response = transfer.GetToString()
    if response = invalid or response = ""
        m.top.errorMessage = "The playlist could not be downloaded."
        return
    end if

    parsed = ParseJson(response)
    if parsed = invalid
        m.top.errorMessage = "The playlist contains invalid JSON."
        return
    end if

    m.top.result = parsed
end sub
