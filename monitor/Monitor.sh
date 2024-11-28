#!/bin/bash 

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

# Create configuration directory for Prometheus
mkdir -p ~/monitor_config && cd ~/monitor_config

# Define Prometheus configuration
cat <<EOF > ~/monitor_config/prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    scrape_interval: 5s
    static_configs:
      - targets: ['192.168.56.70:9090']  # Localhost IP & Prometheus port

  - job_name: 'mysql_exporter'
    static_configs:
      - targets: ['192.168.56.10:9104']  # d01 IP & MySQL Exporter port

  - job_name: 'memcached_exporter'
    static_configs:
      - targets: ['192.168.56.20:9150']  # mc01 IP & Memecached Exporter port

  - job_name: 'rabbitmq_exporter'
    static_configs:
      - targets: ['192.168.56.30:9419']  # rmq01 IP & RabbitMQ Exporter port

  - job_name: 'jmx_exporter'
    static_configs:
      - targets: ['192.168.56.40:5556']  # app01 IP & JMX Exporter port

  - job_name: 'nginx_exporter'
    static_configs:
      - targets: ['192.168.56.50:9113']  # web01 IP & NGINX Exporter port

  - job_name: 'node_exporter'
    static_configs:
      - targets: ['192.168.56.60:9100']  # master01 IP & Node Exporter port
EOF

# Create Docker Compose file for Prometheus and Grafana
# Bind mount a local file to a specific location within a container through prom volume
cat <<EOL > ~/monitor_config/docker-compose.yml
services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    volumes:
      - ~/monitor_config/prometheus.yml:/etc/prometheus/prometheus.yml
    ports:
      - "9090:9090"

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    ports:
      - "3000:3000"
    volumes:
      - grafana_data:/var/lib/grafana

volumes:
  grafana_data:
EOL

# Change to the config directory
cd ~/monitor_config

# Start Prometheus and Grafana
docker compose up -d

# Ensure passwordless sudo for the vagrant user (optional, but useful for automation)
echo 'vagrant ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/vagrant
