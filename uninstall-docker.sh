#!/bin/bash - 
#===============================================================================
#
#          FILE: uninstall-docker.sh
# 
#         USAGE: ./uninstall-docker.sh 
# 
#   DESCRIPTION: 
# 
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: YOUR NAME (), 
#  ORGANIZATION: 
#       CREATED: 04/06/2025 01:46
#      REVISION:  ---
#===============================================================================

set -o nounset                              # Treat unset variables as an error

# Uninstall the Docker Engine, CLI, containerd, and Docker Compose packages
sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras

# Remove source list and keyrings
sudo rm /etc/apt/sources.list.d/docker.list
sudo rm /etc/apt/keyrings/docker.asc

# Update packages
sudo apt-get update
