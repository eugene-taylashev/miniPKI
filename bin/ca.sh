#!/bin/bash
#-----------------------------------------------------------------------------
# Create a key and the self-signed certificate for root CA 
# Run this script only once for your miniPKI
#
#  Usage: $0 [switch] [subject or hostname]
#
#  where optional subject in format:
#    "/C=US/ST=CA/L=Fremont/O=Example Inc./CN=root.example.com"
#        default: /CN=ca
#        or hostname (i.e ca.example.com)"
#
#    optional switches:
#    -v  be verbose
#    -r  use RSA, by default: ECDSA with prime256v1
#    -h  this help
#
# Copyright (C) by Eugene Taylashev 2021 under the MIT License
#-----------------------------------------------------------------------------

#=============================================================================
#
#  Variable declarations
#
#=============================================================================
#-- get the absolute path of the base directory
#DIR_BASE=$(realpath $0 | sed 's/^\(.*\)\/bin\/.*$/\1/')
#source $DIR_BASE/etc/params.sh     #-- Use common variables

#-- non absolute path
source ./etc/params.sh       #-- Use common variables

SVER="20210221_01"           #-- Script version
FLOG="$DIR_LOG/ca.log"       #-- Log file with details (overwritten)
CNAME="ca"                   #-- common name (CN) or hostname
SUBJ="$CA_SUBJ"              #-- Subject for the certificate
IS_RSA=0                     #-- 0 - ECDSA; 1 - RSA
VERBOSE=0                    #-- 1 - be verbose flag


#=============================================================================
#
#  Function declarations
#
#=============================================================================
source $DIR_LIB/functions.sh        #-- Use common functions

#-----------------------------------------------------------------------------
# Show usage and exit
#-----------------------------------------------------------------------------
usage(){
    echo "Create a root CA key and a self-signed certificate"
    echo " "
    echo "Usage: $0 [switch] [subject or hostname]"
    echo "    where optional subject in format:"
    echo "    \"/C=US/ST=CA/L=Fremont/O=Example Inc./CN=root.example.com\""
    echo "       default: \"$CA_SUBJ\""
    echo "    or hostname (i.e ca.example.com)"
    echo " "
    echo "    optional switches:"
    echo "      -r  use RSA, by default: ECDSA with prime256v1"
    echo "      -v  be verbose"
    echo "      -h  this help"
    exit 0
}
# function usage


#=============================================================================
#
#  MAIN()
#
#=============================================================================

#-- Check input parameters
while getopts ":hvr" opt; do
  case ${opt} in
    r ) IS_RSA=1  # generate RSA key + cert
      ;;
    v ) VERBOSE=1 # be verbose flag=1
      ;;
    * ) usage
      ;;
  esac
done
shift $((OPTIND -1))

check_dir_structure #-- verify that right directories are created

#-- create the log file (overwritten)
echo "#=============================================================================" >$FLOG    
dlog "[ok] - Create Certificate Authority (CA) key and certificate"
dlog "[ok] - script ver $SVER on $(date)"
dlog "[ok] - common functions ver $FVER"

exit_if_no_openssl      #-- Check if OpenSSL is installed
exit_if_not_root        #-- Check execution rights

#-- get Subject from input parameters
if [[ $# -ge 1 ]] ; then
    TMP=$1
    if [ "$TMP" = "--help" ] ; then usage ; fi
    SUBJ="$TMP" #-- Subject for the root CA
    shift
fi

#-- inform about ECDSA/RSA
if [ $IS_RSA -eq 1 ] ; then
    dlog "[ok] - use RSA for key and certificate"
else 
    dlog "[ok] - use ECDSA with prime256v1 for key and certificate"
fi

#-- normilize hostname and subject
parse_subject_hostname 

#-- redefine key/cert file names
CA_SUBJ=$SUBJ
CA_KEY=$DIR_KEY/$CNAME.key  #-- Certificate Authority private key
CA_CRT=$DIR_CRT/$CNAME.crt  #-- Certificate Authority public certificate


#-- Verify that the script is not executed by mistake. 
#   Do not overwrite exisitng root CA files
if [ -f $CA_KEY ] || [ -f $CA_CRT ] ; then
  derr "ERROR: the root CA key $CA_KEY or certificate $CA_CRT exist"
  derr "Run this script only once or remove $CA_KEY and $CA_CRT"
  derr " "
  usage
fi

#-- Report settings
[ $IS_RSA -eq 1 ] && dlog "[ok] - key size $CA_SIZE bits"
dlog "[ok] - validity $CA_DAYS days"
dlog "[ok] - subject '$CA_SUBJ'"
if [ -f $FCONF ] ; then
    dlog "[ok] - configuration file $FCONF"
else
    derr "[not ok] - ERROR: no configuration file $FCONF"
    my_abort
fi
dlog "[ok] - key will be $CA_KEY"
dlog "[ok] - certificate will be $CA_CRT"

set_rand    #-- Get some randomness

#-- Create the root CA key and self-signed the certificate
if [ $IS_RSA -eq 1 ] ; then
    openssl req -x509 -newkey rsa:$CA_SIZE -rand $FRND -keyout $CA_KEY \
    -sha256 -out $CA_CRT -nodes -days $CA_DAYS \
    -config $FCONF -extensions v3_ca \
    -subj $CA_SUBJ 2>>$FLOG
else 
    openssl req -new -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
    -rand $FRND -x509 -nodes -days $CA_DAYS -out $CA_CRT -keyout $CA_KEY \
    -config $FCONF -extensions v3_ca \
    -subj $CA_SUBJ 2>>$FLOG
fi
is_critical "[ok] - Created root CA key and certificate as $CA_KEY; $CA_CRT" \
"[not ok] - ERROR creating root CA private key and certificate as $CA_KEY; $CA_CRT"

#-- verify that the private key exists
if [ -f $CA_KEY ] ; then
    dlog "[ok] - CA private key $CA_KEY"
    #-- check the key with OpenSSL
    if [ $IS_RSA -eq 1 ] ; then
        openssl rsa -in $CA_KEY -check -noout 2>>$FLOG
    else
        openssl ec -in $CA_KEY -check -noout 2>>$FLOG
    fi
else
    derr "[not ok] - ERROR: CA private key $CA_KEY does NOT exist"
fi

#-- verify that the certificate exists
if [ -f $CA_CRT ] ; then
    dlog "[ok] - CA certificate $CA_CRT"
else
    derr "[not ok] - ERROR: CA certificate $CA_CRT does NOT exist"
fi

#-- Output the certificate info for verification
out_cert $CA_CRT >>$FLOG
#[ $VERBOSE -eq 1 ] && out_cert $CA_CRT

dlog "[ok] - done. See the log in $FLOG"
exit 0 #-- We are done
