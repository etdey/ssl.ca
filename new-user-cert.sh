#!/bin/bash
##
##  new-user-cert.sh - create the user cert for personal use.
##  Copyright (c) 2000 Yeak Nai Siew, All Rights Reserved. 
##

KEYBITS=2048
HASHALGO="sha256"

# Create the key. This should be done once per cert.
CERT=$1
if [ $# -ne 1 ]; then
        echo "Usage: $0 user@email.address.com"
        exit 1
fi

# if private key exists, ask if we want to generate a new key
if [ -f $CERT.key ]; then
  read -p "a key for this cn is already existing, generate a new one? " ANSWER
  if [ "$ANSWER" == "Y" ] || [ "$ANSWER" == "y" ]; then
    rm -f $CERT.key
  fi
fi

if [ ! -f $CERT.key ]; then
	echo "No $CERT.key found. Generating one"
	openssl genrsa -out $CERT.key $KEYBITS
	echo ""
fi

# Fill the necessary certificate data
CONFIG="user-cert.conf"
cat >$CONFIG <<EOT
[ req ]
default_bits			= $KEYBITS
default_keyfile			= user.key
default_md              = $HASHALGO
distinguished_name		= req_distinguished_name
string_mask			= nombstr
req_extensions			= v3_req
[ req_distinguished_name ]
commonName			= Common Name (eg, John Doe)
commonName_max			= 64
emailAddress			= Email Address
emailAddress_max		= 40
[ v3_req ]
subjectKeyIdentifier=hash
basicConstraints = critical,CA:FALSE
keyUsage = digitalSignature
extendedKeyUsage = codeSigning, msCodeInd, msCodeCom
nsCertType = client, email, objsign
EOT

echo "Fill in certificate data"
openssl req -new -config $CONFIG -key $CERT.key -out $CERT.csr

rm -f $CONFIG

echo ""
echo "You may now run ./sign-user-cert.sh to get it signed"
