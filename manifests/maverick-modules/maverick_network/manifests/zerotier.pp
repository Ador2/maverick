# @summary
#   Maverick_network::Zerotier class
#   This class installs/manages Zerotier network software/configuration.
#
# @example Declaring the class
#   This class is included from maverick_network class and should not be included from elsewhere
#
# @param active
#   If true, starts the zerotier service and enables at boot time.
# @param libzt
#   If true, compiles and installs the libzt component.
# @param join_network
#   If true, network specified in $network_id param will eb joined.  If false, the network will be left.
# @param network_id
#   The zerotier network to use.
#
class maverick_network::zerotier (
    Boolean $active = false,
    Boolean $libzt = false,
    Boolean $join_network = true,
    String $network_id = "8056c2e21c000001",
) {

    # Workaround for ubilinux
    if $::lsbdistid == "ubilinux" and $::lsbdistcodename == "dolcetto" {
        $_release = "stretch"
    } else {
        $_release = $::lsbdistcodename
    }

    if $_release {
        # Install core zerotier pgp key, repo and package
        apt::key { 'zerotier':
            id      => '74A5E9C458E1A431F1DA57A71657198823E52A61',
        } ->
        apt::source { 'zerotier':
            location      => "https://download.zerotier.com/debian/${_release}",
            release       => $_release,
            repos         => 'main',
            key           => {'id' => '74A5E9C458E1A431F1DA57A71657198823E52A61'},
            notify        => Exec["apt_update"],
        } ->
        package { "zerotier-one":
            ensure      => installed,
            require     => Exec["apt_update"],
        } ->
        file { "/usr/bin/zerotier-cli":
            target      => "/usr/sbin/zerotier-cli",
        } ->
        # Create initial crypto keys and register, and copy private key to mav user for user control
        exec { "zt-createkeys":
            command     => "/bin/systemctl start zerotier-one; sleep 10; /bin/systemctl stop zerotier-one",
            creates     => "/var/lib/zerotier-one/authtoken.secret",
        } ->
        exec { "mav-ztkey":
            command     => "/bin/cat /var/lib/zerotier-one/authtoken.secret >>/srv/maverick/.zeroTierOneAuthToken",
            creates     => "/srv/maverick/.zeroTierOneAuthToken",
        } ->
        file { "/srv/maverick/.zeroTierOneAuthToken":
            owner       => "mav",
            group       => "mav",
            mode        => "600",
        }

        # Install libzt - library is a WIP
        if $libzt == true {
            ensure_packages(["swig", "swig-examples"]) # for python_module target
            oncevcsrepo { "git-libzt":
                gitsource   => "https://github.com/zerotier/libzt.git",
                dest        => "/srv/maverick/software/libzt",
                submodules  => true,
            } ->
            exec { "libzt-cmake-setup":
                command     => "/usr/bin/cmake -H. -Bbuild -DCMAKE_BUILD_TYPE=DEBUG",
                cwd         => "/srv/maverick/software/libzt",
                creates     => "/srv/maverick/software/libzt/build/Makefile",
                user        => "mav",
                require     => Package["swig"],
            } ->
            exec { "libzt-cmake-build":
                command     => "/usr/bin/cmake --build build",
                cwd         => "/srv/maverick/software/libzt",
                creates     => "/srv/maverick/software/libzt/bin/lib/libzt.so",
                user        => "mav",
                require     => Package["swig"],
            }
        }

        if $active == true {
            service { "zerotier-one":
                ensure      => running,
                enable      => true,
                require     => Package["zerotier-one"],
            }
            if $join_network == true {
                exec { "zt-controlnetwork":
                    command     => "/usr/sbin/zerotier-cli join ${network_id}",
                    unless      => "/usr/sbin/zerotier-cli listnetworks |grep ${network_id}",
                    require     => Service["zerotier-one"],
                }
            } else {
                exec { "zt-controlnetwork":
                    command     => "/usr/sbin/zerotier-cli leave ${network_id}",
                    onlyif      => "/usr/sbin/zerotier-cli listnetworks |grep ${network_id}",
                    require     => Service["zerotier-one"],
                }
            }
        } else {
            if $join_network == false {
                exec { "zt-controlnetwork":
                    command     => "/usr/sbin/zerotier-cli leave ${network_id}",
                    onlyif      => "/usr/sbin/zerotier-cli listnetworks |grep ${network_id}",
                    before      => Service["zerotier-one"],
                }
            }
            service { "zerotier-one":
                ensure      => stopped,
                enable      => false,
                require     => Package["zerotier-one"],
            }
        }
    }
}
