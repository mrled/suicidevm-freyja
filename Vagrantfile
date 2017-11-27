# Freyja Vagrantfile

require 'json'

# Hyper-V integration services configuration requires 1.9.4
Vagrant.require_version ">= 1.9.4"

# Find the repository root directory
freyjaRootDir = File.dirname(__FILE__)

# How many VMs to bring up?
freyjaVmCount = 1

# Why not calculate this based on the current date?
# Because then it only works once during the `vagrant up`. It won't work for e.g. `vagrant rdp`.
buildDate = "20171026"

# VM settings - these apply no matter which provider
cpuCount = 2
memCount = 2048

# Secrets file (not committed to repo)
secrets = JSON.parse(File.read(File.join(freyjaRootDir, 'Vagrantfile.secrets.json')))

Vagrant.configure("2") do |config|

    (1..freyjaVmCount).each do |idx|
        boxName = "Freyja-#{buildDate}-#{idx}"
        config.vm.define boxName do |node|

            node.vm.box = "wintriallab-win10-32"
            node.vm.box_url = "file:///C:/Users/mledbetter/Documents/Vagrant/wintriallab-win10-32.json"
            node.vm.communicator = "winrm"
            node.winrm.username = "vagrant"
            node.winrm.password = "V@grant123"
            node.vm.guest = :windows
            node.windows.halt_timeout = 15
            node.vm.hostname = boxName

            node.vm.provider :virtualbox do |v, override|
                #v.gui = true
                v.customize ["modifyvm", :id, "--cpus", cpuCount]
                v.customize ["modifyvm", :id, "--memory", memCount]
                v.customize ["setextradata", "global", "GUI/SuppressMessages", "all" ]
                v.customize ["modifyvm", :id, "--accelerate2dvideo", "on"]
                v.customize ["modifyvm", :id, "--vram", 128]
                v.customize ["modifyvm", :id, "--clipboard", "bidirectional"]
                v.customize ["modifyvm", :id, "--draganddrop", "bidirectional"]
            end

            node.vm.provider "hyperv" do |h|

                # Some, maybe most?, VPNs only work with bridged connections
                # Furthermore, working with `vagrant rdp` might be tough on non-bridged public networks
                # Hyper-V seems like it gets less testing/attention than VirtualBox
                node.vm.network :public_network, :adapter=>1, type:"dhcp", :bridge=>'HyperVWifiSwitch'

                h.cpus = cpuCount
                h.memory = memCount
                h.vmname = boxName

                # Use a COW rather than copying the disk file first - much faster
                h.differencing_disk = true

                # This appears to work
                h.auto_start_action = "Nothing"

                # This doesn't appear to work, even though the docs say it should
                # h.auto_stop_action = "ShutDown"

                # Documented here: https://technet.microsoft.com/en-us/library/dn798297%28v=ws.11%29.aspx?f=255&MSPPError=-2147217396
                h.vm_integration_services = {
                    guest_service_interface: true,
                    heartbeat: true,
                    shutdown: true,
                    time_synchronization: true,
                    vss: true,

                    # This must be on in order for Vagrant to find the IP address,
                    # which it does via Get-VMNetworkAdapter;
                    # if you run that command and find an empty IPAddresses property,
                    # it's probably because this was disabled.
                    key_value_pair_exchange: true,
                }
            end

            node.vm.synced_folder ".", "/vagrant", disabled: true
            node.vm.synced_folder freyjaRootDir, "/Freyja", :mount_options => ["ro"], smb_username: secrets['smb_username'], smb_password: secrets['smb_password']
            node.vm.provision "shell", inline: "powershell.exe -File C:\\Freyja\\provision.ps1"
        end
    end

end
