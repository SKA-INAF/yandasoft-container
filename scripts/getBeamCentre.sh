#!/bin/bash

NARGS="$#"
if [ "$NARGS" -lt 2 ]; then
	echo "ERROR: Missing input arguments"
	exit 1
fi

FOOTPRINT_FILE=$1
BEAM_ID=$2
echo "FOOTPRINT_FILE: $FOOTPRINT_FILE"
echo "BEAM_ID: $BEAM_ID"

line=`awk '$1=='"$BEAM_ID" $FOOTPRINT_FILE`
echo "line: $line"

ra_field=$(echo $line | sed -e 's/,/ /g' | sed -e 's/(//g' | sed -e 's/)//g'| awk '{print $4}')
ra=$(echo "$ra_field" | awk -F':' '{printf "%sh%sm%s",$1,$2,$3}')
dec_field=$(echo $line | sed -e 's/,/ /g' | sed -e 's/(//g' | sed -e 's/)//g'| awk '{print $5}')
dec=$(echo "$dec_field" | awk -F':' '{printf "%s.%s.%s",$1,$2,$3}')

DIRECTION="[$ra, $dec, J2000]"
echo "$DIRECTION"

