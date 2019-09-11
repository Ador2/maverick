class maverick_vision (
    $visiond = true,
    $gstreamer = true,
    $opencv = true,
    $visionlibs = true,
    $openvino = true,
    $mjpg_streamer = false,
    $aruco = true,
    $orb_slam2 = false,
    $vision_landing = true,
    $vision_seek = true,
    $camera_manager = true,
    $collision_avoidance = false,
    $rtabmap = false,
) {

    file { ["/srv/maverick/config/vision", "/srv/maverick/data/vision", "/srv/maverick/var/log/vision"]:
        ensure      => directory,
        owner       => "mav",
        group       => "mav",
        mode        => "755",
    }

    # Create status.d directory for maverick status`
    file { "/srv/maverick/software/maverick/bin/status.d/123.vision":
        ensure      => directory,
        owner       => "mav",
        group       => "mav",
        mode        => "755",
    } ->
    file { "/srv/maverick/software/maverick/bin/status.d/123.vision/__init__":
        owner       => "mav",
        content     => "Vision Services",
    }
    
    if $visionlibs == true {
        class { "maverick_vision::visionlibs": }
    }

    if $visiond == true {
        class { "maverick_vision::visiond": }
    }

    if $gstreamer == true {
        class { "maverick_vision::gstreamer": }
    }

    if $mjpg_streamer == true  {
        class { "maverick_vision::mjpg-streamer": }
    }

    if $opencv == true {
        class { "maverick_vision::opencv": }
    }

    if $aruco == true {
        class { "maverick_vision::aruco": }
    }

    if $orb_slam2 == true {
        class { "maverick_vision::orb_slam2": }
    }

    if $vision_landing == true {
        class { "maverick_vision::vision_landing": }
    }

    if $camera_manager == true {
        class { "maverick_vision::camera_manager": }
    }

    if $vision_seek == true {
        class { "maverick_vision::vision_seek": }
    }
    
    if $collision_avoidance == true {
        class { "maverick_vision::collision_avoidance": }
    }

    if $rtabmap == true {
        class { "maverick_vision::rtabmap": }
    }
}
