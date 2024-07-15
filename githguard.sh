#!/usr/bin/env bash

# ------ DEFAULTS ------

BG3_APPDATA=""
BACKUP_DIR=$(readlink -f "$(dirname "${0}")/backups")
MAX_BACKUPS=3
LOG_FILE="${BACKUP_DIR}/bg3_backup.log"
GAME_EXECUTABLE=""
MAX_LOG_FILES=3
LOG_SIZE_THRESHOLD=10485760
TEMP_DIR=$(mktemp -d)
TEMP_BACKUP_PATH=""
KEEP_BACKUP=""
KILL_ONLY=0
RESTORE_LATEST=0
RESTORE_FILE=""
LAUNCH_AFTER_RESTORE=0
SKIP_RESTORE_SAFE_BACKUP=0

# ------ FUNCTIONS ------

# Helper function
print_usage() {
    echo "Usage: $0 -p -a <bg3_appdata> -b <backup_dir> -l <log_file> -m <max_backups> -r <backup_file> -L <game_executable>
    -a <bg3_appdata>    Path to the Baldur's Gate 3 app data directory (required)
    -b <backup_dir>     Path to the backup directory (default: ${BACKUP_DIR})
    -l <log_file>       Path to the log file (default: ${LOG_FILE})
    -m <max_backups>    Maximum number of backups to keep (default: $MAX_BACKUPS)
    -p                  Mark backup(s) to persist, even if it becomes stale or exceeds max amount. (default: false)
    -K                  Finds and immediately kills any BG3 processes (without allowing the game to autosave on exit). (default: false)
    -k                  Creates persistent backup prior to finding and immediately killing any BG3 processes (without allowing the game to autosave on exit). (default: false)
    -R                  Restores the most recent tar.gz backup file in the provided backup directory. Can't be used with \"-r\". (default: false)
    -r <restore_file>   Restores a specific tar.gz backup file. Can't be used with \"-R\". (default: none)
    -s                  Skip pre-emptive backup of appdata when restoring/writing to appdata directory. Not recommended. (default: false)
    <game_executable>   Path to the game executable. Passed as \"%command%\" by Steam. (default: none)"
}

# Function to log messages with timestamp
log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" | tee -a "${LOG_FILE}"
}

# Rotate logs based on filesize
rotate_logs() {
    if [ -f "${LOG_FILE}" ] && [ $(stat -c%s "${LOG_FILE}") -ge $LOG_SIZE_THRESHOLD ]; then
        for ((i=$MAX_LOG_FILES-1; i>=1; i--)); do
            if [ -f "${LOG_FILE}.${i}.gz" ]; then
                mv "${LOG_FILE}.${i}.gz" "${LOG_FILE}.$((i+1)).gz"
            fi
        done
        if [ -f "${LOG_FILE}" ]; then
            gzip "${LOG_FILE}"
            mv "${LOG_FILE}.gz" "${LOG_FILE}.1.gz"
        fi
        log "Log file rotated"
    fi
}

# Function to check if rsync is installed
check_rsync() {
    if ! command -v rsync &> /dev/null; then
        log "Warning: rsync is not installed, you may experience issues with performance!"
        echo '
        Please install rsync using the following instructions:
          On Debian/Ubuntu: sudo apt-get install rsync
          On Fedora: sudo dnf install rsync
          On Arch Linux: sudo pacman -S rsync
          On macOS: brew install rsync
          On Windows with WSL: sudo apt-get install rsync
        '
        return 1
    fi
    return 0
}

# Function to find and kill BG3
kill_bg3() {
  BGPID=$(pgrep -fn "bg3.*.exe")
  if [[ $BGPID =~ ^[0-9]+$ ]]; then
      log "Baldur's Gate 3 is running. Attempting to terminate..."
      
      # Force kill and wait for pid
      kill -9 $BGPID
      tail --pid "$BGPID" -f /dev/null & wait $!
      
      # Verify
      if ps -p $BGPID > /dev/null 2>&1; then
          log "Error: Failed to terminate Baldur's Gate 3."
          exit 1
      else
          log "Successfully terminated Baldur's Gate 3."
      fi
  else
      log "Baldur's Gate 3 is not running. Nothing to terminate."
  fi
}

