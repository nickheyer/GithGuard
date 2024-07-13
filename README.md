# GithGuard

GithGuard is a backup script designed to safeguard your Baldur's Gate 3 save data. It creates backups before launching the game and compresses them while the game runs, ensuring that your progress is always protected. The script uses `rsync` for efficient backups if available, and falls back to `cp -r` if `rsync` is not installed.



![alt text="laizel laughing"](https://i.redd.it/zucyha82ercc1.jpeg)




## Example Usage

First, clone GithGuard and chmod to mark as an executable. It's recommended to do so on the drive your BG3 save data is located (for performance reasons).

```bash
git clone git@github.com:nickheyer/GithGuard.git
cd GithGuard
chmod +x ./backup.sh

# type "pwd" to see the below used <path_to_githguard_dir>
```


To use GithGuard with your Baldur's Gate 3 save data, add the following launch options to Steam:

```bash
<path_to_githguard_dir>/backup.sh -a "/path/to/bg3_appdata" -m 3 "%command%"
```

#### Linux

The below example shows what your Baldur's Gate 3 launch options might look like on a linux system using proton:

```bash
WINEDLLOVERRIDES="DWrite.dll=n,b" PROTON_NO_ESYNC=1 /mnt/gamedrive/scripts/GithGuard/backup.sh -a "/mnt/gamedrive/SteamLibrary/steamapps/compatdata/1086940/pfx/drive_c/users/steamuser/AppData/Local/Larian Studios" "%command%"
```

#### Windows ( NOT TESTED )

The below example shows what your Baldur's Gate 3 launch options might look like on a linux system using proton:

```bash
wsl bash -c '/mnt/gamedrive/scripts/GithGuard/backup.sh -a "/mnt/gamedrive/SteamLibrary/steamapps/compatdata/1086940/pfx/drive_c/users/steamuser/AppData/Local/Larian Studios" "cmd.exe /C %command%"'
```

To manually invoke GithGuard, simply remove the steam launch "%command%" and run from a command line:

```bash
<path_to_githguard_dir>/backup.sh -a "/path/to/bg3_appdata" -m 3
```

### Parameters

- `-a <bg3_appdata>`: Path to the Baldur's Gate 3 app data directory (required)
- `-b <backup_dir>`: Path to the backup directory (default: `<script_directory>/backups`)
- `-l <log_file>`: Path to the log file (default: `<backup_dir>/bg3_backup.log`)
- `-m <max_backups>`: Maximum number of backups to keep (default: 3)
- `<game_executable>`: Path to the game executable (passed as `%command%` by Steam)


## Installation

### Dependencies

GithGuard requires `rsync` for efficient backups. If `rsync` is not installed, the script will fall back to using `cp -r`.

#### Installing `rsync`

- **Debian/Ubuntu**:
  ```bash
  sudo apt-get install rsync
  ```

- **Fedora**:
  ```bash
  sudo dnf install rsync
  ```

- **Arch Linux**:
  ```bash
  sudo pacman -S rsync
  ```

- **macOS**:
  ```bash
  brew install rsync
  ```

- **Windows with WSL**:
  ```bash
  sudo apt-get install rsync
  ```

## Logging

The script logs all operations to the specified log file. By default, the log file is located at `<backup_dir>/bg3_backup.log`. The logs are rotated based on file size to ensure they don't grow indefinitely.

## Backup and Cleanup

GithGuard creates a timestamped backup in a temporary location before launching the game. It then compresses the backup and stores it in the specified backup directory. Old backups are automatically cleaned up, keeping only the most recent backups as specified by the `-m` parameter.

## Script Details

### Functions

- **print_usage**: Prints the usage instructions.
- **log**: Logs messages with a timestamp.
- **rotate_logs**: Rotates the log files based on file size.
- **check_rsync**: Checks if `rsync` is installed and provides installation instructions if not.
- **set_temp_dir**: Sets the temporary directory path for backups.
- **rm_temp_dir**: Removes the temporary directory.
- **create_temp_backup**: Creates a timestamped backup in the temporary location.
- **compress_backup**: Compresses the temporary backup.
- **cleanup_backups**: Removes old backups, keeping only the most recent specified number.

### Execution Flow

1. **Pre-launch Backup**: Creates a temporary backup before launching the game.
2. **Launch Game**: Launches the specified game executable.
3. **Compression and Cleanup**: Compresses the temporary backup and cleans up old backups.
4. **Wait for Game Exit**: Waits for the game to exit and logs the exit status.

## License

This project is licensed under the MIT License.
