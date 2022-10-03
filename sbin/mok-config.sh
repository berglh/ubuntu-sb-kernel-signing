#!/bin/bash

if [ "$EUID" != 0 ]; then
   echo "This script must be run as root to write the OpenSSL MOK config file" 
   exit 1
fi

if ((BASH_VERSINFO[0] < 4)); then
   echo "This script requires at least bash version 4"
   exit 1
fi

declare -A EXTENDEDKEYUSAGE=(["0"]="1.3.6.1.4.1.2312.16" ["1"]="1.3.6.1.4.1.2312.16.1" ["2"]="1.3.6.1.4.1.2312.16.1.1" ["3"]="1.3.6.1.4.1.2312.16.1.2" ["4"]="1.3.6.1.4.1.2312.16.1.3")

echo "
########
## OpenSSL MOK Config File Setup
"
echo "Enter OpenSSL config settings, or enter to accept defaults"
echo ''

read -p "OpenSSL MOK config file path (default: /etc/ssl/openssl-mok.cnf): " CONFIGFILE
CONFIGFILE=${CONFIGFILE:-"/etc/ssl/openssl-mok.cnf"}

read -p "Country code (default: UK): " COUNTRYCODE
COUNTRYCODE=${COUNTRYCODE:-"UK"}

read -p "State, region or province code (default: LDN): " STATE
STATE=${STATE:-"LDN"}

read -p "City or town (default: London): " CITY
CITY=${CITY:-"London"}

read -p "Organisation name (default: Canonical Ltd.): " ORG
ORG=${ORG:-"Canonical Ltd."}

read -p "Email address (default: user@ubuntu.com): " EMAIL
EMAIL=${EMAIL:-user@ubuntu.com}

echo ''
read -p "Choose the extendedKeyUsage extension (default: 4)
0: 1.3.6.1.4.1.2312.16      - Kernel OIDs
1: 1.3.6.1.4.1.2312.16.1    - X.509 extendedKeyUsage restriction set
2: 1.3.6.1.4.1.2312.16.1.1  - Firmware signing only        [Sign linux firmware]
3: 1.3.6.1.4.1.2312.16.1.2  - Module signing only          [Sign DKMS modules i.e. graphics drivers]
4: 1.3.6.1.4.1.2312.16.1.3  - Kexecable image signing only [Sign kernels]
Key Usage: " IND
IND=${IND:-4}
EKU=${EXTENDEDKEYUSAGE[$IND]:-EXTENDEDKEYUSAGE[2]}

# Generate OpenSSL MOK Configuration File
echo ''
echo 'HOME                    = .
RANDFILE                = $ENV::HOME/.rnd 
[ req ]
distinguished_name      = req_distinguished_name
x509_extensions         = v3
string_mask             = utf8only
prompt                  = no
[ req_distinguished_name ]
countryName             = '$COUNTRYCODE'
stateOrProvinceName     = '$STATE'
localityName            = '$CITY'
0.organizationName      = '$ORG'
commonName              = Secure Boot Signing Key
emailAddress            = '$EMAIL'
[ v3 ]
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always,issuer
basicConstraints        = critical,CA:FALSE
extendedKeyUsage        = codeSigning,'$EKU'
nsComment               = "OpenSSL Generated Certificate"' | tee ${CONFIGFILE}

echo "
Wrote OpenSSL MOK config file to ${CONFIGFILE}"
