#!/bin/sh
SAVE=0

usage() {
    echo "Usage: $0 [-s]"
    echo "Generates a valid ASP.NET Core self-signed certificate for the local machine."
    echo "The certificate will be imported into the system's certificate store and into various other places."
    echo "  -s: Also saves the generated crtfile to the home directory"
    exit 1
}

while getopts "sh" opt
do
    case "$opt" in
        s)
            SAVE=1
            ;;
        h)
            usage
            exit 1
            ;;
        *)
            ;;
    esac
done

TMP_PATH=/var/tmp/localhost-dev-cert
if [ ! -d $TMP_PATH ]; then
    mkdir $TMP_PATH
fi

cleanup() {
    rm -R $TMP_PATH
}

KEYFILE=$TMP_PATH/devcert.key
CSRFILE=$TMP_PATH/devcert.csr
CRTFILE=$TMP_PATH/devcert.crt
PFXFILE=$TMP_PATH/dotnet-devcert.pfx
CAFILE=$TMP_PATH/devcert-root-ca.crt
CAKEY=$TMP_PATH/devcert-root-ca.key


NSSDB_PATHS="$HOME/.pki/nssdb \
    $HOME/snap/chromium/current/.pki/nssdb \
    $HOME/snap/postman/current/.pki/nssdb"

CA_CONF_PATH=$TMP_PATH/ca.conf
cat >> $CA_CONF_PATH <<EOF
[ req ]
prompt                      = no
distinguished_name          = subject
x509_extensions             = x509_ext
 
[ subject ]
commonName                  = localhost
 
[ x509_ext ]
subjectKeyIdentifier        = hash
authorityKeyIdentifier      = keyid:always,issuer
basicConstraints            = critical,CA:true
nsComment                   = "Dev CA"
EOF

CONF_PATH=$TMP_PATH/localhost.conf
cat >> $CONF_PATH <<EOF
[req]
prompt                  = no
default_bits            = 2048
distinguished_name      = subject
req_extensions          = req_ext
x509_extensions         = x509_ext

[ subject ]
commonName              = localhost

[req_ext]
basicConstraints        = critical,CA:false
subjectAltName          = @alt_names

[x509_ext]
basicConstraints        = critical,CA:false
keyUsage                = critical, keyCertSign, cRLSign, digitalSignature,keyEncipherment
extendedKeyUsage        = critical, serverAuth
subjectAltName          = critical, @alt_names
1.3.6.1.4.1.311.84.1.1  = ASN1:UTF8String:ASP.NET Core HTTPS development certificate # Needed to get it imported by dotnet dev-certs

[alt_names]
DNS.1                   = localhost
EOF

configure_nssdb() {
    echo "Configuring nssdb for $1"
    certutil -d sql:"$1" -D -n devcert-root-ca
    certutil -d sql:"$1" -A -t "CP,," -n devcert-root-ca -i $CAFILE
}

openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout $CAKEY -out $CAFILE -config $CA_CONF_PATH --passout pass:
openssl req -new -nodes -newkey rsa:2048 -keyout $KEYFILE -out $CSRFILE -config $CONF_PATH
openssl x509 -req -in $CSRFILE -CA $CAFILE -CAkey $CAKEY -CAcreateserial -out $CRTFILE -days 365 -extfile $CONF_PATH -extensions x509_ext --passin pass:
openssl pkcs12 -export -out $PFXFILE -inkey $KEYFILE -in $CRTFILE --passout pass:

for NSSDB in $NSSDB_PATHS; do
    if [ -d "$NSSDB" ]; then
        configure_nssdb "$NSSDB"
    fi
done

if [ "$(id -u)" -ne 0 ]; then
    # shellcheck disable=SC2034 # SUDO will be used in parent scripts.
    SUDO='sudo'
fi

dotnet dev-certs https --clean --import $PFXFILE -p ""

if [ "$SAVE" = 1 ]; then
   cp $CAFILE $HOME
   echo "Saved root-ca to $HOME/$(basename $CAFILE)"
   cp $CAKEY $HOME
   echo "Saved certificate to $HOME/$(basename $CAKEY)"
   cp $CRTFILE $HOME
   echo "Saved certificate to $HOME/$(basename $CRTFILE)"
   cp $PFXFILE $HOME
   echo "Saved certificate to $HOME/$(basename $PFXFILE)"
   cp $KEYFILE $HOME
   echo "Saved key to $HOME/$(basename $KEYFILE)"
fi
