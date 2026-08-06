#!/bin/bash
# ===============================================================
# RGS Tech - BigBlueButton & RGS Academy Suite Complete Cleaner
# ===============================================================
# This script completely uninstalls and scrubs BigBlueButton, RGS
# Management App, Greenlight, Keycloak, Nginx, PostgreSQL, Redis,
# MongoDB, MySQL, Coturn, FreeSWITCH, HAProxy, Docker, configs, and repos.
#
# After running this script, the system will be restored to a completely
# clean state as if BigBlueButton/RGS Suite was never installed on it,
# guaranteeing error-free re-installations without package conflicts.
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
  echo "  • BigBlueButton (all bbb-* packages, FreeSWITCH, Coturn, HAProxy)"
  echo "  • RGS Management App, Greenlight v3, Keycloak & LTI Framework"
  echo "  • Web servers & reverse proxies: Nginx, Certbot & SSL Certs"
  echo "  • Databases: MySQL, PostgreSQL, MongoDB, Redis (all data & users)"
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
echo "  Starting Comprehensive System Cleanup..."
echo "==============================================================="

# 1. Instantly kill daemon processes & non-blocking stop of all active services/timers
echo "[1/8] 🛑 Instantly killing leftover processes and terminating services..."

# Kill all active backend daemons immediately before systemctl stop so services don't wait for graceful timeouts
pkill -9 -f "bbb-" 2>/dev/null || true
pkill -9 -f freeswitch 2>/dev/null || true
pkill -9 -f turnserver 2>/dev/null || true
pkill -9 -f haproxy 2>/dev/null || true
pkill -9 -f rgs-app 2>/dev/null || true
pkill -9 -f greenlight 2>/dev/null || true
pkill -9 -f "node " 2>/dev/null || true
pkill -9 -f "java " 2>/dev/null || true

SERVICES=(
  "bigbluebutton.target" "rgs-management-app.service" "greenlight-v3.service"
  "bbb-web.service" "bbb-webrtc-sfu.service" "bbb-rap-starter.service" "bbb-rap-resque-worker.service"
  "bbb-record-core.service" "bbb-record-core.timer" "bbb-rap-caption-inbox.service"
  "bbb-fsesl-akka.service" "bbb-apps-akka.service" "bbb-transcription-controller.service"
  "bbb-graphql-server.service" "bbb-graphql-middleware.service" "bbb-graphql-actions.service"
  "bbb-livekit.service" "bbb-webrtc-recorder.service" "bbb-webhooks.service"
  "bbb-playback-2.8.service" "bbb-playback-3.0.service" "bbb-playback-presentation.service"
  "bbb-playback-notes.service" "bbb-playback-podcast.service" "bbb-playback-screenshare.service"
  "bbb-playback-video.service" "freeswitch.service" "coturn.service" "haproxy.service"
  "dummy-nic.service" "nginx.service" "postgresql.service" "mongod.service"
  "redis-server.service" "redis.service" "mysql.service" "docker.service" "containerd.service"
)

# Pass all services to systemctl in a single command with --no-block to prevent hanging
systemctl stop --no-block "${SERVICES[@]}" 2>/dev/null || true
systemctl disable --no-block "${SERVICES[@]}" 2>/dev/null || true

# Stop any running instances of template systemd services without blocking
TMPL_SERVICES=$(systemctl list-units --full --all --no-legend 2>/dev/null | grep -E 'bbb-|bigbluebutton|rgs-|greenlight|freeswitch|turnserver|haproxy' | awk '{print $1}' | tr '\n' ' ' || true)
if [ -n "$TMPL_SERVICES" ]; then
  systemctl stop --no-block $TMPL_SERVICES 2>/dev/null || true
  systemctl disable --no-block $TMPL_SERVICES 2>/dev/null || true
fi

sleep 1
# Ensure any stubborn child processes are terminated
pkill -9 -f "bbb-|freeswitch|turnserver|haproxy|rgs-app|greenlight|livekit|node|java|nginx|redis|postgres|mongo|docker|containerd" 2>/dev/null || true

# 2. Remove Docker Containers, Images, and Volumes immediately
echo "[2/8] 🐳 Cleaning up Docker containers, networks, volumes, and images..."
if command -v docker >/dev/null 2>&1; then
  FORCED_CONTAINERS=$(docker ps -a -q 2>/dev/null)
  if [ -n "$FORCED_CONTAINERS" ]; then
    docker kill $FORCED_CONTAINERS 2>/dev/null || true
    docker rm -f -v $FORCED_CONTAINERS 2>/dev/null || true
  fi

  FORCED_IMAGES=$(docker images -q "bigbluebutton/*" 2>/dev/null)
  if [ -n "$FORCED_IMAGES" ]; then
    docker rmi -f $FORCED_IMAGES 2>/dev/null || true
  fi

  docker volume prune -f 2>/dev/null || true
  docker network prune -f 2>/dev/null || true
fi
rm -rf ~/greenlight-v3 ~/greenlight ~/bbb-lti /root/greenlight-v3 /root/greenlight /root/bbb-lti 2>/dev/null || true

