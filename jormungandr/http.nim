#[
    References:
        - https://github.com/rapid7/metasploit-payloads/blob/9ebb095a0acf95c4e55e62d44a57f7da740f1b16/c/meterpreter/source/metsrv/server_transport_winhttp.c
        - https://github.com/rapid7/metasploit-payloads/blob/9ebb095a0acf95c4e55e62d44a57f7da740f1b16/c/meterpreter/source/metsrv/server_transport_wininet.c
        - https://gist.github.com/henkman/2e7a4dcf4822bc0029d7d2af731da5c5
]#

import winim/lean
import winim/inc/winhttp

proc safeStringSlice(n: LPCWSTR, l: DWORD): LPCWSTR =
    var
        nim_string = $n
        nim_int = l-1

    return nim_string[.. nim_int]

proc httpRequestException(msg: string) =
    raise newException(ValueError, "Error when performing HTTP request: " & $msg)

proc http_get_request*(url: string): string =
    var
        bits: URL_COMPONENTS
        hSession, hConnect, hReq: HINTERNET
        flags: DWORD = WINHTTP_FLAG_BYPASS_PROXY_CACHE or WINHTTP_FLAG_SECURE
        ieConfig: WINHTTP_CURRENT_USER_IE_PROXY_CONFIG
        proxyInfo: WINHTTP_PROXY_INFO

    echo "+ Attempting HTTP GET request to: " & url

    hSession = WinHttpOpen("JORMUNGANDR", WINHTTP_ACCESS_TYPE_DEFAULT_PROXY, WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, 0)
    if hSession.isNil:
        httpRequestException("hSession is null")

    zeroMem(addr bits, sizeof(bits))
    bits.dwStructSize = cast[DWORD](sizeof(bits))

    bits.dwSchemeLength    = -1
    bits.dwHostNameLength  = -1
    bits.dwUrlPathLength   = -1
    bits.dwExtraInfoLength = -1

    WinHttpCrackUrl(url, 0, 0, addr bits)
    var actual_hostname = safeStringSlice(bits.lpszHostName, bits.dwHostNameLength)
    var actual_scheme = safeStringSlice(bits.lpszScheme, bits.dwSchemeLength)

    echo "* [HTTP] Scheme: ", actual_scheme
    echo "* [HTTP] Hostname: ", actual_hostname
    echo "* [HTTP] URL Path: ", bits.lpszUrlPath

    hConnect = WinHttpConnect(hSession, actual_hostname, bits.nPort, 0)
    if hConnect.isNil:
        httpRequestException("hConnect is null")

    hReq = WinHttpOpenRequest(hConnect, "GET", bits.lpszUrlPath, NULL, WINHTTP_NO_REFERER, WINHTTP_DEFAULT_ACCEPT_TYPES, flags)
    if hReq.isNil:
        httpRequestException("hReq is null")

    if WinHttpGetIEProxyConfigForCurrentUser(addr ieConfig):
        echo "* [PROXY] Got IE Configuration"
        echo "* [PROXY] Autodetect: ", ieConfig.fAutoDetect
        echo "* [PROXY] Auto URL: ", $ieConfig.lpszAutoConfigUrl
        echo "* [PROXY] Proxy: ", $ieConfig.lpszProxy
        echo "* [PROXY] Proxy Bypass: ", $ieConfig.lpszProxyBypass

        if (not ieConfig.lpszAutoConfigUrl.isNil or ieConfig.fAutoDetect.bool):
            var autoProxyOpts: WINHTTP_AUTOPROXY_OPTIONS

            if ieConfig.fAutoDetect:
                echo "* [PROXY] IE config set to autodetect with DNS or DHCP"
                autoProxyOpts.dwFlags = WINHTTP_AUTOPROXY_AUTO_DETECT
                autoProxyOpts.dwAutoDetectFlags = WINHTTP_AUTO_DETECT_TYPE_DHCP or WINHTTP_AUTO_DETECT_TYPE_DNS_A
                autoProxyOpts.lpszAutoConfigUrl = NULL

            elif not ieConfig.lpszAutoConfigUrl.isNil:
                echo "* [PROXY] IE config set to autodetect with URL ", ieConfig.lpszAutoConfigUrl

                autoProxyOpts.dwFlags = WINHTTP_AUTOPROXY_CONFIG_URL
                autoProxyOpts.dwAutoDetectFlags = 0
                autoProxyOpts.lpszAutoConfigUrl = ieConfig.lpszAutoConfigUrl

            autoProxyOpts.fAutoLogonIfChallenged = TRUE;

            WinHttpGetProxyForUrl(hSession, bits.lpszUrlPath, addr autoProxyOpts, addr proxyInfo)

        elif not ieConfig.lpszProxy.isNil:
            echo "* [PROXY] IE config set to proxy %s with bypass %s", ieConfig.lpszProxy, ieConfig.lpszProxyBypass

            proxyInfo.dwAccessType = WINHTTP_ACCESS_TYPE_NAMED_PROXY
            proxyInfo.lpszProxy = ieConfig.lpszProxy
            proxyInfo.lpszProxyBypass = ieConfig.lpszProxyBypass

            ieConfig.lpszProxy = NULL
            ieConfig.lpszProxyBypass = NULL

    WinHttpSetOption(hReq, WINHTTP_OPTION_PROXY, addr proxyInfo, cast[DWORD](sizeof(WINHTTP_PROXY_INFO)))

    if WinHttpSendRequest(hReq, WINHTTP_NO_ADDITIONAL_HEADERS, 0, WINHTTP_NO_REQUEST_DATA, 0, 0, 0).bool:
        if WinHttpReceiveResponse(hReq, NULL).bool:
            var 
                dwSize, dwDownloaded: DWORD
                dataBuffer: string = ""

            while true:
                WinHttpQueryDataAvailable(hReq, addr dwSize)
                if dwSize == 0:
                    break

                var pszOutBuffer: cstring = newString(dwSize)
                echo "* Receiving data: ", dwSize
                if not WinHttpReadData(hReq, addr pszOutBuffer[0], dwSize, addr dwDownloaded).bool:
                    httpRequestException("Error receiving data")

                dataBuffer = $dataBuffer & $pszOutBuffer

            echo "+ Total data received: ", len(dataBuffer)
            return dataBuffer
