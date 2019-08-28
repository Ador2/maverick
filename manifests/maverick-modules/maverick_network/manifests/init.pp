class maverick_network (
    $ethernet = true,
    $wireless = true,
    $netman = false,
    $predictable = false,
    $dhcpcd = false,
    $avahi = true,
    $dnsmasq = false,
    $dnsclient = false, 
    $ipv6 = undef,
    $wpasupplicant_template = true,
    $zerotier = true,
    $timesync = true,
    ) {

    # Install software 
    ensure_packages(["ethtool", "iw", "wpasupplicant", "wireless-tools", "rfkill", "dnsutils", "resolvconf", "nload", "hostapd"])
    
    # Create log directory
    file { ["/srv/maverick/var/log/network", "/srv/maverick/config/network", "/srv/maverick/data/network"]:
        ensure      => directory,
        mode        => "755",
        owner       => "mav",
        group       => "mav",
    }

    # Install/setup wifibroadcast
    class { "maverick_network::wifibroadcast": }
    
    # Ensure wpa_supplicant isn't running
    # Note NetworkManager seems to start this regardless of wpa_supplicant enabled state
    service { "wpa_supplicant":
        ensure      => stopped,
        enable      => false,
        require     => Package["wpasupplicant"]
    }

    # Base network setup
    class { "network": 
        hostname => "${hostname}",
        config_file_notify => '',
    }
    network::interface { 'lo':
        enable_dhcp     => false,
        auto            => true,
        method          => loopback,
        manage_order    => 0,
    }

    if $timesync == true {
        class { "maverick_network::timesync": }
    }
    
    if $dnsclient == true {
        class { "maverick_network::dnsclient": }
    }

    if $avahi == true {
        class { "maverick_network::avahi": }
    }

    if $dnsmasq == true {
        class { "maverick_network::dnsmasq": }
    }

    if $dhcpcd == false {
        # Make sure dhcp client daemons are turned off, for now we depend on dhclient/wpa_supplicant
        service { "udhcpd":
            ensure      => stopped,
            enable      => false
        } ->
        service { "dhcpcd":
            ensure      => stopped,
            enable      => false,
        }
    }

    # Turn off IPv6 - #213
    if $ipv6 == false {
        base::sysctl::conf {
        	"net.ipv6.conf.all.disable_ipv6": 					value => 1;
            "net.ipv6.conf.default.disable_ipv6": 				value => 1;
            "net.ipv6.conf.lo.disable_ipv6": 					value => 1;
        }
    } elsif $ipv6 == true {
        base::sysctl::conf {
        	"net.ipv6.conf.all.disable_ipv6": 					value => 0;
            "net.ipv6.conf.default.disable_ipv6": 				value => 0;
            "net.ipv6.conf.lo.disable_ipv6": 					value => 0;
        }
    }
    
    # Set high network buffers to better cope with our likely crappy usb ethernet and wifi links (12mb instead of default 128k)
    # Need to look closer at this to ensure it doesn't increase latency
    base::sysctl::conf { 
        "net.core.rmem_max": 							value => '12582912';
        "net.core.wmem_max": 							value => '12582912';
        "net.ipv4.tcp_rmem":							value => "10240 87380 12582912";
        "net.ipv4.tcp_wmem":							value => "10240 87380 12582912";
    }
    
    ### Interface naming configuration
    # Turn off biosdevname
    package { "biosdevname":
        ensure      => purged,
    }
    # Turn off desktop udev rules
    file { "/etc/udev/rules.d/75-persistent-net-generator.rules":
        ensure      => link,
        target      => "/dev/null",
    }
    exec { "update-initramfs":
        command         => "/usr/sbin/update-initramfs -u",
        refreshonly     => true,
    }
    if $predictable == false {
        file { "/etc/udev/rules.d/80-net-setup-link.rules":
            ensure      => link,
            target      => "/dev/null",
            notify      => Exec["update-initramfs"],
        }
        if $odroid_present == "yes" {
            lineval { "predictable-names-odroid-off":
                file => "/media/boot/boot.ini", 
                field => "net.ifnames", 
                oldvalue => "1", 
                newvalue => "0", 
                linesearch => "bootrootfs"
            }
        }
        if $raspberry_present == "yes" {
            lineval { "predictable-names-raspberry-off":
                file => "/boot/cmdline.txt", 
                field => "net.ifnames", 
                oldvalue => "1", 
                newvalue => "0", 
                linesearch => "root="
            }
        }
    } else {
        file { "/etc/udev/rules.d/80-net-setup-link.rules":
            ensure      => absent,
            notify      => Exec["update-initramfs"],
        }
        if $odroid_present == "yes" {
            lineval { "predictable-names-odroid-on":
                file => "/media/boot/boot.ini", 
                field => "net.ifnames", 
                oldvalue => "0", 
                newvalue => "1", 
                linesearch => "bootrootfs"
            }
        }
        if $raspberry_present == "yes" {
            lineval { "predictable-names-raspberry-on":
                file => "/boot/cmdline.txt", 
                field => "net.ifnames", 
                oldvalue => "0", 
                newvalue => "1", 
                linesearch => "root="
            }
        }
    }
    
    if $netman == false {
        # Remove connman - ubuntu/intel connection manager.  Ugly and unwielding, we want a more controllable, consistent interface to networking.
        # Ensure This is done after the rest of wireless is setup otherwise we lose access to everything.
        if $netman_connmand == "yes" {
            warning("Disabling connman connection manager: Please reset hardware and log back in if the connection hangs.  Please reboot when maverick is completed to activate new network config.")
        }
        service { "connman.service":
            ensure      => undef,
            enable      => false,
            require     => Class["maverick_network::wifibroadcast"],
        }
        package { ["cmst", "connman"]:
            ensure      => purged,
        }
        # Remove NetworkManager
        if $netman_networkmanager == "yes" {
            warning("Disabling NetworkManager connection manager: Please reset hardware and log back in if the connection hangs.  Please reboot when maverick is completed to activate new network config.")
        }
        service { "NetworkManager.service":
            ensure      => stopped,
            enable      => false,
        } ->
        service { "NetworkManager-wait-online":
            ensure      => stopped,
            enable      => false,
            require     => Class["maverick_network::wifibroadcast"],
        }
        package { "network-manager":
            ensure      => absent, # remove but don't purge, so it can be restored later
        }
        # Reset resolv.conf to resolvconf
        file { "/etc/resolv.conf":
            ensure      => symlink,
            target      => "/run/resolvconf/resolv.conf",
        }
    }
    
    # Hack ifup-wait-all-auto.service to have a shorter timeout period as this hangs the boot process until all interfaces are up.  We don't want this.
    exec { "hack-ifup-wait":
        command     => '/bin/sed /lib/systemd/system/ifup-wait-all-auto.service -i -r -e "s/^TimeoutStartSec\\=.*/TimeoutStartSec=5/"',
        unless      => "/bin/grep 'TimeoutStartSec\\=5' /lib/systemd/system/ifup-wait-all-auto.service",
        onlyif      => "/bin/ls /lib/systemd/system/ifup-wait-all-auto.service",
    }
    
    # Reduce dhcp timeout
    # First, if we don't have an unhashed timeout line, unhash one
    exec { "dhcp-reduce-timeout-unhash":
        command     => '/bin/sed /etc/dhcp/dhclient.conf -i -r -e "s/^#timeout/timeout/"',
        unless      => "/bin/grep -e '^timeout' /etc/dhcp/dhclient.conf",
    } ->
    # Change the timeout value if necessary
    exec { "dhcp-reduce-timeout":
        command     => '/bin/sed /etc/dhcp/dhclient.conf -i -r -e "s/^timeout\s.*/timeout 5;/"',
        unless      => "/bin/grep -e '^timeout 5;' /etc/dhcp/dhclient.conf",
    }
    
    # Try to force a renew when dhclient runs
    file { "/etc/dhcp/dhclient-enter-hooks.d/forcerenew":
        content     => "old_ip_address=1.2.3.4",
    }
    
    # Define a service that unblocks radios with rfkill
    file { "/etc/systemd/system/rfkill-unblock.service":
        ensure      => present,
        source      => "puppet:///modules/maverick_network/rfkill-unblock.service",
        mode        => "644",
        owner       => "root",
        group       => "root",
        notify      => Exec["maverick-systemctl-daemon-reload"],
        require     => Package["rfkill"]
    } ->
    service { "rfkill-unblock.service":
        enable      => true,
        ensure      => "running",
    }
    
    # If wireless auth defaults are set in config, configure it 
    # Retrieve wireless auth data from hiera
    $wifi_ssid = lookup('wifi_ssid')
    $wifi_passphrase = lookup('wifi_passphrase')

    if $wpasupplicant_template == true {
        file { "/etc/wpa_supplicant/wpa_supplicant.conf":
            content => template("maverick_network/wpa_supplicant.conf.erb"),
            mode    => "600",
            owner   => "root",
            group   => "root",
            replace => false,
        }
    }
    
    # Define and configure monitor-mode interface setup in systemd
    file { ["/srv/maverick/software/maverick/bin/monitor-interface.sh", "/etc/systemd/system/monitor-interface@.service"]:
        ensure      => absent,
        notify      => Exec["maverick-systemctl-daemon-reload"],
    } ->
    file { "/srv/maverick/software/maverick/bin/network-if-monitor":
        ensure      => absent,
        target      => "/srv/maverick/software/maverick/manifests/maverick-modules/maverick_network/files/network-if-monitor.sh"
    } ->
    file { "/srv/maverick/software/maverick/bin/network-if-managed":
        ensure      => absent,
        target      => "/srv/maverick/software/maverick/manifests/maverick-modules/maverick_network/files/network-if-managed.sh"
    }
    file { "/srv/maverick/software/maverick/bin/network-if-config":
        ensure      => link,
        target      => "/srv/maverick/software/maverick/manifests/maverick-modules/maverick_network/files/network-if-config.sh"
    }
    
    # Retrieve defined interfaces and process
    $interfaces = lookup("maverick_network::interfaces", {merge => hash})
    if $interfaces {
        concat { "/etc/udev/rules.d/10-network-customnames.rules":
            ensure      => present,
        }
		create_resources("maverick_network::process_interface", $interfaces)

        # Scan through config to detect AP interfaces.  If not found, then disable hostap
        $combine = $interfaces.map |$items| {
            if !empty($items[1]) {
                $_keys = keys($items[1])
                if "mode" in $_keys and $items[1]["mode"] == "ap" { 1 }
            }
        }
        # If no AP interface detected, ensure hostapd is turned off
        if count($combine, 1) == 0 {
            service { "hostapd":
                ensure      => stopped,
                enable      => false,
            }
        }

	}
	
	if $zerotier == true {
	    class { "maverick_network::zerotier": }
	}
    
}
