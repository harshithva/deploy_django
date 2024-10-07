#!/bin/bash

# Check if user provided all required arguments
if [ "$#" -ne 3 ]; then
    echo "Usage: ./deploy_django.sh <project_path> <project_name> <server_ip_or_domain>"
    exit 1
fi

PROJECT_PATH=$1
PROJECT_NAME=$2
SERVER_IP_OR_DOMAIN=$3

# Update and install necessary packages
sudo apt update && sudo apt install -y python3-pip python3-venv nginx

# Allow Nginx through firewall
sudo ufw allow 'Nginx Full'

# Navigate to the project directory
cd $PROJECT_PATH || { echo "Project path not found! Exiting..."; exit 1; }

# Set up virtual environment and activate it
python3 -m venv venv
source venv/bin/activate

# Install Django and Gunicorn
pip install django gunicorn

# Collect static files (if applicable)
python manage.py collectstatic --noinput

# Start Gunicorn server (in background)
gunicorn --workers 3 --bind 0.0.0.0:8000 $PROJECT_NAME.wsgi:application &

# Create an Nginx configuration file
sudo tee /etc/nginx/sites-available/$PROJECT_NAME <<EOF
server {
    listen 80;
    server_name $SERVER_IP_OR_DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /static/ {
        alias $PROJECT_PATH/static/;
    }

    location /media/ {
        alias $PROJECT_PATH/media/;
    }
}
EOF

# Enable the Nginx configuration
sudo ln -s /etc/nginx/sites-available/$PROJECT_NAME /etc/nginx/sites-enabled/

# Restart Nginx
sudo systemctl restart nginx

echo "Deployment complete! Your Django app is now running on $SERVER_IP_OR_DOMAIN"
