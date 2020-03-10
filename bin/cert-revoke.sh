#!/bin/bash
#-----------------------------------------------------------------------------
# Revokes a certificate and updates CRL (run as root)
#
# Usage: cert-revoke.sh host_name
#     where: host_name - name of the host used as filename for crt
#		
# Dependancy: requires openssl and /CA structure
#
# Updated on Mar 10, 2020 by Eugene Taylashev
#
#-----------------------------------------------------------------------------
#-- Check args
if [ $# -lt 1 ]
  then
    echo "Usage: cert-revoke.sh host_name"
	echo "Arguments are required! Exiting"
	exit 1
fi

#-- Assign args
CA_DIR=.
SA_CONFIG=$CA_DIR/openssl.cnf
CRL=$CA_DIR/crl/intermediate.crl
HNAME=$1

#-- Check that certificate exists
if [ ! -s $CA_DIR/certs/$HNAME.crt ] ; then
    echo "Certificate $CA_DIR/certs/$HNAME.crt does not exists! Exiting"
    echo "Serach required cert in $CA_DIR/index.txt and revoke manually."
	exit 1
fi

echo "--- Revoking certificate $CA_DIR/$HNAME.crt"
#--  revoke certificate
/usr/bin/openssl ca -config $SA_CONFIG -revoke $CA_DIR/certs/${HNAME}.crt

echo "--- Updating CRL"
#--  update CRL
/usr/bin/openssl ca -config $SA_CONFIG -gencrl -out $CRL


exit 0
