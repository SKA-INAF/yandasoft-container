#!/bin/bash

function getBeamCentre()
{
	local footprint_file=$1
	local beam_id=$2
	echo "footprint_file=$footprint_file"
	echo "beam_id=$beam_id"

	line=`awk '$1==$beam_id' $footprint_file`
	echo $line
	ra_field=$(echo $line | sed -e 's/,/ /g' | sed -e 's/(//g' | sed -e 's/)//g'| awk '{print $4}')
	ra=$(echo "$ra_field" | awk -F':' '{printf "%sh%sm%s",$1,$2,$3}')
	dec_field=$(echo $line | sed -e 's/,/ /g' | sed -e 's/(//g' | sed -e 's/)//g'| awk '{print $5}')
  dec=$(echo "$dec_field" | awk -F':' '{printf "%s.%s.%s",$1,$2,$3}')
	dir="[$ra, $dec, J2000]"

	echo "$dir"
}
