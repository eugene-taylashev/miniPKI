#!/bin/bash
#-----------------------------------------------------------------------------
# Script revokes a certificate and updates CRL
# Run this script as a root (sudo)
#
#-- ToDO: add revocation reason -crl_reason val
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
FLOG="$DIR_LOG/revoke.log"	#-- Log file with details (overwritten)
FNAME=""				#-- Certificate Filename
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
	echo "Revoke  a certificate and update the CRL"
	echo "Usage: $0 [switch] certificate_file.crt"
	echo "    where optional switches:"
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
while getopts ":hv" opt; do
  case ${opt} in
    v ) VERBOSE=1 # be verbose flag=1
      ;;
	* ) usage
	  ;;
  esac
done
shift $((OPTIND -1))


#-- create the log file
echo "#=============================================================================" >$FLOG	
dlog "Revoke a Certificate and update CRL script ver $SVER on $(date)"

if [ $# -lt 1 ] ; then
    derr "[not ok] - no input parameter with the certificate filename"
	usage
fi

#-- get Subject from input parameters
TMP=$1
if [ "$TMP" = "--help" ] ; then usage ; fi
FNAME="$TMP"	#-- Certificate Filename
shift

if ! [ -f $FNAME ] ; then
    derr "[not ok] - the certificate file $FNAME does NOT exist"
	usage
fi

exit_if_not_root  #-- Check execution rights

#-- inform the config
dlog "[ok] - certificate file $FNAME "
dlog "[ok] - certificate revocation list (CRL) $CRL "
if [ -f $FCONF ] ; then
	dlog "[ok] - configuration file $FCONF"
else
	derr "[not ok] - ERROR: no configuration file $FCONF"
	my_abort
fi

#--  revoke certificate 
openssl ca -config $FCONF -revoke $FNAME \
-keyfile $SA_KEY -cert $SA_CRT 2>>$FLOG
is_critical "[ok] - Revoked the certificate $FNAME" \
"[not ok] - ERROR revoking the certificate $FNAME"

#--  update CRL
openssl ca -config $FCONF -gencrl -out $CRL \
-keyfile $SA_KEY -cert $SA_CRT 2>>$FLOG
is_critical "[ok] - Updated CRL $CRL" \
"[not ok] - ERROR updating CRL $CRL"

#-- Output the CRL for verification
openssl crl -in $CRL -noout -text  >>$FLOG

dlog "[ok] - done. See the log in $FLOG"
exit 0 #-- We are done