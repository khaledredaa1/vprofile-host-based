#!/bin/bash

# Update OS with the latest patches and install Python3
apt-get update -y
apt-get upgrade -y
apt-get install python3 -y   # Required for ansible

# Install Nginx
apt-get install -y nginx

# Configure Nginx for reverse proxy
cat <<EOF > /etc/nginx/sites-available/vproapp
upstream vproapp {
    server app01:8080;
}

server {
    listen 80;
    location / {
        proxy_pass http://vproapp;
    }
}
EOF

# Enable the configuration and restart Nginx
rm -f /etc/nginx/sites-enabled/default
ln -s /etc/nginx/sites-available/vproapp /etc/nginx/sites-enabled/vproapp
systemctl restart nginx

######
######
######
######

### NGINX Exporter Setup ###

# Update package index and install Docker
apt-get update -y
sudo apt-get -y install curl lsb-release gnupg apt-transport-https ca-certificates software-properties-common

# Install Docker and Docker Compose
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/docker.gpg
add-apt-repository "deb [arch=$(dpkg --print-architecture)] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update -y
apt-get -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Enable Docker and start it
systemctl enable docker
systemctl start docker

# Add the current user to the Docker group to allow running Docker without sudo
usermod -aG docker $USER
newgrp docker  # Refresh group membership without requiring logout

# Create directory for Nginx Exporter
mkdir -p ~/nginx_exporter && cd ~/nginx_exporter

# Docker Compose file for Nginx Exporter
cat <<EOL > docker-compose.yml
services:
  nginx_exporter:
    image: nginx/nginx-prometheus-exporter:latest
    container_name: nginx-exporter
    restart: unless-stopped
    ports:
      - "9113:9113"
EOL

# Start NGINX Exporter
docker compose up -d

# Ensure passwordless sudo for the vagrant user (optional, but useful for automation)
echo 'vagrant ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/vagrant
