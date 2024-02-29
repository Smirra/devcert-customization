#!/bin/sh
. "$(dirname "$0")/common.sh"

$SUDO cp $CAFILE "/etc/pki/ca-trust/source/anchors/"
$SUDO update-ca-trust

cleanup