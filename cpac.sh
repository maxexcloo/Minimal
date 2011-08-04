#!/bin/sh
# CREDITS: Dannix @ LowEndTalk (http://v2.lowendtalk.com/users/65/dannix/)

export LANG=C LANGUAGE=C LC_ALL=C
PKGMANAGER=/usr/bin/aptitude
$PKGMANAGER -y purge "~c"
pkgsfile=lists/temp

if [ ! -f $pkgsfile ]; then
	echo "File: $pkgsfile not found. Can't proceed."
	exit 1
fi
tmpfile=/tmp/$$_installed.txt

$PKGMANAGER search '~i' -F '%p' > $tmpfile
while read pkg; do
	req=0
	pattern=${pkg}' *$'
	req=`grep -c -E "$pattern" $tmpfile`
	if [ $req -eq 0 ]; then
		$PKGMANAGER -y install $pkg
	fi
done < $pkgsfile

$PKGMANAGER -y install deborphan
sort -u $pkgsfile > $tmpfile

CONTINUE=true
while $COUNTINUE; do
	COUNT=`deborphan -a -n -p 1 -k $tmpfile -e deborphan | awk 'END {print NR}'`
	if [ $COUNT -eq 0 ]; then
		COUNTINUE=false
	fi
	for pkg in `deborphan -a -n -p 1 -k $tmpfile -e deborphan | awk '{print $2}'`; do
		$PKGMANAGER -y purge $pkg
	done
done

rm $tmpfile
$PKGMANAGER -y purge deborphan
$PKGMANAGER -y purge "~c"
