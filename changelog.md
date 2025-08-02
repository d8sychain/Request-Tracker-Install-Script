# Changelog - RT Installation Script

## \[2025-08-01] - Version Fetching, Logging, and Improved Error Handling

### Added
- **Dynamic Version Fetching**
  - If no RT version is entered, the script scrapes the official RT release directory and uses the latest available
- **Logging System**
  - Output now logged to `/var/log/rt_install.log` using `tee`
  - Captures start/end time for duration total and logs stages with timestamps
  - Logs key variables and credentials for debugging (sensitive data included)
- **Command Prerequisite Checks**
  - Verifies `curl`, `wget`, and `mysql` are available before continuing
- **Improved Error Handling**
  - Captures non-zero exit codes and notifies the user where to find the log
  - Checks that the RT URL is still valid
  - Checks that the RT version entered is valid, fails after 5 attempts
  - Graceful failure and logging if the tarball fails to extract
  - Fails gracefully if the RT tarball fails to extract
- **Retry Mechanism**
  - User has up to 5 attempts to enter a valid RT version (format or availability)

### Changed
- **Comment Lines**
  - Changed the style of comment lines and added additional comments
- **Log Message Formatting**
  - All messages now include `[INFO]`, `[WARN]`, or `[ERROR]` prefixes with timestamps, instead of just echoing to the terminal
- **Database User Creation Logging**
  - Improved success/failure reporting when creating the RT DB user
- **Output Readability**
  - Changed formatting of prompts and summaries for improved UX


## \[2025-08-01] - Enhanced Installer & Added RT 5.x/6.x Support

### Added
- **Interactive Prompts**
  - RT version (with validation and online availability check)
  - RT name (used in RT\_SiteConfig.pm)
  - Domain name (used in Apache config and RT\_SiteConfig.pm)
  - Organization name (used in RT\_SiteConfig.pm)
  - Reverse proxy usage (adds canonicalization config to RT if enabled)
  - SSL usage (sets $WebSecureCookies and $WebPort accordingly)
  - Secure password prompts for MariaDB (MySQL) root and RT DB user (non-empty enforced)
  - Pause for user confirmation after displaying the collected configuration before proceeding
- **Cleanup of Temp Files**
  - Remove downloaded tarball and extracted source directory post-install


### Changed
- **Dynamic Variables and Paths**
  - RT installation directory (`RT_DIR`) now dynamically set based on major version, e.g., `/opt/rt5` or `/opt/rt6`
  - Database name (`DB_NAME`) dynamically set based on major version, e.g., `rt5` or `rt6`
  - Apache site config filename reflects version, e.g., `rt5.conf`, `rt6.conf`
- **Moved Root Check**
  - Moved root check at start of script before any prompts to avoid wasted input if not run as root
- **Code Optimization**
  - Moved code block **# Update RT configuration** above **# Enable RT site and disable default site** and removed the need to restart Apache twice.

### Notes
- **Script supports both RT 5.x and 6.x versions transparently**
- **Script designed for fresh installs only; upgrades not supported**
