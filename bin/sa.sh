#!/bin/bash
#-----------------------------------------------------------------------------
# Script creates a Signing Authority (SA) key and signes the certificate 
# with rootCA's key
# Run this script only few times for your PKI
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
FLOG="$DIR_LOG/sa.log"	#-- Log file with details (overwritten)
CNAME="sa"				#-- common name (CN) or hostname
SUBJ="$SA_SUBJ"			#-- Subject for the certificate
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
	echo "Create a Signing Authority (SA) key and a certificate"
	echo "Usage: $0 [switch] [subject or hostname]"
	echo "    where optional switches:"
    echo "      -v  be verbose"
    echo "      -h  this help"
	echo "    optional subject in format:"
    echo "    \"/C=US/ST=CA/L=Fremont/O=Example/CN=sa1.example.com\""
	echo "      default: \"${SUBJ_PREFIX}${SA_SUBJ}\""
	echo "    or hostname (i.e sa1.example.com)"
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

#-- create the log file or append to exisiting
echo "#=============================================================================" >>$FLOG	
dlog "Create Signing Authority (SA) script ver $SVER on $(date)"

#-- Verify that the script is not executed by mistake. 
#   Do not overwrite exisitng SA files
if [ -f $SA_KEY ] || [ -f $SA_CRT ] ; then
  derr "ERROR: the SA key $SA_KEY or certificate $SA_CRT exist"
  derr "Run this script only once or remove $SA_KEY and $SA_CRT"
  derr " "
  usage
fi

exit_if_not_root 		#-- Check execution rights

#-- get Subject from input parameters
if [[ $# -ge 1 ]] ; then
	TMP=$1
	if [ "$TMP" = "--help" ] ; then usage ; fi
	SUBJ="$TMP"	#-- Subject for the certificate
	shift
fi

#-- normilize hostname and subject
parse_subject_hostname 


#-- inform the config
dlog "[ok] - SA's size $SA_SIZE bits"
dlog "[ok] - SA's validity $SA_DAYS days"
dlog "[ok] - SA's subject='$SUBJ'"
dlog "[ok] - SA's hostname $CNAME"
if [ -f $FCONF ] ; then
	dlog "[ok] - configuration file $FCONF"
else
	derr "[not ok] - ERROR: no configuration file $FCONF"
	my_abort
fi

#-- redefine key/cert file names
SA_KEY=$DIR_KEY/$CNAME.key	#-- Signing Authority private key
SA_CSR=$DIR_CSR/$CNAME.csr	#-- Signing Authority certificate signing request
SA_CRT=$DIR_CRT/$CNAME.crt  #-- Signing Authority public certificate

set_rand	#-- Get some randomness

#-- Create Signing Authority's key and certificate signing request (CSR)
openssl req -new -newkey rsa:$SA_SIZE -rand $FRND -keyout $SA_KEY \
-nodes -out $SA_CSR -config $FCONF -subj $SUBJ 2>>$FLOG
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
else
	derr "[not ok] - ERROR: SA's private key $SA_KEY does NOT exist"
fi

#-- verify that the certificate exists
if [ -f $SA_CRT ] ; then
	dlog "[ok] - SA's certificate $SA_CRT"
	#-- remove the certificate signing request
	#rm -f $SA_CSR
else
	derr "[not ok] - ERROR: SA's certificate $SA_CRT does NOT exist"
fi

#-- Output the certificate info for verification
out_cert $SA_CRT >>$FLOG
[ $VERBOSE -eq 1 ] && out_cert $SA_CRT

dlog "[ok] - done. See the log in $FLOG"
exit 0 #-- We are done