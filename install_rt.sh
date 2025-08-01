#!/bin/bash

# HendGrow automation - Installation script for Request Tracker 5
# Reach out vi: https://www.youtube.com/@HendGrow | https://x.com/HendGrow
# Run this script as root (e.g., sudo ./hendgrow_auto_install_rt5.sh)

# Exit on any error
set -e

# Variables
RT_VERSION="5.0.7"
RT_TARBALL="rt-${RT_VERSION}.tar.gz"
RT_URL="https://download.bestpractical.com/pub/rt/release/${RT_TARBALL}"
RT_DIR="/opt/rt5"
DB_NAME="rt5"
DB_USER="rt_user"
DB_PASS="ChangeMePlease12345"  #You must change this and update accordingly to a secure password after the install !!!!!
MYSQL_ROOT_PASSWORD="ChangeMePlease12345"  # You must change this and update accordingly to a secure password after the install !!!!!
WEB_USER="www-data"
WEB_GROUP="www-data"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Error: This script must be run as root (use sudo)."
  exit 1
fi

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
chown root "/tmp/rt-5.0.7.tar.gz"
tar -xzvf "/tmp/${RT_TARBALL}" -C /tmp
cd "/tmp/rt-5.0.7"

# Configure CPAN for Perl dependencies
echo "----->Configuring CPAN...<-----"
sleep 5
cpan App::cpanminus  # Ensure cpanminus is installed
echo "----->Installing Perl dependencies...<-----"
sleep 5
./configure --with-web-user="${WEB_USER}" --with-web-group="${WEB_GROUP}"
make testdeps || true  # Check dependencies, continue even if some are missing
sleep 5
make fixdeps           # Install missing dependencies (will require interaction)
sleep 5
make fixdeps           # 2nd run for Install missing dependencies (may require interaction)

# Install RT
echo "----->Installing RT 5.0.7<-----"
sleep 5
make install

# Initialize RT database
echo "----->Initializing RT5 database...<-----"
sleep 5
cd "/tmp/rt-5.0.7/"
make initialize-database
cd "/tmp/rt-5.0.7"

# Create rt DB user and grant privileges
echo "----->Create rt DB user...<-----"
# Create user and grant privileges
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "
  ALTER USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
  GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
  FLUSH PRIVILEGES;
"

# Check if user was created
if [ $? -eq 0 ]; then
    echo "Database user $DB_USER created successfully"
else
    echo "Failed to create database user"
fi


# Configure Apache
echo "----->Configuring Apache for RT5<-----"

cat > /etc/apache2/sites-available/rt5.conf <<EOF
<VirtualHost *:80>
    ServerName rt.localhost
    ServerAdmin webmaster@localhost
    DocumentRoot ${RT_DIR}/share/html
    AddDefaultCharset UTF-8
    ScriptAlias / ${RT_DIR}/sbin/rt-server.fcgi/
    <Location />
        Require all granted
        Options +ExecCGI
        AddHandler fcgid-script .fcgi
    </Location>
    ErrorLog \${APACHE_LOG_DIR}/rt5_error.log
    CustomLog \${APACHE_LOG_DIR}/rt5_access.log combined
</VirtualHost>
EOF

# Enable RT site and disable default site
echo "----->Enable RT site and disable default site<-----"
sleep 5
a2ensite rt5
a2dissite 000-default
systemctl restart apache2

# Update RT configuration
echo "----->Updating RT site configuration<-----"
sleep 5
cat >> "${RT_DIR}/etc/RT_SiteConfig.pm" <<EOF
Set( \$rtname, 'MyRT' );
Set( \$Organization, 'example.com' );
Set( \$WebDomain, 'rt.localhost' );
Set( \$DatabaseName, '${DB_NAME}' );
Set( \$DatabaseUser, '${DB_USER}' );
Set( \$DatabasePassword, '${DB_PASS}' );
Set( \$WebSecureCookies, '0'); 
EOF

#Restart Apache
echo "----->Restart Apache<-----"
sudo systemctl restart apache2

# Final instructions
echo "----->Installation complete!<-----"
echo "Access RT at http://rt.localhost or http://your-servers-ip-address with default credentials: root / password"
echo "Next steps:"
echo "1. Change the default root password in the RT web interface."
echo "2. Configure email settings in ${RT_DIR}/etc/RT_SiteConfig.pm."
echo "3. Set up a proper domain name and SSL (recommended for production)."
echo "4. Adjust firewall rules if necessary (e.g., ufw allow 80)."
echo "5, Refer to the guide on our site for more links on how to secure your server https://hendgrow.com/2025/03/22/45-request-tracker-one-script-install/"
echo "6, Consider subscribing to our channel youtube.com/HendGrow & following us on x.com/HendGrow" 

exit 0
