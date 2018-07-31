#!/bin/bash
# Modified: Benjamin Smee
# Date: Fri Sep 10 11:35:41 BST 2004

# This is the email address reports get mailed to
MAILTO=root@localhost

# Set this to suppress mailings when there's nothing to report
QUIETREPORTS=1

# This parameter defines which aide command to run from the cron script.
# Sensible values are "update" and "check".
# Default is "check", ensuring backwards compatibility.
# Since "update" does not take any longer, it is recommended to use "update",
# so that a new database is created every day. The new database needs to be
# manually copied over the current one, though.
COMMAND=update

# This parameter defines how many lines to return per e-mail. Output longer
# than this value will be truncated in the e-mail sent out.
LINES=1000

PATH="/bin:/usr/bin:/sbin:/usr/sbin"
LOGDIR="/var/log/aide"
LOGFILE="aide.log"
CONFFILE="/etc/aide/aide.conf"
ERRORLOG="aide_error.log"
ERRORTMP=`mktemp /tmp/$ERRORLOG.XXXXXXXXX`
DATESUFFIX=$(date '+%FT%T')

[ -f /usr/bin/aide -o -f /usr/sbin/aide ] || exit 0

DBFILE=`grep "^database=file:" $CONFFILE | head -n 1 | cut -d':' -f 2`
NEWDBFILE=`grep "^database_out=file:" $CONFFILE | head -n 1 | cut -d':' -f 2`
DATABASE="${DBFILE}"
NEWDATABASE="${NEWDBFILE}"
DATE=`date +"at %F %R"`
FQDN=`hostname -f 2> /dev/null`
if [ $? -ne 0 ]; then
    FQDN=$HOSTNAME
fi

# default values

DATABASE="${DATABASE:-/var/lib/aide/aide.db.gz}"

AIDEARGS="-V4 --config=$CONFFILE"
if [ ! -f $DATABASE ]; then
    (
        echo "Fatal error: The AIDE database does not exist!"
    ) | /usr/bin/mail -s "Daily AIDE report for $FQDN" $MAILTO
    exit 0
fi

aide $AIDEARGS --$COMMAND >"$LOGDIR/$LOGFILE" 2>"$ERRORTMP"
RETVAL=$?

if [ "${COMMAND}" == "update" ]; then
    cp -p ${NEWDATABASE} ${DATABASE/.gz/.$DATESUFFIX.gz}
    cp -p ${NEWDATABASE} ${DATABASE}
fi

if [ -n "$QUIETREPORTS" ] && [ $QUIETREPORTS -a \! -s $LOGDIR/$LOGFILE -a \! -s $ERRORTMP ]; then
    # Bail now because there was no output and QUIETREPORTS is set
    exit 0
fi

(
    cat << EOF;
This is an automated report generated by the Advanced Intrusion Detection
Environment on $FQDN ${DATE}.
EOF
    cp ${ERRORTMP} ${LOGDIR}/${ERRORLOG}
    rm -f "$ERRORTMP"

    if [ -s "$LOGDIR/$ERRORLOG" ]; then
        errorlines=`wc -l "$LOGDIR/$ERRORLOG" | awk '{ print $1 }'`
        echo "Errors encountered by AIDE: $errorlines"
        echo "AIDE error log location: ${LOGDIR}/${ERRORLOG}"
    fi
    echo "AIDE exit value: ${RETVAL}"

    echo ""

    if [ -s "$LOGDIR/$LOGFILE" ]; then
        loglines=`wc -l "$LOGDIR/$LOGFILE" | awk '{ print $1 }'`
        if [ ${loglines:=0} -gt $LINES ]; then
            cat << EOF;

****************************************************************************
*   aide has returned long output which has been truncated in this mail    *
****************************************************************************

EOF
            echo "Output is $loglines lines, truncated to $LINES."
            head -$LINES "$LOGDIR/$LOGFILE"
            echo "The full output can be found in $LOGDIR/$LOGFILE."
        else
            cat "$LOGDIR/$LOGFILE"
        fi
    else
        echo "AIDE detected no changes."
    fi

) | /usr/bin/mail -s "Daily AIDE report for $FQDN" $MAILTO