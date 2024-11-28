#!/bin/bash

# Update OS with the latest patches and install Python3
#yum update -y
dnf install epel-release -y
dnf install python3 -y   # Required for ansible

# Install Java, and dependencies
dnf -y install java-11-openjdk java-11-openjdk-devel git maven wget

# Download and extract Tomcat
cd /tmp
wget https://archive.apache.org/dist/tomcat/tomcat-9/v9.0.75/bin/apache-tomcat-9.0.75.tar.gz
tar xzvf apache-tomcat-9.0.75.tar.gz
useradd --home-dir /usr/local/tomcat --shell /sbin/nologin tomcat
cp -r /tmp/apache-tomcat-9.0.75/* /usr/local/tomcat/
chown -R tomcat:tomcat /usr/local/tomcat/

# Configure Tomcat as a systemd service
cat <<EOF > /etc/systemd/system/tomcat.service
[Unit]
Description=Tomcat
After=network.target

[Service]
User=tomcat
WorkingDirectory=/usr/local/tomcat
Environment=JRE_HOME=/usr/lib/jvm/jre
Environment=JAVA_HOME=/usr/lib/jvm/jre
Environment=CATALINA_HOME=/usr/local/tomcat
ExecStart=/usr/local/tomcat/bin/catalina.sh run
ExecStop=/usr/local/tomcat/bin/shutdown.sh
SyslogIdentifier=tomcat-%i

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd, start and enable Tomcat
systemctl daemon-reload
systemctl start tomcat
systemctl enable tomcat

# Configure firewall for Tomcat
systemctl start firewalld
systemctl enable firewalld
firewall-cmd --zone=public --add-port=8080/tcp --permanent
firewall-cmd --reload

# Build and deploy the application
git clone -b main https://github.com/hkhcoder/vprofile-project.git
cd vprofile-project
mvn install
systemctl stop tomcat
rm -rf /usr/local/tomcat/webapps/ROOT*
cp target/vprofile-v2.war /usr/local/tomcat/webapps/ROOT.war
chown -R tomcat:tomcat /usr/local/tomcat/webapps
systemctl start tomcat

######
######
######
######

### JMX Exporter Setup ###

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

# Create directory for JMX Exporter
mkdir -p ~/jmx_exporter && cd ~/jmx_exporter

# Docker Compose file for JMX Exporter
cat <<EOF > docker-compose.yml
services:
  jmx-exporter:
    image: bitnami/jmx-exporter:latest
    container_name: jmx_exporter
    environment:
      - JMX_HOST= 8080                           # Application host
      - JMX_PORT= 5556                           # Application JMX port
      - JVM_OPTS=-Xms512m -Xmx512m
    ports:
      - "5556:5556"                              # Exposing JMX Exporter port
    volumes:
      - ./config.yml:/opt/bitnami/jmx-exporter/conf/config.yml
    restart: unless-stopped

volumes:
  jmx_exporter_data:
EOF

# Create a sample JMX Exporter configuration file
cat <<EOF > config.yml
---
startDelaySeconds: 0
hostPort: 8080:5556                              # Application host:Application JMX port
ssl: false
lowercaseOutputName: true
lowercaseOutputLabelNames: true
whitelistObjectNames:
  - "java.lang:type=Memory"
  - "java.lang:type=GarbageCollector,name=*"
EOF

# Start JMX Exporter service using Docker Compose
docker compose up -d

# Ensure passwordless sudo for the vagrant user (optional, but useful for automation)
echo 'vagrant ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/vagrant
