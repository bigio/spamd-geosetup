#!/bin/sh

# ex:ts=8 sw=4:

TMPFILE=`mktemp -t spamd.log.XXXXXXXX` || exit 1
TMPSORT=`mktemp -t spamd.log.XXXXXXXX` || exit 1

$(cat $1 | awk '{print $6 "\n";}' | sed 's/\://g;s/logfile//g' > $TMPFILE)
$(cat $TMPFILE | sort | uniq >$TMPSORT)
for IP in $(<$TMPSORT);
do
	GEOIPSTATE=$(geoiplookup $IP | awk '{print $5 " " $6 " " $7;}')
	OUTPUT="Ip: $IP, State: $GEOIPSTATE"
	echo $OUTPUT
done
rm -f $TMPFILE
rm -f $TMPSORT
