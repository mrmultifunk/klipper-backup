#!/bin/bash
# This is a shell script for restoring files from a backup

# To run this script, first make it executable and then execute it:
# 1. chmod +x ./restore.sh
# 2. ./restore.sh

# Reads the 'backup_folder' variable value from the '.env' file
backup_folder=$(grep "backup_folder" .env | awk -F'=' '{print $2}')

# Loop over each line in the '.env' file
while IFS= read -r line; do
    # Check if the line starts with 'path_'
    if [[ $line == path_* ]]; then
        # Extract the destination path from the line
        destination_path=$(echo "$line" | awk -F'=' '{print $2}')
        # Extract the backup file name from the line
        backup_file=$(echo "$line" | awk -F'/' '{print $NF}')
        # Copy the backup file from the backup folder to the destination path
        cp "$backup_folder/$backup_file" "$destination_path"
    fi
done < .env # This reads from the '.env' file

# Print a message to the console once the files are restored
echo "Restored files"
