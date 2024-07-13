#!/usr/bin/env bash

# Default values (can be overridden by command line arguments)
BG3_APPDATA=""
BACKUP_DIR=$(readlink -f "$(dirname "${0}")/backups")
MAX_BACKUPS=3
LOG_FILE="${BACKUP_DIR}/bg3_backup.log"
DEFAULT_EXECUTABLE="echo 'No game executable provided, sleeping for 10 seconds instead...' && sleep 10"
MAX_LOG_FILES=3
LOG_SIZE_THRESHOLD=10485760
TEMP_DIR=$(mktemp -d)
TEMP_BACKUP_PATH=""

# Function to print usage
print_usage() {
    echo "Usage: $0 -a <bg3_appdata> -b <backup_dir> -l <log_file> -m <max_backups> <game_executable>
    -a <bg3_appdata>    Path to the Baldur's Gate 3 app data directory (required)
    -b <backup_dir>     Path to the backup directory (default: ${BACKUP_DIR})
    -l <log_file>       Path to the log file (default: ${LOG_FILE})
    -m <max_backups>    Maximum number of backups to keep (default: $MAX_BACKUPS)
    <game_executable>   Path to the game executable (passed as %command% by Steam)"
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

# Parse command line arguments
while getopts "a:b:l:m:" opt; do
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
        \? )
            print_usage
            exit 1
            ;;
    esac
done
shift $((OPTIND -1))

# Ensure log file directory exists
mkdir -p "${BACKUP_DIR}"
mkdir -p "$(dirname "${LOG_FILE}")"

rotate_logs

GAME_EXECUTABLE=${1-$DEFAULT_EXECUTABLE}

# Ensure required arguments are provided
if [ -z "${BG3_APPDATA}" ]; then
    log "Error: BG3_APPDATA must be specified."
    print_usage
    exit 1
fi

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
    BACKUP_FILE="${BACKUP_DIR}/bg3_backup_${TIMESTAMP}.tar.gz"
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
        for ((i=$MAX_BACKUPS; i<$BACKUP_COUNT; i++)); do
            rm -rf "${BACKUPS[$i]}"
            log "Removed old backup: ${BACKUPS[$i]}"
        done
    fi
    log "Cleanup complete!"
}

# Backup before game launch (copy to temp location)
log "Creating pre-launch backup..."
create_temp_backup
log "Pre-launch backup created!"

# Launch the game
log "Launching game executable: ${GAME_EXECUTABLE}"
(eval "${GAME_EXECUTABLE}") &
GAME_PID=$!
log "Game executable was launched with PID: $GAME_PID"

# Compress and clean
log "Starting compression and cleanup of backup data..."
compress_backup
cleanup_backups
rm_temp_dir
log "Compression and cleanup of backup data is complete!"

# Wait for the game to finish
wait $GAME_PID
log "Game exited with status $GAME_EXIT_STATUS"

log "All done!"
