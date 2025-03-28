#!/bin/bash

# Define package metadata variables
packageName="pi-hole"
version="v5.10"
arch="ipq806x"
firmware="5.2-9283"
maintainer="Pi-hole Project"
displayname="Pi-hole"
maintainer_url="https://pi-hole.net"
support_url="https://discourse.pi-hole.net/"
helpurl="https://docs.pi-hole.net/"
adminport=80
adminurl="web"
dsmuidir="ui"
beta="no"
install_replace_packages="$packageName"
install_conflict_packages="$packageName"
install_replace_force_packages="$packageName"

# Check if the SPK_AP_TEMPLATE directory exists
if [ -d "SPK_AP_TEMPLATE" ]; then
    echo "SPK_AP_TEMPLATE directory already exists."
else
    # Create the SPK_AP_TEMPLATE directory
    mkdir "SPK_AP_TEMPLATE"
    echo "SPK_AP_TEMPLATE directory has been created."
fi

# Check if the INFO file already exists in SPK_AP_TEMPLATE directory
if [ -f "SPK_AP_TEMPLATE/INFO" ]; then
    echo "INFO file already exists in SPK_AP_TEMPLATE directory."
else
    # Create the INFO file with package metadata in SPK_AP_TEMPLATE directory
    cat <<EOF > "SPK_AP_TEMPLATE/INFO"
package="$packageName"
version="$version"
description="Pi-hole is a network-wide ad blocker that protects your devices from ads and tracking."
arch="$arch"
firmware="$firmware"
maintainer="$maintainer"
displayname="$displayname"
maintainer_url="$maintainer_url"
support_url="$support_url"
helpurl="$helpurl"
adminport=$adminport
adminurl="$adminurl"
dsmuidir="$dsmuidir"
beta="$beta"
install_replace_packages="$install_replace_packages"
install_conflict_packages="$install_conflict_packages"
install_replace_force_packages="$install_replace_force_packages"
EOF

    echo "INFO file has been created in SPK_AP_TEMPLATE directory."
fi