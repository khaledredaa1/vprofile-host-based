#!/bin/bash

# Update OS with the latest patches and install Python3
#yum update -y
dnf install epel-release -y
dnf install python3 -y   # Required for ansible

# Install git and MariaDB
yum install -y git mariadb-server

# Start and enable MariaDB
systemctl start mariadb
systemctl enable mariadb

# Run MySQL secure installation
mysql_secure_installation <<EOF

Y
admin123
admin123
Y
Y
n
Y
Y
EOF

# Set up the database and user
mysql -u root -padmin123 <<EOF
CREATE DATABASE accounts;
GRANT ALL PRIVILEGES ON accounts.* TO 'admin'@'%' IDENTIFIED BY 'admin123';
FLUSH PRIVILEGES;
EOF

# Download project source code and initialize database
git clone -b main https://github.com/hkhcoder/vprofile-project.git
cd vprofile-project
mysql -u root -padmin123 accounts < src/main/resources/db_backup.sql
systemctl restart mariadb

# configure firewall for mariadb
systemctl start firewalld
systemctl enable firewalld
firewall-cmd --zone=public --add-port=3306/tcp --permanent
firewall-cmd --reload

######
######
######
######

### Mariadb Exporter Setup ###

# Update package index
#sudo dnf -y update

# Install required packages for Docker installation
sudo dnf -y install dnf-plugins-core

# Add Docker’s official repository
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# Install Docker Engine
sudo dnf -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Start and enable Docker service
sudo systemctl start docker
sudo systemctl enable docker

# Add current user to the Docker group to run Docker without sudo
sudo usermod -aG docker $USER
newgrp docker # Refresh group membership without requiring logout

# Create directory for MariaDB Exporter
mkdir -p ~/mariadb_exporter && cd ~/mariadb_exporter

# Docker Compose file for MariaDB Exporter
cat <<EOL > docker-compose.yml
services:
  mariadb_exporter:
    image: prom/mysqld-exporter:latest
    container_name: mariadb-exporter
    restart: unless-stopped
    environment:
      DATA_SOURCE_NAME: "user:password@tcp(mariadb-server-hostname:3306)/"
    ports:
      - "9104:9104"
EOL

# Start MariaDB Exporter
docker compose up -d

# Ensure passwordless sudo for the vagrant user (optional, but useful for automation)
echo 'vagrant ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/vagrant
