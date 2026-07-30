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
echo "Enter the name of the package you want to update."
echo "(For example: bbb-html5, bbb-web, bbb-webrtc-sfu)"
echo ""
read -p "Package Name: " PKG_NAME

if [ -z "$PKG_NAME" ]; then
    echo "Error: Package name cannot be empty."
    exit 1
fi

echo ""
echo "Updating repository index..."
apt-get update

echo ""
echo "Reinstalling latest version of $PKG_NAME from private repo..."
apt-get install --reinstall -y "$PKG_NAME"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Successfully updated $PKG_NAME!"
    echo "Note: Depending on the package, you may need to restart BigBlueButton:"
    echo "sudo bbb-conf --restart"
else
    echo ""
    echo "❌ Failed to update $PKG_NAME. Check if the name is correct and available in the repo."
fi
