#!/usr/bin/env bash
#
# Sign an HTTPS client certificate.
#
# Copyright 2025 Eric Dey. All rights reserved.
#
ME=$(basename "$0")
MYDIR=$(dirname "$0")
cd $(dirname "$0")  # operate from within my directory

# Configuration Items
#
KEY_ALGORITHM="sha256"
CERT_VALID_DAYS=730
CERT_CRL_DAYS=30

OPENSSL="openssl"
RANDOM_FILE="/dev/urandom"

# Check command line arguments
if [[ $# -ne 1 || "$1" == "-h" || "$1" == "--help" ]]; then
    echo "Usage: $0 <name>"
    exit 1
fi
CERT_NAME="$1"

# Derived configuration items
CERT_CSR_FILE="${CERT_NAME}.csr"
CERT_CRT_FILE="${CERT_NAME}.crt"
CA_CONFIG_FILE="ca.config"

# CA files and directories
CA_KEY_FILE="ca.key"
CA_CERT_FILE="ca.crt"
CA_DB_CERTS_DIR="ca.db.certs"
CA_DB_INDEX_FILE="ca.db.index"
CA_DB_SERIAL_FILE="ca.db.serial"


function cleanup_and_exit {
    exit_code=${1:-0}
    if [[ $exit_code -ne 0 ]]; then
        echo -e "An error occurred. This was the CA configuration input:\n----"
        cat $CA_CONFIG_FILE
        echo "----"
    fi
    for f in $CA_CONFIG_FILE ${CA_DB_INDEX_FILE}.old ${CA_DB_SERIAL_FILE}.old; do
        rm $f 2>/dev/null
    done
    exit $exit_code
}


# Check for required CA files/directories
error_count=0
if [[ ! -f $CA_KEY_FILE ]]; then
    ((error_count++))
    echo -e "Missing CA key file. Create one by running:\n  ./create-root-ca.sh"
fi
if [[ ! -f $CA_CERT_FILE ]]; then
    ((error_count++))
    echo -e "Missing CA certificate file. Create one by running:\n  ./create-root-ca.sh"
fi
if [[ ! -d $CA_DB_CERTS_DIR ]]; then
    echo "Creating CA database directory: $CA_DB_CERTS_DIR"
    mkdir $CA_DB_CERTS_DIR
    [[ $? -ne 0 ]] && ((error_count++))
fi
if [[ ! -f $CA_DB_SERIAL_FILE ]]; then
    echo "Creating CA database serial file: $CA_DB_SERIAL_FILE"
    echo '01' >$CA_DB_SERIAL_FILE
    [[ $? -ne 0 ]] && ((error_count++))
fi
if [[ ! -f $CA_DB_INDEX_FILE ]]; then
    echo "Creating CA database index file: $CA_DB_INDEX_FILE"
    cp /dev/null $CA_DB_INDEX_FILE
    [[ $? -ne 0 ]] && ((error_count++))
fi
if [[ $error_count -ne 0 ]]; then
    echo "Fix the CA errors before continuing."
    exit 1
fi

# Check for the CSR file
if [[ ! -f $CERT_CSR_FILE ]]; then
    echo -e "No $CERT_CSR_FILE fround. Create one by running:\n  ./new-client-cert.sh $CERT_NAME"
	exit 1
fi

# Generate the CA configuration file
cat > $CA_CONFIG_FILE <<EOF
[ ca ]
default_ca      = CA_default

[ CA_default ]
dir             = .

# CA certificate and key
certificate     = \$dir/$CA_CERT_FILE
private_key     = \$dir/$CA_KEY_FILE

# Certificate tracking files and directories
certs           = \$dir
new_certs_dir   = \$dir/$CA_DB_CERTS_DIR
database        = \$dir/$CA_DB_INDEX_FILE
serial          = \$dir/$CA_DB_SERIAL_FILE
#rand_serial     = no
RANDFILE        = $RANDOM_FILE

# Certificate generation defaults
default_days    = $CERT_VALID_DAYS
default_crl_days= $CERT_CRL_DAYS
default_md      = $KEY_ALGORITHM
x509_extensions = client_ca_extensions
policy          = policy_match

# other generation options
#copy_extensions = copy
preserve        = no
email_in_dn     = no

[ policy_match ]
countryName             = optional
stateOrProvinceName     = optional
localityName            = optional
organizationName        = optional
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[ client_ca_extensions ]
basicConstraints = critical,CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth

# copy the SAN from the CSR into the final certificate
#subjectAltName = copy

# link the cert back to this specific CA key
authorityKeyIdentifier = keyid,issuer
subjectKeyIdentifier = hash

EOF

# # revoke an existing old certificate
# if [[ -f $CERT_CRT_FILE ]]; then
#     echo "Revoking current certificate: $CERT_CRT_FILE"
#     $OPENSSL ca -revoke $CERT_CRT_FILE -config $CA_CONFIG_FILE
#     [[ $? -ne 0 ]] && cleanup_and_exit 1
#     echo ""
# fi

# sign the certificate
echo "CA signing: $CERT_CSR_FILE -> $CERT_CRT_FILE:"
$OPENSSL ca -config $CA_CONFIG_FILE -out $CERT_CRT_FILE -infiles $CERT_CSR_FILE
[[ $? -ne 0 ]] && cleanup_and_exit 1
echo ""

# verify the signed certificate
echo "CA verifying: $CERT_CRT_FILE <-> CA cert"
$OPENSSL verify -CAfile $CA_CERT_FILE $CERT_CRT_FILE
[[ $? -ne 0 ]] && cleanup_and_exit 1
echo ""


cat <<EOF
Signed client certificate created: $CERT_CRT_FILE

CN: $(openssl x509 -in $CERT_CRT_FILE -noout -subject | sed 's/subject= //')
Valid From: $(openssl x509 -in $CERT_CRT_FILE -noout -startdate | sed 's/notBefore=//')
Valid To: $(openssl x509 -in $CERT_CRT_FILE -noout -enddate | sed 's/notAfter=//')

EOF

cleanup_and_exit 0
