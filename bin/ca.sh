#!/bin/bash
#-----------------------------------------------------------------------------
# Script creates a root CA key and the self-signed certificate
# Run this script only once for your miniPKI
#
#  Usage: $0 [switch] [subject]
#  where optional subject in format:
#    "/C=US/ST=CA/L=Fremont/O=Example Inc./CN=root.example.com"
#    optional switches:
#    -v  be verbose
#    -h  this help
#
# Copyright (C) by Eugene Taylashev 2020 under the MIT License
#-----------------------------------------------------------------------------

#=============================================================================
#
#  Variable declarations
#
#=============================================================================
source ./etc/params.sh		#-- Use common variables

SVER="20200409"			#-- Updated on Apr 8, 2020 by Eugene
FLOG="$DIR_LOG/ca.log"	#-- Log file with details (overwritten)
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
	echo "Create a root CA key and a self-signed certificate"
	echo "Usage: $0 [switch] [subject]"
	echo "    where optional subject in format:"
    echo "    \"/C=US/ST=CA/L=Fremont/O=Example Inc./CN=root.example.com\""
	echo "       default: \"$SUBJ_PREFIX/CN=rootCA\""
	echo "    optional switches:"
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

check_dir_structure	#-- verify that right directories are created

#-- create the log file
echo "#=============================================================================" >$FLOG	
dlog "Create root CA script ver $SVER on $(date)"

#-- Verify that the script is not executed by mistake. 
#   Do not overwrite exisitng root CA files
if [ -f $CA_KEY ] || [ -f $CA_CRT ] ; then
  derr "ERROR: the root CA key $CA_KEY or certificate $CA_CRT exist"
  derr "Run this script only once or remove $CA_KEY and $CA_CRT"
  derr " "
  usage
fi

#-- get Subject from input parameters
if [[ $# -ge 1 ]] ; then
	TMP=$1
	if [ "$TMP" = "--help" ] ; then usage ; fi
	CA_SUBJ="$TMP"	#-- Subject for the root CA
	shift
fi

exit_if_not_root 		#-- Check execution rights

#-- Append Subject prefix, if defined
# this step is debatable. Should the admin enter the right subject?
if [ "$SUBJ_PREFIX" != "" ] ; then
	CA_SUBJ="${SUBJ_PREFIX}${CA_SUBJ}"
fi

#-- inform the config
dlog "[ok] - rootCA's size $CA_SIZE bits"
dlog "[ok] - rootCA's validity $CA_DAYS days"
dlog "[ok] - rootCA's subject='$CA_SUBJ'"

set_rand	#-- Get some randomness

#-- Create the root CA key and self-signed certificate
openssl req -x509 -newkey rsa:$CA_SIZE -rand $FRND -keyout $CA_KEY \
-sha256 -out $CA_CRT -nodes -days $CA_DAYS \
-config $FCONF -extensions v3_ca \
-subj $CA_SUBJ 2>>$FLOG
is_critical "[ok] - Created root CA key and certificate as $CA_KEY; $CA_CRT" \
"[not ok] - ERROR creating root CA private key and certificate as $CA_KEY; $CA_CRT"

#-- verify that the private key exists
if [ -f $CA_KEY ] ; then
	dlog "[ok] - CA private key $CA_KEY"
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
openssl x509 -in $CA_CRT -text -noout >>$FLOG
[ $VERBOSE -eq 1 ] && openssl x509 -in $CA_CRT -text -noout

dlog "[ok] - done. See the log in $FLOG"
exit 0 #-- We are done