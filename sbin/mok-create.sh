#!/bin/bash

if [ "$EUID" != 0 ]; then
   echo "This script must be run as root to write the OpenSSL MOK config file" 
   exit 1
fi

if ((BASH_VERSINFO[0] < 4)); then
   echo "This script requires at least bash version 4"
   exit 1
fi

echo "
########
## OpenSSL Create MOK Certificates
"

read -p "Provide path to MOK certificate store (default: /var/lib/shim-signed/mok): "
MOK_CERT_DIR=${MOK_CERT_DIR:-"/var/lib/shim-signed/mok"}

read -r -p "Provide the MOK certificate name, cannot be \"MOK\" (default: MOK-Kernel): "
MOK_CERT_NAME=${MOK_CERT_NAME:-"MOK-Kernel"}

if [ $MOK_CERT_NAME == "MOK" ]; then
   echo "MOK certificate name cannot be \"MOK\", as this overrides the default Ubuntu MOK for DKMS modules"
   exit 1
fi

if [ $CONFIGFILE == "" ]; then
   read -p "Provide OpenSSL MOK config file path (default: /etc/ssl/openssl-mok.cnf): "
   CONFIGFILE=${CONFIGFILE:-"/etc/ssl/openssl-mok.cnf"}
fi

mok_file_check() {
   if [ -f "${MOK_CERT_DIR}/${MOK_CERT_NAME}.der" ]; then
      read -r -p "The file ${MOK_CERT_DIR}/${MOK_CERT_NAME}.der already exists, are you sure you want to overwrite it? [y/n]: " _response
      case "$_response" in
         [Yy])
         echo "Overwriting ${MOK_CERT_DIR}/${MOK_CERT_NAME}.* files"
         ;;
         [Nn])
         read -r -p "Provide a new MOK certificate name, cannot be \"MOK\" (default: MOK-Kernel): " _response
         MOK_CERT_NAME=${_response:-"MOK-Kernel"}
         if [ $MOK_CERT_NAME == "MOK" ] || [ $MOK_CERT_NAME == "" ]; then
            echo "MOK certificate name cannot be \"MOK\", as this overrides the default Ubuntu MOK for DKMS modules
            "
            exit 1
         fi
         mok_file_check
         ;;
         *)
         mok_file_check
         ;;
      esac
   fi
}
mok_file_check

echo "
Creating MOK private certificate"
openssl req -config $CONFIGFILE \
   -new -x509 -newkey rsa:2048 \
   -nodes -days 36500 -outform DER \
   -keyout "${MOK_CERT_DIR}/${MOK_CERT_NAME}.priv" \
   -out "${MOK_CERT_DIR}/${MOK_CERT_NAME}.der"

echo "
Creating MOK pem certificate"
openssl x509 -in "${MOK_CERT_DIR}/${MOK_CERT_NAME}".der -inform DER -outform PEM -out "${MOK_CERT_DIR}/${MOK_CERT_NAME}".pem
echo "${MOK_CERT_DIR}/${MOK_CERT_NAME}.pem certificate details:
"
openssl x509 -in "${MOK_CERT_DIR}/${MOK_CERT_NAME}".pem -text | grep -e "Issuer" -e "Not After" -e "Signing" | sed 's/    //g'
