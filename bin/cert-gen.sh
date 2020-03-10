#!/bin/bash
#-----------------------------------------------------------------------------
# Generates a private RSA key and creates Certificate Signing Request (csr)
#
# Usage: cert-gen.sh host_name [common_name]
#     where: host_name - name of the host used as filename for key and CSR
#		common_name - (optional) host common_name, 
#		by default host_name.conestogac.on.ca
#		
# Dependancy: requires openssl and /CA/openssl.cnf
#
# Updated on Mar 10, 2020 by Eugene Taylashev
#
#-----------------------------------------------------------------------------
#-- Check args
if [ $# -lt 1 ]
  then
    echo "Usage: gen_cert.sh host_name [common_name]"
	echo "Arguments are required! Exiting"
	exit 1
fi

#-- Assign args
HNAME=$1
CNAME=$2
KEY_LEN=2048

#-- Check common name and assign default
if [ "${CNAME}" = "" ] ; then
    CNAME=${HNAME}.conestogac.on.ca
fi

#-- get some randomness
date > rnd

echo "--- Generating private key for $HNAME as ${HNAME}.key"
#--  create a private key for the device. Add -aes256 to encrypt the key
/usr/bin/openssl genrsa -rand rnd -out ${HNAME}.key $KEY_LEN

echo "--- Generating the certificate signing request as ${HNAME}.csr"
#--  generate the certificate signing request.
/usr/bin/openssl req -new -sha256 -config /CA/openssl.cnf \
-key ${HNAME}.key -out ${HNAME}.csr \
-subj "/C=CA/ST=ON/L=Waterloo/O=Conestoga College/CN=${CNAME}"

#-- set proper permission
chmod 400 ${HNAME}.key
chmod 444 ${HNAME}.csr

#-- clean up
rm rnd

echo "--- Done! Send the ${HNAME}.csr file for signing by Certificate Authority"
echo "Keep the private key ${HNAME}.key very protected"

exit 0
