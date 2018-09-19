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

        Script "VpnConfigYesp" {
            GetScript = { return @{ Result = "" } }
            TestScript = {
                if (Test-Path -LiteralPath "${env:ProgramData}\Freyja\YESP.config") {
                    $content = Get-Content -LiteralPath "${env:ProgramData}\Freyja\YESP.config"
                    return $content -EQ $using:YespVpnConfig
                }
                return $false
            }
            SetScript = {
                Out-File -LiteralPath "${env:ProgramData}\Freyja\YESP.config" -InputObject $using:YespVpnConfig -Encoding ASCII -Force
            }
        }

        Script "VpnConfigBps" {
            GetScript = { return @{ Result = "" } }
            TestScript = {
                if (Test-Path -LiteralPath "${env:ProgramData}\Freyja\BPS.config") {
                    $content = Get-Content -LiteralPath "${env:ProgramData}\Freyja\BPS.config"
                    return $content -EQ $using:BpsVpnConfig
                }
                return $false
            }
            SetScript = {
                Out-File -LiteralPath "${env:ProgramData}\Freyja\BPS.config" -InputObject $using:BpsVpnConfig -Encoding ASCII -Force
            }
        }

        Script "AnyConnectYesp" {
            GetScript = { return @{ Result = "" } }
            TestScript = {
                if (Test-Path -LiteralPath "${env:SystemRoot}\system32\yesp-anyconnect.bat") {
                    $content = Get-Content -LiteralPath "${env:SystemRoot}\system32\yesp-anyconnect.bat"
                    $bat = '@anyconnect.bat connect {0} -s < "%ProgramData%\Freyja\YESP.config"' -f $using:YespVpnServer
                    return $content -EQ $bat
                }
                return $false
            }
            SetScript = {
                $bat = '@anyconnect.bat connect {0} -s < "%ProgramData%\Freyja\YESP.config"' -f $using:YespVpnServer
                Out-File -LiteralPath "${env:SystemRoot}\system32\yesp-anyconnect.bat" -InputObject $bat -Encoding ASCII -Force
            }
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
        Script "AnyConnectBps" {
            GetScript = { return @{ Result = "" } }
            TestScript = {
                if (Test-Path -LiteralPath "${env:SystemRoot}\system32\bps-anyconnect.bat") {
                    $content = Get-Content -LiteralPath "${env:SystemRoot}\system32\bps-anyconnect.bat"
                    $bat = '@anyconnect.bat connect {0} -s < "%ProgramData%\Freyja\BPS.config"' -f $using:BpsVpnServer
                    return $content -EQ $bat
                }
                return $false
            }
            SetScript = {
                $bat = '@anyconnect.bat connect {0} -s < "%ProgramData%\Freyja\BPS.config"' -f $using:BpsVpnServer
                Out-File -LiteralPath "${env:SystemRoot}\system32\bps-anyconnect.bat" -InputObject $bat -Encoding ASCII -Force
            }
        }

        File "Hosts" {
            DestinationPath = "${env:SystemRoot}\System32\drivers\etc\hosts"
            Contents = @(
                "#### BPS"
                "# Production"
                "10.244.1.48         edfiapp01"
                "10.244.1.144        edfisql01"
                "10.244.1.145        edfisql02"
                "10.244.1.142        edfiprodlisten"
                "10.244.5.40         edfiweb01"
                "10.244.5.42         edfiweb02"
                "# Staging"
                "10.23.12.48         stagedfiapp01"
                "10.23.12.144        stagedfisql01"
                "10.23.12.145        stagedfisql02"
                "10.244.5.140        stagedfiweb01"
                "10.23.12.142        edfistaglisten"
                "# Development"
                "10.244.1.47         cicd01"
            )
            Ensure = "Present"
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
                Test-Path -Path "${env:ProgramFiles(x86)}\Cisco AnyConnect VPN Client"
            }
            SetScript = {
                $process = Start-Process -FilePath "C:\Resources\anyconnect-win-4.2.02075-web-deploy-k9.exe" -Wait -PassThru -ArgumentList @(
                    '/l*v!'
                    "${env:ProgramData}\Freyja\anyconnect_install.log"
                    '/quiet'
                    '/passive'
                    '/qn'
                )
                if ($process.ExitCode -ne 0) {
                    throw "The Firefox installer at exited with code $($process.ExitCode)"
                }
            }
        }

        Script "InstallFuckingAnyconnectBat" {
            GetScript = { return @{ Result = "" } }
            TestScript = {
                if (Test-Path -LiteralPath "${env:SystemRoot}\system32\anyconnect.bat") {
                    $content = Get-Content -LiteralPath "${env:SystemRoot}\system32\anyconnect.bat"
                    $bat = '@"%ProgramFiles(x86)%\Cisco\Cisco AnyConnect Secure Mobility Client\vpncli.exe" %*'
                    return $content -EQ $bat
                }
                return $false
            }
            SetScript = {
                $bat = '@"%ProgramFiles(x86)%\Cisco\Cisco AnyConnect Secure Mobility Client\vpncli.exe" %*'
                Out-File -LiteralPath "${env:SystemRoot}\system32\anyconnect.bat" -InputObject $bat -Encoding ASCII -Force
            }
        }

        Registry "DisableFuckingAnyconnectGuiAutostart" {
            Key = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run\AnyConnect"
            ValueName = ""
            Ensure = "Absent"
        }

        Script "InstallSsms" {
            GetScript = { return @{ Result = "" } }
            TestScript = {

            }
            SetScript = {
                Start-Process -FilePath "C:\Resources\SSMS-Setup-ENU.exe" -ArgumentList @(
                    "/install"
                    "/quiet"
                    "/norestart"
                    "/log", "${env:ProgramData}\Freyja\SSMS.Install.log"
                )
            }
        }

    }
}
