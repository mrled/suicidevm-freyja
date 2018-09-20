@{
    AllNodes = @(
        @{
            NodeName                    = 'FREYJA';
            Role                        = 'FREYJA';
            InterfaceAlias              = 'Ethernet';
            AddressFamily               = 'IPv4';
            # Lability_SwitchName         = "Wifi-HyperV-VSwitch";
            Lability_Media              = 'WIN10_x64_Enterprise_EN_Eval';
            Lability_ProcessorCount     = 1;
            Lability_StartupMemory      = 3GB;
            PSDscAllowPlainTextPassword = $true;
            Lability_Resource           = @(
                'Firefox'
                'FuckingAnyconnect'
            );
        }
    );
    NonNodeData = @{
        Lability = @{
            EnvironmentPrefix = "FRJ0920"
            DSCResource = @(
                @{ Name = 'xComputerManagement'; RequiredVersion = '4.1.0.0'; }
                @{ Name = 'xNetworking'; RequiredVersion = '5.7.0.0'; }
            );
            Resource = @(
                @{
                    Id = 'Firefox';
                    Filename = 'Firefox-Latest.exe';
                    Uri = 'https://download.mozilla.org/?product=firefox-latest-ssl&os=win64&lang=en-US';
                }
                @{
                    Id = 'FuckingAnyconnect';
                    Filename = 'anyconnect-win-4.2.02075-web-deploy-k9.exe';
                    Uri = 'https://raw.githubusercontent.com/mrled/SuicideVM-Freyja/master/anyconnect-win-4.2.02075-web-deploy-k9.exe';
                    Checksum = 'D710A505A9871254DD1BA982D0C61A05';
                };
                @{
                    Id = 'SSMS';
                    Filename = 'SSMS-Setup-ENU.exe';
                    Uri = 'https://download.microsoft.com/download/0/5/B/05B2AF8F-906F-4C57-A58E-5780F64F9D62/SSMS-Setup-ENU.exe';
                };
            );
        };
    };
};
