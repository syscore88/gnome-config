#!/bin/bash
# ==========================================================
# SKRYPT KONFIGURACJI WIZUALNEJ GNOME
# ==========================================================

set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive
export PATH="/usr/sbin:/sbin:$PATH"

detect_system_lang() {
    local sys_lang="${LANG:-}"
    [[ -z "$sys_lang" ]] && sys_lang="${LC_ALL:-${LC_MESSAGES:-}}"
    if [[ "$sys_lang" == pl_PL* || "$sys_lang" == pl* ]]; then
        echo "pl"
    else
        echo "en"
    fi
}
SCRIPT_LANG="$(detect_system_lang)"

INFO='\033[0;34m'
SUCCESS='\033[0;32m'
WARN='\033[0;33m'
ERR='\033[0;31m'
NC='\033[0m'

TMP_LOG="$(mktemp /tmp/install-log.XXXXXX)"
LOG_FILE="$HOME/install_error_$(date +%Y%m%d_%H%M%S).log"

exec 3>&1
exec >>"$TMP_LOG" 2>&1

cleanup_on_exit() {
    local exit_code=$?
    printf '\033[?7h' >&3
    if [ "$exit_code" -ne 0 ]; then
        echo -e "\n" >&3
        cp -f "$TMP_LOG" "$LOG_FILE" 2>/dev/null || true
        if [[ "$SCRIPT_LANG" == "pl" ]]; then
            echo -e "${ERR}✘ Wystąpił błąd (kod: $exit_code). Szczegółowy log zapisano w: $LOG_FILE${NC}" >&3
        else
            echo -e "${ERR}✘ An error occurred (code: $exit_code). Detailed log saved to: $LOG_FILE${NC}" >&3
        fi
    fi
    rm -f "$TMP_LOG"
}
trap cleanup_on_exit EXIT

_pick_msg() { [[ "$SCRIPT_LANG" == "pl" ]] && echo "$1" || echo "$2"; }
log_info()  { local m; m="$(_pick_msg "$1" "$2")"; echo -e "${INFO}==> $m${NC}"; }
log_ok()    { local m; m="$(_pick_msg "$1" "$2")"; echo -e "${SUCCESS}✔ $m${NC}"; }
log_err()   { local m; m="$(_pick_msg "$1" "$2")"; echo -e "${ERR}✘ ERROR: $m${NC}"; }
log_warn()  { local m; m="$(_pick_msg "$1" "$2")"; echo -e "${WARN}⚠ WARN: $m${NC}"; }

trap 'log_err "Błąd w linii $LINENO. Polecenie: $BASH_COMMAND" "Error at line $LINENO. Command: $BASH_COMMAND"' ERR

