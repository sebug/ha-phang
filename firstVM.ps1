Add-WindowsFeature Web-Server
Set-Content -Path C:\inetpub\wwwroot\iisstart.htm -Value '<p>Hello from first server over HAProxy</p>'