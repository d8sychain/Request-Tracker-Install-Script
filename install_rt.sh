#!/bin/bash

# Installation script for Request Tracker 5.x.x and 6.x.x (may also install older than 5, untested)
# Run this script as root (e.g., sudo ./install_rt.sh)
# Original script by HendGrow - https://hendgrow.com/ugs/hendgrow_auto_install_rt5.sh

# ===== Exit If Any Command Returns a Not 0 Status =====
set -e

# ===== Save Original stdout/stderr for Later Restoration =====
exec 3>&1 4>&2

# ===== Logging Setup =====
LOG_FILE="/var/log/rt_install.log"
START_TIME=$(date +%s)
exec > >(tee -a "$LOG_FILE") 2>&1
SLEEP_TIME=5

# ===== Print Message If The Script Fails =====
trap 'ret=$?; if [ $ret -ne 0 ]; then echo "Script failed. The log for this script can be found at $LOG_FILE"; fi' EXIT

# ===== Test For Required Commands =====
for cmd in curl wget mysql; do
  command -v "$cmd" >/dev/null || {
    echo "[ERROR] Required command '$cmd' not found. Please install it first."
    exit 1
  }
done

# ===== Start of Installation log =====
echo "[INFO] ($(date)) The script has started"
sleep $SLEEP_TIME

# ===== Root Privilege Check =====
if [ "$EUID" -ne 0 ]; then
  echo "[ERROR] ($(date)) This script must be run as root."
  exit 1
fi

# ===== Default Variable Declarations =====
RT_DIR=""
DB_NAME=""
DB_USER="rt_user"
WEB_USER="www-data"
WEB_GROUP="www-data"

# ===== Validate RT Download URL Base =====
RT_BASE_URL="https://download.bestpractical.com/pub/rt/release/"
if ! curl --head --silent --fail "$RT_BASE_URL" > /dev/null; then
  echo "[ERROR] ($(date)) Cannot reach RT release base URL: $RT_BASE_URL"
  echo "[ERROR] Please check your internet connection or the upstream source."
  exit 1
fi

# ===== Function: Get Latest RT Version =====
get_latest_rt_version() {
  curl -s "$RT_BASE_URL" | \
    grep -oE 'rt-[0-9]+\.[0-9]+\.[0-9]+\.tar\.gz' | \
    sed 's/^rt-\(.*\)\.tar\.gz$/\1/' | \
    sort -V | tail -n 1
}

