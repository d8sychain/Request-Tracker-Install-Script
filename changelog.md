# Changelog - RT Installation Script

## \[2025-08-01] - Enhanced Installer & Added RT 5.x/6.x Support

### Added

* Interactive prompts for:

  * RT version (with validation and online availability check)
  * RT name (used in RT\_SiteConfig.pm)
  * Domain name (used in Apache config and RT\_SiteConfig.pm)
  * Organization name (used in RT\_SiteConfig.pm)
  * Reverse proxy usage (adds canonicalization config to RT if enabled)
  * SSL usage (sets $WebSecureCookies and $WebPort accordingly)
  * Secure password prompts for MariaDB (MySQL) root and RT DB user (non-empty enforced)
* Cleanup of downloaded tarball and extracted source directory post-install
* Pause for user confirmation after displaying the collected configuration before proceeding

### Changed

* RT installation directory (`RT_DIR`) now dynamically set based on major version, e.g., `/opt/rt5` or `/opt/rt6`
* Database name (`DB_NAME`) dynamically set based on major version, e.g., `rt5` or `rt6`
* Apache site config filename reflects version, e.g., `rt5.conf`, `rt6.conf`
* Consistent use of variables for all version-dependent file paths and URLs
* Added root check at start of script before any prompts to avoid wasted input if not run as root
* Moved code block **# Update RT configuration** above **# Enable RT site and disable default site** and removed the need to restart Apache twice.

### Notes

* Script supports both RT 5.x and 6.x versions transparently
* Script designed for fresh installs only; upgrades not supported
