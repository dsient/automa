#!/usr/bin/env bash
# ============================================================================
# rpi-cyber-auto-menu.sh  –  Multi‑profile cyber‑tool installer for RPi
#
# Usage:   sudo ./rpi-cyber-auto-menu.sh
# Profiles:  1) Pi Zero (minimal)   2) Pi 3B+ (moderate)   3) Pi 5 8 GB (full)
# ============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

# ---- Global settings -----------------------------------------------------
USER_NAME="${SUDO_USER:-$USER}"
LOG_FILE="/var/log/rpi_cyber_auto.log"
BACKUP_DIR="$HOME/.rpi_auto_backups"
ZSH_THEME_NAME="funky"
# --------------------------------------------------------------------------

# ---- Logging helpers ------------------------------------------------------
log()   { printf '[%(%F %T)T] %s\n' -1 "$*" | tee -a "$LOG_FILE"; }
info()  { log " [INFO] $*"; }
warn()  { log " [WARN] $*" >&2; }
err()   { log "[ERROR] $*" >&2; exit 1; }
# --------------------------------------------------------------------------

# ---- Root guard -----------------------------------------------------------
check_root() {
    [ "$(id -u)" -eq 0 ] || err "Run as root (sudo $0)."
    log "Privileges OK."
}
# --------------------------------------------------------------------------

# ---- Command existence check ----------------------------------------------
cmd_exists() { command -v "$1" >/dev/null 2>&1; }

# ---- Backup helper --------------------------------------------------------
backup_file() {
    local src="$1"
    if [ -f "$src" ]; then
        local bak="$BACKUP_DIR$(dirname "$src")/$(basename "$src").bak-$(date +%s)"
        mkdir -p "$(dirname "$bak")"
        cp -a "$src" "$bak"
        info "Backed up $src → $bak"
    fi
}

