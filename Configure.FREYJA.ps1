Configuration FreyjaConfig {
    Param (
        [Parameter(Mandatory)] [PSCredential] $YespVpnCredential,
        [Parameter(Mandatory)] [PSCredential] $BpsVpnCredential,
        [Parameter(Mandatory)] [string] $YespVpnServer,
        [Parameter(Mandatory)] [string] $BpsVpnServer
    )

    Import-DscResource -Module PSDesiredStateConfiguration

    Import-DscResource -Module xComputerManagement -ModuleVersion 4.1.0.0
    Import-DscResource -Module xNetworking -ModuleVersion 5.7.0.0

    # A powershell script that converts a text file to UTF-8 without a Byte Order Mark (BOM)
    $ConvertToUtf8NoBom = @(
        '[CmdletBinding()] Param('
        '    [Parameter(Mandatory)] [string] $FilePath'
        ')'
        '$contents = (Get-Content -Path $FilePath) -Join "`r`n"'
        '$utf8NoBomEncoding = New-Object -TypeName System.Text.UTF8Encoding -ArgumentList @($false)'
        'Remove-Item -Path $FilePath'
        '[System.IO.File]::WriteAllLines($FilePath, $contents, $utf8NoBomEncoding)'
    ) -join "`r`n"

    # VPN configuration files
    # Actually just lines of text that are sent as standard input to the anyconnect exe
    # Some VPNs just need something like "username[ENTER]password[ENTER]",
    # but others are more complex
    $YespVpnConfig = @(
        $YespVpnCredential.UserName
        $YespVpnCredential.GetNetworkCredential().Password
    ) -join "`r`n"
    $BpsVpnConfig = @(
        '6'
        $BpsVpnCredential.UserName
        $BpsVpnCredential.GetNetworkCredential().Password
        'y'
    ) -join "`r`n"

    # Common configuration for all nodes
    node $AllNodes.Where({$_.Role -in 'FREYJA'}).NodeName {

        LocalConfigurationManager {
            RebootNodeIfNeeded   = $true;
            AllowModuleOverwrite = $true;
            ConfigurationMode    = 'ApplyOnly';
        }

        xFirewall 'FPS-ICMP4-ERQ-In' {
            Name        = 'FPS-ICMP4-ERQ-In';
            DisplayName = 'File and Printer Sharing (Echo Request - ICMPv4-In)';
            Description = 'Echo request messages are sent as ping requests to other nodes.';
            Direction   = 'Inbound';
            Action      = 'Allow';
            Enabled     = 'True';
            Profile     = 'Any';
        }

        xFirewall 'FPS-ICMP6-ERQ-In' {
            Name        = 'FPS-ICMP6-ERQ-In';
            DisplayName = 'File and Printer Sharing (Echo Request - ICMPv6-In)';
            Description = 'Echo request messages are sent as ping requests to other nodes.';
            Direction   = 'Inbound';
            Action      = 'Allow';
            Enabled     = 'True';
            Profile     = 'Any';
        }

        xComputer 'Hostname' {
            Name = $node.NodeName;
        }

        File 'FreyjaProgramData' {
            DestinationPath = "${env:ProgramData}\Freyja"
            Type = "Directory"
            Ensure = "Present"
        }

        File 'ConvertToUtf8NoBom' {
            DestinationPath = "${env:ProgramData}\Freyja\ConvertTo-Utf8NoBom.ps1"
            Contents = $ConvertToUtf8NoBom
            Ensure = "Present"
        }

        File 'VpnConfigYesp' {
            DestinationPath = "${env:ProgramData}\Freyja\YESP.config"
            Contents = $YespVpnConfig
            Ensure = 'Present'
        }

        File 'VpnConfigBps' {
            DestinationPath = "${env:ProgramData}\Freyja\BPS.config"
            Contents = $BpsVpnConfig
            Ensure = 'Present'
        }

        File 'AnyConnectYesp' {
            DestinationPath = "${env:SystemRoot}\system32\yesp-anyconnect.bat"
            Contents = '@anyconnect.bat connect {0} -s < "%ProgramData%\Freyja\YESP.config"' -f $YespVpnServer
            Ensure = 'Present'
        }

        # BPS requires two pre-config steps to deal with cert issues lololololololol
        # I think I could probably fully automate that based on this stuff below
        # but I haven't really tried yet:
        #
        # $bpsPreConfig1 = @(
        #     "y",
        #     "y"
        # )
        # $bpsPreConfig2 = @(
        #     "y",
        #     "y",
        #     "6",
        #     $username,
        #     $password,
        #     "y"
        # )
        # $bpsPreConfig1 | anyconnect.bat connect $BpsVpnServer -s
        # anyconnect.bat disconnect
        # $bpsPreConfig2 | anyconnect.bat connect $BpsVpnServer -s
        # anyconnect.bat disconnect
        File 'AnyConnectBps' {
            DestinationPath = "${env:SystemRoot}\system32\bps-anyconnect.bat"
            Contents = '@anyconnect.bat connect {0} -s < "%ProgramData%\Freyja\BPS.config"' -f $BpsVpnServer
            Ensure = 'Present'
        }

        # DSC will save the VPN configs as UTF-16, but anyconnect expects stdin to be UTF-8 with no BOM.
        # Convert the config files to this format.
        # This is kind of a dumb hack -
        # a better solution would have some custom DSC resource for writing files in this format directly
        Script "FixByteOrderMark" {
            GetScript = { return @{ Result = "" } }
            TestScript = { $false }
            SetScript = {
                foreach ($config in (Get-ChildItem -Path "${env:ProgramData}\Freyja\*.config")) {
                    & "${env:ProgramData}\Freyja\ConvertTo-Utf8NoBom.ps1" -FilePath $config.FullName
                }
            }
        }

        Script "InstallFirefox" {
            GetScript = { return @{ Result = "" } }
            TestScript = {
                Test-Path -Path "${env:ProgramFiles}\Mozilla Firefox"
            }
            SetScript = {
                $process = Start-Process -FilePath "C:\Resources\Firefox-Latest.exe" -Wait -PassThru -ArgumentList @('-ms')
                if ($process.ExitCode -ne 0) {
                    throw "The Firefox installer at exited with code $($process.ExitCode)"
                }
            }
        }

        Script "InstallFuckingAnyconnect" {
            GetScript = { return @{ Result = "" } }
            TestScript = {
                Test-Path -Path "C:\Program Files (x86)\Cisco AnyConnect VPN Client"
            }
            SetScript = {
                $process = Start-Process -FilePath "C:\Resources\anyconnect-win-4.2.02075-web-deploy-k9.exe" -Wait -PassThru -ArgumentList @(
                    '/l*v!'
                    'C:\ProgramData\Freyja\anyconnect_install.log'
                    '/quiet'
                    '/passive'
                    '/qn'
                )
                if ($process.ExitCode -ne 0) {
                    throw "The Firefox installer at exited with code $($process.ExitCode)"
                }
            }
        }

        File "InstallFuckingAnyconnectBat" {
            DestinationPath = 'C:\Windows\system32\anyconnect.bat'
            Contents = '@"C:\Program Files (x86)\Cisco\Cisco AnyConnect Secure Mobility Client\vpncli.exe" %*'
            Ensure = 'Present'
        }

        Registry "DisableFuckingAnyconnectGuiAutostart" {
            Key = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run\AnyConnect"
            ValueName = ""
            Ensure = "Absent"
        }

    }
p
}
