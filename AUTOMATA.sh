sudo apt update && sudo apt full-upgrade -y;
sudo apt install git curl wget ca-certificates gnupg lsb-release build-essential python3 python3-pip python3-setuptools python3-venv python3-dev tmux htop iotop iftop btop zsh ufw nano vim silversearcher-ag ripgrep fd-find jq sipcalc whois dnsutils net-tools && python3 -m pip install --upgrade pip setuptools wheel --break-system-packages;
sudo apt install adb android-tools-adb android-tools-fastboot ufw libimobiledevice-utils usbmuxd ideviceinstaller ifuse esptool flashrom bluez bluez-hcidump binwalk squashfs-tools qemu-user-static lz4 lzop xz-utils zstd snap snapd openocd picocom minicom sigrok pulseview flashrom spi-tools i2c-tools python3-smbus nmap zenmap sqlmap hydra john nikto dirb beef gobuster dnsrecon dnsenum smbclient smbmap onesixtyone snmp snmp-mibs-downloader && systemctl enable postgresql --now && msfdb init; 
pip3 install --break-system-packages esptool platformio nrfutil mvt tailscale paramiko netmiko;
git clone https://github.com/justcallmekoko/ESP32Marauder.git /opt/esp32marauder;
curl -fsSL https://tailscale.com/install.sh | sh && sudo tailscale up;

sudo ufw --force reset;
sudo ufw default deny incoming;
sudo ufw default allow outgoing;
sudo ufw allow ssh;
sudo ufw --force enable;
sudo apt update && sudo apt full-upgrade -y;
echo "[ o7 ]: SUCCESS!"
clear && cowsay "ALL DONE! =D"
