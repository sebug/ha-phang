Add-WindowsFeature Web-Server
Set-Content -Path C:\inetpub\wwwroot\iisstart.htm -Value '<p>Hello from second server over HAProxy</p>'
