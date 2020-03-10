#!/bin/bash
#-----------------------------------------------------------------------------
# Report certificates that has expired or will expire in N (default 60) days
# 
# Updated on Mar 10, 2020 by Eugene Taylashev
#-----------------------------------------------------------------------------

#-- set some vars
CA_DIR=certs
DAYS=60

#-- get number of days to check from args
if [ "$1" != "" ] ; then
    DAYS=$1
fi

#-- check all files in the directory
for cert in $CA_DIR/* ; do

    ENDDATE=$(openssl x509 -checkend $(( 86400 * DAYS )) -enddate -noout -in "$cert" )
    if [[ $? -ne 0 ]] ; then
        echo "$cert: $ENDDATE"
    fi
done
