#!/bin/bash
#-----------------------------------------------------------------------------
# Create a Signing Authority (SA) key and a certificate signed by CA
# Run this script only few times for your PKI
#
#      Usage: $0 [switch] [subject or hostname]
#
#          where optional subject in format:
#          "/C=US/ST=CA/L=Fremont/O=Example/CN=sa1.example.com"
#            default: "${SUBJ_PREFIX}${SA_SUBJ}"
#          or hostname (i.e sa1.example.com)
#
#          optional switches:
#            -c  ca_cert.crt    CA's certificate
#            -k  ca.key         CA's key
#            -r                 use RSA, by default: ECDSA with prime256v1
#            -v                 be verbose
#            -h                 this help
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
source ./etc/params.sh      #-- Use common variables

SVER="20210221_01"      #-- Script version
FLOG="$DIR_LOG/sa.log"  #-- Log file with details (append)
CNAME=""                #-- common name (CN) or hostname
SUBJ="$SA_SUBJ"         #-- Subject for the certificate
IS_RSA=0                #-- 0 - ECDSA; 1 - RSA
VERBOSE=0               #-- 1 - be verbose flag


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
    echo "Create Signing Authority (SA) key and certificate"
    echo " "
    echo "Usage: $0 [switch] [subject or hostname]"
    echo " "
    echo "    where optional subject in format:"
    echo "    \"/C=US/ST=CA/L=Fremont/O=Example/CN=sa1.example.com\""
    echo "      default: \"${SUBJ_PREFIX}${SA_SUBJ}\""
    echo "    or hostname (i.e sa1.example.com)"
    echo " "
    echo "    optional switches:"
    echo "      -c ca_cert.crt CA's certificate, by default: $CA_CRT"
    echo "      -k ca.key      CA's key, by default: $CA_KEY"
    echo "      -r             use RSA, by default: ECDSA with prime256v1"
    echo "      -v             be verbose"
    echo "      -h             this help"
    exit 0
}
# function usage


#=============================================================================
#
#  MAIN()
#
#=============================================================================

#-- Check input parameters
while getopts ":hvrk:c:" opt; do
  case ${opt} in
    k )
      CA_KEY=$OPTARG
      ;;
    c )
      CA_CRT=$OPTARG
      ;;
    : )
      echo "Invalid option: -$OPTARG requires an argument (run -h for help)" 1>&2
      ;;
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

#-- create the log file or append to exisiting
echo "#=============================================================================" >>$FLOG   
dlog "[ok] - Create Signing Authority (SA) key and certificate"
dlog "[ok] - script ver $SVER on $(date)"
dlog "[ok] - common functions ver $FVER"

exit_if_no_openssl      #-- Check if OpenSSL is installed
exit_if_not_root        #-- Check execution rights

#-- get Subject from input parameters
if [[ $# -ge 1 ]] ; then
    TMP=$1
    if [ "$TMP" = "--help" ] ; then usage ; fi
    SUBJ="$TMP" #-- Subject for the certificate
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

#-- Report settings
[ $IS_RSA -eq 1 ] && dlog "[ok] - key size $SA_SIZE bits"
dlog "[ok] - validity $SA_DAYS days"
dlog "[ok] - subject '$SUBJ'"
dlog "[ok] - hostname '$CNAME'"
if [ -f $FCONF ] ; then
    dlog "[ok] - configuration file $FCONF"
else
    derr "[not ok] - ERROR: no configuration file $FCONF"
    my_abort
fi

#-- verify that the CA's private key exists
if [ -f $CA_KEY ] ; then
    dlog "[ok] - CA private key $CA_KEY"
else
    derr "[not ok] - ERROR: CA private key $CA_KEY does NOT exist"
    echo "Specify the CA private key with -k key_file"
    my_abort
fi

#-- verify that the CA's certificate exists
if [ -f $CA_CRT ] ; then
    dlog "[ok] - CA certificate $CA_CRT"
else
    derr "[not ok] - ERROR: CA certificate $CA_CRT does NOT exist"
    echo "Specify the CA certificate with -c cert_file"
    my_abort
fi

#-- redefine key/cert file names
SA_KEY=$DIR_KEY/$CNAME.key  #-- Signing Authority private key
SA_CSR=$DIR_CSR/$CNAME.csr  #-- Signing Authority certificate signing request
SA_CRT=$DIR_CRT/$CNAME.crt  #-- Signing Authority public certificate

#-- Verify that the script is not executed by mistake. 
#   Do not overwrite exisitng SA files
if [ -f $SA_KEY ] || [ -f $SA_CRT ] ; then
  derr "ERROR: the SA key $SA_KEY or certificate $SA_CRT exist"
  derr "Run this script only once or remove $SA_KEY and $SA_CRT"
  derr " "
  usage
fi

set_rand    #-- Get some randomness

#-- Create Signing Authority's key and certificate signing request (CSR)
if [ $IS_RSA -eq 1 ] ; then
    openssl req -new -newkey rsa:$SA_SIZE -rand $FRND -keyout $SA_KEY \
    -nodes -out $SA_CSR -config $FCONF -sha256 -subj $SUBJ 2>>$FLOG
else
    openssl req -new -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
    -rand $FRND -keyout $SA_KEY -nodes -out $SA_CSR -sha256 \
    -config $FCONF -subj $SUBJ 2>>$FLOG
fi
is_critical "[ok] - Created SA key and certificate signing request as $SA_KEY; $SA_CSR" \
"[not ok] - ERROR creating SA key and certificate signing request as $SA_KEY; $SA_CSR"

#-- sign the CSR with the CA root key
openssl ca -in $SA_CSR -notext -batch -create_serial \
-config $FCONF -extensions v3_intermediate_ca \
-keyfile $CA_KEY -cert $CA_CRT \
-out $SA_CRT -days $SA_DAYS 2>>$FLOG
is_critical "[ok] - Signed the SA's signing request as $SA_CRT" \
"[not ok] - ERROR signing SA's signing request as $SA_CRT"


#-- verify that the private key exists
if [ -f $SA_KEY ] ; then
    dlog "[ok] - SA's private key $SA_KEY"

    #-- check the key with OpenSSL
    if [ $IS_RSA -eq 1 ] ; then
        openssl rsa -in $SA_KEY -check -noout 2>>$FLOG
    else
        openssl ec -in $SA_KEY -check -noout 2>>$FLOG
    fi
else
    derr "[not ok] - ERROR: SA's private key $SA_KEY does NOT exist"
fi

#-- verify that the certificate exists
if [ -f $SA_CRT ] ; then
    dlog "[ok] - SA's certificate $SA_CRT"

    #-- remove the certificate signing request
    rm -f $SA_CSR

    #-- Output the certificate info for verification
    out_cert $SA_CRT >>$FLOG
    #[ $VERBOSE -eq 1 ] && out_cert $SA_CRT
else
    derr "[not ok] - ERROR: SA's certificate $SA_CRT does NOT exist"
fi

dlog "[ok] - done. See the log in $FLOG"
exit 0 #-- We are done