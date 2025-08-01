#!/bin/bash

# Installation script for Request Tracker 5.x.x and 6.x.x
# Run this script as root (e.g., sudo ./install_rt.sh)
# Original script by HendGrow - https://hendgrow.com/ugs/hendgrow_auto_install_rt5.sh

# Exit on any error
set -e

# Ensure script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Error: This script must be run as root (use sudo)."
  exit 1
fi

# Variables
RT_DIR=""
DB_NAME=""
DB_USER="rt_user"
WEB_USER="www-data"
WEB_GROUP="www-data"

# Prompt for RT version
while true; do
  read -p "Enter RT version to install [default: 5.0.7]: " RT_VERSION
  RT_VERSION=${RT_VERSION:-5.0.7}

  # Validate format (e.g., 6.1.5)
  if [[ ! "$RT_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Invalid version format. Use format like 5.0.7 or 6.1.5."
    continue
  fi

  # Check if tarball exists
  RT_TARBALL="rt-${RT_VERSION}.tar.gz"
  RT_URL="https://download.bestpractical.com/pub/rt/release/${RT_TARBALL}"

  echo "Checking if version $RT_VERSION is available online..."
  if curl --head --silent --fail "$RT_URL" > /dev/null; then
    echo "RT version $RT_VERSION is available."
    break
  else
    echo "RT version $RT_VERSION not found at $RT_URL."
  fi
done

# Set RT directory and DB name based on version
MAJOR_VERSION="${RT_VERSION%%.*}"
RT_DIR="/opt/rt${MAJOR_VERSION}"
DB_NAME="rt${MAJOR_VERSION}"
APACHE_CONF="rt${MAJOR_VERSION}.conf"
RT_TMP_DIR="/tmp/rt-${RT_VERSION}"

# Prompt for RT Name
read -p "Enter RT name (e.g., MyRT) [default: MyRT]: " RT_NAME
RT_NAME=${RT_NAME:-MyRT}

# Prompt for domain name
read -p "Enter domain name for RT (e.g., rt.example.com) [default: rt.localhost]: " WEB_DOMAIN
WEB_DOMAIN=${WEB_DOMAIN:-rt.localhost}

# Prompt for organization name
read -p "Enter organization name (e.g., example.com) [default: example.com]: " ORG_NAME
ORG_NAME=${ORG_NAME:-example.com}

# Prompt for reverse proxy setup
read -p "Is this behind a reverse proxy? (y/n) [default: n]: " BEHIND_PROXY
BEHIND_PROXY=${BEHIND_PROXY,,}  # to lowercase
BEHIND_PROXY=${BEHIND_PROXY:-n}

# Prompt for SSL
read -p "Is SSL enabled (HTTPS)? (y/n) [default: n]: " USE_SSL
USE_SSL=${USE_SSL,,}
USE_SSL=${USE_SSL:-n}

# Set secure cookies value
SECURE_COOKIES=0
if [[ "$USE_SSL" == "y" ]]; then
  SECURE_COOKIES=1
fi

# Prompt for MySQL root password (must not be empty)
while true; do
  read -s -p "Enter MySQL root password: " MYSQL_ROOT_PASSWORD
  echo
  if [[ -z "$MYSQL_ROOT_PASSWORD" ]]; then
    echo "Password cannot be empty. Please try again."
  else
    break
  fi
done

# Prompt for RT database user password (must not be empty)
while true; do
  read -s -p "Enter RT database user password: " DB_PASS
  echo
  if [[ -z "$DB_PASS" ]]; then
    echo "Password cannot be empty. Please try again."
  else
    break
  fi
done

# Confirm settings
echo "\nConfiguration Summary:"
echo "  RT Version: $RT_VERSION"
echo "  RT Name: $RT_NAME"
echo "  Domain: $WEB_DOMAIN"
echo "  Organization: $ORG_NAME"
echo "  Behind Proxy: $BEHIND_PROXY"
echo "  SSL Enabled: $USE_SSL"
echo "  DB User: $DB_USER"
echo "  DB Name: $DB_NAME"
echo "\nPress Enter to continue or Ctrl+C to cancel."
read

# Update package list and install dependencies
echo "----->Updating package list and installing dependencies...<-----"
sleep 5
apt update
apt install -y build-essential apache2 libapache2-mod-fcgid mariadb-server mariadb-client \
  libssl-dev libexpat1-dev libgnupg-interface-perl zlib1g-dev wget tar perl cpanminus \
  libmysqlclient-dev libgd-dev graphviz

# Enable Apache modules
echo "----->Enabling Apache modules...<-----"
sleep 5
a2enmod fcgid rewrite

# Download and extract RT
echo "----->Downloading Request Tracker ${RT_VERSION}...<-----"
sleep 5 
wget -O "/tmp/${RT_TARBALL}" "${RT_URL}"
chown root "/tmp/${RT_TARBALL}"
tar -xzvf "/tmp/${RT_TARBALL}" -C /tmp
cd "${RT_TMP_DIR}"

# Configure CPAN for Perl dependencies
echo "----->Configuring CPAN...<-----"
sleep 5
cpan App::cpanminus  # Ensure cpanminus is installed
echo "----->Installing Perl dependencies...<-----"
sleep 5
./configure --with-web-user="${WEB_USER}" --with-web-group="${WEB_GROUP}"
make testdeps || true
sleep 5
make fixdeps
sleep 5
make fixdeps

# Install RT
echo "----->Installing RT ${RT_VERSION}<-----"
sleep 5
make install

# Initialize RT database
echo "----->Initializing RT5 database...<-----"
sleep 5
cd "${RT_TMP_DIR}"
make initialize-database

# Create rt DB user and grant privileges
echo "----->Create rt DB user...<-----"
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "
  ALTER USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
  GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
  FLUSH PRIVILEGES;
"

if [ $? -eq 0 ]; then
  echo "Database user $DB_USER created successfully"
else
  echo "Failed to create database user"
fi

# Configure Apache
cat > /etc/apache2/sites-available/${APACHE_CONF} <<EOF
<VirtualHost *:80>
    ServerName ${WEB_DOMAIN}
    ServerAdmin webmaster@localhost
    DocumentRoot ${RT_DIR}/share/html
    AddDefaultCharset UTF-8
    ScriptAlias / ${RT_DIR}/sbin/rt-server.fcgi/
    <Location />
        Require all granted
        Options +ExecCGI
        AddHandler fcgid-script .fcgi
    </Location>
    ErrorLog \${APACHE_LOG_DIR}/rt${MAJOR_VERSION}_error.log
    CustomLog \${APACHE_LOG_DIR}/rt${MAJOR_VERSION}_access.log combined
</VirtualHost>
EOF

# Update RT configuration
echo "----->Updating RT site configuration<-----"
sleep 5
cat >> "${RT_DIR}/etc/RT_SiteConfig.pm" <<EOF
Set( \$rtname, '${RT_NAME}' );
Set( \$Organization, '${ORG_NAME}' );
Set( \$WebDomain, '${WEB_DOMAIN}' );
Set( \$DatabaseName, '${DB_NAME}' );
Set( \$DatabaseUser, '${DB_USER}' );
Set( \$DatabasePassword, '${DB_PASS}' );
Set( \$WebSecureCookies, ${SECURE_COOKIES} );
EOF

if [[ "$BEHIND_PROXY" == "y" ]]; then
  echo "Set( \$CanonicalizeRedirectURLs, '1' );" >> "${RT_DIR}/etc/RT_SiteConfig.pm"
  echo "Set( \$CanonicalizeURLsInFeeds, '1' );" >> "${RT_DIR}/etc/RT_SiteConfig.pm"
fi

if [[ "$USE_SSL" == "y" ]]; then
  echo "Set( \$WebPort, 443 );" >> "${RT_DIR}/etc/RT_SiteConfig.pm"
fi

# Enable RT site and disable default site
echo "----->Enable RT site and disable default site<-----"
sleep 5
a2ensite ${APACHE_CONF}
a2dissite 000-default
systemctl restart apache2

# Cleanup
rm -rf "$RT_TMP_DIR"
rm -f "/tmp/${RT_TARBALL}"

echo "Temporary installation files removed."

# Final instructions
echo "----->Installation complete!<-----"
echo "Access RT at http://${WEB_DOMAIN} or http://your-server-ip-address with default credentials: root / password"
echo "Next steps:"
echo "1. Change the default root password in the RT web interface."
echo "2. Configure email settings in ${RT_DIR}/etc/RT_SiteConfig.pm."
echo "3. Set up a proper domain name and SSL (recommended for production)."
echo "4. Adjust firewall rules if necessary (e.g., ufw allow 80)."
echo "5. See https://hendgrow.com/2025/03/22/45-request-tracker-one-script-install/ for further security guidance."
echo "6. Subscribe: youtube.com/HendGrow | Follow: x.com/HendGrow"

exit 0