# ---- Package installer (idempotent) ---------------------------------------
install_packages() {
    local pkg to_install=()
    for pkg in "$@"; do
        if dpkg -s "$pkg" &>/dev/null && dpkg -s "$pkg" 2>/dev/null | grep -q 'Status: install ok installed'; then
            info "$pkg already installed."
        else
            to_install+=("$pkg")
        fi
    done
    if [ ${#to_install[@]} -gt 0 ]; then
        info "Installing: ${to_install[*]}"
        apt-get update -qq
        DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${to_install[@]}"
    else
        info "All requested packages already present."
    fi
}

# ---- Add user to groups (idempotent) --------------------------------------
add_user_to_groups() {
    local user="$1"; shift
    local grp
    for grp in "$@"; do
        if groups "$user" | grep -qw "$grp"; then
            info "$user already in $grp."
        else
            usermod -a -G "$grp" "$user"
            info "Added $user to $grp."
        fi
    done
}

# ---- Config snippet writer ------------------------------------------------
set_config_value() {
    local file="$1" key="$2" value="$3" comment="${4:-""}"
    [ -f "$file" ] || { mkdir -p "$(dirname "$file")"; touch "$file"; }
    backup_file "$file"
    if grep -qE "^\s*${key}\s*=" "$file"; then
        sed -i "s|^\(\s*${key}\s*=\).*|\1${value}|" "$file"
    else
        echo -e "\n# Auto-added: ${comment}\n${key}=${value}" >> "$file"
    fi
    info "Set ${key}=${value} in ${file}"
}

# ---- Systemd service enabler -----------------------------------------------
enable_service() {
    local svc="$1"
    systemctl is-enabled --quiet "$svc" || { systemctl enable "$svc"; info "Enabled $svc."; }
    systemctl is-active --quiet "$svc" || { systemctl start "$svc"; info "Started $svc."; }
}

# ============================================================================
#   SECTION 1 – SYSTEM & CORE UTILITIES
# ============================================================================
install_system_base() {
    info "=== System Base ==="
    install_packages \
        git curl wget ca-certificates gnupg lsb-release \
        build-essential python3 python3-pip python3-setuptools \
        python3-venv python3-dev \
        tmux htop iotop iftop btop neofetch \
        zsh ufw nano vim silversearcher-ag ripgrep fd-find \
        jq sipcalc whois dnsutils net-tools

    python3 -m pip install --upgrade pip setuptools wheel 2>&1 | tee -a "$LOG_FILE"
}

# ============================================================================
#   SECTION 2 – FORENSICS & DISK IMAGING
# ============================================================================
install_forensics_suite() {
    info "=== Forensic Imaging & Analysis ==="
    install_packages \
        dcfldd dc3dd guymager ewf-tools \
        sleuthkit autopsy \
        testdisk photorec \
        foremost scalpel \
        bulk-extractor \
        libimage-exiftool-perl \
        exfatprogs exfat-fuse hfsprogs hfsutils \
        md5deep hashdeep ssdeep \
        yara

    if [ ! -d /opt/4n6pi ]; then
        git clone https://github.com/egonl/4n6pi.git /opt/4n6pi
        pip3 install -r /opt/4n6pi/requirements.txt
        info "4n6pi cloned to /opt/4n6pi"
    fi
}

# ============================================================================
#   SECTION 3 – WIRELESS ANALYSIS & MONITOR MODE
# ============================================================================
install_wireless_tools() {
    info "=== Wireless Analysis Suite ==="
    install_packages \
        aircrack-ng \
        kismet \
        tshark wireshark \
        horst \
        linssid \
        wavemon \
        hcxtools hcxdumptool \
        sparrow-wifi \
        bettercap \
        reaver cowpatty
}

# ---- Optional: Nexmon for internal brcmfmac monitor mode -------------------
setup_nexmon_monitor() {
    info "=== Nexmon monitor-mode firmware ==="
    local nexmon_url="https://github.com/seemoo-lab/nexmon.git"
    if [ ! -d /opt/nexmon ]; then
        git clone "$nexmon_url" /opt/nexmon
        cd /opt/nexmon && make && make install
        modprobe -r brcmfmac
        modprobe brcmfmac
        info "Nexmon installed. Reboot recommended."
    else
        info "Nexmon already present."
    fi
}

# ============================================================================
#   SECTION 4 – ANDROID / MOBILE FORENSICS
# ============================================================================
install_android_forensics() {
    info "=== Android Forensics Tools ==="
    install_packages \
        android-tools-adb android-tools-fastboot \
        libimobiledevice-utils libimobiledevice6 \
        usbmuxd ideviceinstaller ifuse

    [ ! -d /opt/ALEAPP ] && git clone https://github.com/abrignoni/ALEAPP.git /opt/ALEAPP
    [ ! -d /opt/iLEAPP ] && git clone https://github.com/abrignoni/iLEAPP.git /opt/iLEAPP
    if [ ! -d /opt/androidqf ]; then
        git clone https://github.com/mvt-project/androidqf.git /opt/androidqf
        pip3 install -r /opt/androidqf/requirements.txt
    fi
    pip3 install mvt  # Mobile Verification Toolkit
}

# ============================================================================
#   SECTION 5 – ESP32 / IOT SECURITY TOOLS
# ============================================================================
install_iot_tools() {
    info "=== ESP32 & IoT Security Tools ==="
    install_packages \
        esptool flashrom \
        platformio-udev \
        bluez bluez-hcidump \
        gattool

    pip3 install esptool platformio nrfutil 2>/dev/null || true

    [ ! -d /opt/esp32marauder ] && git clone https://github.com/justcallmekoko/ESP32Marauder.git /opt/esp32marauder
}

# ============================================================================
#   SECTION 6 – FIRMWARE ANALYSIS
# ============================================================================
install_firmware_tools() {
    info "=== Firmware Analysis ==="
    install_packages \
        binwalk \
        firmware-mod-kit \
        squashfs-tools \
        jefferson \
        sasquatch \
        qemu-user-static \
        ubi_reader \
        lz4 lzop xz-utils zstd

    [ ! -d /opt/firmwalker ] && git clone https://github.com/craigz28/firmwalker.git /opt/firmwalker

    # Ghidra (heavy) – only for Pi 4/5 with ≥4 GB. Uncomment if desired.
    if [ ! -d /opt/ghidra ]; then
        wget -qO- https://github.com/NationalSecurityAgency/ghidra/releases/latest/download/ghidra_11.x.x_PUBLIC_linux_arm64.tar.gz | tar xz -C /opt
    fi
}

# ============================================================================
#   SECTION 7 – HARDWARE SECURITY
# ============================================================================
install_hardware_security() {
    info "=== Hardware Security Tools ==="
    install_packages \
        openocd \
        picocom minicom \
        sigrok pulseview \
        flashrom \
        spi-tools i2c-tools \
        python3-smbus

    [ ! -d /opt/pifex ] && git clone https://github.com/nicocasel/pifex-tools.git /opt/pifex
    pip3 install -r /opt/pifex/requirements.txt 2>/dev/null || true
}

# ============================================================================
#   SECTION 8 – PENETRATION TESTING FRAMEWORKS (HEAVY)
# ============================================================================
install_pentest_frameworks() {
    info "=== Pen‑Testing Frameworks ==="
    install_packages \
        nmap zenmap \
        sqlmap \
        hydra \
        john \
        nikto \
        dirb dirbuster gobuster \
        searchsploit \
        beef-xss \
        dnsrecon dnsenum \
        enum4linux \
        smbclient smbmap \
        onesixtyone \
        snmp snmp-mibs-downloader \
        metasploit-framework

    systemctl enable postgresql --now 2>/dev/null || true
    msfdb init 2>/dev/null || true
    info "Metasploit database initialised."
}

# ============================================================================
#   SECTION 9 – OH‑MY‑ZSH & QOL
# ============================================================================
install_oh_my_zsh() {
    info "=== Oh‑My‑Zsh ==="
    if [ ! -d "/home/${USER_NAME}/.oh-my-zsh" ]; then
        su - "$USER_NAME" -c 'export RUNZSH=no; sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'
    fi
    local zshrc="/home/${USER_NAME}/.zshrc"
    backup_file "$zshrc"
    sed -i "s/^ZSH_THEME=\"[^\"]*\"/ZSH_THEME=\"${ZSH_THEME_NAME}\"/" "$zshrc"
    chsh -s "$(which zsh)" "$USER_NAME"
    info "Zsh default shell for ${USER_NAME}."
}

# ============================================================================
#   SECTION 10 – TAILSCALE & REMOTE ACCESS
# ============================================================================
install_tailscale() {
    info "=== Tailscale ==="
    if ! cmd_exists tailscale; then
        curl -fsSL https://tailscale.com/install.sh | sh
    fi
    enable_service tailscaled
    tailscale status >/dev/null 2>&1 || warn "Run 'sudo tailscale up' manually."
}

install_rpi_connect() {
    info "=== Raspberry Pi Connect ==="
    install_packages rpi-connect
    enable_service rpi-connect
    add_user_to_groups "$USER_NAME" rpi-connect
}

# ============================================================================
#   OPTIONAL HARDENING
# ============================================================================
enable_ufw_baseline() {
    info "=== UFW Baseline Firewall ==="
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw --force enable
}

disable_ipv6_if_needed() {
    local cmdline="/boot/firmware/cmdline.txt"
    backup_file "$cmdline"
    grep -q 'ipv6.disable=1' "$cmdline" || {
        sed -i 's/$/ ipv6.disable=1/' "$cmdline"
        info "IPv6 disabled in kernel cmdline (reboot to apply)."
    }
}

# ============================================================================
#   PROFILE DEFINITIONS
# ============================================================================

profile_pi_zero() {
    # Minimal yet powerful: passive wireless, basic forensics, remote admin
    install_system_base
    install_oh_my_zsh
    install_wireless_tools
    install_tailscale
    install_rpi_connect
    enable_ufw_baseline
    info "Pi Zero profile completed."
}

profile_pi_3b() {
    # Medium build – forensics, IoT, firmware, mobile, hardware (no beef/metasploit)
    install_system_base
    install_oh_my_zsh
    install_forensics_suite
    install_wireless_tools
    install_android_forensics
    install_iot_tools
    install_firmware_tools
    install_hardware_security
    install_tailscale
    install_rpi_connect
    enable_ufw_baseline
    info "Pi 3B+ profile completed."
}

profile_pi_5() {
    # Full powerhouse – everything including pentest frameworks
    install_system_base
    install_oh_my_zsh
    install_forensics_suite
    install_wireless_tools
    install_android_forensics
    install_iot_tools
    install_firmware_tools
    install_hardware_security
    install_pentest_frameworks
    install_tailscale
    install_rpi_connect
    enable_ufw_baseline
    # Ghidra (uncomment if you have 8 GB):
    # install_firmware_tools   # already called, but Ghidra is inside that function if uncommented
    info "Pi 5 (8 GB) profile completed."
}

# ============================================================================
#   INTERACTIVE MENU
# ============================================================================
show_menu() {
    echo ""
    echo "==================================================="
    echo "  RPi Automa v1"
    echo "==================================================="
    echo "  1) Pi Zero / Zero 2 W  (minimal – passive wireless & SSH)"
    echo "  2) Pi 3B+              (moderate – forensics, mobile, IoT)"
    echo "  3) Pi 5 (8GB)          (full – + Metasploit, Beef, heavy tools)"
    echo "  4) Exit without changes"
    echo "==================================================="
    echo -n "Choose your board [1-4]: "
}

# ============================================================================
#   MAIN
# ============================================================================
main() {
    mkdir -p "$BACKUP_DIR"
    check_root

    while true; do
        show_menu
        read -r choice
        case "$choice" in
            1)
                log "Starting Pi Zero / Zero 2 W profile..."
                profile_pi_zero
                break
                ;;
            2)
                log "Starting Pi 3B+ profile..."
                profile_pi_3b
                break
                ;;
            3)
                log "Starting Pi 5 (8 GB) profile..."
                profile_pi_5
                break
                ;;
            4)
                info "Exiting without changes."
                exit 0
                ;;
            *)
                warn "Invalid selection. Please enter 1, 2, 3, or 4."
                ;;
        esac
    done

    # ---- Fun ----
    [ -x /usr/games/cowsay ] && /usr/games/cowsay "Setup complete, $(whoami)!" || true
    info "Hostname: $(hostname) | Uptime: $(uptime -p) | Kernel: $(uname -r)"
    log "All done. Reboot recommended."
}

main "$@"