#!/bin/bash
# RGS Tech - Private BigBlueButton Package Updater
# This script quickly updates specific packages from your private FTP/HTTP repository.

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (use sudo ./update-pkg.sh)"
  exit 1
fi

echo "==============================================================="
echo "  RGS Tech - Specific Package Updater (Ubuntu)"
echo "==============================================================="
echo ""
read -p "Enter FTP/Repo Username (e.g. rgs-classes-software): " REPO_USER </dev/tty
REPO_USER=$(echo "$REPO_USER" | tr -d '\r ')
read -s -p "Enter FTP/Repo Password: " REPO_PASS </dev/tty
REPO_PASS=$(echo "$REPO_PASS" | tr -d '\r ')
echo ""
echo ""

echo "Configuring repository authentication and sources..."
mkdir -p /etc/apt/auth.conf.d /etc/apt/sources.list.d
echo "machine repo.rgstech.center login ${REPO_USER} password ${REPO_PASS}" > /etc/apt/auth.conf.d/rgstech.conf
chmod 600 /etc/apt/auth.conf.d/rgstech.conf
echo "deb [trusted=yes] https://repo.rgstech.center ./" > /etc/apt/sources.list.d/bigbluebutton.list

echo ""
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
echo "14) bbb-mkclean                   29) ALL PACKAGES (Full System Upgrade)"
echo "15) bbb-playback"
echo ""

read -p "Enter the number of the package (1-29): " PKG_NUM </dev/tty
PKG_NUM=$(echo "$PKG_NUM" | tr -d '\r ')

case $PKG_NUM in
    1) PKG_NAME="bbb-apps-akka" ;;
    2) PKG_NAME="bbb-config" ;;
    3) PKG_NAME="bbb-export-annotations" ;;
    4) PKG_NAME="bbb-freeswitch-core" ;;
    5) PKG_NAME="bbb-freeswitch-sounds" ;;
    6) PKG_NAME="bbb-fsesl-akka" ;;
    7) PKG_NAME="bbb-graphql-actions" ;;
    8) PKG_NAME="bbb-graphql-middleware" ;;
    9) PKG_NAME="bbb-graphql-server" ;;
    10) PKG_NAME="bbb-html5" ;;
    11) PKG_NAME="bbb-learning-dashboard" ;;
    12) PKG_NAME="bbb-libreoffice-docker" ;;
    13) PKG_NAME="bbb-livekit" ;;
    14) PKG_NAME="bbb-mkclean" ;;
    15) PKG_NAME="bbb-playback" ;;
    16) PKG_NAME="bbb-playback-notes" ;;
    17) PKG_NAME="bbb-playback-podcast" ;;
    18) PKG_NAME="bbb-playback-presentation" ;;
    19) PKG_NAME="bbb-playback-screenshare" ;;
    20) PKG_NAME="bbb-playback-video" ;;
    21) PKG_NAME="bbb-record-core" ;;
    22) PKG_NAME="bbb-transcription-controller" ;;
    23) PKG_NAME="bbb-web" ;;
    24) PKG_NAME="bbb-webhooks" ;;
    25) PKG_NAME="bbb-webrtc-recorder" ;;
    26) PKG_NAME="bbb-webrtc-sfu" ;;
    27) PKG_NAME="bbb-yq-go" ;;
    28) PKG_NAME="bigbluebutton" ;;
    29) PKG_NAME="ALL_PACKAGES" ;;
    *) echo "Invalid selection!"; exit 1 ;;
esac

echo ""
echo "Clearing old APT cached lists for clean refresh..."
rm -f /var/lib/apt/lists/*repo.rgstech.center* || true

echo "Updating repository index..."
apt-get update

echo ""
if [ "$PKG_NAME" = "ALL_PACKAGES" ]; then
    echo "Upgrading ALL packages from repository..."
    apt-get upgrade -y
    STATUS=$?
else
    echo "Reinstalling latest version of $PKG_NAME from private repo..."
    apt-get install --reinstall -y "$PKG_NAME"
    STATUS=$?
fi

if [ $STATUS -eq 0 ]; then
    echo ""
    echo "✅ Successfully updated $PKG_NAME!"
    echo ""
    read -p "Do you want to restart BigBlueButton to apply changes? (y/n): " ans_restart </dev/tty
    ans_restart=$(echo "$ans_restart" | tr -d '\r ')
    if [[ "$ans_restart" =~ ^[Yy]$ ]]; then
        echo "Restarting BigBlueButton..."
        bbb-conf --restart
    else
        echo "Restart skipped. Changes may not take effect until you run: sudo bbb-conf --restart"
    fi
else
    echo ""
    echo "❌ Failed to update $PKG_NAME. Check credentials and repository connectivity."
fi
