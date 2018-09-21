# Install and start WMI collector service

sc.exe create "ServiceNow WMI Collector" binPath= %1 start= auto
sc.exe start "ServiceNow WMI Collector"
sc.exe  failure "ServiceNow WMI Collector" reset= 86400 actions= restart/1/restart/1/restart/1
