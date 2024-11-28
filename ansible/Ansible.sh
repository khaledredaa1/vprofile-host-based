#!/bin/bash

# Install EPEL repository, Ansible, and Python
# yum update -y
dnf install epel-release -y
dnf install ansible -y
dnf install python3 -y

# Configure Ansible settings
bash -c 'cat <<EOF > /etc/ansible/ansible.cfg
[defaults]
remote_port       = 22
remote_user       = vagrant
host_key_checking = False
roles_path        = /home/vagrant/vproject

[privilege_escalation]
become          = True
become_method   = sudo
become_user     = root
become_ask_pass = False

EOF'

# Create Ansible hosts file
bash -c 'cat <<EOF > /etc/ansible/hosts
 [vprofile]
   db01
   mc01
   rmq01
   app01
   web01
 [mariadb]
   db01
 [memcache]
   mc01
 [rabbitmq]
   rmq01
 [tomcat]
   app01
 [nginx]
   web01
 [monitor]
   monitor01
EOF'

# Ensure passwordless sudo for the vagrant user
echo 'vagrant ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/vagrant

######
######
######
######

## Memcached Exporter Setup ##

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

# Create directory for Node Exporter
mkdir -p ~/node_exporter && cd ~/node_exporter

# Create Docker Compose file for Node Exporter
cat <<EOL > docker-compose.yml
services:
  node_exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    restart: unless-stopped
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    ports:
      - "9100:9100"
EOL

# Start Node Exporter
docker compose up -d
