#!/bin/bash

# Update OS with the latest patches and install Python3
#yum update -y
dnf install epel-release -y
dnf install python3 -y   # Required for ansible

# Install Memcache
dnf install -y memcached

# Start and enable Memcache
systemctl start memcached
systemctl enable memcached

# Update Memcache configuration to allow remote access
sed -i 's/127.0.0.1/0.0.0.0/g' /etc/sysconfig/memcached
systemctl restart memcached

# Configure firewall for Memcache ports
systemctl start firewalld
systemctl enable firewalld
firewall-cmd --add-port=11211/tcp --permanent
firewall-cmd --add-port=11111/udp --permanent
firewall-cmd --reload

######
######
######
######

### Memcached Exporter Setup ###

# Update package index
#dnf -y update

# Install required packages for Docker installation
dnf -y install dnf-plugins-core

# Add Docker’s official repository
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# Install Docker Engine
dnf -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Start and enable Docker service
systemctl start docker
systemctl enable docker

# Add current user to the Docker group to run Docker without sudo
usermod -aG docker $USER
newgrp docker # Refresh group membership without requiring logout

# Create directory for Memcached Exporter
mkdir -p ~/memcached_exporter && cd ~/memcached_exporter

# Docker Compose file for Memcached Exporter
cat <<EOL > docker-compose.yml
services:
  memcached_exporter:
    image: prom/memcached-exporter:latest
    container_name: memcached-exporter
    restart: unless-stopped
    ports:
      - "9150:9150"
EOL

# Start Memcached Exporter
docker compose up -d

# Ensure passwordless sudo for the vagrant user (optional, but useful for automation)
echo 'vagrant ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/vagrant
