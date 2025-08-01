# Installation Guide for Request Tracker 5.x.x/6.x.x (Based on HendGrow's Original Script)

## Overview

This guide and script provide a way to install Request Tracker (RT) 5 or 6 on a Debian-based system using an enhanced Bash script. The script interacts with the user to collect configuration options, installs required dependencies, sets up MariaDB, configures Apache, and initializes RT.

## Changelog (Compared to the Original Script)

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

1. Login to your Linux distro locally or via SSH

2. Move to the **tmp** directory (optional)

   ```bash
   cd /tmp
   ```
3. Download the script using either **wget** or **curl**:

   **Using wget:**
   ```bash
   wget https://raw.githubusercontent.com/d8sychain/Request-Tracker-Install-Script/main/install_rt.sh
   ```

   **Or using curl:**
   ```bash
   curl -O https://raw.githubusercontent.com/d8sychain/Request-Tracker-Install-Script/main/install_rt.sh
   ```

4. Make the script executable:

   ```bash
   chmod +x install_rt.sh
   ```

5. Run the script with root privileges:

   ```bash
   sudo ./install_rt.sh
   ```

6. Follow the prompts:

   * Enter desired RT version (e.g., 5.0.8, 6.0.0)
   * Enter RT Name (used for branding and directory structure)
   * Supply domain name and organization
   * Indicate if you're behind a reverse proxy
   * Indicate if you're using SSL
   * Provide MariaDB root password
   * Set RT MariaDB database and user passwords

7. As the script runs it will:

   * Download and unpack RT
   * Install all OS and Perl dependencies
   * Create and configure the MySQL database
   * Generate Apache configuration
   * Clean up temporary files

8. There will be several prompts while installing all OS and Perl dependencies:

     *You can just press Enter at each of the following prompts since the default is what you want.*
   * Would you like to configure as much as possible automatically? [yes] –> Response = yes
   * *Note: Don’t be concerned about seeing the MISSING messages. The script will rectify this at a later stage.*
   * Continue anyways? [y] –> Response = y
   * Check for a new version of the Public Suffix List? [N] –> Response = N
   * Do you want to run external tests? These tests *will* *fail* if you do not have network connectivity. [n] –> Response = n
   * These tests will detect if there are network problems and fail soft, so please disable them only if you definitely don’t want to have any network traffic to external sites. [Y/n] –> Response = Y
   * Do you want to build the XS Stash module? [y] –> Response = y
   * Do you want to use the XS Stash by default? [y] –> Response = y

9. At the last prompt, enter the MySQL root password that you entered earlier.

10. Access the RT interface via browser:

   * URL: `http(s)://<your domain>` or `http://<server IP>`
   * Default login: `root / password`

## Post-Installation Recommendations 

* **Change the default password for the RT user root via the WebUI**
* **Configure email in RT\_SiteConfig.pm** (e.g. /opt/rt6/etc/RT_SiteConfig.pm)
* **Enable SSL via reverse proxy or Let's Encrypt**
* **Open firewall ports if needed**

## Resources
* Request Tracker latest documentation: https://docs.bestpractical.com/rt/latest
* Install guide for Ubuntu Server 18 (should be similar to the latest version 24): https://ubuntu.com/tutorials/install-ubuntu-server
* Download the latest Ubuntu Server: https://ubuntu.com/download/server

## Support & Attribution

* Based on HendGrow's original [installation guide](https://hendgrow.com/2025/03/22/45-request-tracker-one-script-install/)
* YouTube: [@HendGrow](https://www.youtube.com/@HendGrow)
* X (Twitter): [@HendGrow](https://x.com/HendGrow)
