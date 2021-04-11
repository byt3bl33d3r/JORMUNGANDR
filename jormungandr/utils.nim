import winim/lean
import winim/inc/iphlpapi
import strformat

proc getMacAddr*(): string =
    var AdapterInfo: PIP_ADAPTER_INFO
    var dwBufLen: DWORD = cast[DWORD](sizeof(AdapterInfo))
    #var mac_addr: cstring = cast[cstring](malloc(17))
    AdapterInfo = cast[ptr IP_ADAPTER_INFO](alloc(sizeof((IP_ADAPTER_INFO))))

    if AdapterInfo == nil:
        echo "Error allocating memory needed to call GetAdaptersinfo"

    if GetAdaptersInfo(AdapterInfo, addr(dwBufLen)) == ERROR_BUFFER_OVERFLOW:
        AdapterInfo = cast[ptr IP_ADAPTER_INFO](alloc(dwBufLen))

    if AdapterInfo == nil:
        echo "Error allocating memory needed to call GetAdaptersinfo"

    if GetAdaptersInfo(AdapterInfo, addr(dwBufLen)) == NO_ERROR:
        var pAdapterInfo: PIP_ADAPTER_INFO = AdapterInfo
        ##  Contains pointer to current adapter info
        #while true:
        return fmt"{pAdapterInfo.Address[0]:02X}-{pAdapterInfo.Address[1]:02X}-{pAdapterInfo.Address[2]:02X}-{pAdapterInfo.Address[3]:02X}-{pAdapterInfo.Address[4]:02X}-{pAdapterInfo.Address[5]:02X}"
        #[
        echo("Address: %s, mac: %s\n", pAdapterInfo.IpAddressList.IpAddress.String, mac_addr)
        pAdapterInfo = pAdapterInfo.Next
        if pAdapterInfo.isNil:
            break
        ]#

    dealloc(AdapterInfo)

proc safeStringSlice*(n: LPCWSTR, l: DWORD): LPCWSTR =
    var
        nim_string = $n
        nim_int = l-1

    return nim_string[.. nim_int]
