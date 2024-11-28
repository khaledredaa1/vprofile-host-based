#!/bin/bash

# Update OS with the latest patches and install Python3
# yum update -y
dnf install epel-release -y
dnf install python3 -y   # Required for ansible

# Install RabbitMQ
dnf -y install centos-release-rabbitmq-38
dnf --enablerepo=centos-rabbitmq-38 -y install rabbitmq-server

# Start and enable RabbitMQ
systemctl enable --now rabbitmq-server

# Configure RabbitMQ user and permissions
echo "[{rabbit, [{loopback_users, []}]}]." > /etc/rabbitmq/rabbitmq.config
rabbitmqctl add_user test test
rabbitmqctl set_user_tags test administrator

# Restart RabbitMQ to apply changes
systemctl restart rabbitmq-server

# Configure firewall for RabbitMQ
systemctl start firewalld
systemctl enable firewalld
firewall-cmd --add-port=5672/tcp --permanent
firewall-cmd --reload

######
######
######
######

### RabbitMQ Exporter Setup ###

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

# Create directory for RabbitMQ Exporter
mkdir -p ~/rabbitmq_exporter && cd ~/rabbitmq_exporter

# Docker Compose file for RabbitMQ Exporter
cat <<EOL > docker-compose.yml
services:
  rabbitmq_exporter:
    image: kbudde/rabbitmq-exporter:latest
    container_name: rabbitmq-exporter
    restart: unless-stopped
    environment:
      RABBITMQ_USER: "username"
      RABBITMQ_PASSWORD: "password"
      RABBITMQ_URL: "http://rabbitmq-server-hostname:15672"
    ports:
      - "9419:9419"
EOL

# Start RabbitMQ Exporter
docker compose up -d

# Ensure passwordless sudo for the vagrant user (optional, but useful for automation)
echo 'vagrant ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/vagrant