# ===== Prompt for RT Version with Retry Limit =====
MAX_RETRIES=5
attempt=1
while (( attempt <= MAX_RETRIES )); do
  read -p "Enter RT version to install [leave blank for latest]: " RT_VERSION
  if [[ -z "$RT_VERSION" ]]; then
    RT_VERSION=$(get_latest_rt_version)
    if [[ -z "$RT_VERSION" ]]; then
      echo "[ERROR] ($(date)) Failed to fetch latest RT version."
      exit 1
    fi
    echo "[INFO] ($(date)) Using latest RT version: $RT_VERSION"
    sleep $SLEEP_TIME
  fi

  # ===== Validate Version Format (x.y.z) =====
  if [[ ! "$RT_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "[WARN] ($(date)) Invalid version format."
    ((attempt++))
    if (( attempt > MAX_RETRIES )); then
      echo "[ERROR] ($(date)) Maximum retries exceeded. Exiting..."
      exit 1
    fi
    continue
  fi

  RT_TARBALL="rt-${RT_VERSION}.tar.gz"
  RT_URL="${RT_BASE_URL}${RT_TARBALL}"

  # ===== Check if RT_VERSION Is Available / Valid =====
  echo "[INFO] ($(date)) Checking if version $RT_VERSION is available..."
  sleep $SLEEP_TIME
  if curl --head --silent --fail "$RT_URL" > /dev/null; then
    echo "[INFO] ($(date)) RT version $RT_VERSION is available."
    sleep $SLEEP_TIME
    break
  else
    echo "[ERROR] ($(date)) RT version $RT_VERSION not found at $RT_URL."
    ((attempt++))
    if (( attempt > MAX_RETRIES )); then
      echo "[ERROR] ($(date)) Maximum retries exceeded. Exiting..."
      exit 1
    fi    
  fi
done

# ===== Derived Variable Assignments =====
MAJOR_VERSION="${RT_VERSION%%.*}"
RT_DIR="/opt/rt${MAJOR_VERSION}"
DB_NAME="rt${MAJOR_VERSION}"
APACHE_CONF="rt${MAJOR_VERSION}.conf"
RT_TMP_DIR="/tmp/rt-${RT_VERSION}"

# ===== Prompt for Site Configuration =====
read -p "Enter RT name (e.g., MyRT) [default: MyRT]: " RT_NAME
RT_NAME=${RT_NAME:-MyRT}

read -p "Enter domain name for RT (e.g., rt.example.com) [default: rt.localhost]: " WEB_DOMAIN
WEB_DOMAIN=${WEB_DOMAIN:-rt.localhost}

read -p "Enter organization name (e.g., example.com) [default: example.com]: " ORG_NAME
ORG_NAME=${ORG_NAME:-example.com}

read -p "Is this behind a reverse proxy? (y/n) [default: n]: " BEHIND_PROXY
BEHIND_PROXY=${BEHIND_PROXY,,}
BEHIND_PROXY=${BEHIND_PROXY:-n}

read -p "Is SSL enabled (HTTPS)? (y/n) [default: n]: " USE_SSL
USE_SSL=${USE_SSL,,}
USE_SSL=${USE_SSL:-n}

# ===== Set Secure Cookies If SSL Is Enabled =====
SECURE_COOKIES=0
[[ "$USE_SSL" == "y" ]] && SECURE_COOKIES=1

# ===== Prompt for MySQL Credentials =====
while true; do
  read -s -p "Enter MySQL root password: " MYSQL_ROOT_PASSWORD
  echo
  [[ -z "$MYSQL_ROOT_PASSWORD" ]] && echo "[WARN] ($(date)) Password cannot be empty." || break
done

while true; do
  read -s -p "Enter RT database user password: " DB_PASS
  echo
  [[ -z "$DB_PASS" ]] && echo "[WARN] ($(date)) Password cannot be empty." || break
done

# ===== Display Configuration Summary =====
echo ""
echo "===== Configuration Summary: ====="
echo "  RT Version: $RT_VERSION"
echo "  RT Name: $RT_NAME"
echo "  Domain: $WEB_DOMAIN"
echo "  Organization: $ORG_NAME"
echo "  Behind Proxy: $BEHIND_PROXY"
echo "  SSL Enabled: $USE_SSL"
echo "  DB User: $DB_USER"
echo "  DB Name: $DB_NAME"
echo ""
echo "Press Enter to continue or Ctrl+C to cancel."
read

# ===== Install Required Packages =====
echo "[INFO] ($(date)) Updating package list and installing dependencies..."
sleep $SLEEP_TIME
apt update
apt install -y build-essential apache2 \
  libapache2-mod-fcgid mariadb-server mariadb-client \
  libssl-dev libexpat1-dev libgnupg-interface-perl \
  zlib1g-dev wget tar perl cpanminus \
  libmysqlclient-dev libgd-dev graphviz

# ===== Enable Required Apache Modules =====
echo "[INFO] ($(date)) Enabling Apache modules..."
sleep $SLEEP_TIME
a2enmod fcgid rewrite

# ===== Download and Extract RT Source =====
echo "[INFO] ($(date)) Downloading Request Tracker ${RT_VERSION}..."
sleep $SLEEP_TIME
wget -O "/tmp/${RT_TARBALL}" "${RT_URL}"
chown root "/tmp/${RT_TARBALL}"
set +e  # Disable immediate exit
tar -xzvf "/tmp/${RT_TARBALL}" -C /tmp
TAR_EXIT_CODE=$?
set -e  # Re-enable immediate exit
if [ $TAR_EXIT_CODE -ne 0 ]; then
  echo "[ERROR] ($(date)) Failed to extract ${RT_TARBALL}. Exiting."
  exit 1
fi
cd "${RT_TMP_DIR}"

# ===== Install Required Perl Modules =====
echo "[INFO] ($(date)) Configuring CPAN and installing Perl dependencies..."
sleep $SLEEP_TIME
cpan App::cpanminus
./configure --with-web-user="${WEB_USER}" --with-web-group="${WEB_GROUP}"
make testdeps || true
make fixdeps
make fixdeps

# ===== Compile and Install RT =====
echo "[INFO] ($(date)) Installing RT ${RT_VERSION}..."
sleep $SLEEP_TIME
make install

# ===== Initialize RT Database =====
echo "[INFO] ($(date)) Initializing RT database..."
sleep $SLEEP_TIME
cd "${RT_TMP_DIR}"
make initialize-database

# ===== Create MySQL User and Grant Access =====
echo "[INFO] ($(date)) Creating RT database user and granting privileges..."
sleep $SLEEP_TIME
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "
  ALTER USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
  GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
  FLUSH PRIVILEGES;"

if [ $? -eq 0 ]; then
  echo "[INFO] ($(date)) Database user $DB_USER created successfully."
  sleep $SLEEP_TIME
else
  echo "[ERROR] ($(date)) Failed to create database user."
fi

# ===== Configure Apache VirtualHost =====
echo "[INFO] ($(date)) Configuring Apache site..."
sleep $SLEEP_TIME
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

# ===== Append Custom RT Site Settings =====
echo "[INFO] ($(date)) Updating RT site configuration..."
sleep $SLEEP_TIME
cat >> "${RT_DIR}/etc/RT_SiteConfig.pm" <<EOF
Set( \$rtname, '${RT_NAME}' );
Set( \$Organization, '${ORG_NAME}' );
Set( \$WebDomain, '${WEB_DOMAIN}' );
Set( \$DatabaseName, '${DB_NAME}' );
Set( \$DatabaseUser, '${DB_USER}' );
Set( \$DatabasePassword, '${DB_PASS}' );
Set( \$WebSecureCookies, ${SECURE_COOKIES} );
EOF

[[ "$BEHIND_PROXY" == "y" ]] && echo "Set( \$CanonicalizeRedirectURLs, '1' );" >> "${RT_DIR}/etc/RT_SiteConfig.pm"
[[ "$BEHIND_PROXY" == "y" ]] && echo "Set( \$CanonicalizeURLsInFeeds, '1' );" >> "${RT_DIR}/etc/RT_SiteConfig.pm"
[[ "$USE_SSL" == "y" ]] && echo "Set( \$WebPort, 443 );" >> "${RT_DIR}/etc/RT_SiteConfig.pm"

# ===== Activate Apache Site and Restart Service =====
echo "[INFO] ($(date)) Enabling Apache site and restarting server..."
sleep $SLEEP_TIME
a2ensite ${APACHE_CONF}
a2dissite 000-default
systemctl restart apache2

# ===== Remove Temporary Files =====
echo "[INFO] ($(date)) Cleaning up temporary files..."
sleep $SLEEP_TIME
rm -rf "$RT_TMP_DIR"
rm -f "/tmp/${RT_TARBALL}"

# ===== Script Completion Notice =====
echo "========== Script completed at $(date) =========="
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
echo "Total time elapsed: ${DURATION} seconds"

# ===== Restore stdout/stderr to Original Streams =====
exec 1>&3 2>&4

# ===== Log Sensitive and Key Configuration Details =====
{
  echo ""
  echo "[DEBUG] RT_VERSION=$RT_VERSION"
  echo "[DEBUG] RT_NAME=$RT_NAME"
  echo "[DEBUG] WEB_DOMAIN=$WEB_DOMAIN"
  echo "[DEBUG] ORG_NAME=$ORG_NAME"
  echo "[DEBUG] MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD"
  echo "[DEBUG] DB_NAME=$DB_NAME"
  echo "[DEBUG] DB_USER=$DB_USER"
  echo "[DEBUG] DB_PASS=$DB_PASS"
  echo "[DEBUG] BEHIND_PROXY=$BEHIND_PROXY"
  echo "[DEBUG] USE_SSL=$USE_SSL"
  echo "[DEBUG] SECURE_COOKIES=$SECURE_COOKIES"
  echo "[DEBUG] WEB_USER=$WEB_USER"
  echo "[DEBUG] WEB_GROUP=$WEB_GROUP"
  echo "[DEBUG] RT_URL=$RT_URL"
} >> "$LOG_FILE"


# ===== Final Instructions to User =====
echo "Access RT at http://${WEB_DOMAIN} or http://your-server-ip-address"
echo "Default login: root / password"
echo ""
echo "The log for this script can be found at $LOG_FILE"
echo ""
echo "Next steps:"
echo "1. Change root password via RT web UI"
echo "2. Configure email in ${RT_DIR}/etc/RT_SiteConfig.pm"
echo "3. Set up a proper domain name and SSL (recommended for production)."
echo "4. Adjust firewall rules if necessary (e.g., ufw allow 80)."
echo "5. See https://hendgrow.com/2025/03/22/45-request-tracker-one-script-install/ for further security guidance."
echo "6. Subscribe: youtube.com/HendGrow | Follow: x.com/HendGrow"

exit 0
