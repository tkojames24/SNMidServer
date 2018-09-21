@echo off
set MIDBATCH=bin\%1
set A1=%~2
start "ServiceNow MID Batch" /min cmd.exe /e:on /c %MIDBATCH% "%A1%"