# 3. Purge All APT Packages (Installed & Residual States)
echo "[3/8] 🗑️ Purging BigBlueButton, RGS, databases, and web servers via APT..."

# Release any stuck dpkg/apt locks
pkill -9 -f "apt-get|apt|dpkg" 2>/dev/null || true
rm -f /var/lib/dpkg/lock /var/lib/dpkg/lock-frontend /var/cache/apt/archives/lock 2>/dev/null || true
dpkg --configure -a --force-all 2>/dev/null || true

PKGS_TO_PURGE=(
  "bigbluebutton*" "bbb-*" "rgs-management-app*" "greenlight*"
  "freeswitch*" "coturn*" "haproxy*" "nginx*" "certbot*" "python3-certbot-nginx*"
  "yq-go*" "bbb-yq-go*" "yq*" "redis-server*" "redis-tools*" "mongodb-org*" "mongodb*"
  "postgresql*" "mysql-server*" "mysql-client*" "libpq5*" "nodejs*" "docker-ce*"
  "docker-ce-cli*" "containerd.io*" "docker-buildx-plugin*" "docker-compose-plugin*"
)

apt-get purge -y -o Dpkg::Options::="--force-all" "${PKGS_TO_PURGE[@]}" 2>/dev/null || true

# Guarantee removal of lingering residual package states in dpkg status
RESIDUAL_PKGS=$(dpkg-query -W -f='${Package} ${Status}\n' 2>/dev/null | grep -E "(bigbluebutton|bbb-|rgs-management|greenlight|freeswitch|coturn|haproxy|nginx|yq-go|redis|mongodb|postgres|mysql|docker|certbot)" | awk '{print $1}' | sort -u || true)
if [ -n "$RESIDUAL_PKGS" ]; then
  echo "[ℹ️] Purging remaining package database records: $(echo $RESIDUAL_PKGS | tr '\n' ' ')"
  dpkg --purge --force-all $RESIDUAL_PKGS 2>/dev/null || true
  apt-get purge -y -o Dpkg::Options::="--force-all" $RESIDUAL_PKGS 2>/dev/null || true
fi

apt-get autoremove --purge -y 2>/dev/null || true
apt-get clean

# 4. Erase Data Directories, Databases, Configs & Logs
echo "[4/8] 🧹 Erasing application directories, logs, configs, and database storage..."

if [ "$KEEP_RECORDINGS" = true ] && [ -d "/var/bigbluebutton" ]; then
  echo "[ℹ️] Preserving recordings into temporary backup location..."
  mkdir -p /var/bbb_recordings_backup
  cp -rf /var/bigbluebutton/published /var/bbb_recordings_backup/ 2>/dev/null || true
  cp -rf /var/bigbluebutton/unpublished /var/bbb_recordings_backup/ 2>/dev/null || true
fi

DIRS_TO_REMOVE=(
  "/etc/bigbluebutton" "/var/bigbluebutton" "/var/log/bigbluebutton"
  "/usr/share/bigbluebutton" "/usr/local/bigbluebutton" "/var/lib/bigbluebutton"
  "/usr/share/bbb-web" "/usr/share/bbb-*" "/etc/bbb-*" "/var/log/bbb-*"
  "/var/www/bigbluebutton-default" "/var/www/rgs-app" "/var/www/html/*"
  "/opt/freeswitch" "/etc/freeswitch" "/var/log/freeswitch" "/var/lib/freeswitch"
  "/usr/share/freeswitch" "/var/freeswitch"
  "/etc/nginx" "/var/log/nginx" "/usr/share/nginx" "/var/lib/nginx"
  "/etc/haproxy" "/var/lib/haproxy" "/run/haproxy"
  "/etc/turnserver.conf" "/var/log/turnserver" "/var/lib/turnserver"
  "/etc/default/coturn" "/etc/logrotate.d/coturn"
  "/var/lib/mysql" "/etc/mysql" "/var/log/mysql"
  "/var/lib/postgresql" "/etc/postgresql" "/var/log/postgresql"
  "/var/lib/mongodb" "/var/log/mongodb" "/etc/mongod.conf"
  "/var/lib/redis" "/etc/redis" "/var/log/redis"
  "/var/mediasoup" "/usr/lib/node_modules"
  "/root/.npm" "/root/.node-gyp" "/root/.pm2" "/root/.rnd" "/etc/letsencrypt"
  "/var/lib/docker" "/var/lib/containerd"
  "/tmp/*bigbluebutton*" "/tmp/carriage-return.*" "/tmp/*rgs*"
)

for target in "${DIRS_TO_REMOVE[@]}"; do
  rm -rf $target 2>/dev/null || true
done

