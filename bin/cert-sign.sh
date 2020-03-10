#!/bin/bash
#-----------------------------------------------------------------------------
# Sign the Certificate Signing Request (csr) as root
#
# Usage: sign_cert.sh host_name
#     where: host_name - Certificate Signing Request file name without .csr 
#		
# Dependancy: requires openssl  and CA structure at /CA
#
# Updated on Mar 10, 2020 by Eugene Taylashev
#
#-----------------------------------------------------------------------------
#-- Check args
if [ $# -lt 1 ]
  then
    echo "Usage: cert-sign.sh host_name"
	echo "Arguments are required! Exiting"
	exit 1
fi


#-- Assign args
CNAME=$1
CERT_DAYS=730
CA_DIR=.
CHAIN=CA-chain.pem

#-- Check that file exists
if [ ! -s $CNAME.csr ] ; then
   echo "File $CNAME.csr does not exist or empty"
	echo "File is required! Exiting"
	exit 1
fi

#-- move CSR into the right folder
mv $CNAME.csr $CA_DIR/csr

#-- sign the CSR with the CA root key for 2 years
/usr/bin/openssl ca -in $CA_DIR/csr/$CNAME.csr -notext \
-config $CA_DIR/minipki.cnf -extensions server_cert \
-out $CNAME.crt -days $CERT_DAYS -md sha256

#-- save an extra copy of the certificate (one is in /CA/newcerts)
cp $CNAME.crt $CA_DIR/certs/


#-- Copy certificate chain file
if [ ! -s $CHAIN ] ; then
    cp $CA_DIR/certs/$CHAIN .
fi

echo "--- Done! Certificate $CNAME.crt is signed."
echo "Use $CHAIN as the certificate chain file."
