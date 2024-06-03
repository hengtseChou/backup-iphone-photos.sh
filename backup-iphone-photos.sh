#!/bin/bash
set -e

_indent() { sed 's/^/  /'; }

_help() {
    echo "Usage: backup-iphone-photos SOURCE DEST"
    echo -e "Sync files from subfolders in SOURCE to DEST\nThen organize them into new yyyy-mm folders base on timestamps" | _indent
    echo "Options:"
    echo "--help  Display this help message and exit" | _indent
}

if [ "$1" == "--help" ]; then
     _help
    exit 0
fi
if [ "$#" -ne 2 ]; then
    echo "Error: Invalid number of arguments."
    _help
    exit 1
fi

source_dir="$1"
dest_dir="$2"
if ! which rsybc >/dev/null; then
    echo "Error: rsync not found. Make sure you have rsync installed on your system."
    exit 1
fi
if [ ! -d "$source_dir" ]; then
    echo "Error: Source directory '$source_dir' does not exist."
    exit 1
fi
if [ ! -d "$dest_dir" ]; then
    echo "Error: Destination directory '$dest_dir' does not exist."
    exit 1
fi

record="$dest_dir/.processed_subfolders"

if [ ! -e "$record" ]; then
    touch "$record"
fi
if [ -f "$record" ]; then
    processed_subfolders=$(cat "$record")
else
    processed_subfolders=""
fi

echo ":: Backup started."
sleep 0.5

# Iterate through each subfolder in the source directory
for source_subfolder in "$source_dir"/*/; do

    subfolder_name=$(basename "$source_subfolder")
    # Check if the current subfolder has been processed before
    # The last synced subfolder will be re-checked again
    if [[ "$processed_subfolders" =~ $subfolder_name && "$subfolder_name" != "${processed_subfolders##* }" ]]; then
        echo ":: Skipping fully processed subfolder: $subfolder_name"
        continue
    fi

    # Run the synchronization process
    files=("$source_subfolder"*)
    total_files=${#files[@]}
    for i in "${!files[@]}"; do
        file=${files[i]}
        if [ -f "$file" ]; then
            last_modified=$(stat -c %Y "$file")
            year_month=$(date -d "@$last_modified" +%Y-%m)
            mkdir -p "$dest_dir/$year_month"
            echo -ne "\\r:: Processing $subfolder_name: file $((i + 1)) of $total_files"
            rsync -a --ignore-existing "$file" "$dest_dir/$year_month/"
        fi
    done
    echo -e "\\n:: $subfolder_name completed."

    # Update the processed record
    if [ -z "$processed_subfolders" ]; then
        processed_subfolders="$subfolder_name"
    else
    	processed_subfolders="$processed_subfolders $subfolder_name"
    fi
    echo "$processed_subfolders" > "$record"
done

echo ":: Backup completed."