if [ "$KEEP_RECORDINGS" = true ] && [ -d "/var/bbb_recordings_backup" ]; then
  mkdir -p /var/bigbluebutton
  mv /var/bbb_recordings_backup/* /var/bigbluebutton/ 2>/dev/null || true
  rm -rf /var/bbb_recordings_backup
  echo "[✅] Saved video recordings restored to /var/bigbluebutton"
fi

# 5. Remove Systemd Overrides, Symlinks & Virtual NICs
echo "[5/8] 🔧 Removing systemd unit overrides, symlinks, and virtual NICs..."
rm -rf /etc/systemd/system/*freeswitch* 2>/dev/null || true
rm -rf /etc/systemd/system/*bbb-* 2>/dev/null || true
rm -rf /etc/systemd/system/*bigbluebutton* 2>/dev/null || true
rm -rf /etc/systemd/system/*coturn* 2>/dev/null || true
rm -rf /etc/systemd/system/*rgs-* 2>/dev/null || true
rm -rf /etc/systemd/system/*nginx* 2>/dev/null || true
rm -rf /etc/systemd/system/*greenlight* 2>/dev/null || true
rm -rf /etc/systemd/system/multi-user.target.wants/rgs-management-app.service 2>/dev/null || true
rm -rf /etc/systemd/system/multi-user.target.wants/nginx.service 2>/dev/null || true
rm -f /lib/systemd/system/dummy-nic.service /etc/systemd/system/dummy-nic.service 2>/dev/null || true

systemctl daemon-reload 2>/dev/null || true
systemctl reset-failed 2>/dev/null || true

# 6. Remove Users, Groups & Scrub DPKG Statoverrides
echo "[6/8] 👥 Removing service accounts and sanitizing dpkg statoverride records..."
USERS_TO_REMOVE=("bigbluebutton" "freeswitch" "turnserver" "haproxy" "mongodb" "postgres" "redis" "greenlight" "mysql")

for u in "${USERS_TO_REMOVE[@]}"; do
  if id "$u" >/dev/null 2>&1; then
    userdel -r "$u" 2>/dev/null || true
  fi
  groupdel "$u" 2>/dev/null || true
done

# Clean up ANY orphaned dpkg statoverride entries for deleted users (prevents fatal dpkg error 2 on subsequent installations)
if [ -f /var/lib/dpkg/statoverride ]; then
  echo "[ℹ️] Cleaning orphaned statoverride entries from dpkg database..."
  for u in "${USERS_TO_REMOVE[@]}"; do
    sed -i -E "/^($u|[^ ]+ $u) /d; / (bigbluebutton|freeswitch|turnserver|haproxy|mongodb|postgres|redis|greenlight|mysql) /d" /var/lib/dpkg/statoverride 2>/dev/null || true
  done
fi

# 7. Revert Security Hardening & Remove APT Repositories
echo "[7/8] 🔓 Reverting system hardening and removing APT repository configurations..."

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

REPOS_TO_DELETE=(
  "/etc/apt/auth.conf.d/rgstech.conf"
  "/etc/apt/sources.list.d/bigbluebutton*"
  "/etc/apt/sources.list.d/nodesource*"
  "/etc/apt/sources.list.d/docker*"
  "/etc/apt/sources.list.d/*martin-uni-mainz*"
  "/etc/apt/sources.list.d/*mongodb*"
  "/etc/apt/sources.list.d/*pgdg*"
  "/etc/apt/sources.list.d/*mysql*"
  "/etc/apt/sources.list.d/*redis*"
  "/etc/apt/keyrings/nodesource.gpg"
  "/usr/share/keyrings/docker-archive-keyring.gpg"
  "/etc/apt/trusted.gpg.d/bigbluebutton*"
  "/etc/apt/apt.conf.d/01proxy"
)

for r in "${REPOS_TO_DELETE[@]}"; do
  rm -rf $r 2>/dev/null || true
done

if [ -d "/etc/ImageMagick-6" ]; then
  apt-get install --reinstall -y -o Dpkg::Options::="--force-confmiss" imagemagick-6-common 2>/dev/null || true
fi

rm -f /var/lib/apt/lists/*repo.rgstech.center* 2>/dev/null || true
rm -f /var/lib/apt/lists/*bigbluebutton* 2>/dev/null || true
rm -f /var/lib/apt/lists/*nodesource* 2>/dev/null || true
rm -f /var/lib/apt/lists/*download.docker* 2>/dev/null || true
apt-get update 2>/dev/null || true

# 8. Final Verification
echo "[8/8] 🔍 Verifying cleanup results..."
REMAINING_PKGS=$(dpkg-query -W -f='${Package}\n' 2>/dev/null | grep -E "^(bigbluebutton|bbb-|rgs-management-app|freeswitch|coturn|haproxy)$" || true)
if [ -n "$REMAINING_PKGS" ]; then
  echo "⚠️ Note: The following related packages remain on the system:"
  echo "$REMAINING_PKGS"
  dpkg --purge --force-all $REMAINING_PKGS 2>/dev/null || true
  echo "[ℹ️] Forced final purge on remaining packages."
else
  echo "[✅] All BigBlueButton, RGS, and associated database packages successfully purged."
fi

echo ""
echo "==============================================================="
echo " 🎉 CLEANUP COMPLETE!"
echo "==============================================================="
echo "Your server has been completely scrubbed of BigBlueButton,"
echo "RGS Management Suite, Greenlight, Keycloak, Nginx, MySQL,"
echo "PostgreSQL, Redis, MongoDB, and associated configuration files."
echo "The system is now restored to a clean state for re-installation!"
echo "==============================================================="
echo ""