# Function to list available backups
list_backups() {
    log "Listing available backups:"
    for backup in ${BACKUP_DIR}/*.tar.gz; do
        log " - $(basename "${backup}") ($(date -r "${backup}" "+%Y-%m-%d %H:%M:%S"))"
    done
}

# Creates the temp backup to copy files to initially
set_temp_dir() {
    TIMESTAMP=$(date +"%Y%m%d%H%M%S")
    TEMP_BACKUP_PATH="${TEMP_DIR}/bg3_backup_${TIMESTAMP}"
    log "Creating temp backup path: ${TEMP_BACKUP_PATH}"
    mkdir -p "${TEMP_BACKUP_PATH}"
}

# Removes the entire temp parent folder (tmp dir)
rm_temp_dir() {
    log "Deleting temp backup dir: $TEMP_DIR"
    rm -rf $TEMP_DIR
}

# Creates a timestamped backup in the temporary location
create_temp_backup() {
    set_temp_dir
    if check_rsync; then
        log "Creating temporary backup at ${TEMP_BACKUP_PATH} using rsync"
        rsync -a --delete "${BG3_APPDATA}/" "${TEMP_BACKUP_PATH}"  
    else
        log "Creating temporary backup at ${TEMP_BACKUP_PATH} using cp -r. This may take a while."
        cp -r "${BG3_APPDATA}" "${TEMP_BACKUP_PATH}"
    fi
    log "Successfully created temporary backup at ${TEMP_BACKUP_PATH}"
}

# Compresses the temporary backup
compress_backup() {
    TIMESTAMP=$(date +"%Y%m%d%H%M%S")
    BACKUP_FILE="${BACKUP_DIR}/${KEEP_BACKUP}bg3_backup_${TIMESTAMP}.tar.gz"
    log "Compressing backup to ${BACKUP_FILE}"
    tar czf "${BACKUP_FILE}" -C "${TEMP_BACKUP_PATH}" .
    log "Compression complete!"
}

# Function to remove old backups, keeping only the most recent $MAX_BACKUPS
cleanup_backups() {
    log "Cleaning up outdated backup files..."
    BACKUPS=($(ls -dt ${BACKUP_DIR}/bg3_backup_*.tar.gz))
    BACKUP_COUNT=${#BACKUPS[@]}
    if [ $BACKUP_COUNT -gt $MAX_BACKUPS ]; then
        log "Backup count of ${BACKUP_COUNT} exceeds the max of ${MAX_BACKUPS}..."
        for ((i=$MAX_BACKUPS; i<$BACKUP_COUNT; i++)); do
            rm -rf "${BACKUPS[$i]}"
            log "Removed old backup: ${BACKUPS[$i]}"
        done
    fi
    log "Cleanup complete!"
}

# Compress save data in temp 
compress_and_clean() {
    log "Starting compression and cleanup of backup data..."
    compress_backup
    cleanup_backups
    rm_temp_dir
    log "Compression and cleanup of backup data is complete!"
}

# Function to restore the backup
restore_backup() {
  if [ $SKIP_RESTORE_SAFE_BACKUP -ne 1 ]; then
    KEEP_BACKUP="RESTORE_"
    log "Safely backing up existing app data..."
    create_temp_backup
    compress_and_clean
    log "Backed up existing app data!"
  else
    log "Skipping backup of existing BG3 appdata before restoring (and writing over) BG3 appdata directory. Not recommended..."
  fi

    log "Restoring backup from ${RESTORE_FILE} to ${BG3_APPDATA}"
    mkdir -p "${TEMP_DIR}/restore"
    tar xzf "${RESTORE_FILE}" -C "${TEMP_DIR}/restore"
    rsync -a --delete "${TEMP_DIR}/restore/" "${BG3_APPDATA}/"
    log "Restore complete!"
}

# ------ OPTS ------

# Parse command line arguments
while getopts "a:b:l:m:pKkRr:" opt; do
    case ${opt} in
        a )
            BG3_APPDATA=$(readlink -f "${OPTARG}")
            ;;
        b )
            BACKUP_DIR=$(readlink -f "${OPTARG}")
            ;;
        l )
            LOG_FILE=$(readlink -f "${OPTARG}")
            ;;
        m )
            MAX_BACKUPS=$OPTARG
            ;;
        p )
            KEEP_BACKUP="KEEP_"
            ;;
        K )
            KILL_ONLY=1
            ;;
        k )
            KEEP_BACKUP="KILLED_"
            ;;
        R )
            RESTORE_LATEST=1
            ;;
        r )
            RESTORE_FILE=$(readlink -f "${OPTARG}")
            ;;
        s )
            SKIP_RESTORE_SAFE_BACKUP=1
            ;;
        \? )
            print_usage
            exit 1
            ;;
    esac
done
shift $((OPTIND -1))
GAME_EXECUTABLE=${1-""}


# ------ MAIN ------

# Ensure log file directory exists and are rotated
mkdir -p "$(dirname "${LOG_FILE}")"
rotate_logs

# If quick kill flag was provided, log and kill BG3
if [ $KILL_ONLY -eq 1 ]; then
    kill_bg3
    exit 0
fi

# Ensure backup directory exists
mkdir -p "${BACKUP_DIR}"

# Ensure required arguments are provided
if [ -z "${BG3_APPDATA}" ]; then
    log "Error: BG3_APPDATA must be specified."
    print_usage
    exit 1
fi

if [ "$KEEP_BACKUP" = "KEEP_" ]; then
    log "Keep backup flag is set, this backup will not be deleted by future backup rotations."
fi

# If restore latest flag provided, find the most recent backup file to restore from
if [ $RESTORE_LATEST -ne 0 ] && [ -z "${RESTORE_FILE}" ]; then
    RESTORE_FILE=$(ls -t ${BACKUP_DIR}/*.tar.gz 2>/dev/null | head -n 1)
fi

# Restore backup if the restore path is set by default flag (or was specified)
if [ -n "${RESTORE_FILE}" ]; then

    # Check if the restore path exists
    if [ ! -f "${RESTORE_FILE}" ]; then
        log "Error: Backup file does not exist: ${RESTORE_FILE}. Unable to restore."
        list_backups
        exit 1
    fi

    # Kill bg3 if running, start restoration process
    kill_bg3
    restore_backup

    if [ -n "${GAME_EXECUTABLE}" ]; then
        log "Launching game executable: ${GAME_EXECUTABLE}"
        (eval "${GAME_EXECUTABLE}") &
        GAME_PID=$!
        log "Game executable was launched with PID: $GAME_PID"

        # Wait for the game to finish
        wait $GAME_PID
        log "Game exited with status: ${?-'UNKNOWN'}"
    fi

    log "All done!"
    exit 0
fi

# Backup before game launch (copy to temp location)
log "Copying files from bg3 appdata dir to temp backup location..."
create_temp_backup
log "Temp backup created!"

if [ "$KEEP_BACKUP" = "KILLED_" ]; then
    log "Kill flag is set. Killing BG3..."
    kill_bg3

    # Compress temp data to destination backup dir, clean temp/backups
    compress_and_clean
elif [ -n "${GAME_EXECUTABLE}" ]; then
    log "Launching game executable: ${GAME_EXECUTABLE}"
    (eval "${GAME_EXECUTABLE}") &
    GAME_PID=$!
    log "Game executable was launched with PID: $GAME_PID"

    # Compress temp data to destination backup dir, clean temp/backups
    compress_and_clean

    # Wait for the game to finish
    wait $GAME_PID
    log "Game exited with status: ${?-'UNKNOWN'}"
fi

log "All done!"
