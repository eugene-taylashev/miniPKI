#!/bin/bash
#-----------------------------------------------------------------------------
# Common functions for miniPKI
#
# Copyright (C) by Eugene Taylashev 2020 under the MIT License
#-----------------------------------------------------------------------------
FVER="20200410_02"
#=============================================================================
#
#  Function declarations
#
#=============================================================================
#-----------------------------------------------------------------------------
#  Output debugging/logging message
#------------------------------------------------------------------------------
dlog(){
  MSG="$1"
  echo "$MSG" >>$FLOG
  [ $VERBOSE -eq 1 ] && echo "$MSG"
}
# function dlog


#-----------------------------------------------------------------------------
#  Output error message
#------------------------------------------------------------------------------
derr(){
  MSG="$1"
  echo "$MSG" >>$FLOG
  echo "$MSG"
}
# function derr

#-----------------------------------------------------------------------------
# Abort script execution due to a critical error. Output log file
#-----------------------------------------------------------------------------
my_abort(){
	echo "Critical error! Aborting..."
	echo "See the log $FLOG for details"
	exit 2
}


#-----------------------------------------------------------------------------
#  Output good or bad message based on return status $?
#------------------------------------------------------------------------------
is_good(){
    STATUS=$?
    MSG_GOOD="$1"
    MSG_BAD="$2"
    
    if [ $STATUS -eq 0 ] ; then
        dlog "${MSG_GOOD}"
    else
        derr "${MSG_BAD}"
    fi
}
# function is_good


#-----------------------------------------------------------------------------
#  Output good or bad message based on return status $?
#  Abort for the error
#------------------------------------------------------------------------------
is_critical(){
    STATUS=$?
    MSG_GOOD="$1"
    MSG_BAD="$2"
    
    if [ $STATUS -eq 0 ] ; then
        dlog "${MSG_GOOD}"
    else
        derr "${MSG_BAD}"
		my_abort
    fi
}
# function is_critical


#------------------------------------------------------------------------------
# Check access rights to the private key, and exit with error if not enough
#------------------------------------------------------------------------------
exit_if_not_root(){
	if [ `whoami` = "root" ] || [ -r $FTST ] ; then
		dlog "[ok] - sufficient privileges are used to run the script"
	else
		derr "[not ok] - root privileges are required. Run with sudo..."
		my_abort
	fi
}
# function exit_if_not_root


#------------------------------------------------------------------------------
#  Get some randomness
#------------------------------------------------------------------------------
set_rand(){
	date > $FRND
}
# function set_rand

#------------------------------------------------------------------------------
#  Output certificate details
#------------------------------------------------------------------------------
out_cert(){
	CRT="$1"
	[ -f $CRT ] && openssl x509 -in $CRT -text -noout
}
# function out_cert


#------------------------------------------------------------------------------
#  Output certificate signing request details
#------------------------------------------------------------------------------
out_csr(){
	CSR="$1"
	[ -f $CSR ] && openssl req -in $CSR -text -noout
}
# function out_cert


#-----------------------------------------------------------------------------
# Check if hostname/FQDN or subject/DN has been provided as an argument
# Parse a hostname from the subject/DN or construct a subject from the hostname
# hostname -> fully qualified domain name (FQDN)
# subject -> distinguished name (DN)
#-----------------------------------------------------------------------------
parse_subject_hostname(){
	PAT1="/CN"
	PAT2="/cn"

	if [[ $SUBJ =~  $PAT1 ]] || [[ $SUBJ =~ $PAT2 ]] ; then
		#-- parse hostname
		CNAME=$(echo $SUBJ | sed 's/^.*\/cn=\([^.^/]*\).*$/\1/i')

		#-- Append Subject prefix, if defined
		if [ "$SUBJ_PREFIX" != "" ] ; then
			SUBJ="${SUBJ_PREFIX}${SUBJ}"
		fi
	else
		CNAME=$SUBJ
		SUBJ="$SUBJ_PREFIX/CN=$CNAME"
	fi
}
# function parse_subject_hostname


#-----------------------------------------------------------------------------
#  Checks if important directories and files exist
#------------------------------------------------------------------------------
check_dir_structure(){
	if ! [ -d $DIR_KEY ] ; then
		#-- create directory for private keys
		mkdir $DIR_KEY
		chmod 700 $DIR_KEY
	fi
	! [ -d $DIR_CSR ] && mkdir $DIR_CSR		#-- directory for certificate signing requests (CSR) 
	! [ -d $DIR_CRT ] && mkdir $DIR_CRT		#-- directory for certificates
	! [ -d $DIR_NCRT ] && mkdir $DIR_NCRT	#-- backup directory for certificates
	! [ -d $DIR_LOG ] && mkdir $DIR_LOG		#-- directory for logs
	! [ -d $DIR_CRL ] && mkdir $DIR_CRL		#-- directory for CRLS
	! [ -d $DIR_TMP ] && mkdir $DIR_TMP		#-- temp directory
	
	#-- create needed files
	if ! [ -f $FTST ] ; then
		echo "do not delete this file. It is used for permission checking" >$FTST
		chmod 400 $FTST
	fi
	! [ -f $DIR_LIB/index.txt ] && touch $DIR_LIB/index.txt
	! [ -f $DIR_LIB/index.txt.attr ] && echo "unique_subject = yes" >$DIR_LIB/index.txt.attr
	! [ -f $DIR_LIB/serial ] && echo "1000" >$DIR_LIB/serial
	! [ -f $DIR_LIB/crlnumber ] && echo "1000" >$DIR_LIB/crlnumber
}
# function check_dir_structure
