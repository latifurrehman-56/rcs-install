#!/bin/bash
# ===============================================================
# RGS Tech - BigBlueButton & RGS Academy Suite Complete Cleaner
# ===============================================================
# This script completely uninstalls and scrubs BigBlueButton, RGS
# Management App, Greenlight, Keycloak, Nginx, PostgreSQL, Redis,
# MongoDB, Coturn, FreeSWITCH, HAProxy, Docker, configs, and repos.
#
# After running this script, the system will be restored to a clean
# state as if BigBlueButton/RGS Suite was never installed on it.
# ===============================================================

if [ "$EUID" -ne 0 ]; then
  echo "❌ Error: Please run this script as root (use: sudo ./clean.sh)"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

usage() {
  cat <<HERE
Usage: sudo ./clean.sh [OPTIONS]

Options:
  -f, --force             Run silently without asking for user confirmation.
  -k, --keep-recordings   Preserve BigBlueButton video recordings (/var/bigbluebutton/published & unpublished).
  -h, --help              Display this help message and exit.

Example:
  sudo ./clean.sh --force
HERE
}

FORCE=false
KEEP_RECORDINGS=false

while [[ "$#" -gt 0 ]]; do
  case $1 in
    -f|--force) FORCE=true; shift ;;
    -k|--keep-recordings) KEEP_RECORDINGS=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown parameter passed: $1"; usage; exit 1 ;;
  esac
done

if [ "$FORCE" = false ]; then
  echo "==============================================================="
  echo " ⚠️  WARNING: COMPLETE UNINSTALLATION & DATA WIPING  ⚠️"
  echo "==============================================================="
  echo "This script will COMPLETELY UNINSTALL and ERASE:"
  echo "  • BigBlueButton (all bbb-* packages, FreeSWITCH, Coturn)"
  echo "  • RGS Management App, Greenlight v3, Keycloak & LTI Framework"
  echo "  • Web servers & reverse proxies: Nginx, HAProxy, Certbot & Certs"
  echo "  • Databases: PostgreSQL, MongoDB, Redis (including ALL databases)"
  echo "  • Docker containers, images, volumes & runtime engines"
  echo "  • System configuration overrides, service accounts, & APT repos"
  if [ "$KEEP_RECORDINGS" = true ]; then
    echo "  • [INFO] Video recordings WILL BE PRESERVED (-k flag enabled)."
  else
    echo "  • ALL recorded lectures and video files in /var/bigbluebutton!"
  fi
  echo "==============================================================="
  echo ""
  read -p "Are you sure you want to proceed? Type 'YES' or 'y' to continue: " CONFIRM </dev/tty
  CONFIRM=$(echo "$CONFIRM" | tr -d '\r ' | awk '{print tolower($0)}')
  if [[ "$CONFIRM" != "yes" && "$CONFIRM" != "y" ]]; then
    echo "❌ Cleanup cancelled by user. Nothing was changed."
    exit 0
  fi
  echo ""
fi

echo "==============================================================="
echo "  Starting Complete System Cleanup..."
echo "==============================================================="

# 1. Stop all active services and kill lingering processes
echo "[1/7] 🛑 Stopping active services and killing leftover processes..."
SERVICES=(
  "bbb-web" "bbb-webrtc-sfu" "bbb-rap-starter" "bbb-rap-resque-worker" "bbb-record-core"
  "bbb-fsesl-akka" "bbb-apps-akka" "bbb-transcription-controller" "bbb-graphql-server"
  "bbb-graphql-middleware" "bbb-graphql-actions" "bbb-livekit" "bbb-webrtc-recorder"
  "bbb-playback-2.8" "bbb-playback-3.0" "freeswitch" "rgs-management-app" "coturn"
  "haproxy" "dummy-nic" "nginx" "postgresql" "mongod" "redis-server" "docker"
)

