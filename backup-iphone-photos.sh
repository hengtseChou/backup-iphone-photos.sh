#!/bin/bash
_indent() { sed 's/^/  /'; }

_help() {
    echo "Usage: backup-iphone-photos [-s SOURCE] [-d DEST] [-l]"
    echo -e "Sync files from subfolders in SOURCE to DEST\nThen organize them into new yyyy-mm folders based on timestamps" | _indent
    echo "Options:"
    echo "--help  Display this help message and exit" | _indent
    echo "-s      Specify the source directory" | _indent
    echo "-d      Specify the destination directory" | _indent
    echo "-l      Show less output" | _indent
}

source_dir=""
dest_dir=""
less_output=false

while getopts ":s:d:l-:" opt; do
    case $opt in
    s) source_dir="$OPTARG" ;;
    d) dest_dir="$OPTARG" ;;
    l) less_output=true ;;
    -)
        case "${OPTARG}" in
        help)
            _help
            exit 0
            ;;
        *)
            echo "Invalid option: --${OPTARG}" >&2
            _help
            exit 1
            ;;
        esac
        ;;
    \?)
        echo "Invalid option: -$OPTARG" >&2
        _help
        exit 1
        ;;
    :)
        echo "Option -$OPTARG requires an argument." >&2
        _help
        exit 1
        ;;
    esac
done

if [ -z "$source_dir" ] || [ -z "$dest_dir" ]; then
    echo "Error: Source and destination directories are required."
    _help
    exit 1
fi
if ! command -v rsync 2>&1 >/dev/null; then
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
folders=("$source_dir"/*/)
first=$(basename "${folders[0]}")
last=$(basename "${folders[-1]}")
echo ":: Syncing from $first to $last."
sleep 1

# Iterate through each subfolder in the source directory
for source_subfolder in "${folders[@]}"; do

    subfolder_name=$(basename "$source_subfolder")
    # Check if the current subfolder has been processed before
    # The last synced subfolder will be re-checked again
    if [[ "$processed_subfolders" =~ $subfolder_name && "$subfolder_name" != "${processed_subfolders##* }" ]]; then
        if [ "$less_output" = false ]; then
            echo ":: Skipping fully processed subfolder: $subfolder_name"
        fi
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
    echo "$processed_subfolders" >"$record"
done

echo ":: Backup completed."
echo ":: Calculating backup storage usage..."
echo ":: Backup stroage usage: $(du -sh $source_dir | cut -f1)."
