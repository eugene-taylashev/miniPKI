#!/bin/bash
#-----------------------------------------------------------------------------
# Script checks and reports close-to-exripe certificates in the dir ./certs
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
FLOG="$DIR_LOG/check.log"	#-- Log file with details
DAYS=60					#-- number of days to warn in advance
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
	echo "Report soon-to-expire certificates"
	echo "Usage: $0 [switch] [days_to_warn]"
	echo "    where optional switches:"
    echo "      -v  be verbose"
    echo "      -h  this help"
	echo "    subject in format:"
    echo "    \"/C=US/ST=CA/L=Fremont/O=Example/CN=www.example.com\""
	echo "    days default: $DAYS"
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
dlog "Check certificate's expiration dates script ver $SVER on $(date)"

#-- get Days from input parameters
if [[ $# -ge 1 ]] ; then
	TMP=$1
	if [ "$TMP" = "--help" ] ; then usage ; fi
	DAYS="$TMP"	#-- Subject for the certificate
	shift
fi

#-- check that days is int
if ! [ $DAYS -gt 0 ] ; then
	derr "[not ok] - days '$DAYS' need to be an integer"
	my_abort
fi

#-- inform the config
dlog "[ok] - days to warn $DAYS"
dlog "[ok] - directory to check '$DIR_CRT'"

#-- check all files in the directory
for cert in $DIR_CRT/*.crt ; do
	
    ENDDATE=$(openssl x509 -checkend $(( 86400 * DAYS )) -enddate -noout -in "$cert" )
    if [[ $? -ne 0 ]] ; then
        [ $VERBOSE -eq 0 ] && echo "SOON-TO-EXPIRE $cert: $ENDDATE"
		dlog "[not ok] - $cert: $ENDDATE"
	else 
		dlog "[ok] - $cert"
    fi
done

dlog "[ok] - done. See the log in $FLOG"
exit 0 #-- We are done