for svc in "${SERVICES[@]}"; do
  if systemctl is-active --quiet "$svc" 2>/dev/null || systemctl is-enabled --quiet "$svc" 2>/dev/null; then
    systemctl stop "$svc" 2>/dev/null || true
    systemctl disable "$svc" 2>/dev/null || true
  fi
done

# Stop any running instances of template systemd services (bbb-html5-*, etc.)
for tmpl in $(systemctl list-units --full --all 2>/dev/null | grep -E 'bbb-html5-|bbb-playback-' | awk '{print $1}'); do
  systemctl stop "$tmpl" 2>/dev/null || true
  systemctl disable "$tmpl" 2>/dev/null || true
done

# Kill running daemon processes by name if they are stuck
pkill -9 -f bbb-web 2>/dev/null || true
pkill -9 -f freeswitch 2>/dev/null || true
pkill -9 -f turnserver 2>/dev/null || true
pkill -9 -f haproxy 2>/dev/null || true
pkill -9 -f rgs-app 2>/dev/null || true

# 2. Remove Docker Containers, Images, and Volumes
echo "[2/7] 🐳 Cleaning up Docker containers, networks, volumes, and images..."
if command -v docker >/dev/null 2>&1; then
  # Try shutting down docker compose stacks if directories exist
  for dir in ~/greenlight-v3 ~/greenlight ~/bbb-lti /root/greenlight-v3 /root/greenlight /root/bbb-lti; do
    if [ -f "$dir/docker-compose.yml" ]; then
      docker compose -f "$dir/docker-compose.yml" down -v 2>/dev/null || true
    fi
  done

  # Stop and remove any remaining containers matching BBB/GL/LTI names
  FORCED_CONTAINERS=$(docker ps -a -q --filter "name=greenlight" --filter "name=broker" --filter "name=rooms" --filter "name=postgres" --filter "name=redis" 2>/dev/null)
  if [ -n "$FORCED_CONTAINERS" ]; then
    docker stop $FORCED_CONTAINERS 2>/dev/null || true
    docker rm -f -v $FORCED_CONTAINERS 2>/dev/null || true
  fi

  # Remove BBB related images
  FORCED_IMAGES=$(docker images -q "bigbluebutton/*" 2>/dev/null)
  if [ -n "$FORCED_IMAGES" ]; then
    docker rmi -f $FORCED_IMAGES 2>/dev/null || true
  fi

  # Prune dangling volumes and networks
  docker volume prune -f 2>/dev/null || true
  docker network prune -f 2>/dev/null || true
fi

# Remove application folders
rm -rf ~/greenlight-v3 ~/greenlight ~/bbb-lti /root/greenlight-v3 /root/greenlight /root/bbb-lti 2>/dev/null || true

# 3. Revert Systemd Overrides & Custom Virtual NICs
echo "[3/7] 🔧 Removing systemd override configurations & virtual NICs..."
rm -rf /etc/systemd/system/freeswitch.service.d 2>/dev/null || true
rm -rf /etc/systemd/system/bbb-html5-frontend@.service.d 2>/dev/null || true
rm -rf /etc/systemd/system/bbb-html5-backend@.service.d 2>/dev/null || true
rm -rf /etc/systemd/system/bbb-webrtc-sfu.service.d 2>/dev/null || true
rm -rf /etc/systemd/system/bbb-web.service.d 2>/dev/null || true
rm -rf /etc/systemd/system/coturn.service.d 2>/dev/null || true
rm -f /lib/systemd/system/dummy-nic.service /etc/systemd/system/dummy-nic.service 2>/dev/null || true

# Reload systemd daemon to clear cached overrides and deleted units
systemctl daemon-reload 2>/dev/null || true
systemctl reset-failed 2>/dev/null || true

# 4. Purge All APT Packages (BBB, RGS, Databases, Web Servers)
echo "[4/7] 🗑️ Purging BigBlueButton, RGS, and dependencies via APT..."
while fuser /var/lib/dpkg/lock >/dev/null 2>&1 || fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
  echo "Waiting for dpkg locks to release..."
  sleep 1
done

