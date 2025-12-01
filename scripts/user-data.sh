#!/bin/bash
set -e

# Update system
apt-get update -y
apt-get upgrade -y

# Install Node.js 18.x
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

# Install Git
apt-get install -y git

# Install Nginx
apt-get install -y nginx

# Install MySQL client
apt-get install -y mysql-client

# Clone the application
cd /home/ubuntu
git clone https://github.com/pravinmishraaws/theepicbook.git
cd theepicbook

# Create .env file with database configuration
cat > .env << ENVEOF
DB_HOST=${db_host}
DB_NAME=${db_name}
DB_USER=${db_username}
DB_PASSWORD=${db_password}
PORT=${app_port}
ENVEOF

# Install application dependencies
npm install

# Configure Nginx as reverse proxy
cat > /etc/nginx/sites-available/default << NGINXEOF
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:${app_port};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
NGINXEOF

# Restart Nginx
systemctl restart nginx
systemctl enable nginx

# Create systemd service for the application
cat > /etc/systemd/system/epicbook.service << SERVICEEOF
[Unit]
Description=EpicBook Node.js Application
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/theepicbook
Environment=NODE_ENV=production
ExecStart=/usr/bin/node server.js
Restart=on-failure

[Install]
WantedBy=multi-user.target
SERVICEEOF

# Set proper ownership
chown -R ubuntu:ubuntu /home/ubuntu/theepicbook

# Start the application service
systemctl daemon-reload
systemctl enable epicbook
systemctl start epicbook

# Wait for database to be ready and initialize
sleep 30