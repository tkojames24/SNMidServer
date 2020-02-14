Set objDomain = GetObject("LDAP://rootDSE")
strDC = objDomain.Get("dnsHostName")
Wscript.Echo strDC