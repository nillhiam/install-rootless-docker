#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# CODENAME=$(grep CODENAME /etc/os-release | awk -F= '{print $2}')
VERSION_ID=$(grep VERSION_ID /etc/os-release | awk -F= '{print $2}')
DISTRIBUTION=$(grep ^ID /etc/os-release | awk -F= '{print $2}')


DOCKER_SERVICE="docker.service"
DOCKER_SOCKET="docker.socket"

DOCKER_ROOTLESS_SETUPTOOL="/usr/bin/dockerd-rootless-setuptool.sh"

DOCKER_SOCKET_PATH="DOCKER_HOST=unix:///run/user/$(id -u $USER)/docker.sock"

function print_header {
  local text=$1
  local line_length=65
  local half=$(((line_length-1-${#text})/2))
  local padding=$(printf "%0.1s" \#{1..65})
  echo -e "${GREEN}##################################################################"
  printf "%*.*s %s %*.*s\n" 0 "$half" "$padding" "$text" 0 "$half" "$padding"
  echo -e "##################################################################${NC}"
}

function install_and_configure_prerequisites {
  print_header "Prerequisites$"
  # check if 'uidmap' is installed
  if ! dpkg -s uidmap  &> /dev/null; then 
    sudo apt install  -y uidmap
  fi

  # Subordinate uid/gid
  local uid=$(grep "^$(whoami):" /etc/subuid | cut -d:  -f3)
  local gid=$(grep "^$(whoami):" /etc/subgid | cut -d:  -f3)
  MIN_SUBORDINATE=65536

  { [ "$uid" -eq "$MIN_SUBORDINATE" ] && [ "$gid" -eq "$MIN_SUBORDINATE" ]; } ||  { echo "The subordinate UIDs/GIDs is incorrect"; exit 1; }

  # Install dbus-user-session
  if ! dpkg -s dbus-user-session &> /dev/null; then 
    sudo apt-get install -y dbus-user-session 
    echo "You must relogin."
  fi

  # Installing fuse-overlayfs is recommended
  if [ "$DISTRIBUTION" = "debian" ] && [ "$VERSION_ID" = "11"  ]; then
   if ! dpkg -s fuse-overlayfs &> /dev/null; then 
     sudo apt-get install -y fuse-overlayfs
     echo "fuse-overlayfs installed in Debian 11"
   fi
  fi

  # Rootless docker requires version of slirp4netns greater than v0.4.0
  if ! dpkg -l slirp4netns &> /dev/null; then
    sudo apt-get install -y slirp4netns
    echo 'slirp4netns installed'
  fi
}


function disable_rootful_docker {
  print_header "Disable Rootful Docker"
  docker_user=$(ps -o user= -p "$(systemctl show -p MainPID docker | cut -d= -f2)")
  if [ "$docker_user" = "root" ]; then
    sudo systemctl disable --now $DOCKER_SERVICE $DOCKER_SOCKET 
    sudo rm /var/run/docker.sock 
    echo "Rootful docker disabled."
  else
    echo "There is no rootful docker running."
  fi
}

function post_install {
  # Post install
  if ! grep -q docker /etc/group; then
    sudo groupadd docker
  fi
  sudo usermod -aG docker "$USER"
  # newgrp docker

  # Enabe docker service
  sudo systemctl enable docker.service
  sudo systemctl enable containerd.service
}

function install_docker {
  print_header "Install Docker"
  # Install docker
  ## Uninstall old versions
  for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do sudo apt-get remove -y $pkg; done

  ## Add Docker's official GPG key:
  sudo apt-get update
  sudo apt-get install -y ca-certificates curl
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc

  ## Add the repository to Apt sources:
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update

  ## Install docker ce
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  post_install
}

function uninstall_docker {
  sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras
  sudo rm /etc/apt/sources.list.d/docker.list
  sudo rm /etc/apt/keyrings/docker.asc

  # Delete Images, Containers, Volumes and configuration files
  # sudo rm -rf /var/lib/docker
  # sudo rm -rf /var/lib/containerd
}

function install_and_configure_rootless_docker {
  print_header "Install Rootless Docker"
  # Install rootless-docker
  # Check if $DOCKER_ROOTLESS_SETUPTOOL exists. if not install it.
  if [ ! -f $DOCKER_ROOTLESS_SETUPTOOL ]; then
    sudo apt-get install -y docker-ce-rootless-extras
  fi
  # Set up a not-root user daemon
  dockerd-rootless-setuptool.sh install

  # Start docker service
  systemctl --user start docker

  # Launch the daemon on system startup, enable the systemd service and lingering
  sudo systemctl --user enable docker
  sudo loginctl enable-linger "$(whoami)"


  # [INFO] Make sure the following environment variable(s) are set (or add them to ~/.bashrc):
  BASHRC="$HOME/.bashrc"
  if ! grep -q '/usr/bin' "$BASHRC"; then
    echo -e "\nexport PATH=/usr/bin:\$PATH" >> "$BASHRC"
  fi

  #[INFO] Some applications may require the following environment variable too:
  if ! grep -q "$DOCKER_SOCKET_PATH" "$BASHRC"; then
    echo "export $DOCKER_SOCKET_PATH" >> "$BASHRC"
  fi

  source "$BASHRC"

}


function main {
  # check if docker is install
  # Disable docker if already exists
  sudo systemctl is-enabled $DOCKER_SERVICE > /dev/null 2>&1
  local is_enabled=$?
  local is_active=$(sudo systemctl is-active $DOCKER_SERVICE)

  if [ "$is_enabled" = "0" ] || [ "$is_active" = "active" ]; then
    disable_rootful_docker
  else
    install_docker
    disable_rootful_docker
  fi
  install_and_configure_rootless_docker
}

main
