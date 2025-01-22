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
      echo "[ERROR] Invalid option: --${OPTARG}" >&2
      _help
      exit 1
      ;;
    esac
    ;;
  \?)
    echo "[ERROR] Invalid option: -$OPTARG" >&2
    _help
    exit 1
    ;;
  esac
done

if [ $OPTIND -eq 1 ]; then
  _help
  exit 1
fi
if [ -z "$source_dir" ] || [ -z "$dest_dir" ]; then
  echo "[ERROR] Source and destination directory must be specified by -s and -t"
  exit 1
fi
if ! command -v rsync 2>&1 >/dev/null; then
  echo "[ERROR] rsync not found. Make sure you have rsync installed on your system"
  exit 1
fi
if [ ! -d "$source_dir" ]; then
  echo "[ERROR] Source directory '$source_dir' does not exist"
  exit 1
fi
if [ ! -d "$dest_dir" ]; then
  echo "[ERROR] Destination directory '$dest_dir' does not exist"
  exit 1
fi

record="$dest_dir/.processed_subfolders"

if [ ! -e "$record" ]; then
  echo "[INFO] Backup record file not found. Creating a new one..."
  touch "$record"
fi
if [ -f "$record" ]; then
  processed_subfolders=$(cat "$record")
else
  processed_subfolders=""
fi

echo "[INFO] Backup started"
folders=("$source_dir"/*/)
first=$(basename "${folders[0]}")
last=$(basename "${folders[-1]}")
echo "[INFO] Syncing from $first to $last"
sleep 1

# Iterate through each subfolder in the source directory
for source_subfolder in "${folders[@]}"; do

  subfolder_name=$(basename "$source_subfolder")
  # Check if the current subfolder has been processed before
  # The last synced subfolder will be re-checked again
  if [[ "$processed_subfolders" =~ $subfolder_name && "$subfolder_name" != "${processed_subfolders##* }" ]]; then
    if [ "$less_output" = false ]; then
      echo "--> Skipping fully processed subfolder: $subfolder_name"
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
      echo -ne "\\r--> Processing $subfolder_name: file $((i + 1)) of $total_files"
      rsync -a --ignore-existing "$file" "$dest_dir/$year_month/"
    fi
  done
  echo -e "\\n[INFO] $subfolder_name completed"

  # Update the processed record
  if [ -z "$processed_subfolders" ]; then
    processed_subfolders="$subfolder_name"
  else
    processed_subfolders="$processed_subfolders $subfolder_name"
  fi
  echo "$processed_subfolders" >"$record"
done

echo "[INFO] Backup completed"
echo "[INFO] Calculating backup storage usage..."
echo "[INFO] Backup stroage usage: $(du -sh $source_dir | cut -f1)"
