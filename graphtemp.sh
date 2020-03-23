#!/bin/bash
HOMEDIR=/var/www/html/temps
cd $HOMEDIR
RRD="rrdtool"
DB="$HOMEDIR/temps.rrd"
SunsetHrs=$[ $2 / 3600 - 12 ]
SunsetMins=$[ ($2 - (($SunsetHrs + 12) * 3600)) / 60 ]
SunriseHrs=$[ $1 / 3600]
SunriseMins=$[ ($1 - (($SunriseHrs) * 3600)) / 60 ]
SUNS="Sunset\: $SunsetHrs\:`printf "%02d" $SunsetMins` PM   Sunrise\: $SunriseHrs\:`printf "%02d" $SunriseMins` AM"
#SUNS=$3
#echo "PR1"
#echo $SUNS
#echo "PR2"
COMMENT="Generated on `date "+%d %m %y %H\:%M %Z"`"
IMAGE="temps.png"
watermark="Ronin Technologies Inc."
width=600
height=100
IDS=( 10.C59A3B000800 22.738803000000 22.398703000000 10.791D6B000800 10.F38C3B000800 10.37D96A000800 28.81B350000000 10.B0FB3E010800 )
#0 starts from left on breadboard NEWIDS= ( 10.A4DD4B010800 10.53474C010800 10.A4DD4B010800 10.B0FB3E010800 )
periods=("Last 3 Hours" "Last 24 Hours" "Last 2 Days" "Last Week" "Last Month" "Last Year")
period_index=0
for time in 3h 24h 48h 8days 1month 1year
do
	if [ $period_index -gt 4 ] ; then
		SUNS=""
	fi
	PERIOD="${periods[$period_index]}"
	TITLE="Paul and Helen's House Temps For $PERIOD"
	2>/dev/null rrdtool graph `echo $PERIOD | tr ' ' '_'`_$IMAGE -A -s -$time -e now -a PNG \
     -t "$TITLE" \
     -v "°C" \
	 -w $width \
	 -h $height \
	 -W "$watermark" \
	 -z \
	 -Y \
     DEF:Basement=$DB:theatre:AVERAGE \
     DEF:HTPC=$DB:htpc:AVERAGE \
	 DEF:Furnace=$DB:furnace:AVERAGE \
     DEF:Nook=$DB:nook:AVERAGE \
	 DEF:Garage=$DB:garage:AVERAGE \
     DEF:Bedroom=$DB:bedroom:AVERAGE \
     DEF:Attic=$DB:attic:AVERAGE \
	 DEF:Outside=$DB:outside:AVERAGE \
	 CDEF:nightplus=LTIME,86400,%,$1,LT,INF,LTIME,86400,%,$2,GT,INF,UNKN,Basement,*,IF,IF \
	 CDEF:nightminus=LTIME,86400,%,$1,LT,NEGINF,LTIME,86400,%,$2,GT,NEGINF,UNKN,Basement,*,IF,IF \
     AREA:nightplus#CCCCCCAA \
     AREA:nightminus#CCCCCCAA \
     COMMENT:"\t\t\tnow       avg.      max.      min."\\n \
  LINE1:Basement#0000FF:"Theatre\t" \
      GPRINT:Basement:LAST:"%5.1lf °C" \
     GPRINT:Basement:AVERAGE:"%5.1lf °C" \
     GPRINT:Basement:MAX:"%5.1lf °C" \
     GPRINT:Basement:MIN:"%5.1lf °C"\\n \
     LINE1:HTPC#FF0000:"HTPC\t" \
     GPRINT:HTPC:LAST:"%5.1lf °C" \
     GPRINT:HTPC:AVERAGE:"%5.1lf °C" \
     GPRINT:HTPC:MAX:"%5.1lf °C" \
     GPRINT:HTPC:MIN:"%5.1lf °C"\\n \
     LINE1:Furnace#9900FF:"Furnace\t" \
     GPRINT:Furnace:LAST:"%5.1lf °C" \
     GPRINT:Furnace:AVERAGE:"%5.1lf °C" \
     GPRINT:Furnace:MAX:"%5.1lf °C" \
     GPRINT:Furnace:MIN:"%5.1lf °C"\\n \
     LINE1:Nook#33CCCC:"Nook\t" \
     GPRINT:Nook:LAST:"%5.1lf °C" \
     GPRINT:Nook:AVERAGE:"%5.1lf °C" \
     GPRINT:Nook:MAX:"%5.1lf °C" \
     GPRINT:Nook:MIN:"%5.1lf °C"\\n \
     LINE1:Garage#FF00FF:"Garage\t" \
     GPRINT:Garage:LAST:"%5.1lf °C" \
     GPRINT:Garage:AVERAGE:"%5.1lf °C" \
     GPRINT:Garage:MAX:"%5.1lf °C" \
     GPRINT:Garage:MIN:"%5.1lf °C"\\n \
     LINE1:Bedroom#ffff00:"Bedroom\t" \
     GPRINT:Bedroom:LAST:"%5.1lf °C" \
     GPRINT:Bedroom:AVERAGE:"%5.1lf °C" \
     GPRINT:Bedroom:MAX:"%5.1lf °C" \
     GPRINT:Bedroom:MIN:"%5.1lf °C"\\n \
     LINE1:Attic#865F00:"Attic\t" \
     GPRINT:Attic:LAST:"%5.1lf °C" \
     GPRINT:Attic:AVERAGE:"%5.1lf °C" \
     GPRINT:Attic:MAX:"%5.1lf °C" \
     GPRINT:Attic:MIN:"%5.1lf °C"\\n \
     LINE2:Outside#00FF00:"Outside\t" \
     GPRINT:Outside:LAST:"%5.1lf °C" \
     GPRINT:Outside:AVERAGE:"%5.1lf °C" \
     GPRINT:Outside:MAX:"%5.1lf °C" \
     GPRINT:Outside:MIN:"%5.1lf °C"\\n \
	HRULE:0#00FFFF:"Freezing"\\n \
     COMMENT:"$SUNS"\\n \
     COMMENT:"$COMMENT"
	 
	colors=( "0000FF" "FF0000" "9900FF" "33CCCC" "FF00FF" "FFFF00" "865F00" "00FF00" )
	i=0
	for sensor in Theatre HTPC Furnace Nook Garage Bedroom Attic Outside 
	do
		name=`echo $sensor | tr [:upper:] [:lower:]`
		2>/dev/null rrdtool graph `echo $PERIOD | tr ' ' '_'`_${name}.png -A -s -$time -e now -a PNG \
		-t "$sensor Temperature For $PERIOD" \
		-v "°C" \
		-w $width \
		-h $height \
		-W "$watermark" \
		-z \
		-Y \
		DEF:$sensor=$DB:$name:AVERAGE \
		CDEF:nightplus=LTIME,86400,%,$1,LT,INF,LTIME,86400,%,$2,GT,INF,UNKN,$sensor,*,IF,IF \
	        CDEF:nightminus=LTIME,86400,%,$1,LT,NEGINF,LTIME,86400,%,$2,GT,NEGINF,UNKN,$sensor,*,IF,IF \
		AREA:nightplus#CCCCCCAA \
		AREA:nightminus#CCCCCCAA \
		COMMENT:"\t\t\tnow       avg.      max.      min."\\n \
		LINE2:$sensor#${colors[$i]}:"$sensor\t" \
		GPRINT:$sensor:LAST:"%5.1lf °C" \
		GPRINT:$sensor:AVERAGE:"%5.1lf °C" \
		GPRINT:$sensor:MAX:"%5.1lf °C" \
		GPRINT:$sensor:MIN:"%5.1lf °C"\\n \
		HRULE:0#00FFFF:"Freezing"\\n \
		COMMENT:"$SUNS"\\n \
		COMMENT:"1-Wire Address ${IDS[$i]}"\\n \
		COMMENT:"$COMMENT"

		i=$[ $i + 1 ]
	done
		period_index=$[ $period_index + 1 ]
done
