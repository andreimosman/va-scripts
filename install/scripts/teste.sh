#!/bin/sh
#cat /var/run/dmesg.boot |grep -E '([as]d|da|amrd)[0-9]+:'|sed -E 's/://g' |sed -E 's/ /|/'|sed -E 's/ /|/'|sed -E 's/( at ).*//g'|sed -E 's/[\<\>]//g'|sed -E 's/ /_/g'|grep 'MB|'|sort 

while read REPLY; do
   echo $REPLY
done
echo "FIM";







