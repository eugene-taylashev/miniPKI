#!/bin/bash
#-----------------------------------------------------------------------------
# Create a private key and a certificate signed by SA
#
#   Usage: $0 [switch] subject_or_hostname"
#
#       where subject in format:"
#       \"/C=US/ST=CA/L=Fremont/O=Example/CN=www.example.com\""
#         default: \"${SUBJ_PREFIX}${SUBJ}\""
#       or hostname (i.e www)"
#
#       optional switches:"
#         -a 'subjectAltName' - i.e. 'DNS:example.com,DNS:www.example.com'"
#         -b              copy the key and the cert to a local directory"
#         -c  sa_cert.crt SA's certificate"
#         -k  sa.key      SA's key"
#         -u              create a CLIENT certificate (SERVER by default)"
#         -p              create a PEER certificate (SERVER+CLIENT)"
#         -r              use RSA, by default: ECDSA with prime256v1
#         -v              be verbose"
#         -h              this help"
#
# Copyright (C) by Eugene Taylashev 2021 under the MIT License
#-----------------------------------------------------------------------------

#=============================================================================
#
#  Variable declarations
#
#=============================================================================
#-- get the absolute path of the base directory
DIR_BASE=$(realpath $0 | sed 's/^\(.*\)\/bin\/.*$/\1/')
source $DIR_BASE/etc/params.sh      #-- Use common variables

#-- non absolute path
#source ./etc/params.sh     #-- Use common variables

SVER="20210221_01"          #-- Script version
FLOG="$DIR_LOG/cert.log"    #-- Log file with details (append)
CNAME=""                    #-- common name (CN) or hostname
SUBJ="/CN=localhost"        #-- Subject for the certificate
IS_CLIENT=0                 #-- flag: 0 - server's cert, 1 - client's cert
IS_COPY=0                   #-- flag: 1 - copy the key and the cert to ./
SAN=""                      #-- subjectAltName
IS_RSA=0                    #-- 0 - ECDSA; 1 - RSA
VERBOSE=0                   #-- 1 - be verbose flag

#-- dynamic configuration
DCONF="$DIR_TMP/cert.cnf"   #-- dynamic configuration file
CNF_PRE="$DIR_LIB/cert-pre.cnf"  #-- part 1 of dynamic config
CNF_SRV="$DIR_LIB/cert-srv.cnf"  #-- part 2 of dynamic config for server
CNF_CLN="$DIR_LIB/cert-cln.cnf"  #-- part 2 of dynamic config for client
CNF_PER="$DIR_LIB/cert-per.cnf"  #-- part 2 of dynamic config for peer


#=============================================================================
#
#  Function declarations
#
#=============================================================================
#-- need an absolute path
source $DIR_LIB/functions.sh        #-- Use common functions


#-----------------------------------------------------------------------------
# Show usage and exit
#-----------------------------------------------------------------------------
usage(){
    echo "Create a private key and a signed certificate"
    echo "Usage: $0 [switch] subject_or_hostname"
    echo " "
    echo "    where subject in format:"
    echo "    \"/C=US/ST=CA/L=Fremont/O=Example/CN=www.example.com\""
    echo "      default: \"${SUBJ_PREFIX}${SUBJ}\""
    echo "    or hostname (i.e www)"
    echo " "
    echo "    optional switches:"
    echo "      -a 'subjectAltName' - i.e. 'DNS:example.com,IP:10.0.0.100'"
    echo "      -b              copy the key and the cert to a local directory"
    echo "      -c  sa_cert.crt SA's certificate, by default: $SA_CRT"
    echo "      -k  sa.key      SA's key, by default: $SA_KEY"
    echo "      -u              create a CLIENT certificate (SERVER by default)"
	echo "      -p              create a PEER certificate (SERVER+CLIENT)"
    echo "      -r              use RSA, by default: ECDSA with prime256v1"
    echo "      -v              be verbose"
    echo "      -h              this help"
    exit 0
}
# function usage


#=============================================================================
#
#  MAIN()
#
#=============================================================================

