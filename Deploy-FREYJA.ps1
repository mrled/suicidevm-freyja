[CmdletBinding()] Param(
    [switch] $DeleteExisting
)

$ErrorActionPreference = "Stop"

if (Get-Module -Name Lability) {
    Write-Verbose -Message "Removing Lability module..."
    Remove-Module -Name Lability
} else {
    Write-Verbose -Message "Lability module not imported."
}
Write-Verbose -Message "Importing Lability module..."
Import-Module -Name Lability

Write-Host -ForegroundColor Magenta -Object "Welcome to FREYJA"
Write-Host -Object "We will now gather configuration data..."

function New-PSCredential {
    [CmdletBinding()] Param(
        [Parameter(Mandatory)] [string] $UserName,
        [Parameter(Mandatory)] [string] $Password
    )
    New-Object -TypeName PSCredential -ArgumentList @(
        $UserName,
        ($Password | ConvertTo-SecureString -AsPlainText -Force)
    )
}

if (Test-Path -Path $PSScriptRoot\secrets.FREYJA.json) {
    $secrets = Get-Content -Path $PSScriptRoot\secrets.FREYJA.json | ConvertFrom-Json
    $adminCred = New-PSCredential -UserName "Administrator" -Password $secrets.vmAdminPassword
    $yespVpnCred = New-PSCredential -UserName $secrets.yespVpnUsername -Password $secrets.yespVpnPassword
    $bpsVpnCred = New-PSCredential -UserName $secrets.bpsVpnUsername -Password $secrets.bpsVpnPassword
    $yespVpnServer = $secrets.yespVpnServer
    $bpsVpnServer = $secrets.bpsVpnServer
} else {
    $adminCred = Get-Credential -UserName "Administrator" -Message "Administrator password for FREYJA VM"
    $yespVpnCred = Get-Credential -Message "YESP VPN credential"
    $bpsVpnCred = Get-Credential -Message "BPS VPN credential"
    $yespVpnServer = Read-Host -Prompt "YESP VPN server"
    $bpsVpnServer = Read-Host -Prompt "BPS VPN server"
}
$configData = "$PSScriptRoot\ConfigurationData.FREYJA.psd1"

$configParams = @{
    YespVpnCredential = $yespVpnCred
    BpsVpnCredential = $bpsVpnCred
    YespVpnServer = $yespVpnServer
    BpsVpnServer = $bpsVpnServer
    ConfigurationData = $configData
    OutputPath = $env:LabilityConfigurationPath
    Verbose = $true
}

if ($DeleteExisting) {
    Write-Host -Object "Deleting existing resources"
    try {
        Remove-VM -Name Freyja -Force -Verbose -ErrorAction SilentlyContinue | Out-Null
        Write-Verbose -Message "Deleted Freyja VM"
    } catch {
        Write-Verbose -Message "No Freyja VM found"
    }
    Remove-Item -Path "${env:LabilityDifferencingVhdPath}\FREYJA*" -Force -Verbose
}

Write-Host -Object "Building the lab..."

. $PSScriptRoot\Configure.FREYJA.ps1
& FreyjaConfig @configParams

Start-LabConfiguration -ConfigurationData $configData -Path $env:LabilityConfigurationPath -Verbose -Credential $adminCred -IgnorePendingReboot
Start-Lab -ConfigurationData $configData -Verbose
