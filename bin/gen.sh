#!/bin/bash
#-----------------------------------------------------------------------------
# Script creates a private key and a certificate signing request (CSR) 
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
FLOG="$DIR_LOG/gen.log"	#-- Log file with details (overwritten)
CNAME=""				#-- common name (CN) or hostname
SUBJ="/CN=localhost"	#-- Subject for the certificate
VERBOSE=0				#-- 1 - be verbose flag


#=============================================================================
#
#  Function declarations
#
#=============================================================================
#-- need an absolute path =TBDef
source $DIR_LIB/functions.sh		#-- Use common functions


#-----------------------------------------------------------------------------
# Show usage and exit
#-----------------------------------------------------------------------------
usage(){
	echo "Create a private key and a certificate signing request (CSR)"
	echo "Usage: $0 [switch] subject_or_hostname"
	echo "    where optional switches:"
    echo "      -v  be verbose"
    echo "      -h  this help"
	echo "    subject in format:"
    echo "    \"/C=US/ST=CA/L=Fremont/O=Example/CN=www.example.com\""
	echo "      default: \"${SUBJ_PREFIX}${SUBJ}\""
	echo "    or hostname (i.e www)"
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
dlog "Create Private Key and CSR script ver $SVER on $(date)"

if [ $# -lt 1 ] ; then
    derr "[not ok] - no input parameter with hostname or subject"
	usage
fi

#-- get Subject from input parameters
TMP=$1
if [ "$TMP" = "--help" ] ; then usage ; fi
SUBJ="$TMP"	#-- Subject for the certificate
shift

#-- normilize hostname and subject
parse_subject_hostname 


#-- inform the config
dlog "[ok] - hostname $CNAME"
dlog "[ok] - subject='$SUBJ'"
if [ -f $FCONF ] ; then
	dlog "[ok] - configuration file $FCONF"
else
	derr "[not ok] - ERROR: no configuration file $FCONF"
	my_abort
fi

#-- define key/csr file names
H_KEY=$CNAME.key	#-- the private key
H_CSR=$CNAME.csr	#-- the certificate signing request (CSR)
#FRND=./rnd

set_rand	#-- Get some randomness

#-- Create a private key and a certificate signing request (CSR)
openssl req -new -newkey rsa:$KSIZE -rand $FRND -keyout $H_KEY \
-nodes -out $H_CSR -config $FCONF -subj $SUBJ 2>>$FLOG
is_critical "[ok] - Created private key and certificate signing request as $H_KEY; $H_CSR" \
"[not ok] - ERROR creating private key and certificate signing request as $H_KEY; $H_CSR"


#-- verify that the private key exists
if [ -f $H_KEY ] ; then
	dlog "[ok] - private key $H_KEY"
else
	derr "[not ok] - ERROR: private key $H_KEY does NOT exist"
fi

#-- verify that the CSR exists
if [ -f $H_CSR ] ; then
	dlog "[ok] - certificate signing request $H_CSR"
	#-- copy to the miniPKI location
	cp $H_CSR $DIR_CSR
else
	derr "[not ok] - ERROR: certificate signing request $H_CSR does NOT exist"
fi

#[ -f $FRND ] && rm -f $FRND		#-- del the temp random file

#-- Output the CSR info for verification
out_csr $H_CSR >>$FLOG
[ $VERBOSE -eq 1 ] && out_csr $H_CSR

dlog "[ok] - done. See the log in $FLOG"
exit 0 #-- We are done