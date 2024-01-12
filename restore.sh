#!/bin/bash
## To Run the script:
## 1. chmod +x ./restore.sh
## 2. ./restore.sh


backup_folder=$(grep "backup_folder" .env | awk -F'=' '{print $2}')
while IFS= read -r line; do
    if [[ $line == path_* ]]; then
        destination_path=$(echo "$line" | awk -F'=' '{print $2}')
        backup_file=$(echo "$line" | awk -F'/' '{print $NF}')
        cp "$backup_folder/$backup_file" "$destination_path"
    fi
done < .env

echo "Restored files"