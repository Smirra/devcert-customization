#!/bin/sh
. "$(dirname "$0")/common.sh"

$SUDO rm /etc/ssl/certs/dotnet-devcert.pem
$SUDO cp $CAFILE "/usr/local/share/ca-certificates"
$SUDO update-ca-certificates

cleanup