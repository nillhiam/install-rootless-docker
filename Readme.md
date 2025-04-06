# Install Rootless docker 

Rootless mode allows to run docker daemon and containers as a non-root user.
- mitigate potential vulnerabilities in the daemon and the container runtime.
- does not require root privileges even during the installation of the Docker daemon.

## Prerequiites:
- [X] Install `uidmap` package
- [X] Check the subordinates UIDs/GIDs
- [-] Debain
    - [X] Install `dbus-user-session`
    - [X] Install `fuse-overlayfs` for Debian 11
    - [X] Install `slirp4netns` version `4.x.x`
    - [X] Disable **rootful docker** 
    - [X] Install Docker Engine
    - [X] Install Docker Rootless
