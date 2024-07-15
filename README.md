# GithGuard

GithGuard is a backup script designed to safeguard your Baldur's Gate 3 save data. It creates backups before launching the game and compresses them while the game runs, ensuring that your progress is always protected. Also, enables "save-scum" in honor mode!

![Laizel laughing](https://i.redd.it/zucyha82ercc1.jpeg)

## Example Usage

First, clone GithGuard and chmod to mark as an executable. It's recommended to do so on the drive your BG3 save data is located (for performance reasons).

```bash
git clone git@github.com:nickheyer/GithGuard.git
cd GithGuard
chmod +x ./githguard.sh
```

#### Linux

Add the following launch options to Steam:

```bash
<path_to_githguard_dir>/githguard.sh -a "/path/to/bg3_appdata" -m 3 "%command%"
```

Example for Linux using Proton:

```bash
WINEDLLOVERRIDES="DWrite.dll=n,b" PROTON_NO_ESYNC=1 <path_to_githguard_dir>/githguard.sh -a "/mnt/gamedrive/SteamLibrary/steamapps/compatdata/1086940/pfx/drive_c/users/steamuser/AppData/Local/Larian Studios" "%command%"
```

Manually invoke GithGuard from the command line:

```bash
<path_to_githguard_dir>/githguard.sh -a "/path/to/bg3_appdata" -m 3
```

#### Windows w/ WSL2 (EXPERIMENTAL)

Add the following launch options to Steam:

```bash
wsl bash -c '<path_to_githguard_dir>/githguard.sh -a "/path/to/bg3_appdata" "cmd.exe /C %command%"'
```

Manually invoke GithGuard from the command line:

```bash
wsl bash -c '<path_to_githguard_dir>/githguard.sh -a "/path/to/bg3_appdata" -m 3'
```

#### Restoring Backups

Restore the most recent backup:

```bash
<path_to_githguard_dir>/githguard.sh -R -a "/path/to/bg3_appdata"
```

Restore a specific backup:

```bash
<path_to_githguard_dir>/githguard.sh -a "/path/to/bg3_appdata" -r "/path/to/backup_file.tar.gz"
```

Restore the most recent backup and launch the game:

```bash
<path_to_githguard_dir>/githguard.sh -R -a "/path/to/bg3_appdata"  "%command%"
```

Restore a specific backup and launch the game:

```bash
<path_to_githguard_dir>/githguard.sh -a "/path/to/bg3_appdata" -r "/path/to/backup_file.tar.gz" "%command%"
```

Restore the most recent backup and do not backup appdata beforehand (not recommended):

```bash
<path_to_githguard_dir>/githguard.sh -R -a "/path/to/bg3_appdata" -s
```

## Parameters

- `-a <bg3_appdata>`: Path to the Baldur's Gate 3 app data directory (required)
- `-b <backup_dir>`: Path to the backup directory (default: `<script_directory>/backups`)
- `-l <log_file>`: Path to the log file (default: `<backup_dir>/bg3_backup.log`)
- `-m <max_backups>`: Maximum number of backups to keep (default: 3)
- `-p`: Mark backup(s) to persist, even if it becomes stale or exceeds max amount. (default: false)
- `-K`: Finds and immediately kills any BG3 processes (without allowing the game to autosave on exit). (default: false)
- `-k`: Creates persistent backup prior to finding and immediately killing any BG3 processes (without allowing the game to autosave on exit). (default: false)
- `-R`: Restores the most recent tar.gz backup file in the provided backup directory. Can't be used with `-r`. (default: false)
- `-r <restore_file>`: Restores a specific tar.gz backup file. Can't be used with `-R`. (default: none)
- `-s`: Skip pre-emptive backup of appdata when restoring/writing to appdata directory. Not recommended. (default: false)
- `<game_executable>`: Path to the game executable. Passed as `%command%` by Steam. (default: none)

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

## Restore

GithGuard can also restore your Baldur's Gate 3 save data from a specified backup file. If no backup file is specified, it defaults to the most recent backup in the backup directory (if a backup directory is provided). The restored save data can optionally be followed by launching the game executable.

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
- **restore_backup**: Restores a specified backup file to the BG3 app data directory.
- **list_backups**: Lists available backups.

### Execution Flow

1. **Pre-launch Backup**: Creates a temporary backup before launching the game.
2. **Launch Game**: Launches the specified game executable.
3. **Compression and Cleanup**: Compresses the temporary backup and cleans up old backups.
4. **Wait for Game Exit**: Waits for the game to exit and logs the exit status.
5. **Restore Backup**: Restores a specified backup file to the BG3 app data directory, optionally launching the game afterward.

## License

This project is licensed under the MIT License.
