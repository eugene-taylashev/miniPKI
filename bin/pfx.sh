#!/bin/bash
#-----------------------------------------------------------------------------
# Convert PEM key+cert to PKCS12/PFX
#
#      Usage: $0 [switch] common_name_or_hostname
#          hostname/filename (i.e sa1.example.com)
#
#          optional switches:
#            -b                 copy PFX to a local directory"
#            -v  				be verbose
#            -h  				this help
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
source $DIR_BASE/etc/params.sh     #-- Use common variables


SVER="20200411_01"      #-- Script version
FLOG="$DIR_LOG/convert.log"  #-- Log file with details (append)
CNAME=""                #-- common name (CN) or hostname
IS_COPY=0					#-- flag: 1 - copy the key and the cert to ./
VERBOSE=1               #-- 1 - be verbose flag
FPFX=""					#-- result file PFX

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
    echo "Convert PEM key+certificate to PKCS12/PFX"
	echo " "
    echo "Usage: $0 [switch] common_name_or_hostname"
    echo "    where "
    echo "    hostname or common name (i.e server1, sa1.example.com)"
	echo " "
    echo "    optional switches:"
	echo "      -b              copy PFX to a local directory"
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
while getopts ":hv" opt; do
  case ${opt} in
    v ) VERBOSE=1 # be verbose flag=1
      ;;
    b ) IS_COPY=1 # copy PFX to ./
      ;;
    h ) usage
      ;;
  esac
done
shift $((OPTIND -1))

#-- create the log file or append to exisiting
echo "#=============================================================================" >>$FLOG   
dlog "[ok] - Convert PEM key+certificate to PKCS12/PFX"
dlog "[ok] - script ver $SVER on $(date)"
dlog "[ok] - common functions ver $FVER"

exit_if_not_root        #-- Check execution rights

#-- get Subject from input parameters
if [[ $# -ge 1 ]] ; then
    TMP=$1
    if [ "$TMP" = "--help" ] ; then usage ; fi
    CNAME="$TMP" #-- Common name for files
    shift
fi

#-- define key/csr file names
H_KEY=$DIR_KEY/$CNAME.key   #-- the private key
H_CRT=$DIR_CRT/$CNAME.crt  #-- the certificate
FPFX=$DIR_CRT/$CNAME.pfx	#-- result of conversion

#-- Report settings
dlog "[ok] - hostname '$CNAME'"

#-- verify that the private key exists
if [ -f $H_KEY ] ; then
    dlog "[ok] - private key $H_KEY"
else
    derr "[not ok] - ERROR: the private key $H_KEY does NOT exist"
    my_abort
fi

#-- verify that the the certificate exists
if [ -f $H_CRT ] ; then
    dlog "[ok] - the certificate $H_CRT"
else
    derr "[not ok] - ERROR: the certificate $H_CRT does NOT exist"
    my_abort
fi

dlog "[ok] - converted cert will be '$FPFX'"

#-- Convert
openssl pkcs12 -inkey $H_KEY -in $H_CRT -export -out $FPFX 2>>$FLOG
is_critical "[ok] - convert $CNAME to $FPFX" \
"[not ok] - ERROR converting $CNAME to $FPFX"

#-- verify that the certificate exists
if [ -f $FPFX ] ; then
	dlog "[ok] - the converted certificate $FPFX"

	#-- Copy the cert to the current directory
	[ $IS_COPY -gt 0 ] && cp $FPFX ./

else
	derr "[not ok] - ERROR: the certificate $FPFX does NOT exist"
fi

dlog "[ok] - done. See the log in $FLOG"
exit 0 #-- We are done
