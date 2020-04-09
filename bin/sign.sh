#!/bin/bash
#-----------------------------------------------------------------------------
# Script creates a certificate for SERVER or CLIENT by signing a CSR with the SA's key
# Run this script as a root (sudo )
#
# Copyright (C) by Eugene Taylashev 2020 under the MIT License
#-----------------------------------------------------------------------------

#=============================================================================
#
#  Variable declarations
#
#=============================================================================
#-- get the absolute path of the base directory
DIR_BASE=$(realpath $0 | sed 's/^\(.*\)\/bin\/.*$/\1/')
source $DIR_BASE/etc/params.sh		#-- Use common variables

SVER="20200409"			#-- Updated on Apr 8, 2020 by Eugene
FLOG="$DIR_LOG/sign.log"	#-- Log file with details (overwritten)
FNAME=""				#-- file name with CSR
IS_CLIENT=0				#-- flag: 0 - server's cert, 1 - client's cert
VERBOSE=0				#-- 1 - be verbose flag


#=============================================================================
#
#  Function declarations
#
#=============================================================================
source $DIR_LIB/functions.sh		#-- Use common functions

#-----------------------------------------------------------------------------
# Show usage and exit
#-----------------------------------------------------------------------------
usage(){
	echo "Create a ceritifcate from the certificate signing request (CSR)"
	echo "Usage: $0 [switch] certificate_signing_request.csr"
	echo "    where optional switches:"
    echo "      -c  create a CLIENT certificate"
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
while getopts ":hvc" opt; do
  case ${opt} in
    c ) IS_CLIENT=1 # create a CLIENT certificate for 
      ;;
    v ) VERBOSE=1 # be verbose flag=1
      ;;
	* ) usage
	  ;;
  esac
done
shift $((OPTIND -1))

#-- create the log file or append to exisiting
echo "#=============================================================================" >>$FLOG	
dlog "Sign a CSR script ver $SVER on $(date)"

if [ $# -lt 1 ] ; then
    derr "[not ok] - no input parameter with CSR filename"
	usage
fi

exit_if_not_root  #-- Check execution rights

#-- get CSR filename from input parameters
if [[ $# -ge 1 ]] ; then
	TMP=$1
	if [ "$TMP" = "--help" ] ; then usage ; fi
	FNAME="$TMP"	#-- CSR filename
	shift
fi

if [ -f $FNAME ] ; then 
	dlog "[ok] - CSR file $FNAME"
else
	derr "[not ok] - ERROR: CSR file $FNAME does not exist"
	my_abort
fi

#-- get common name out of filename
CNAME=$(basename -- "$FNAME")
CNAME="${CNAME%.*}"	#-- remove the last extension

#-- inform the config
dlog "[ok] - common name: $CNAME"
if [ $IS_CLIENT -eq 0 ] ; then
	EXT="server_cert"
	dlog "[ok] - SERVER certificate will be created"
else
	EXT="client_cert"
	dlog "[ok] - CLIENT certificate will be created"
fi
dlog "[ok] - cert's validity $KDAYS days"
if [ -f $FCONF ] ; then
	dlog "[ok] - configuration file $FCONF"
else
	derr "[not ok] - ERROR: no configuration file $FCONF"
	my_abort
fi
dlog "[ok] - the SA's private key $SA_KEY"
dlog "[ok] - the SA's certificate $SA_CRT"

K_CRT=$DIR_CRT/$CNAME.crt  #-- the certificate

#-- sign the CSR with the SA's key 
openssl ca -in $FNAME -notext -batch -create_serial \
-config $FCONF -extensions $EXT \
-keyfile $SA_KEY -cert $SA_CRT \
-out $K_CRT -days $KDAYS 2>>$FLOG
is_critical "[ok] - Signed the CSR as $K_CRT" \
"[not ok] - ERROR signing the CSR as $K_CRT"


#-- verify that the certificate exists
if [ -f $K_CRT ] ; then
	dlog "[ok] - the certificate $K_CRT"
	#-- remove the certificate signing request
	#rm -f $FNAME
else
	derr "[not ok] - ERROR: the certificate $K_CRT does NOT exist"
fi

#-- Output the certificate info for verification
out_cert $K_CRT >>$FLOG
[ $VERBOSE -eq 1 ] && out_cert $K_CRT

#-- Copy the cert to the local directory
cp $K_CRT ./

dlog "[ok] - done. See the log in $FLOG"
exit 0 #-- We are done