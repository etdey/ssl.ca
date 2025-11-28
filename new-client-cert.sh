#!/usr/bin/env bash
#
# Creates a new HTTPS client certificate.
#
# Copyright 2025 Eric Dey. All rights reserved.
#
# This is used for provisioning service's client certificate to be used
# exclusively with HTTPS validation.
#
ME=$(basename "$0")
MYDIR=$(dirname "$0")
cd $(dirname "$0")  # operate from within my directory

# Configuration Items
#
KEY_ALGORITHM="sha256"
KEY_SIZE=2048

OPENSSL="openssl"

# Check command line arguments
if [[ $# -ne 1 || "$1" == "-h" || "$1" == "--help" ]]; then
    echo "Usage: $0 <name>"
    exit 1
fi
CERT_NAME="$1"

# Derived configuration items
CERT_URI="URI:appclient://${CERT_NAME}"
CERT_KEYFILE="${CERT_NAME}.key"
CERT_CSRFILE="${CERT_NAME}.csr"
CSR_CONFIG_FILE="${CERT_NAME}.conf"

# If the key file exists, ask if we should regenerate it
if [[ -f $CERT_KEYFILE ]]; then
    echo "Found an existing key file: $CERT_KEYFILE"
    read -p "Replace and regenerate a new key? " ANSWER
    case "$ANSWER" in
        "y" | "Y" | "yes" | "YES" )
            rm $CERT_KEYFILE
            ;;
        * )
            echo "Reusing existing key"
            ;;
    esac
fi
echo ""

# Generate a new key file
if [[ ! -f $CERT_KEYFILE ]]; then
	echo "Generating a new key ..."
	$OPENSSL genrsa -out $CERT_KEYFILE $KEY_SIZE
	echo ""
fi

# Generate the configuration input for creating the CSR
cat > $CSR_CONFIG_FILE <<EOF
[ req ]
default_bits                = $KEY_SIZE
default_keyfile             = service.key
default_md                  = $KEY_ALGORITHM
distinguished_name          = req_distinguished_name
string_mask                 = utf8only 
req_extensions              = req_cert_extensions

[ req_distinguished_name ]
commonName                  = Client Name
commonName_default          = ${CERT_NAME}
commonName_max              = 64

[ req_cert_extensions ]
# subjectAltName              = ${CERT_URI}
basicConstraints            = critical,CA:FALSE
keyUsage                    = digitalSignature, keyEncipherment
extendedKeyUsage            = clientAuth
EOF

echo "Fill in certificate request data..."
$OPENSSL req -new -config $CSR_CONFIG_FILE -key $CERT_KEYFILE -out $CERT_CSRFILE
if [[ $? -ne 0 ]]; then
    echo -e "\nError creating the CSR; this was the configuration input:\n----"
    cat $CSR_CONFIG_FILE
    echo "----"
fi

rm $CSR_CONFIG_FILE

echo ""
echo -e "To sign the certificate, run:\n  $MYDIR/sign-client-cert.sh ${CERT_NAME}"