show_progress() {
    local step=$1
    local total=$2
    local msg=$3
    local percent=$(( step * 100 / total ))

    local cols
    cols=$(tput cols 2>/dev/null)
    [[ "$cols" =~ ^[0-9]+$ ]] || cols=80

    local bar_width=50
    local reserved=12
    if (( cols - reserved < bar_width )); then
        bar_width=$(( cols - reserved ))
        (( bar_width < 10 )) && bar_width=10
    fi

    local overhead=$(( bar_width + reserved ))
    local avail=$(( cols - overhead ))
    if (( avail < 5 )); then avail=5; fi
    if (( ${#msg} > avail )); then
        msg="${msg:0:$((avail - 1))}…"
    fi

    local filled=$(( percent * bar_width / 100 ))
    local empty=$(( bar_width - filled ))

    local bar_filled=""
    local bar_empty=""
    if [ $filled -gt 0 ]; then printf -v bar_filled '%*s' "$filled" ''; bar_filled="${bar_filled// /#}"; fi
    if [ $empty -gt 0 ]; then printf -v bar_empty '%*s' "$empty" ''; bar_empty="${bar_empty// /-}"; fi

    printf "\r\033[K[\033[1;32m%s\033[0;90m%s\033[0m] %3d%% | \033[1;36m%s\033[0m" "$bar_filled" "$bar_empty" "$percent" "$msg" >&3
}

if [[ "$SCRIPT_LANG" == "pl" ]]; then
    MSG_PHASE_1="[1/3] Wykrywanie dystrybucji i konfiguracja uprawnień..."
    MSG_PHASE_2="[2/3] Instalacja i weryfikacja pakietów GNOME..."
    MSG_PHASE_3="[3/3] Konfiguracja środowiska, tapety i ustawień wizualnych..."
    MSG_LOGIN_WALLPAPER="Konfiguracja tapety ekranu logowania (GDM) przez dconf..."
else
    MSG_PHASE_1="[1/3] Detecting distribution and configuring permissions..."
    MSG_PHASE_2="[2/3] Installing and verifying GNOME packages..."
    MSG_PHASE_3="[3/3] Configuring environment, wallpaper, and visual settings..."
    MSG_LOGIN_WALLPAPER="Configuring GDM login screen wallpaper via dconf..."
fi

TOTAL_STEPS=12

CURRENT_USER=$(whoami)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
USER_PICTURES="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")"
wallpaper_PATH="$USER_PICTURES/wallpaper.jpg"

if [[ "$EUID" -eq 0 ]]; then
    echo -e "${ERR}✘ Nie uruchamiaj skryptu jako root. Uruchom jako zwykły użytkownik z sudo.${NC}" >&3
    exit 1
fi

RUN0_NOPASSWD_FILE="/etc/polkit-1/rules.d/51-run0-nopasswd.rules"
USE_RUN0=0
if ! command -v visudo >/dev/null 2>&1 || sudo --version 2>/dev/null | grep -qi "run0"; then
    USE_RUN0=1
fi

sudo -v

if [[ "$USE_RUN0" -eq 1 ]]; then
    printf 'polkit._run0_nopasswd.push("%s");\n' "$CURRENT_USER" | sudo tee "$RUN0_NOPASSWD_FILE" > /dev/null
    sudo systemctl try-restart polkit 2>/dev/null || true
else
    SUDOERS_TMP="$(mktemp)"
    echo "$CURRENT_USER ALL=(ALL) NOPASSWD: ALL" > "$SUDOERS_TMP"
    if sudo visudo -cf "$SUDOERS_TMP" &>/dev/null; then
        sudo install -m 0440 -o root -g root "$SUDOERS_TMP" /etc/sudoers.d/99-temp-installer
    else
        rm -f "$SUDOERS_TMP"
        log_err "Nieprawidłowa składnia reguły sudoers." "Invalid sudoers rule syntax."
        exit 1
    fi
    rm -f "$SUDOERS_TMP"
fi

# ==========================================================
# 1. WSTĘPNE SPRAWDZENIA I UPRAWNIENIA
# ==========================================================
show_progress 0 $TOTAL_STEPS "$MSG_PHASE_1"

printf '\033[?7h' >&3

printf '\033[?7l' >&3

show_progress 1 $TOTAL_STEPS "$MSG_PHASE_1"

# ==========================================================
# 2. WYKRYWANIE DYSTRYBUCJI I INSTALACJA PAKIETÓW
# ==========================================================
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS="${ID:-}"
        OS_LIKE="${ID_LIKE:-}"
    else
        OS="unknown"
        OS_LIKE=""
    fi
}

install_gnome_packages() {
    if [[ "$OS" == *"ubuntu"* || "$OS" == *"debian"* || "$OS_LIKE" == *"ubuntu"* || "$OS_LIKE" == *"debian"* || "$OS" == *"pop"* || "$OS" == *"linuxmint"* ]]; then
        sudo apt-get update -yq || true
        for pkg in gnome-tweaks gnome-shell-extension-prefs gnome-shell-extensions dconf-cli; do
            sudo apt-get install -yq "$pkg" || true
        done
    elif [[ "$OS" == "fedora" || "$OS_LIKE" == *"fedora"* ]]; then
        for pkg in gnome-tweaks gnome-extensions-app dconf; do
            sudo dnf install -yq "$pkg" || true
        done
    elif [[ "$OS" == "arch" || "$OS_LIKE" == *"arch"* || "$OS" == "manjaro" ]]; then
        for pkg in gnome-tweaks gnome-shell-extensions dconf; do
            sudo pacman -S --noconfirm --needed "$pkg" || true
        done
    elif [[ "$OS" == *"opensuse"* || "$OS" == *"suse"* || "$OS_LIKE" == *"suse"* ]]; then
        for pkg in gnome-tweaks gnome-shell-extensions dconf; do
            sudo zypper install -yqn "$pkg" || true
        done
    fi
}

detect_os
show_progress 2 $TOTAL_STEPS "$MSG_PHASE_2"

install_gnome_packages
show_progress 3 $TOTAL_STEPS "$MSG_PHASE_2"

# ==========================================================
# 3. KONFIGURACJA WIZUALNA GNOME
# ==========================================================
show_progress 4 $TOTAL_STEPS "$MSG_PHASE_3"

if [[ -d "$SCRIPT_DIR/.config" ]]; then cp -af "$SCRIPT_DIR/.config/." ~/.config/ || true; fi
if [[ -d "$SCRIPT_DIR/.local" ]]; then cp -af "$SCRIPT_DIR/.local/." ~/.local/ || true; fi

if [[ -d "$SCRIPT_DIR/.icons" ]]; then
    mkdir -p ~/.icons
    cp -af "$SCRIPT_DIR/.icons/." ~/.icons/ || true
fi

if [[ -f "$SCRIPT_DIR/wallpaper.jpg" ]]; then
    mkdir -p "$(dirname "$wallpaper_PATH")"
    cp -af "$SCRIPT_DIR/wallpaper.jpg" "$wallpaper_PATH" || true
fi

show_progress 5 $TOTAL_STEPS "$MSG_PHASE_3"

if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.background picture-uri "file://$wallpaper_PATH" 2>/dev/null \
        && gsettings set org.gnome.desktop.background picture-uri-dark "file://$wallpaper_PATH" 2>/dev/null \
        && gsettings set org.gnome.desktop.background picture-options "zoom" 2>/dev/null || true

    gsettings set org.gnome.shell favorite-apps "['org.gnome.Nautilus.desktop']" 2>/dev/null || true
fi

show_progress 7 $TOTAL_STEPS "$MSG_PHASE_3"

if command -v dconf &>/dev/null; then
    mkdir -p "$HOME/.config/dconf"

    dconf load / <<'DCONF_EOF' || true
[org/gnome/Ptyxis/Profiles/979e3c3bcf05a3fa49ec466f6a5d0ca7]
bold-is-bright=true
palette='xterm'

[org/gnome/TextEditor]
restore-session=false

[org/gnome/deja-dup]
backend='google'
periodic-timestamp='2026-07-19T19:39:27.503131+02'
prompt-check='2026-07-19T19:41:27.902242+02'

[org/gnome/desktop/calendar]
show-weekdate=true
week-start-day='monday'

[org/gnome/desktop/interface]
accent-color='purple'
clock-show-seconds=true
clock-show-weekday=true
color-scheme='prefer-dark'
cursor-theme='McMojave-Cursors'
gtk-theme='Mojave-Dark'
icon-theme='BigSur'
toolkit-accessibility=false

[org/gnome/desktop/wm/preferences]
button-layout='appmenu:minimize,maximize,close'

[org/gnome/shell]
disabled-extensions=['ubuntu-dock@ubuntu.com', 'ubuntu-appindicators@ubuntu.com']
enabled-extensions=['ding@rastersoft.com', 'tiling-assistant@ubuntu.com', 'compiz-alike-magic-lamp-effect@hermes83.github.com', 'blur-my-shell@aunetx', 'weatherpanel@attentivecoder', 'compiz-windows-effect@hermes83.github.com', 'clipboard-history@alexsaveau.dev', 'system-monitor-panel@naimur']

[org/gnome/shell/extensions/appindicator]
icon-brightness=0.0
icon-contrast=0.0
icon-opacity=240
icon-saturation=0.0
icon-size=0

[org/gnome/shell/extensions/blur-my-shell]
pipelines={'pipeline_default': {'name': <'Default'>, 'effects': <[<{'type': <'native_static_gaussian_blur'>, 'id': <'effect_000000000000'>, 'params': <{'radius': <30>, 'brightness': <0.78000000000000003>, 'unscaled_radius': <45>}>}>, <{'type': <'corner'>, 'id': <'effect_10639405078369'>, 'params': <{'radius': <130>, 'corners_top': <true>, 'corners_bottom': <true>}>}>]>}}
rounded-blur-found=false
settings-version=2

[org/gnome/shell/extensions/blur-my-shell/appfolder]
brightness=0.59999999999999998
sigma=22

[org/gnome/shell/extensions/blur-my-shell/applications]
blur=true
brightness=0.84999999999999998
pipeline='pipeline_default'

[org/gnome/shell/extensions/blur-my-shell/coverflow-alt-tab]
pipeline='pipeline_default'

[org/gnome/shell/extensions/blur-my-shell/dash-to-dock]
blur=false
brightness=0.59999999999999998
override-background=true
pipeline='pipeline_default'
sigma=30
static-blur=false
style-dash-to-dock=0

[org/gnome/shell/extensions/blur-my-shell/dash-to-panel]
blur-original-panel=false

[org/gnome/shell/extensions/blur-my-shell/hidetopbar]
compatibility=false

[org/gnome/shell/extensions/blur-my-shell/lockscreen]
pipeline='pipeline_default'

[org/gnome/shell/extensions/blur-my-shell/overview]
pipeline='pipeline_default'
style-components=3

[org/gnome/shell/extensions/blur-my-shell/panel]
brightness=0.75
corner-radius=0
force-light-text=true
override-background=true
override-background-dynamically=true
pipeline='pipeline_default'
sigma=10
static-blur=false
style-panel=0

[org/gnome/shell/extensions/blur-my-shell/screenshot]
pipeline='pipeline_default'

[org/gnome/shell/extensions/blur-my-shell/window-list]
brightness=0.59999999999999998
sigma=30

[org/gnome/shell/extensions/com/github/hermes83/compiz-windows-effect]
last-version=31
preset='R'

[org/gnome/shell/extensions/dash-to-dock]
always-center-icons=true
apply-custom-theme=false
background-opacity=0.40000000000000002
custom-theme-shrink=true
dash-max-icon-size=40
dock-position='BOTTOM'
extend-height=false
height-fraction=0.78000000000000003
hide-tooltip=true
multi-monitor=true
preferred-monitor=-2
preferred-monitor-by-connector='Virtual-1'
preview-size-scale=0.20000000000000001
running-indicator-style='DOT'
show-apps-always-in-the-edge=false
show-apps-at-top=true
show-favorites=true
show-mounts=false
show-mounts-only-mounted=false
show-running=true
show-trash=false
transparency-mode='FIXED'

[org/gnome/shell/extensions/ding]
check-x11wayland=true
show-home=false

[org/gnome/shell/extensions/system-monitor-panel]
network-unit='bytes'
refresh-interval=15
show-cpu=false
show-disk=false
show-external-disks=true
show-gpu=false
show-gpu-card=true
show-icons=false
show-memory=false
show-network=true
show-temperature=false

[org/gnome/shell/extensions/system-monitor]
memory-calculation-method='all'
position='right'

[org/gnome/shell/extensions/tiling-assistant]
focus-hint-color='rgb(203,67,20)'
last-version-installed=54
overridden-settings={'org.gnome.mutter.edge-tiling': <@mb nothing>, 'org.gnome.mutter.keybindings.toggle-tiled-left': <@mb nothing>, 'org.gnome.mutter.keybindings.toggle-tiled-right': <@mb nothing>}
tiling-popup-all-workspace=true

[org/gnome/shell/extensions/weatherornot]
position='right'

[org/gnome/shell/extensions/weatherpanel]
actual-city=0
city='[{"label":"Warszawa","region":"województwo mazowieckie","postcode":"97-500","country":"Polska","lat":51.06713,"lon":19.44477}]'
position-in-panel='left'

[org/gnome/shell/world-clocks]
locations=@av []

[org/gnome/software]
check-timestamp=int64 1786635579
first-run=false

[org/gnome/system/location]
enabled=true

[org/gnome/terminal/legacy]
theme-variant='dark'

[org/gnome/terminal/legacy/profiles:/:b1dcc9dd-5262-4d8d-a863-c897e6d979b9]
background-color='rgb(0,0,0)'
cursor-colors-set=true
cursor-foreground-color='rgb(12,18,234)'
foreground-color='rgb(20,219,138)'
use-theme-colors=false
visible-name='user'

[org/gnome/tweaks]
show-extensions-notice=false

[org/gtk/gtk4/settings/file-chooser]
show-hidden=true
sort-directories-first=true
DCONF_EOF
fi

show_progress 8 $TOTAL_STEPS "$MSG_PHASE_3"

if command -v pipx &>/dev/null; then
    pipx install gnome-extensions-cli --force || true

    GEXT_CMD="$HOME/.local/bin/gext"
    if command -v gext &>/dev/null; then
        GEXT_CMD="gext"
    fi

    if [[ -x "$GEXT_CMD" ]] || command -v gext &>/dev/null; then
        for ext in \
            ding@rastersoft.com \
            tiling-assistant@ubuntu.com \
            compiz-alike-magic-lamp-effect@hermes83.github.com \
            compiz-windows-effect@hermes83.github.com \
            blur-my-shell@aunetx \
            weatherpanel@attentivecoder \
            clipboard-history@alexsaveau.dev \
            system-monitor-panel@naimur; do
            "$GEXT_CMD" install "$ext" || true
        done
    fi
fi

show_progress 9 $TOTAL_STEPS "$MSG_PHASE_3"

if [[ -f "$SCRIPT_DIR/piwo.png" ]]; then
    AVATAR_DEST="/var/lib/AccountsService/icons/$CURRENT_USER"
    sudo mkdir -p "$(dirname "$AVATAR_DEST")" || true
    sudo cp -af "$SCRIPT_DIR/piwo.png" "$AVATAR_DEST" || true
    sudo chmod 644 "$AVATAR_DEST" || true

    ACCOUNTS_FILE="/var/lib/AccountsService/users/$CURRENT_USER"
    if [[ -f "$ACCOUNTS_FILE" ]]; then
        if sudo grep -q "^Icon=" "$ACCOUNTS_FILE"; then
            sudo sed -i "s|^Icon=.*|Icon=$AVATAR_DEST|" "$ACCOUNTS_FILE" || true
        elif sudo grep -q "^\[User\]" "$ACCOUNTS_FILE"; then
            sudo sed -i "/^\[User\]/a Icon=$AVATAR_DEST" "$ACCOUNTS_FILE" || true
        else
            echo "Icon=$AVATAR_DEST" | sudo tee -a "$ACCOUNTS_FILE" > /dev/null
        fi
    else
        echo -e "[User]\nIcon=$AVATAR_DEST" | sudo tee "$ACCOUNTS_FILE" > /dev/null
    fi
fi

show_progress 10 $TOTAL_STEPS "$MSG_PHASE_3"

# ==========================================================
# 3b. TAPETA EKRANU LOGOWANIA (GDM)
# ==========================================================
if [[ -f "$SCRIPT_DIR/login-wallpaper.png" ]]; then
    show_progress 11 $TOTAL_STEPS "$MSG_LOGIN_WALLPAPER"

    LOGIN_BG_DIR="/usr/share/backgrounds/custom"
    LOGIN_BG_DEST="$LOGIN_BG_DIR/login-wallpaper.png"

    sudo mkdir -p "$LOGIN_BG_DIR" || true
    sudo cp -af "$SCRIPT_DIR/login-wallpaper.png" "$LOGIN_BG_DEST" || true
    sudo chmod 644 "$LOGIN_BG_DEST" || true

    sudo mkdir -p /etc/dconf/profile || true
    if [[ ! -f /etc/dconf/profile/gdm ]] || ! grep -q "system-db:gdm" /etc/dconf/profile/gdm 2>/dev/null; then
        printf 'user-db:user\nsystem-db:gdm\nfile-db:/usr/share/gdm/greeter-dconf-defaults\n' \
            | sudo tee /etc/dconf/profile/gdm > /dev/null || true
    fi

    sudo mkdir -p /etc/dconf/db/gdm.d || true
    {
        echo "[org/gnome/desktop/background]"
        echo "picture-uri='file://$LOGIN_BG_DEST'"
        echo "picture-uri-dark='file://$LOGIN_BG_DEST'"
        echo "picture-options='zoom'"
    } | sudo tee /etc/dconf/db/gdm.d/01-login-wallpaper > /dev/null || true

    if command -v dconf &>/dev/null; then
        sudo dconf update || true
    fi
fi

# ==========================================================
# 4. ZAKOŃCZENIE I SPRZĄTANIE
# ==========================================================
if [[ "$USE_RUN0" -eq 1 ]]; then
    sudo rm -f "$RUN0_NOPASSWD_FILE"
    sudo systemctl try-restart polkit 2>/dev/null || true
else
    sudo rm -f /etc/sudoers.d/99-temp-installer
fi

show_progress 12 $TOTAL_STEPS "$MSG_PHASE_3"
echo -e "\n" >&3

if [[ "$SCRIPT_LANG" == "pl" ]]; then
    echo -e "${SUCCESS}✔ KONFIGURACJA WIZUALNA ZAKOŃCZONA!${NC}" >&3
else
    echo -e "${SUCCESS}✔ VISUAL CONFIGURATION COMPLETED!${NC}" >&3
fi

systemctl reboot
