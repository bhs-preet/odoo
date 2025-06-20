#!/bin/bash

# Configuration variables
DOMAIN="oddev.boathire.com.au"
FOLDER_NAME="oddev"
RUN_APT_UPDATE="no"  # Set to "yes" only if you want to run apt-get update
SETUP_SSL="yes"      # Set to "yes" to configure SSL with Let's Encrypt
MODE="install"       # Set to "install" or "remove"
ODOO_VERSION="18.0"  # Latest production version of Odoo
DB_PASSWORD="$(openssl rand -base64 32)"  # Random password for PostgreSQL
ODOO_MASTER_PASSWORD="$(openssl rand -base64 32)"  # Random master password for Odoo

# Exit on error
set -e

# Function to print status messages
print_status() {
    echo "==> $1"
}

# Function to remove the service
remove_service() {
    print_status "Removing Odoo service..."
    
    # Stop and remove Docker containers
    if docker ps -a | grep -q odoo; then
        print_status "Stopping and removing Docker containers..."
        cd /var/www/$FOLDER_NAME
        docker-compose down -v
    fi
    
    # Remove Apache configuration
    if [ -f "/etc/apache2/sites-available/$DOMAIN.conf" ]; then
        print_status "Removing Apache configuration..."
        a2dissite $DOMAIN.conf
        rm /etc/apache2/sites-available/$DOMAIN.conf
    fi
    
    # Remove SSL configuration if it exists
    if [ -f "/etc/apache2/sites-available/${DOMAIN}-le-ssl.conf" ]; then
        print_status "Removing SSL Apache configuration..."
        a2dissite ${DOMAIN}-le-ssl.conf
        rm /etc/apache2/sites-available/${DOMAIN}-le-ssl.conf
    fi
    
    # Remove SSL certificate if it exists
    if [ -d "/etc/letsencrypt/live/$DOMAIN" ]; then
        print_status "Removing SSL certificate..."
        certbot delete --cert-name $DOMAIN
    fi
    
    # Remove directory
    if [ -d "/var/www/$FOLDER_NAME" ]; then
        print_status "Removing installation directory..."
        rm -rf /var/www/$FOLDER_NAME
    fi
    
    # Reload Apache
    print_status "Reloading Apache..."
    systemctl reload apache2
    
    print_status "Removal complete!"
    exit 0
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# Handle removal mode
if [ "$MODE" = "remove" ]; then
    remove_service
fi

# Install Docker and dependencies if not present
if ! command -v docker &> /dev/null; then
    print_status "Installing Docker and dependencies..."
    if [ "$RUN_APT_UPDATE" = "yes" ]; then
        print_status "Running apt-get update (this may take a while)..."
        apt-get update
    else
        print_status "Skipping apt-get update for safety. If Docker installation fails, set RUN_APT_UPDATE=yes"
    fi
    
    # All system dependencies are already installed, so we can proceed with Docker installation
    print_status "System dependencies are already installed"
    
    # Install Docker
    print_status "Installing Docker..."
    apt-get install -y docker.io
    
    # Install Docker Compose
    print_status "Installing Docker Compose..."
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    # Start and enable Docker
    print_status "Starting Docker service..."
    systemctl enable docker
    systemctl start docker
fi

# Create directory structure
print_status "Creating directory structure..."
mkdir -p /var/www/$FOLDER_NAME
cd /var/www/$FOLDER_NAME

# Create docker-compose.yml
print_status "Creating docker-compose.yml..."
cat > docker-compose.yml << EOL
version: '3'
services:
  db:
    image: postgres:15
    container_name: odoo-db
    environment:
      - POSTGRES_DB=postgres
      - POSTGRES_PASSWORD=$DB_PASSWORD
      - POSTGRES_USER=odoo
      - PGDATA=/var/lib/postgresql/data/pgdata
    volumes:
      - odoo-db-data:/var/lib/postgresql/data/pgdata
    restart: always

  odoo:
    image: odoo:$ODOO_VERSION
    container_name: odoo
    depends_on:
      - db
    ports:
      - "8069:8069"
    environment:
      - HOST=db
      - USER=odoo
      - PASSWORD=$DB_PASSWORD
    volumes:
      - odoo-web-data:/var/lib/odoo
      - ./config:/etc/odoo
      - ./addons:/mnt/extra-addons
    restart: always

volumes:
  odoo-web-data:
  odoo-db-data:
EOL

# Create Odoo configuration directory and file
print_status "Creating Odoo configuration..."
mkdir -p config addons
cat > config/odoo.conf << EOL
[options]
addons_path = /mnt/extra-addons,/usr/lib/python3/dist-packages/odoo/addons
admin_passwd = $ODOO_MASTER_PASSWORD
csv_internal_sep = ,
data_dir = /var/lib/odoo
db_host = db
db_port = 5432
db_user = odoo
db_password = $DB_PASSWORD
dbfilter = .*
demo = {}
email_from = False
geoip_database = /usr/share/GeoIP/GeoLite2-City.mmdb
http_enable = True
http_interface = 
http_port = 8069
import_partial = 
limit_memory_hard = 2684354560
limit_memory_soft = 2147483648
limit_request = 8192
limit_time_cpu = 60
limit_time_real = 120
limit_time_real_cron = -1
list_db = True
log_db = False
log_db_level = warning
log_handler = :INFO
log_level = info
logfile = 
longpolling_port = 8072
max_cron_threads = 2
osv_memory_age_limit = False
osv_memory_count_limit = False
pg_path = 
pidfile = 
proxy_mode = True
reportgz = False
screencasts = 
screenshots = /tmp/odoo_tests
server_wide_modules = base,web
smtp_password = False
smtp_port = 587
smtp_server = localhost
smtp_ssl = False
smtp_user = False
syslog = False
test_enable = False
test_file = 
test_tags = None
transient_age_limit = 1.0
translate_modules = ['all']
unaccent = False
upgrade_path = 
without_demo = False
workers = 0
EOL

# Create Apache configuration
print_status "Creating Apache configuration..."
cat > /etc/apache2/sites-available/$DOMAIN.conf << EOL
<VirtualHost *:80>
    ServerName $DOMAIN
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/$FOLDER_NAME

    ProxyPreserveHost On
    ProxyPass / http://localhost:8069/
    ProxyPassReverse / http://localhost:8069/
    
    # Handle WebSocket connections for longpolling
    ProxyPass /longpolling/ http://localhost:8072/
    ProxyPassReverse /longpolling/ http://localhost:8072/

    ErrorLog \${APACHE_LOG_DIR}/$DOMAIN-error.log
    CustomLog \${APACHE_LOG_DIR}/$DOMAIN-access.log combined
</VirtualHost>
EOL

# Enable required Apache modules
print_status "Enabling required Apache modules..."
a2enmod proxy
a2enmod proxy_http
a2enmod proxy_wstunnel
a2enmod ssl

# Enable the site
print_status "Enabling the site..."
a2ensite $DOMAIN.conf

# Start Odoo
print_status "Starting Odoo (this may take a few minutes)..."
docker-compose up -d

# Wait for services to be ready
print_status "Waiting for services to start..."
sleep 30

# Setup SSL if enabled
if [ "$SETUP_SSL" = "yes" ]; then
    print_status "Setting up SSL with Let's Encrypt..."
    
    # Check if certbot is installed
    if ! command -v certbot &> /dev/null; then
        print_status "Installing certbot..."
        if [ "$RUN_APT_UPDATE" = "yes" ]; then
            apt-get update
        fi
        apt-get install -y certbot python3-certbot-apache
    fi
    
    # Obtain SSL certificate
    print_status "Obtaining SSL certificate for $DOMAIN..."
    certbot --apache -d $DOMAIN --non-interactive --agree-tos --email webmaster@$DOMAIN
    
    # Update Apache configuration to force HTTPS
    print_status "Updating Apache configuration to force HTTPS..."
    sed -i 's/<VirtualHost \*:80>/<VirtualHost *:80>\n    RewriteEngine On\n    RewriteCond %{HTTPS} off\n    RewriteRule ^(.*)$ https:\/\/%{HTTP_HOST}%{REQUEST_URI} [L,R=301]/' /etc/apache2/sites-available/$DOMAIN.conf
fi

# Reload Apache
print_status "Reloading Apache..."
systemctl reload apache2

# Save credentials to file
print_status "Saving credentials..."
cat > /var/www/$FOLDER_NAME/CREDENTIALS.txt << EOL
=== ODOO INSTALLATION CREDENTIALS ===
Domain: $DOMAIN
Database Password: $DB_PASSWORD
Odoo Master Password: $ODOO_MASTER_PASSWORD

IMPORTANT: Keep these credentials secure!
The master password is required for database management operations.
EOL

chmod 600 /var/www/$FOLDER_NAME/CREDENTIALS.txt

print_status "Installation complete!"
if [ "$SETUP_SSL" = "yes" ]; then
    print_status "Odoo is now accessible at https://$DOMAIN"
else
    print_status "Odoo is now accessible at http://$DOMAIN"
    print_status "To set up SSL later, run: certbot --apache -d $DOMAIN"
fi
print_status "Credentials have been saved to /var/www/$FOLDER_NAME/CREDENTIALS.txt"
print_status "Default login: admin / admin (change this immediately after first login)" 