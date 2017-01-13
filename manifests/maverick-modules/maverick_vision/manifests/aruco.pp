class maverick_vision::aruco (
) {
    

    # Pull aruco from git mirror
    oncevcsrepo { "git-aruco":
        gitsource   => "https://github.com/fnoop/aruco",
        dest        => "/srv/maverick/var/build/aruco",
    } ->
    # Create build directory
    file { "/srv/maverick/var/build/aruco/build":
        ensure      => directory,
        owner       => "mav",
        group       => "mav",
        mode        => 755,
    }
    
    exec { "aruco-prepbuild":
        user        => "mav",
        timeout     => 0,
        environment => ["PKG_CONFIG_PATH=/srv/maverick/software/opencv/lib/pkgconfig", "LD_LIBRARY_PATH=/srv/maverick/software/opencv/lib", "PATH=/srv/maverick/software/opencv/bin:/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/sbin", "CMAKE_PREFIX_PATH=/srv/maverick/software/opencv"],
        # command     => "/usr/bin/cmake -DCMAKE_INSTALL_PREFIX=/srv/maverick/software/aruco -DCMAKE_INSTALL_RPATH=/srv/maverick/software/aruco/lib -DOpenCV_DIR=/srv/maverick/software/opencv/share/OpenCV ..",
        command     => "/usr/bin/cmake -DCMAKE_INSTALL_PREFIX=/srv/maverick/software/aruco -DCMAKE_INSTALL_RPATH=/srv/maverick/software/aruco/lib ..",
        cwd         => "/srv/maverick/var/build/aruco/build",
        creates     => "/srv/maverick/var/build/aruco/build/Makefile",
        require     => [ File["/srv/maverick/var/build/aruco/build"] ], # ensure we have all the dependencies satisfied
    } ->
    exec { "aruco-build":
        user        => "mav",
        timeout     => 0,
        command     => "/usr/bin/make -j${::processorcount} >/srv/maverick/var/log/build/aruco.build.out 2>&1",
        cwd         => "/srv/maverick/var/build/aruco/build",
        creates     => "/srv/maverick/var/build/aruco/build/utility/aruco_tracker",
        require     => Exec["aruco-prepbuild"],
    } ->
    exec { "aruco-install":
        user        => "mav",
        timeout     => 0,
        command     => "/usr/bin/make install >/srv/maverick/var/log/build/aruco.install.out 2>&1",
        cwd         => "/srv/maverick/var/build/aruco/build",
        creates     => "/srv/maverick/software/aruco/bin/arucoblah",
    } ->
    file { "/etc/profile.d/60-maverick-aruco-path.sh":
        mode        => 644,
        owner       => "root",
        group       => "root",
        content     => "export PATH=/srv/maverick/software/aruco/bin:\$PATH",
    } ->
    file { "/etc/profile.d/40-maverick-aruco-ldlibrarypath.sh":
        mode        => 644,
        owner       => "root",
        group       => "root",
        content     => "export LD_LIBRARY_PATH=/srv/maverick/software/aruco/lib:\$LD_LIBRARY_PATH",
    }

}