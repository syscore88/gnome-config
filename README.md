# 🎨 GNOME Visual Configuration Script

An automated Bash shell script designed for complete visual and environment configuration of the **GNOME** desktop across popular Linux distributions. The script automatically detects the system package manager, installs required GNOME utility packages, copies user configurations, sets the desktop wallpaper, loads `dconf` settings, installs GNOME Shell extensions, sets the user avatar, and configures the GDM login screen wallpaper.

The script auto-detects the system language (Polish/English) from the `LANG`/`LC_ALL` locale and prints all status messages accordingly.

---

## 🚀 Script Features

- **Automatic Linux Distribution Detection**: Support for Debian/Ubuntu/Pop!_OS/Linux Mint, Fedora, Arch/Manjaro, and openSUSE/SUSE systems, detected via `/etc/os-release`.
- **Temporary Passwordless Sudo**: Requests the admin password once at the start, then configures a temporary `NOPASSWD` rule (via `/etc/sudoers.d/`, or a `polkit`/`run0` rule on systems without `visudo`) so the rest of the script can run unattended. The rule is automatically removed at the end of the script.
- **GNOME Tools Installation**: Installs `gnome-tweaks`, an extension manager (`gnome-shell-extension-prefs`/`gnome-extensions-app` depending on distro), and `dconf`/`dconf-cli`.
- **Configuration Files Sync**:
  - Copies `.config/`, `.local/`, and `.icons/` folder contents into the corresponding folders in the user's home directory.
- **Wallpaper Management**:
  - Desktop wallpaper copied from `wallpaper.jpg` into the user's Pictures folder (`xdg-user-dir PICTURES`) and applied (light + dark) via `gsettings`.
  - GDM login screen wallpaper applied from `login-wallpaper.png` by writing a dedicated `gdm` `dconf` profile/database (`/etc/dconf/db/gdm.d/01-login-wallpaper`) and running `dconf update`.
- **Import dconf Settings**: Loads a full set of GNOME Shell, extension, terminal, and GTK4 file-chooser preferences directly into the user's `dconf` database via `dconf load /`.
- **GNOME Shell Extensions**: Installs `gnome-extensions-cli` (`gext`) via `pipx`, then downloads and enables:
  - *Desktop Icons NG* (`ding@rastersoft.com`)
  - *Tiling Assistant* (`tiling-assistant@ubuntu.com`)
  - *Compiz-alike Magic Lamp Effect* (`compiz-alike-magic-lamp-effect@hermes83.github.com`)
  - *Compiz Windows Effect* (`compiz-windows-effect@hermes83.github.com`)
  - *Blur my Shell* (`blur-my-shell@aunetx`)
  - *Weather Panel* (`weatherpanel@attentivecoder`)
  - *Clipboard History* (`clipboard-history@alexsaveau.dev`)
  - *System Monitor Panel* (`system-monitor-panel@naimur`)
- **User Avatar Setup**: Automatically sets the user profile picture in `AccountsService` using `piwo.png`.
- **Progress Bar & Logging**: Displays a live progress bar across 3 phases / 12 steps. On failure, a detailed log is saved to `~/install_error_<timestamp>.log`.

---

## 🐧 Supported Distributions

The script identifies the OS using `/etc/os-release` (`ID` / `ID_LIKE`) and selects the corresponding package manager:

| Distribution | Package Manager | Installed Packages |
| :--- | :--- | :--- |
| **Debian / Ubuntu / Pop!_OS / Mint** | `apt` | `gnome-tweaks`, `gnome-shell-extension-prefs`, `gnome-shell-extensions`, `dconf-cli` |
| **Fedora** | `dnf` | `gnome-tweaks`, `gnome-extensions-app`, `dconf` |
| **Arch Linux / Manjaro** | `pacman` | `gnome-tweaks`, `gnome-shell-extensions`, `dconf` |
| **openSUSE / SUSE** | `zypper` | `gnome-tweaks`, `gnome-shell-extensions`, `dconf` |

---

## 🔍 Module Details

### 1. Permissions & Distribution Detection
Verifies the script is **not** run as root, requests the sudo password once, and grants a temporary `NOPASSWD` rule for the duration of the run (via sudoers, or a `polkit`/`run0` rule on systems that lack `visudo`).

### 2. Configuration Copy & Wallpaper
Copies `.config`, `.local`, and `.icons` from the script directory into the user's home directory, copies `wallpaper.jpg` into the Pictures folder, and applies it as the light/dark desktop background via `gsettings` (also pins Nautilus as the only favorite app in the GNOME Shell dash).

### 3. Loading dconf Settings
A predefined block of GNOME Shell extension settings (Blur my Shell, Dash to Dock, Tiling Assistant, Weather Panel, System Monitor, etc.), terminal profile colors, and GTK4 file-chooser preferences is loaded with `dconf load /` under the current user's permissions.

### 4. GNOME Shell Extensions
Installs `gnome-extensions-cli` via `pipx`, then uses it (`gext install <uuid>`) to download and enable each extension listed above.

### 5. User Avatar (AccountsService)
`piwo.png` is copied to `/var/lib/AccountsService/icons/$USER`, and `/var/lib/AccountsService/users/$USER` is created or updated with the matching `Icon=` entry.

### 6. GDM Login Screen Wallpaper
`login-wallpaper.png` is copied to `/usr/share/backgrounds/custom/`. A `gdm` `dconf` profile is created (if missing) pointing at `/usr/share/gdm/greeter-dconf-defaults`, and a database file under `/etc/dconf/db/gdm.d/` sets the GDM background picture (light + dark), before `sudo dconf update` recompiles the database.

### 7. Finalization
The temporary sudo/polkit rule is removed and the system automatically **reboots** (`systemctl reboot`) to apply all changes.

---

 🛠️ How to Use

1. Clone the repository or download the files
```bash
git clone https://github.com/syscore88/gnome-config.git
```

2. Enter the downloaded folder
```bash
cd gnome-config
```

3. Make the script executable
```bash
chmod +x install.sh
```

4. Run the script
> ⚠️ **IMPORTANT:** Run the script as a **regular user** (NOT as root/sudo). The script will ask for the administrator password at the start to configure temporary elevated privileges.
```bash
./install.sh
```
---

<img width="1280" height="800" alt="Screenshot_fedora44_2026-08-31_20:36:07" src="https://github.com/user-attachments/assets/e8e30dce-db0c-4ddb-9845-ba80cd62b47b" />

### ☕ Support the Project

If you find this tool helpful and it saved you some time, consider buying me a coffee to support further development! 

[![Buy Me A Coffee](https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png)](https://buymeacoffee.com/bartekszczecinski)

---

If you find this project useful, leave a star! ⭐

---

## ⚠️ Troubleshooting & Notes

- **Changes not visible after script completion?**
  Log out and log back in, or restart GNOME Shell (`Alt + F2`, type `r` and hit `Enter` on X11 sessions).
- **Extensions not activating automatically:**
  Some extensions require a GNOME Shell restart or re-login to be detected. You can also enable them manually via the *Extensions* app (`gnome-extensions-app`).
