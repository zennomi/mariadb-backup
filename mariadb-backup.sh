#!/bin/bash
set -e

# Load environment variables from .env
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
else
  echo ".env file not found!"
  exit 1
fi

# Check required variables
: "${DB_USER:?Missing DB_USER in .env}"
: "${DB_PASSWORD:?Missing DB_PASSWORD in .env}"
: "${DB_NAME:?Missing DB_NAME in .env}"
: "${GDRIVE_FOLDER_ID:?Missing GDRIVE_FOLDER_ID in .env}"
: "${SERVICE_ACCOUNT_JSON:?Missing SERVICE_ACCOUNT_JSON in .env}"

# Set DB_HOST and DB_PORT defaults if not set
DB_HOST=${DB_HOST:-localhost}
DB_PORT=${DB_PORT:-3306}

# Set backup filename
BACKUP_NAME="${DB_NAME}_$(date +%Y%m%d_%H%M%S).sql.gz"

# Dump and compress the database, throw error if Got error: 1044
mysqldump -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" 2>mysqldump.err | gzip > "$BACKUP_NAME"
if grep -q "Got error: 1044" mysqldump.err; then
  echo "mysqldump failed: Got error: 1044"
  cat mysqldump.err
  rm -f mysqldump.err
  exit 1
fi
rm -f mysqldump.err

# Install gdrive if not present
if ! command -v gdrive &> /dev/null; then
  echo "gdrive not found, installing..."
  if [[ "$OSTYPE" == "darwin"* ]]; then
    brew install gdrive
  else
    sudo add-apt-repository ppa:prasmussen/gdrive -y
    sudo apt-get update
    sudo apt-get install gdrive -y
  fi
fi

# Authenticate gdrive with service account
export GOOGLE_APPLICATION_CREDENTIALS="$SERVICE_ACCOUNT_JSON"

# Upload to Google Drive
# Note: gdrive does not natively support service accounts, so use 'gdrive' alternatives like 'rclone' for service account support
if ! command -v rclone &> /dev/null; then
  echo "rclone not found, installing..."
  if [[ "$OSTYPE" == "darwin"* ]]; then
    brew install rclone
  else
    sudo apt-get install rclone -y
  fi
fi

# Configure rclone if not already configured
echo "[gdrive]
type = drive
scope = drive
service_account_file = $SERVICE_ACCOUNT_JSON
root_folder_id = $GDRIVE_FOLDER_ID
" > rclone.conf

# Upload the backup
rclone --config rclone.conf copy "$BACKUP_NAME" gdrive:

# Retention: keep only last 7 days, but always keep Monday backups
# List all backup files in the GDrive folder
BACKUP_FILES=$(rclone --config rclone.conf lsl gdrive: | awk '{print $4}')

# Get today, 7 days ago, and 1 month ago in YYYYMMDD format
TODAY=$(date +%Y%m%d)
SEVEN_DAYS_AGO=$(date -v-7d +%Y%m%d 2>/dev/null || date -d '7 days ago' +%Y%m%d)
ONE_MONTH_AGO=$(date -v-1m +%Y%m%d 2>/dev/null || date -d '1 month ago' +%Y%m%d)

for FILE in $BACKUP_FILES; do
  # Extract date from filename (assumes format: DBNAME_YYYYMMDD_HHMMSS.sql.gz)
  FILE_DATE=$(echo "$FILE" | grep -oE '[0-9]{8}')
  if [ -z "$FILE_DATE" ]; then
    continue
  fi
  # Get the day of week for this file (1=Monday, 7=Sunday)
  FILE_DOW=$(date -j -f "%Y%m%d" "$FILE_DATE" +%u 2>/dev/null || date -d "$FILE_DATE" +%u)
  # If file is older than 1 month, delete it
  if [ "$FILE_DATE" -lt "$ONE_MONTH_AGO" ]; then
    echo "Deleting backup older than 1 month: $FILE"
    rclone --config rclone.conf deletefile "gdrive:$FILE"
    continue
  fi
  # If file is older than 7 days and not a Monday backup, delete it
  if [ "$FILE_DATE" -lt "$SEVEN_DAYS_AGO" ] && [ "$FILE_DOW" -ne 1 ]; then
    echo "Deleting old backup: $FILE"
    rclone --config rclone.conf deletefile "gdrive:$FILE"
  fi
done

# Clean up
rm "$BACKUP_NAME"
rm rclone.conf

echo "Backup and upload completed successfully!" 