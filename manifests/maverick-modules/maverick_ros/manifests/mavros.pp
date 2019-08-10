define maverick_ros::mavros (
    $rosmaster_port = "11311",
    $mavlink_port = "5770",
    $active = true,
    $mavros_startup_delay = 10,
    $mavros_launcher = "apm.launch",
    $source_sysid = undef,
    $source_cmpid = undef,
    $target_sysid = undef,
    $target_cmpid = undef,
) {
    
    file { "/srv/maverick/config/ros/mavros-${name}.conf":
        ensure      => present,
        owner       => "mav",
        group       => "mav",
        mode        => "644",
        content     => template("maverick_ros/mavros.conf.erb"),
        notify      => Service["maverick-mavros@${name}"],
    }
    
    if $active == true {
    	service { "maverick-mavros@${name}":
            ensure      => running,
            enable      => true,
            require     => [ Exec["maverick-systemctl-daemon-reload"], File["/etc/systemd/system/maverick-mavros@.service"] ]
        }
    } else {
    	service { "maverick-mavros@${name}":
            ensure      => stopped,
            enable      => false,
            require     => [ Exec["maverick-systemctl-daemon-reload"], File["/etc/systemd/system/maverick-mavros@.service"] ]
        }
    }
    
}