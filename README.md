# GLPi Automated Upgrade Script

A robust Bash script to safely and automatically upgrade your [GLPi](https://glpi-project.org/) IT Service Management software.

Upgrading GLPi manually involves multiple tedious steps (stopping services, backing up configs, downloading, extracting, restoring plugins, fixing permissions, and updating the database). This script automates the entire process, minimizing downtime and human error.

## ✨ Features
* **Automatic Backups:** Safely copies your configuration files (`/etc/glpi`, `downstream.php`), user data (`/var/lib/glpi`), marketplace, and plugins before making any changes.
* **Safe Extraction:** Downloads the target release from GitHub, extracts it, and restores your custom plugins/configs.
* **Permission Handling:** Automatically applies the correct web server ownership and file permissions (`0644` for files, `0755` for directories).
* **Automated Database Update:** Runs the necessary `bin/console` commands to check and update the database schema.
* **Strict Error Handling:** If any step fails, the script immediately halts to prevent data corruption.

## ⚠️ Important Warning
**This script backs up your FILES, not your SQL DATABASE.** You **MUST** perform a manual database dump (e.g., using `mysqldump`) or a VM snapshot before running this script. If the database upgrade step fails, you will need that SQL backup to restore your system.

## 🚀 How to Use

### 1. Configure the Script
Open the script in your favorite text editor (like `nano` or `vim`) and update the configuration variables at the top to match your environment:

```bash
# --- Configuration ---
GLPI_VERSION="11.0.5"      # Set this to the version you want to upgrade to
INSTALL_DIR="/var/www/html/glpi"
WEB_USER="www-data"        # 'www-data' for Debian/Ubuntu, 'apache' for CentOS/RHEL
WEB_GROUP="www-data"

# Download the script (or clone the repo)
wget https://github.com/YeMinLattakaKoJ/GLPi/blob/main/glpi_upgrade_ubuntu.sh

# Make the script executable
chmod +x glpi_upgrade.sh

# Run the script as root using sudo
sudo ./glpi_upgrade.sh

🛠️ Troubleshooting
Error: [[: not found or read: arg count

Cause: You executed the script using sudo sh script.sh on a system where sh is aliased to dash (like Ubuntu).

Fix: Run it explicitly with Bash: sudo bash glpi_upgrade.sh or make it executable and run sudo ./glpi_upgrade.sh.

📜 License
This script is provided "as is" without warranty of any kind. Please test it in a staging environment before using it in production.