# Comprehensive package list to purge
PKGS_TO_PURGE=(
  "bigbluebutton*" "bbb-*" "rgs-management-app" "greenlight*"
  "freeswitch*" "coturn" "haproxy" "nginx*" "certbot" "python3-certbot-nginx"
  "yq-go" "bbb-yq-go" "redis-server*" "redis-tools*" "mongodb-org*" "mongodb*"
  "postgresql*" "libpq5" "nodejs" "docker-ce" "docker-ce-cli" "containerd.io"
  "docker-buildx-plugin" "docker-compose-plugin" "docker-compose"
)

apt-get purge -y -o Dpkg::Options::="--force-all" "${PKGS_TO_PURGE[@]}" 2>/dev/null || true
apt-get autoremove --purge -y 2>/dev/null || true
apt-get clean

# 5. Erase Data Directories, Databases, Logs, & Users
echo "[5/7] 🧹 Erasing leftover directories, logs, databases, and user accounts..."

# Handle recordings preservation if requested
if [ "$KEEP_RECORDINGS" = true ] && [ -d "/var/bigbluebutton" ]; then
  echo "[ℹ️] Preserving recordings into temporary backup location..."
  mkdir -p /var/bbb_recordings_backup
  cp -rf /var/bigbluebutton/published /var/bbb_recordings_backup/ 2>/dev/null || true
  cp -rf /var/bigbluebutton/unpublished /var/bbb_recordings_backup/ 2>/dev/null || true
fi

# Remove application directories & configuration trees
DIRS_TO_REMOVE=(
  "/etc/bigbluebutton" "/var/bigbluebutton" "/var/log/bigbluebutton"
  "/usr/share/bigbluebutton" "/usr/local/bigbluebutton" "/var/lib/bigbluebutton"
  "/usr/share/bbb-web" "/var/www/bigbluebutton-default" "/var/www/rgs-app"
  "/opt/freeswitch" "/etc/freeswitch" "/var/log/freeswitch" "/var/lib/freeswitch"
  "/usr/share/freeswitch" "/etc/nginx" "/var/log/nginx" "/usr/share/nginx"
  "/var/lib/nginx" "/etc/haproxy" "/var/lib/haproxy" "/run/haproxy"
  "/etc/turnserver.conf" "/var/log/turnserver" "/var/lib/turnserver"
  "/etc/logrotate.d/coturn" "/var/lib/postgresql" "/etc/postgresql"
  "/var/log/postgresql" "/var/lib/mongodb" "/var/log/mongodb" "/etc/mongod.conf"
  "/var/lib/redis" "/etc/redis" "/var/log/redis" "/usr/lib/node_modules"
  "/root/.npm" "/root/.node-gyp" "/root/.pm2" "/etc/letsencrypt"
  "/var/lib/docker" "/var/lib/containerd" "/tmp/*bigbluebutton*" "/tmp/carriage-return.*"
)

for target in "${DIRS_TO_REMOVE[@]}"; do
  rm -rf $target 2>/dev/null || true
done

