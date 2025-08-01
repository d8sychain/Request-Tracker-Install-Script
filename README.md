# Installation Guide for Request Tracker 5.x.x/6.x.x (Based on HendGrow's Original Script)

## Overview

This guide and script provide a way to install Request Tracker (RT) 5 or 6 on a Debian-based system using an enhanced Bash script. The script interacts with the user to collect configuration options, installs required dependencies, sets up MariaDB, configures Apache, and initializes RT.

## Changelog (Compared to the Original Guide)

* **Interactive Prompts**: Script now asks the user for:

  * RT version (validated and checked online)
  * RT instance name
  * Domain name
  * Organization
  * Reverse proxy and SSL status
  * MariaDB root and RT DB user passwords

* **Conditional RT Configuration**:

  * Adds `CanonicalizeRedirectURLs` and related settings only if behind a reverse proxy.
  * Adds `WebPort` setting only if SSL is enabled.

* **Dynamic Apache Config Naming**: Based on major RT version to avoid conflicts.

* **Dynamic Directory Management**:

  * Sets up `RT_DIR`, `RT_TMP_DIR`, `DB_NAME`, and `APACHE_CONF` based on version.
  * Cleans up temporary files after installation.

* **Final Output**:

  * Displays access URL, default login, and next configuration steps.

## Requirements

* Debian-based Linux distro (e.g., Ubuntu)
* Root access (`sudo` required)
* Internet access to download RT and dependencies

## Instructions

1. Download the script using either **wget** or **curl**:

   **Using wget:**
   ```bash
   wget https://raw.githubusercontent.com/d8sychain/Request-Tracker-Install-Script/main/install_rt.sh
   ```

   **Or using curl:**
   ```bash
   curl -O https://raw.githubusercontent.com/d8sychain/Request-Tracker-Install-Script/main/install_rt.sh
   ```

2. Make the script executable:

   ```bash
   chmod +x install_rt.sh
   ```

3. Run the script with root privileges:

   ```bash
   sudo ./install_rt.sh
   ```

4. Follow the prompts:

   * Enter desired RT version (e.g., 5.0.8, 6.0.0)
   * Enter RT Name (used for branding and directory structure)
   * Supply domain name and organization
   * Indicate if you're behind a reverse proxy
   * Indicate if you're using SSL
   * Provide MariaDB root password
   * Set RT MariaDB database and user passwords

5. Wait for the script to complete. It will:

   * Download and unpack RT
   * Install all OS and Perl dependencies
   * Create and configure the MySQL database
   * Generate Apache configuration
   * Clean up temporary files

6. Access the RT interface via browser:

   * URL: `http(s)://<your domain>` or `http://<server IP>`
   * Default login: `root / password`

## Post-Installation Recommendations 

* **Change the default password**
* **Configure email in RT\_SiteConfig.pm**
* **Enable SSL via reverse proxy or Let's Encrypt**
* **Open firewall ports if needed**

## Support & Attribution

* Based on HendGrow's original [installation guide](https://hendgrow.com/2025/03/22/45-request-tracker-one-script-install/)
* YouTube: [@HendGrow](https://www.youtube.com/@HendGrow)
* X (Twitter): [@HendGrow](https://x.com/HendGrow)
