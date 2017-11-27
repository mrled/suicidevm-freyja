<#
.description
Provision the 'Freyja' boxes, which I use for work
#>

$ErrorActionPreference = "Stop"

Invoke-WebRequest -UseBasicParsing https://raw.githubusercontent.com/mrled/dhd/master/opt/powershell/magic.ps1 | Invoke-Expression

# Install AnyConnect
mkdir -Force -Path "C:\ProgramData\Freyja" | Out-Null
$anyconnectInstaller = "C:\Freyja\anyconnect-win-4.2.02075-web-deploy-k9.exe"
$anyconnectInstLog = "C:\ProgramData\Freyja\anyconnect_install.log"
& $anyconnectInstaller /l*v! $anyconnectInstLog /quiet /passive /qn
Copy-Item -Path "C:\Freyja\system32\anyconnect.bat" -Destination "C:\Windows\system32"

# We do not want the GUI to start on login,
# because running from the commandline will fail while the GUI is running
$runKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
Get-ChildItem -Path $runKey | Where-Object -Property Name -Match "AnyConnect" | Remove-Item -Force

# provision.secret.ps1 contains secrets like passwords, and is not committed to the repo in plain text
. $PSScriptRoot\provision.secret.ps1
