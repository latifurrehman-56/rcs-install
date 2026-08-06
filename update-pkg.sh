#!/bin/bash
# ===============================================================
# RGS Tech - Private BigBlueButton & RGS Suite Package Updater
# ===============================================================
# This script updates specific packages or performs a complete system
# upgrade from your private repository. Supports both interactive menu
# and direct command-line arguments.
# ===============================================================

if [ "$EUID" -ne 0 ]; then
  echo "❌ Error: Please run this script as root (use: sudo ./update-pkg.sh)"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
export LANG=C.UTF-8
export LC_ALL=C.UTF-8

usage() {
  cat <<HERE
Usage: sudo ./update-pkg.sh [OPTIONS] [PACKAGE_NAME]

Options:
  -r, --restart           Automatically restart BigBlueButton after update without prompting
  -y, --yes               Run non-interactively and accept defaults
  -h, --help              Display this help message and exit

Examples:
  sudo ./update-pkg.sh rgs-management-app --restart
  sudo ./update-pkg.sh bbb-html5 -r
  sudo ./update-pkg.sh --all --restart
HERE
}

AUTO_RESTART=false
NON_INTERACTIVE=false
TARGET_PKG=""

while [[ "$#" -gt 0 ]]; do
  case $1 in
    -r|--restart) AUTO_RESTART=true; shift ;;
    -y|--yes) NON_INTERACTIVE=true; shift ;;
    -h|--help) usage; exit 0 ;;
    --all|ALL_PACKAGES) TARGET_PKG="ALL_PACKAGES"; shift ;;
    -*) echo "Unknown option: $1"; usage; exit 1 ;;
    *) TARGET_PKG="$1"; shift ;;
  esac
done

echo "==============================================================="
echo "  RGS Tech - Specific Package & Suite Updater (Ubuntu)"
echo "==============================================================="
echo ""

# Ensure repository authentication exists
if [ -s /etc/apt/auth.conf.d/rgstech.conf ]; then
  echo "✅ Existing repository authentication found in /etc/apt/auth.conf.d/rgstech.conf. Reusing saved credentials!"
  echo ""
else
  if [ "$NON_INTERACTIVE" = true ]; then
    echo "❌ Error: Missing /etc/apt/auth.conf.d/rgstech.conf and non-interactive mode specified."
    exit 1
  fi
  read -p "Enter FTP/Repo Username (e.g. rgs-classes-software): " REPO_USER </dev/tty
  REPO_USER=$(echo "$REPO_USER" | tr -d '\r ')
  read -s -p "Enter FTP/Repo Password: " REPO_PASS </dev/tty
  REPO_PASS=$(echo "$REPO_PASS" | tr -d '\r ')
  echo ""
  echo ""

  echo "[ℹ️] Configuring repository authentication and sources..."
  mkdir -p /etc/apt/auth.conf.d /etc/apt/sources.list.d
  echo "machine repo.rgstech.center login ${REPO_USER} password ${REPO_PASS}" > /etc/apt/auth.conf.d/rgstech.conf
  chmod 600 /etc/apt/auth.conf.d/rgstech.conf
fi

if [ ! -f /etc/apt/sources.list.d/bigbluebutton.list ]; then
  mkdir -p /etc/apt/sources.list.d
  echo "deb [trusted=yes] https://repo.rgstech.center ./" > /etc/apt/sources.list.d/bigbluebutton.list
fi

