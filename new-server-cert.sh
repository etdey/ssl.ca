#!/bin/bash
##
##  new-server-cert.sh - create the server cert
##  Copyright (c) 2000 Yeak Nai Siew, All Rights Reserved. 
##

KEYBITS=2048
HASHALGO="sha256"

# Create the key. This should be done once per cert.
CN=$1
if [ $# -lt 1 ]; then
    echo "Usage: $0 <www.domain.com> [subjectAltName1 [san2 ...]]"
    exit 1
fi

# force the CN to become a SAN even if no other SANs; Chrome compatibility
subjectAltNames="$*"

# if private key exists, ask if we want to generate a new key
if [ -f $CN.key ]; then
    read -p "a key for this cn is already existing, generate a new one? " ANSWER
    if [ "$ANSWER" == "Y" ] || [ "$ANSWER" == "y" ]; then
        rm -f $CN.key
    fi
fi

if [ ! -f $CN.key ]; then
    echo "No $CN.key found. Generating one"
    openssl genrsa -out $CN.key $KEYBITS
    echo ""
fi

# Fill the necessary certificate data
CONFIG="server-cert.conf"
cat >$CONFIG <<EOT
[ req ]
default_bits			= $KEYBITS
default_keyfile			= server.key
default_md              = $HASHALGO
distinguished_name		= req_distinguished_name
string_mask			= nombstr
req_extensions			= v3_req
[ req_distinguished_name ]
countryName			= Country Name (2 letter code)
countryName_default		= US
countryName_min			= 2
countryName_max			= 2
stateOrProvinceName		= State or Province Name (full name)
stateOrProvinceName_default	= Texas
localityName			= Locality Name (eg, city)
localityName_default		= Austin
0.organizationName		= Organization Name (eg, company)
0.organizationName_default	= My Personal Organization
organizationalUnitName		= Organizational Unit Name (eg, section)
organizationalUnitName_default	= Secure Server
commonName			= Common Name (eg, www.domain.com)
commonName_default      = $CN
commonName_max			= 64
emailAddress			= Email Address
emailAddress_max		= 40
[ v3_req ]
nsCertType			= server
basicConstraints		= critical,CA:false
keyUsage		= nonRepudiation, digitalSignature, keyEncipherment
EOT

# Handle optional Subject Alternate Names
if [ "$subjectAltNames" != "" ]; then
    echo "subjectAltName                  = @alt_names" >> $CONFIG
    echo "[alt_names]" >> $CONFIG
    numi=1
    numd=1
    cn_already_added=0

    # CN is added to the SAN list automatically
    for san in $CN  $subjectAltNames; do
        # if CN has already been seen, skip it
        if [ "$san" = "$CN" ]; then
            if [ $cn_already_added -eq 0 ]; then
                cn_already_added=1
            else
                continue     #skip to next SAN
            fi
        fi

        # determine if this looks like an IP or a DNS name
        echo $san | egrep '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$' &> /dev/null
    if [ $? -eq 0 ]; then
            echo "IP.$numi = $san" >> $CONFIG
            let numi++
        else
            echo "DNS.$numd = $san" >> $CONFIG
            let numd++
        fi
    done
fi

echo "Fill in certificate data"
openssl req -new -config $CONFIG -key $CN.key -out $CN.csr

rm -f $CONFIG

echo ""
echo "You may now run ./sign-server-cert.sh to get it signed"
