#!/usr/bin/env bash

# This shebang line tells the system this script should be run using Bash, which is specified by the absolute path returned by 'env'. 'env' is used to ensure the script uses the user's environment configuration.

# This command checks if your local git repository is up-to-date with the remote repository.
# It uses 'git rev-parse HEAD' to get the current local HEAD commit and compares it with the remote HEAD commit obtained via 'git ls-remote'.
# The 'sed' command here is used to format the output of 'git rev-parse --abbrev-ref @{u}' to retrieve the remote tracking branch in a usable format.
# It then uses a conditional (&& and ||) to print a message depending on whether the local and remote are in sync.
[ $(git rev-parse HEAD) = $(git ls-remote $(git rev-parse --abbrev-ref @{u} | \
sed 's/\// /g') | cut -f1) ] && echo -e "Klipper-backup is up to date\n" || echo -e "Klipper-backup is $(tput setaf 1)not$(tput sgr0) up to date, consider making a $(tput setaf 1)git pull$(tput sgr0) to update\n"

# This command sets the variable 'parent_path' to the directory where this script is located.
# It's a common way to get the path of the script regardless of where it's called from.
parent_path=$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd -P)

# This line sources (imports) the .env file which should be located in the same directory as the script.
# This .env file is expected to contain environment variables that the script will use.
source "$parent_path"/.env

# This changes the working directory to the directory where the script is located.
# If the directory change fails (e.g., the directory doesn't exist), 'exit' will terminate the script to prevent unexpected behavior.
cd "$parent_path" || exit

# This block checks if the backup folder exists in the user's home directory. If it doesn't, it creates the folder.
# '$HOME/$backup_folder' uses an environment variable defined in .env. 
# 'mkdir -p' creates the directory and any necessary parent directories.
if [ ! -d "$HOME/$backup_folder" ]; then
  mkdir -p "$HOME/$backup_folder"
fi

# This while loop reads paths from the .env file, ignoring comments (lines starting with '#').
# It uses 'grep' to extract lines containing 'path_' and then uses 'sed' to parse and retain everything after the '=' character.
# The loop processes each path to back up files located there.
while IFS= read -r path; do
  # This nested loop iterates over every file in the given path.
  for file in $HOME/$path; do
    # This if condition checks if the file is a symbolic link and skips it if true.
    if [ -h "$file" ]; then
      echo "Skipping symbolic link: $file"
    # This elif condition checks if the file matches a specific naming pattern ('printer-[0-9]+_[0-9]+.cfg') and skips it.
    # This is likely to avoid backing up auto-generated or temporary configuration files.
    elif [[ $(basename "$file") =~ ^printer-[0-9]+_[0-9]+\.cfg$ ]]; then
        echo "Skipping file: $file"
    else
      # If the file doesn't match the above conditions, it gets copied to the backup folder.
      cp -r $file $HOME/$backup_folder/
    fi
  done
done < <(grep -v '^#' "$parent_path/.env" | grep 'path_' | sed 's/^.*=//')

# This command creates (or overwrites) a README.md file in the parent directory of the backup folder.
# It uses 'echo' with the '-e' flag to enable interpretation of backslash escapes and writes a basic description about the backup.
backup_parent_directory=$(dirname "$backup_folder")
echo -e "# klipper-backup 💾 \nKlipper backup script for manual or automated GitHub backups \n\nThis backup is provided by [klipper-backup](https://github.com/Staubgeborener/klipper-backup)." > "$HOME/$backup_parent_directory/README.md"

# This section sets up the commit message for the git backup.
# It first gets the current timezone using 'timedatectl' and processes it with 'awk'.
# If a parameter is passed to the script, it uses it as the commit message. Otherwise, it uses the current date, formatted differently based on whether the timezone contains 'America'.
timezone=$(timedatectl | grep "Time zone" | awk '{print $3}')
if [ -n "$1" ]; then
    commit_message="$1"
elif [[ "$timezone" == *"America"* ]]; then
    commit_message="New backup from $(date +"%m-%d-%y")"
else
    commit_message="New backup from $(date +"%d-%m-%y")"
fi

# Changes directory to the parent directory of the backup folder.
cd "$HOME/$backup_parent_directory"

# This block checks if a .git directory exists. If not, it creates one and initializes a new git repository.
# It also sets the default branch name in the git configuration.
# 'git symbolic-ref --short -q HEAD' is used to get the current branch name.
if [ ! -d ".git" ]; then
  mkdir .git 
  echo "[init]
          defaultBranch = $branch_name" >> .git/config
  git init
  branch=$(git symbolic-ref --short -q HEAD)
else
  branch=$(git symbolic-ref --short -q HEAD)
fi

# Configures the git username and email for commits, using either provided environment variables or default values.
[[ "$commit_username" != "" ]] && git config user.name "$commit_username" || git config user.name "$(whoami)"
[[ "$commit_email" != "" ]] && git config user.email "$commit_email" || git config user.email "$(whoami)@$(hostname --long)"

# This set of commands stages all changes in the directory for commit, commits them with the previously set message, and then pushes the commit to the specified GitHub repository.
# It uses the 'github_token', 'github_username', and 'github_repository' variables (presumably set in the .env file) to authenticate and specify the remote repository.
git add .
git commit -m "$commit_message"
git push -u https://"$github_token"@github.com/"$github_username"/"$github_repository".git $branch

# Finally, this command removes the backup folder from the home directory after the backup process is completed.
# This step ensures that deletions are effectively recorded in subsequent backups.
rm -rf $HOME/$backup_folder/
