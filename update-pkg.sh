#!/bin/bash
# RGS Tech - Private BigBlueButton Package Updater
# This script quickly updates a single specific package from your private FTP repository.

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (use sudo ./update-pkg.sh)"
  exit
fi

echo "==============================================================="
echo "  RGS Tech - Specific Package Updater (Ubuntu)"
echo "==============================================================="
echo ""
echo "Select the package you want to update/reinstall:"
echo " 1) bbb-apps-akka                 15) bbb-playback-notes"
echo " 2) bbb-config                    16) bbb-playback-podcast"
echo " 3) bbb-etherpad                  17) bbb-playback-presentation"
echo " 4) bbb-freeswitch-core           18) bbb-playback-screenshare"
echo " 5) bbb-freeswitch-sounds         19) bbb-record-core"
echo " 6) bbb-fsesl-akka                20) bbb-web"
echo " 7) bbb-html5                     21) bbb-webhooks"
echo " 8) bbb-graphql-middleware        22) bbb-webrtc-sfu"
echo " 9) bbb-graphql-server            23) bbb-webrtc-recorder"
echo "10) bbb-learning-dashboard        24) bbb-livekit"
echo "11) bbb-libreoffice-docker        25) bbb-transcription-controller"
echo "12) bbb-mkclean                   26) bbb-yq-go"
echo "13) bbb-pads                      27) bigbluebutton"
echo "14) bbb-playback"
echo ""

read -p "Enter the number of the package (1-27): " PKG_NUM

case $PKG_NUM in
    1) PKG_NAME="bbb-apps-akka" ;;
    2) PKG_NAME="bbb-config" ;;
    3) PKG_NAME="bbb-etherpad" ;;
    4) PKG_NAME="bbb-freeswitch-core" ;;
    5) PKG_NAME="bbb-freeswitch-sounds" ;;
    6) PKG_NAME="bbb-fsesl-akka" ;;
    7) PKG_NAME="bbb-html5" ;;
    8) PKG_NAME="bbb-graphql-middleware" ;;
    9) PKG_NAME="bbb-graphql-server" ;;
    10) PKG_NAME="bbb-learning-dashboard" ;;
    11) PKG_NAME="bbb-libreoffice-docker" ;;
    12) PKG_NAME="bbb-mkclean" ;;
    13) PKG_NAME="bbb-pads" ;;
    14) PKG_NAME="bbb-playback" ;;
    15) PKG_NAME="bbb-playback-notes" ;;
    16) PKG_NAME="bbb-playback-podcast" ;;
    17) PKG_NAME="bbb-playback-presentation" ;;
    18) PKG_NAME="bbb-playback-screenshare" ;;
    19) PKG_NAME="bbb-record-core" ;;
    20) PKG_NAME="bbb-web" ;;
    21) PKG_NAME="bbb-webhooks" ;;
    22) PKG_NAME="bbb-webrtc-sfu" ;;
    23) PKG_NAME="bbb-webrtc-recorder" ;;
    24) PKG_NAME="bbb-livekit" ;;
    25) PKG_NAME="bbb-transcription-controller" ;;
    26) PKG_NAME="bbb-yq-go" ;;
    27) PKG_NAME="bigbluebutton" ;;
    *) echo "Invalid selection!"; exit 1 ;;
esac

echo ""
echo "Updating repository index..."
apt-get update

echo ""
echo "Reinstalling latest version of $PKG_NAME from private repo..."
apt-get install --reinstall -y "$PKG_NAME"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Successfully updated $PKG_NAME!"
    echo ""
    read -p "Do you want to restart BigBlueButton to apply changes? (y/n): " ans_restart
    if [[ "$ans_restart" =~ ^[Yy]$ ]]; then
        echo "Restarting BigBlueButton..."
        bbb-conf --restart
    else
        echo "Restart skipped. Changes may not take effect until you run: sudo bbb-conf --restart"
    fi
else
    echo ""
    echo "❌ Failed to update $PKG_NAME. Check if the name is correct and available in the repo."
fi