#-- Check input parameters
while getopts ":hbvuprk:c:a:" opt; do
  case ${opt} in
    k ) SA_KEY=$OPTARG  #-- re-define SA' key
      ;;
    c ) SA_CRT=$OPTARG  #-- re-define SA' certificate
      ;;
    a ) SAN=$OPTARG     #-- enter Subject Alternative Name (SAN) 
      ;;
    u ) IS_CLIENT=1     # create a CLIENT certificate
      ;;
    p ) IS_CLIENT=2     # create a PEER certificate
      ;;
    r ) IS_RSA=1        # generate RSA key + cert
      ;;
    v ) VERBOSE=1       # be verbose flag=1
      ;;
    b ) IS_COPY=1       # copy key and cert to ./
      ;;
    : )
      echo "Invalid option: -$OPTARG requires an argument (run -h for help)" 1>&2
      ;;
    * ) usage
      ;;
  esac
done
shift $((OPTIND -1))


#-- create the log file or append
echo "#=============================================================================" >>$FLOG   
MSG="[ok] - Create key and certificate "
case $IS_CLIENT in 
    1 ) MSG="$MSG for client"
      ;;
    2 ) MSG="$MSG for peer"
      ;;
    * ) MSG="$MSG for server"
      ;;
esac
dlog "$MSG"
dlog "[ok] - script ver $SVER on $(date)"
dlog "[ok] - common functions ver $FVER"

if [ $# -lt 1 ] ; then
    derr "[not ok] - no input parameter with hostname or subject"
    usage
fi

#-- get Subject from input parameters
TMP=$1
if [ "$TMP" = "--help" ] ; then usage ; fi
SUBJ="$TMP" #-- Subject for the certificate
shift

exit_if_no_openssl    #-- Check if OpenSSL is installed
exit_if_not_root      #-- Check execution rights

#-- inform about ECDSA/RSA
if [ $IS_RSA -eq 1 ] ; then
    dlog "[ok] - use RSA for key and certificate"
else 
    dlog "[ok] - use ECDSA with prime256v1 for key and certificate"
fi

#-- normilize hostname and subject
parse_subject_hostname 


#== Report the config
[ $IS_RSA -eq 1 ] && dlog "[ok] - key size $KSIZE bits"
dlog "[ok] - validity $KDAYS days"
dlog "[ok] - hostname '$CNAME'"
dlog "[ok] - subject '$SUBJ'"

#-- Is subjectAltName
if [ "$SAN" != "" ] ; then
    dlog "[ok] - subjectAltName '$SAN'"
fi
#-- verify that the SA's private key exists
if [ -f $SA_KEY ] ; then
    dlog "[ok] - SA private key $SA_KEY"
else
    derr "[not ok] - ERROR: SA private key $SA_KEY does NOT exist"
    echo "Specify the SA private key with -k key_file"
    my_abort
fi

#-- verify that the CA's certificate exists
if [ -f $SA_CRT ] ; then
    dlog "[ok] - SA certificate $SA_CRT"
else
    derr "[not ok] - ERROR: SA certificate $SA_CRT does NOT exist"
    echo "Specify the SA certificate with -c cert_file"
    my_abort
fi

#== Create dynamic config
#-- Check that all right parts exist
if ! [[ -f $CNF_PRE &&  -f $CNF_SRV  &&  -f $CNF_CLN ]] ; then 
    derr "[not ok] - configuration file $CNF_PRE, $CNF_SRV or $CNF_CLN missing"
    my_abort
fi

#-- Initial
cat >${DCONF} <<"EOT1"
[ ca ]
# `man ca`
default_ca = CA_default

#== Directory and file locations.
[ CA_default ]
EOT1
    
echo "dir = $DIR_BASE" >>$DCONF     #-- set the base directory
#-- add the main part
case $IS_CLIENT in
  2)
    #-- for peer
    dlog "[ok] - certificate for PEER"
    EXT="peer_cert"
    sed 's/x509_extensions     = v3_ca/x509_extensions     = peer_cert/' $CNF_PRE >>$DCONF
    cat $CNF_PER >>$DCONF
    ;;
  1)
    #-- for client
    dlog "[ok] - certificate for CLIENT"
    EXT="client_cert"
    sed 's/x509_extensions     = v3_ca/x509_extensions     = client_cert/' $CNF_PRE >>$DCONF
    cat $CNF_CLN >>$DCONF
    ;;
  *)
    #-- for server
    dlog "[ok] - certificate for SERVER"
    EXT="server_cert"
    sed 's/x509_extensions     = v3_ca/x509_extensions     = server_cert/' $CNF_PRE >>$DCONF
    cat $CNF_SRV >>$DCONF
    ;;
