#!/bin/bash
#-----------------------------------------------------------------------------
# Common variables for miniPKI
#
# Copyright (C) by Eugene Taylashev 2020 under the MIT License
#-----------------------------------------------------------------------------

#=============================================================================
#
#  Variable declarations
#
#=============================================================================

#-- Common directories
if [ "$DIR_BASE" = "" ] ; then 
    DIR_BASE=.
fi
DIR_KEY=$DIR_BASE/keys      #-- directory for private keys
DIR_CSR=$DIR_BASE/csr       #-- directory for certificate signing requests (CSR)
DIR_CRT=$DIR_BASE/certs     #-- directory for certificates
DIR_NCRT=$DIR_BASE/certs.backup #-- backup directory for certificates
DIR_LOG=$DIR_BASE/log       #-- directory for logs
DIR_CRL=$DIR_BASE/crl       #-- directory for Certificate Revocation List (CRL)
DIR_LIB=$DIR_BASE/lib       #-- directory with important files like DB
DIR_ETC=$DIR_BASE/etc       #-- directory with configuration files
DIR_TMP=$DIR_BASE/tmp       #-- directory for dynamic configuration files

#-- Typical Server/Client params
SUBJ_PREFIX="" #-- prefix for all subjects i.e. /C=US/ST=CA/L=Fremont/O=Example
KSIZE=2048                  #-- size of the key
KDAYS=730                   #-- certificate validity in days

CA_CHAIN=$DIR_CRT/ca-chain.pem #-- CA+SA certificates
FCONF=$DIR_ETC/minipki.cnf  #-- Configuration file

FRND=$DIR_KEY/rnd           #-- Random file
CRL=$DIR_CRL/minipki.crl    #-- Certificate Revocation List (CRL)


#-- Signing Authority (SA) params
SA_KEY=$DIR_KEY/sa.key      #-- Signing Authority private key
SA_CRT=$DIR_CRT/sa.crt      #-- Signing Authority public certificate
SA_CSR=$DIR_CSR/sa.csr      #-- Signing Authority certificate signing request
SA_SIZE=4096                #-- size of the Signing Authority key
SA_DAYS=3650                #-- Signing Authority certificate validity in days.
SA_SUBJ="$SUBJ_PREFIX/CN=sa"        #-- default subject line for Signing Authority
FTST=$DIR_KEY/do-not-delete.txt      #-- a special file to verify permission

#-- Certificate Authority (CA) params
CA_KEY=$DIR_KEY/ca.key      #-- root CA private key
CA_CRT=$DIR_CRT/ca.crt      #-- root CA public certificate
CA_SIZE=4096                #-- size of the root CA key
CA_DAYS=7300                #-- CA certificate validity in days. Max value is 13210
CA_SUBJ="$SUBJ_PREFIX/CN=ca"    #-- default subject line for Certificate Authority