# Interactive package menu if no target specified via argument
if [ -z "$TARGET_PKG" ]; then
  echo "Select the package you want to update/reinstall:"
  echo " 1) bbb-apps-akka                 16) bbb-playback-notes"
  echo " 2) bbb-config                    17) bbb-playback-podcast"
  echo " 3) bbb-export-annotations        18) bbb-playback-presentation"
  echo " 4) bbb-freeswitch-core           19) bbb-playback-screenshare"
  echo " 5) bbb-freeswitch-sounds         20) bbb-playback-video"
  echo " 6) bbb-fsesl-akka                21) bbb-record-core"
  echo " 7) bbb-graphql-actions           22) bbb-transcription-controller"
  echo " 8) bbb-graphql-middleware        23) bbb-web"
  echo " 9) bbb-graphql-server            24) bbb-webhooks"
  echo "10) bbb-html5                     25) bbb-webrtc-recorder"
  echo "11) bbb-learning-dashboard        26) bbb-webrtc-sfu"
  echo "12) bbb-libreoffice-docker        27) bbb-yq-go"
  echo "13) bbb-livekit                   28) bigbluebutton"
  echo "14) bbb-mkclean                   29) rgs-management-app (React Portal & Backend)"
  echo "15) bbb-playback                  30) ALL PACKAGES (Full RGS & BBB System Upgrade)"
  echo ""

  read -p "Enter the number of the package (1-30): " PKG_NUM </dev/tty
  PKG_NUM=$(echo "$PKG_NUM" | tr -d '\r ')

  case $PKG_NUM in
      1) TARGET_PKG="bbb-apps-akka" ;;
      2) TARGET_PKG="bbb-config" ;;
      3) TARGET_PKG="bbb-export-annotations" ;;
      4) TARGET_PKG="bbb-freeswitch-core" ;;
      5) TARGET_PKG="bbb-freeswitch-sounds" ;;
      6) TARGET_PKG="bbb-fsesl-akka" ;;
      7) TARGET_PKG="bbb-graphql-actions" ;;
      8) TARGET_PKG="bbb-graphql-middleware" ;;
      9) TARGET_PKG="bbb-graphql-server" ;;
      10) TARGET_PKG="bbb-html5" ;;
      11) TARGET_PKG="bbb-learning-dashboard" ;;
      12) TARGET_PKG="bbb-libreoffice-docker" ;;
      13) TARGET_PKG="bbb-livekit" ;;
      14) TARGET_PKG="bbb-mkclean" ;;
      15) TARGET_PKG="bbb-playback" ;;
      16) TARGET_PKG="bbb-playback-notes" ;;
      17) TARGET_PKG="bbb-playback-podcast" ;;
      18) TARGET_PKG="bbb-playback-presentation" ;;
      19) TARGET_PKG="bbb-playback-screenshare" ;;
      20) TARGET_PKG="bbb-playback-video" ;;
      21) TARGET_PKG="bbb-record-core" ;;
      22) TARGET_PKG="bbb-transcription-controller" ;;
      23) TARGET_PKG="bbb-web" ;;
      24) TARGET_PKG="bbb-webhooks" ;;
      25) TARGET_PKG="bbb-webrtc-recorder" ;;
      26) TARGET_PKG="bbb-webrtc-sfu" ;;
      27) TARGET_PKG="bbb-yq-go" ;;
      28) TARGET_PKG="bigbluebutton" ;;
      29) TARGET_PKG="rgs-management-app" ;;
      30) TARGET_PKG="ALL_PACKAGES" ;;
      *) echo "❌ Invalid selection ($PKG_NUM)! Aborting."; exit 1 ;;
  esac
fi

echo ""
echo "[ℹ️] Waiting for any active dpkg/apt package manager locks..."
while fuser /var/lib/dpkg/lock >/dev/null 2>&1 || fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
  sleep 1
done

echo "[ℹ️] Clearing old APT cached lists for clean refresh..."
rm -f /var/lib/apt/lists/*repo.rgstech.center* || true

echo "[ℹ️] Updating repository index from private RGS mirror..."
apt-get update

echo ""
if [ "$TARGET_PKG" = "ALL_PACKAGES" ]; then
  echo "[⬆️] Performing Full System Upgrade (All BBB and RGS packages)..."
  apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confnew" dist-upgrade
  STATUS=$?
else
  echo "[🔄] Reinstalling / updating latest version of '$TARGET_PKG'..."
  apt-get install --reinstall -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confnew" "$TARGET_PKG"
  STATUS=$?
fi

if [ $STATUS -eq 0 ]; then
  echo "[ℹ️] Resolving any pending DPKG configuration file conflicts (.dpkg-new / .dpkg-dist)..."
  find /etc/nginx /etc/bigbluebutton /usr/share/bigbluebutton /var/www -type f -name "*.dpkg-new" -exec sh -c 'mv -f "$1" "${1%.dpkg-new}"' _ {} \; 2>/dev/null || true
  find /etc/nginx /etc/bigbluebutton /usr/share/bigbluebutton /var/www -type f -name "*.dpkg-dist" -exec sh -c 'mv -f "$1" "${1%.dpkg-dist}"' _ {} \; 2>/dev/null || true
  systemctl reload nginx 2>/dev/null || true

  echo ""
  echo "==============================================================="
  echo " ✅ Successfully updated: $TARGET_PKG"
  echo "==============================================================="
  echo ""

  if [ "$AUTO_RESTART" = true ]; then
    echo "[🔄] Automatically restarting BigBlueButton suite..."
    bbb-conf --restart
  elif [ "$NON_INTERACTIVE" = false ]; then
    read -p "Do you want to restart BigBlueButton to apply changes now? (y/n): " ans_restart </dev/tty
    ans_restart=$(echo "$ans_restart" | tr -d '\r ' | awk '{print tolower($0)}')
    if [[ "$ans_restart" == "y" || "$ans_restart" == "yes" ]]; then
      echo "[🔄] Restarting BigBlueButton suite..."
      bbb-conf --restart
    else
      echo "[ℹ️] Restart skipped. Remember to run 'sudo bbb-conf --restart' to activate changes."
    fi
  else
    echo "[ℹ️] Non-interactive update finished. Run 'sudo bbb-conf --restart' to apply changes."
  fi
else
  echo ""
  echo "==============================================================="
  echo " ❌ Error: Failed to update '$TARGET_PKG'."
  echo " Please check repository credentials and server network access."
  echo "==============================================================="
  exit 1
fi