esac

#-- add SAN
if [ "$SAN" != "" ] ; then
    echo "subjectAltName=$SAN" >>$DCONF
fi

if [ -f $DCONF ] ; then
    dlog "[ok] - configuration file $DCONF"
else
    derr "[not ok] - ERROR: no configuration file $DCONF"
    my_abort
fi

#-- define key/csr file names
H_KEY=$DIR_KEY/$CNAME.key   #-- the private key
H_CSR=$DIR_CSR/$CNAME.csr   #-- the certificate signing request (CSR)
H_CRT=$DIR_CRT/$CNAME.crt  #-- the certificate

set_rand    #-- Get some randomness

#-- Create a private key and a certificate signing request (CSR)
if [ $IS_RSA -eq 1 ] ; then
	openssl req -new -newkey rsa:$KSIZE -rand $FRND -keyout $H_KEY \
	-nodes -out $H_CSR -config $DCONF -sha256 -subj $SUBJ 2>>$FLOG
else
    openssl req -new -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
    -rand $FRND -keyout $H_KEY -nodes -out $H_CSR -sha256 \
    -config $FCONF -subj $SUBJ 2>>$FLOG
fi
is_critical "[ok] - created private key $H_KEY and CSR $H_CSR" \
"[not ok] - ERROR creating private key and certificate signing request as $H_KEY; $H_CSR"


#-- verify that the private key exists
if [ -f $H_KEY ] ; then
    dlog "[ok] - private key $H_KEY"

    #-- check the key with OpenSSL
    if [ $IS_RSA -eq 1 ] ; then
        openssl rsa -in $H_KEY -check -noout 2>>$FLOG
    else
        openssl ec -in $H_KEY -check -noout 2>>$FLOG
    fi

    #-- copy the key to the current location
    [ $IS_COPY -gt 0 ] && cp $H_KEY ./
else
    derr "[not ok] - ERROR: private key $H_KEY does NOT exist"
    my_abort
fi

#-- verify that the CSR exists
if [ -f $H_CSR ] ; then
    dlog "[ok] - certificate signing request $H_CSR"

    #-- Output the CSR info for verification
    out_csr $H_CSR >>$FLOG
    #[ $VERBOSE -eq 1 ] && out_csr $H_CSR
else
    derr "[not ok] - ERROR: certificate signing request $H_CSR does NOT exist"
    my_abort
fi

#-- sign the CSR with the SA's key 
openssl ca -in $H_CSR -notext -batch -create_serial \
-keyfile $SA_KEY -cert $SA_CRT -outdir $DIR_NCRT -days $KDAYS \
-config $DCONF -out $H_CRT -extensions $EXT 1>>$FLOG 2>>$FLOG
is_critical "[ok] - signed the CSR as $H_CRT" \
"[not ok] - ERROR signing the CSR as $H_CRT"


#-- verify that the certificate exists
if [ -f $H_CRT ] ; then
    dlog "[ok] - the certificate $H_CRT"

    #-- remove the certificate signing request
    #rm -f $H_CSR

    #-- Copy the cert to the current directory
    [ $IS_COPY -gt 0 ] && cp $H_CRT ./

    #-- Output the certificate info for verification
    out_cert $H_CRT >>$FLOG
    #[ $VERBOSE -eq 1 ] && out_cert $H_CRT
else
    derr "[not ok] - ERROR: the certificate $H_CRT does NOT exist"
fi

dlog "[ok] - done. See the log in $FLOG"
exit 0 #-- We are done