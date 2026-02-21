#!/bin/bash

# ==========================================
# GLPi Automated Upgrade Script
# ==========================================

# --- Configuration ---
GLPI_VERSION="11.0.5"  # Change this to the target version
GLPI_URL="https://github.com/glpi-project/glpi/releases/download/${GLPI_VERSION}/glpi-${GLPI_VERSION}.tgz"

# Paths
INSTALL_DIR="/var/www/html/glpi"
WEB_USER="www-data"       # Use 'www-data' for Debian/Ubuntu, 'apache' for CentOS/RHEL
WEB_GROUP="www-data"

# Determine the real user who invoked sudo (for backup location)
REAL_USER="${SUDO_USER:-$USER}"
BACKUP_BASE="/home/${REAL_USER}/glpi-before-upgrade-$(date +%Y-%m-%d)"

# --- Styling & Functions ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error_exit() {
    echo -e "${RED}[ERROR] Step Failed: $1${NC}"
    exit 1
}

check_error() {
    if [ $? -ne 0 ]; then
        error_exit "$1"
    fi
}

# --- Pre-flight Checks ---
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root. Please use sudo.${NC}" 
   exit 1
fi

warn "Have you backed up your SQL DATABASE? This script only backs up files."
read -p "Press Enter to continue or Ctrl+C to cancel..."

# ==========================================
# 1. Stop Services
# ==========================================
log "Stopping web services..."
systemctl stop apache2
check_error "Failed to stop apache2"
# systemctl stop php-fpm
# check_error "Failed to stop php-fpm"

# ==========================================
# 2. Backups
# ==========================================
log "Creating backup directories at ${BACKUP_BASE}..."
mkdir -p "${BACKUP_BASE}/config" "${BACKUP_BASE}/data"
check_error "Failed to create backup directory"

log "Backing up Configuration (/etc/glpi & downstream.php)..."
# Check if /etc/glpi exists to avoid error
if [ -d "/etc/glpi" ]; then
    cp -p --preserve=mode,ownership /etc/glpi/* "${BACKUP_BASE}/config/"
    check_error "Failed to backup /etc/glpi"
else
    warn "/etc/glpi not found, skipping..."
fi

if [ -f "${INSTALL_DIR}/inc/downstream.php" ]; then
    cp -p --preserve=mode,ownership "${INSTALL_DIR}/inc/downstream.php" "${BACKUP_BASE}/config/"
    check_error "Failed to backup downstream.php"
fi

log "Backing up User Data (/var/lib/glpi)..."
if [ -d "/var/lib/glpi" ]; then
    cp -r -p --preserve=mode,ownership /var/lib/glpi/* "${BACKUP_BASE}/data/"
    check_error "Failed to backup /var/lib/glpi"
fi

log "Backing up Marketplace & Plugins..."
if [ -d "${INSTALL_DIR}/marketplace" ]; then
    cp -r -p --preserve=mode,ownership "${INSTALL_DIR}/marketplace" "${BACKUP_BASE}/"
    check_error "Failed to backup marketplace"
fi

if [ -d "${INSTALL_DIR}/plugins" ]; then
    cp -r -p --preserve=mode,ownership "${INSTALL_DIR}/plugins" "${BACKUP_BASE}/"
    check_error "Failed to backup plugins"
fi

# ==========================================
# 3. Download & Clean
# ==========================================
log "Downloading GLPi version ${GLPI_VERSION}..."
wget -q "${GLPI_URL}" -O "/tmp/glpi-${GLPI_VERSION}.tgz"
check_error "Failed to download GLPi. Check version number or internet connection."

log "Backing up current install folder to /var/www/html/glpi-backup..."
mkdir -p /var/www/html/glpi-backup
# Using rsync for better handling, or standard cp
cp -r -p --preserve=mode,ownership "${INSTALL_DIR}/"* /var/www/html/glpi-backup/ 2>/dev/null
# We don't exit here if it fails (e.g. empty dir), just warn
if [ $? -ne 0 ]; then warn "Could not backup existing GLPI dir (might be empty)"; fi

log "Cleaning target directory ${INSTALL_DIR}..."
# Safety check to ensure we don't delete wrong dir
if [[ "${INSTALL_DIR}" == "/var/www/html/glpi" ]]; then
    rm -rf "${INSTALL_DIR:?}/"*
    check_error "Failed to clean installation directory"
else
    error_exit "Install directory path seems wrong. Stopping for safety."
fi

# ==========================================
# 4. Extract & Restore
# ==========================================
log "Extracting new version..."
tar -xzf "/tmp/glpi-${GLPI_VERSION}.tgz" -C "${INSTALL_DIR}" --strip-components=1
check_error "Failed to extract tarball"

log "Restoring Marketplace, Plugins, and Configs..."
cp -r -p --preserve=mode,ownership "${BACKUP_BASE}/marketplace" "${INSTALL_DIR}/"
check_error "Failed to restore marketplace"

cp -r -p --preserve=mode,ownership "${BACKUP_BASE}/plugins" "${INSTALL_DIR}/"
check_error "Failed to restore plugins"

# Remove default config dir if using downstream/etc setup
if [ -d "${INSTALL_DIR}/config" ]; then
    rmdir "${INSTALL_DIR}/config" 2>/dev/null || rm -rf "${INSTALL_DIR}/config"
    log "Removed default config directory to use external configs."
fi

# Restore downstream.php
cp "${BACKUP_BASE}/config/downstream.php" "${INSTALL_DIR}/inc/"
check_error "Failed to restore downstream.php"

# ==========================================
# 5. Permissions
# ==========================================
log "Applying permissions..."
chown root:root "${INSTALL_DIR}/" -R
chown "${WEB_USER}:${WEB_GROUP}" "${INSTALL_DIR}/marketplace" -Rf
find "${INSTALL_DIR}/" -type f -exec chmod 0644 {} \;
find "${INSTALL_DIR}/" -type d -exec chmod 0755 {} \;
check_error "Failed to set permissions"

# ==========================================
# 6. Database Upgrade
# ==========================================
log "Running Database Check..."
cd "${INSTALL_DIR}"
sudo -u "${WEB_USER}" php bin/console db:check
check_error "Database check failed"

log "Running Database Update..."
sudo -u "${WEB_USER}" php bin/console db:update
check_error "Database update failed"

# ==========================================
# 7. Restart Services
# ==========================================
log "Restarting services..."
systemctl start apache2
# systemctl start php-fpm

echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}       GLPi Upgrade Complete!             ${NC}"
echo -e "${GREEN}==========================================${NC}"