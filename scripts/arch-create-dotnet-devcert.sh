#!/bin/sh
. "$(dirname "$0")/common.sh"

OLD_CA=/etc/ca-certificates/trust-source/localhost.p11-kit
if [ -f "$OLD_CA" ]; then
    $SUDO rm "$OLD_CA"
fi

$SUDO trust anchor --store $CAFILE
$SUDO trust extract-compat

cleanup
