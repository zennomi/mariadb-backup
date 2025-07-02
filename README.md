# MariaDB Backup to Google Drive

This script dumps a MariaDB database and uploads the backup to Google Drive every night using a service account. It works on both macOS and Ubuntu 20.04.

## Features

- Dumps and compresses your MariaDB database
- Uploads the backup to Google Drive using a service account
- Uses secrets from a `.env` file
- Works on macOS and Ubuntu 20.04
- **Automatic backup retention:**
  - Keeps all backups from the last 7 days
  - Always keeps Monday backups for the last month
  - Deletes any backup older than 1 month (including Monday backups)

## Prerequisites

- [MariaDB](https://mariadb.org/) or [MySQL](https://www.mysql.com/) installed
- [rclone](https://rclone.org/) (the script will install it if missing)
- Service account JSON file for Google Drive API
- `brew` (for macOS) or `apt` (for Ubuntu)

**Environment variables in `.env**:

- `DB_USER`: MariaDB username
- `DB_PASSWORD`: MariaDB password
- `DB_NAME`: MariaDB database name
- `DB_HOST`: MariaDB host (default: `localhost`)
- `DB_PORT`: MariaDB port (default: `3306`)
- `GDRIVE_FOLDER_ID`: Google Drive folder ID for backups
- `SERVICE_ACCOUNT_JSON`: Absolute path to your Google service account JSON file

## Setup

1. **Clone this repository**

2. **Copy and edit the environment file:**

   ```sh
   cp .env.example .env
   # Edit .env with your credentials (including DB_HOST and DB_PORT if needed)
   ```

3. **Place your Google service account JSON file** somewhere safe and set its path in `.env` as `SERVICE_ACCOUNT_JSON`.

4. **Make the script executable:**

   ```sh
   chmod +x mariadb-backup.sh
   ```

5. **Test the script:**
   ```sh
   ./mariadb-backup.sh
   ```
   If successful, you should see a message about backup and upload completion.

## Scheduling Backups

### macOS (using `launchd`)

1. Open `crontab` for editing:
   ```sh
   crontab -e
   ```
2. Add the following line to run the backup every night at 2am:
   ```
   0 2 * * * /absolute/path/to/mariadb-backup.sh
   ```

### Ubuntu (using `cron`)

1. Open `crontab` for editing:
   ```sh
   crontab -e
   ```
2. Add the following line to run the backup every night at 2am:
   ```
   0 2 * * * /absolute/path/to/mariadb-backup.sh
   ```

## Notes

- The script will install `rclone` if it is not present.
- The script creates a temporary `rclone.conf` file for each run and deletes it after upload.
- Make sure your service account has access to the target Google Drive folder.

## Troubleshooting

- Ensure all variables in `.env` are set correctly.
- Check that the service account has the correct permissions.
- For more details, check the output/error messages from the script.
