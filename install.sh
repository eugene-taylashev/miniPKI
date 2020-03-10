#!/bin/bash
#-----------------------------------------------------------------------------
# Create directory structure and generate a self-signed Root CA 
#
# TTL = 20 years
#
# Usage: install.sh FQDN [subject]
#     where: FQDN - fully qualified domain name for the root host
#		     subject - subject line for the certificate
#
# Updated on Mar 10, 2020 by Eugene Taylashev
#
#-----------------------------------------------------------------------------
#-- Check args
if [ $# -lt 1 ]
  then
    echo "Usage: install.sh fqdn_root_CA"
	echo "Arguments are required! Exiting"
	exit 1
fi

CA_fqdn=$1
CA_key=private/CA-root.key
CA_cert=certs/CA-root.pem

#=== Create directories
if [ ! -d certs ] ; then
	mkdir certs
fi

if [ ! -d crl ] ; then
	mkdir crl
fi

if [ ! -d csr ] ; then
	mkdir csr
fi

if [ ! -d newcerts ] ; then
	mkdir newcerts
fi

if [ ! -d private ] ; then
	mkdir private
	chown root:root private
	chmod 700 private
fi

#== Create a self-signed root CA 
openssl req -x509 -newkey rsa:4096 -keyout $CA_key -sha256 -out $CA_cert -days 7300 -subj "/CN=$CA_fqdn"