# Restore preserved recordings if keep flag was activated
if [ "$KEEP_RECORDINGS" = true ] && [ -d "/var/bbb_recordings_backup" ]; then
  mkdir -p /var/bigbluebutton
  mv /var/bbb_recordings_backup/* /var/bigbluebutton/ 2>/dev/null || true
  rm -rf /var/bbb_recordings_backup
  echo "[✅] Saved video recordings restored to /var/bigbluebutton"
fi

# Remove users and groups created by installed servers
USERS_TO_REMOVE=("bigbluebutton" "freeswitch" "turnserver" "haproxy" "mongodb" "postgres" "redis" "greenlight")
for u in "${USERS_TO_REMOVE[@]}"; do
  if id "$u" >/dev/null 2>&1; then
    userdel -r "$u" 2>/dev/null || true
  fi
  groupdel "$u" 2>/dev/null || true
done

# Clean up orphaned dpkg statoverride entries for deleted users to prevent dpkg error (code 2) on reinstall
if [ -f /var/lib/dpkg/statoverride ]; then
  for u in "${USERS_TO_REMOVE[@]}"; do
    if ! id -u "$u" >/dev/null 2>&1 && ! getent group "$u" >/dev/null 2>&1; then
      sed -i -E "/^($u|[^ ]+ $u) /d" /var/lib/dpkg/statoverride 2>/dev/null || true
    fi
  done
fi

# 6. Revert Security Hardening & Remove APT Repositories
echo "[6/7] 🔓 Reverting system hardening and removing APT repository configurations..."

# Revert SSH Hardening (if applied by installer)
SSH_HARDEN_FILE="/etc/ssh/sshd_config.d/99-hardened-ciphers.conf"
if [ -f "$SSH_HARDEN_FILE" ]; then
  rm -f "$SSH_HARDEN_FILE"
  if systemctl is-active --quiet ssh 2>/dev/null; then
    systemctl restart ssh 2>/dev/null || true
  elif systemctl is-active --quiet sshd 2>/dev/null; then
    systemctl restart sshd 2>/dev/null || true
  fi
  echo "[ℹ️] Removed custom SSH cipher hardening and restarted sshd."
fi

# Remove APT Repositories & Auth created by RGS & BBB installers
REPOS_TO_DELETE=(
  "/etc/apt/auth.conf.d/rgstech.conf"
  "/etc/apt/sources.list.d/bigbluebutton*"
  "/etc/apt/sources.list.d/nodesource*"
  "/etc/apt/sources.list.d/docker*"
  "/etc/apt/sources.list.d/*martin-uni-mainz*"
  "/etc/apt/sources.list.d/mongodb*"
  "/etc/apt/sources.list.d/pgdg*"
  "/etc/apt/keyrings/nodesource.gpg"
  "/usr/share/keyrings/docker-archive-keyring.gpg"
  "/etc/apt/trusted.gpg.d/bigbluebutton*"
  "/etc/apt/apt.conf.d/01proxy"
)

for r in "${REPOS_TO_DELETE[@]}"; do
  rm -rf $r 2>/dev/null || true
done

# Restore default ImageMagick policy if ImageMagick is still installed
if [ -d "/etc/ImageMagick-6" ]; then
  echo "[ℹ️] Reinstalling ImageMagick defaults to reset security policy overrides..."
  apt-get install --reinstall -y -o Dpkg::Options::="--force-confmiss" imagemagick-6-common 2>/dev/null || true
fi

# Clean APT lists of deleted repositories and refresh index
rm -f /var/lib/apt/lists/*repo.rgstech.center* 2>/dev/null || true
rm -f /var/lib/apt/lists/*bigbluebutton* 2>/dev/null || true
rm -f /var/lib/apt/lists/*nodesource* 2>/dev/null || true
rm -f /var/lib/apt/lists/*download.docker* 2>/dev/null || true
apt-get update 2>/dev/null || true

# 7. Final Verification
echo "[7/7] 🔍 Verifying cleanup results..."
REMAINING_PKGS=$(dpkg -l 2>/dev/null | grep -E "bigbluebutton|rgs-management-app|freeswitch|coturn|haproxy" | awk '{print $2}' || true)
if [ -n "$REMAINING_PKGS" ]; then
  echo "⚠️ Note: The following related packages remain on the system:"
  echo "$REMAINING_PKGS"
  echo "You may run 'sudo apt purge -y <package>' manually if needed."
else
  echo "[✅] All BigBlueButton and RGS packages successfully purged."
fi

echo ""
echo "==============================================================="
echo " 🎉 CLEANUP COMPLETE!"
echo "==============================================================="
echo "Your server has been completely scrubbed of BigBlueButton,"
echo "RGS Management Suite, Greenlight, Keycloak, Nginx, PostgreSQL,"
echo "Redis, MongoDB, and associated configuration files."
echo "The system is now clean as if BBB/RGS was never installed!"
echo "==============================================================="
echo ""
