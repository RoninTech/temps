#!/usr/bin/perl
use strict;
use warnings;
use DateTime;
use Data::Dumper;
use DateTime::Event::Sunrise;
use Math::Round;
use OWNet;
use RRDs;

my %sensors = (
        "10.C59A3B000800" => { name => "Basement", temp => 99 },
        "22.738803000000" => { name => "HTPC", temp => 99 },
        "22.398703000000" => { name => "Furnace", temp => 99 },
        "10.791D6B000800" => { name => "Nook", temp => 99 },
        "10.F38C3B000800" => { name => "Garage", temp => 99 },
        "10.37D96A000800" => { name => "Bedroom", temp => 99 },
        "28.81B350000000" => { name => "Attic", temp => 99 },
#        "10.B0FB3E010800" => { name => "Outside", temp => 99 }
        );

my $dir = "/var/www/html/temps";
my $file = "temps.rrd";
my $db = "$dir/$file";
my ($sunrise_secs, $sunset_secs, $SunsetHrs, $SunsetHrsInSecs, $SunsetMins, $SunriseHrs, $SunriseHrsInSecs, $SunriseMins);
my $SUNS = "";
my $width=600;
my $height=100;
my $watermark="Ronin Technologies Inc.";
my $IMAGE = "$dir/temps.png";
my $COMMENT="Generated on `date \"+%d %m %y %H\:%M %Z\"`";
my $LAT = "50.839152";
my $LON = "-114.009692";
my $RETRIES = 1;

my $failed_sensors = 0;
#
# Function to calculate the sunrise and sunset times to show on the graphs
#
sub get_sunrise_sunset()
{
    my $dt = DateTime->today(time_zone => 'America/Edmonton');
    my $sunrise_span = DateTime::Event::Sunrise ->new( longitude => $LON , latitude => $LAT, altitude => '-0.833', iteration => '1');
    my $both_times = $sunrise_span->sunrise_sunset_span($dt);
#    print "Sunrise is: " , $both_times->start->datetime, "\n";
#    print "Sunset is: " , $both_times->end->datetime, "\n";

    my $sunr = $both_times->start->datetime;
    $sunr =~ s/^.+T//;
#    print $sunr, "\n";
    my $suns = $both_times->end->datetime;
    $suns =~ s/^.+T//;
#    print $suns, "\n";
    my @sunr_bits = split(/:/, $sunr);
    my @suns_bits = split(/:/, $suns);

    $sunrise_secs = $sunr_bits[0]*3600 + $sunr_bits[1]*60 + $sunr_bits[2];
    $sunset_secs = $suns_bits[0]*3600 + $suns_bits[1]*60 + $suns_bits[2];

    $SunsetHrs = round(($sunset_secs / 3600) - 12);
    $SunsetHrsInSecs = ($SunsetHrs + 12) * 3600;
    $SunsetMins = round(($sunset_secs - $SunsetHrsInSecs) / 60);
    $SunriseHrs = round($sunrise_secs / 3600);
    $SunriseHrsInSecs = ($SunriseHrs + 12) * 3600;
    $SunriseMins = round(($sunrise_secs - $SunriseHrsInSecs) / 60);
    $SUNS = "Sunset: ${suns} PM   Sunrise: ${sunr} AM";
#    $SUNS = "Sunset\: $SunsetHrs\:$SunsetMins PM Sunrise\: $SunriseHrs\:$SunriseMins AM";
    print "$SUNS\n";
    #print "Sunrise seconds = ", $sunrise_secs, "\n";
    #print "Sunrise seconds = ", $sunset_secs, "\n";
}

sub get_temps()
{
    # Setup comms to the OWFS server
    my $owserver = OWNet->new('localhost:4304 -v -C');
    # Loop through each sensor
    my $update_string = "N";
    print "\n";
    foreach my $sensor ( keys(%sensors))
    {
        my $temp = 99;
        my $passed;
        if ( $owserver->present("/$sensor") )
        {
			#my $testtemp = `owread -s 4304 /$sensor/temperature`;
			#print "$sensor: $sensors{$sensor}{name} !$testtemp!";
            #$sensors{$sensor}{temp} = $owserver->read("/$sensor/temperature") ."\n";
            $sensors{$sensor}{temp} = `owread -s 4304 /$sensor/temperature`;
            $sensors{$sensor}{temp} =~ s/^\s+//;
            print " $sensor: $sensors{$sensor}{name} =>\t$sensors{$sensor}{temp} \n";
            $passed = 1;
        } else
        {
            print "$sensors{$sensor}{name} not responding, retrying in 2 seconds\n";
            sleep 2;
            # Retry 3 times if we can't communicate on first attempt
            for (my $i = 0; $i < $RETRIES;$i++)
            {
                $passed = 0;
                if ( $owserver->present("/$sensor") )
                {
					#my $testtemp2 = `owread -s 4304 /$sensor/temperature`;
					#print "retry$i $sensor: $sensors{$sensor}{name} $testtemp2";
                    #$sensors{$sensor}{temp} = $owserver->read("/$sensor/temperature");
					$sensors{$sensor}{temp} = `owread -s 4304 /$sensor/temperature`;
                    $sensors{$sensor}{temp} =~ s/^\s+//;
                    if ( $sensors{$sensor}{temp} ne "85" )
                    {
                        print " $sensor: $sensors{$sensor} =>\t$temp \n";
                        $passed = 1;
                        last;
                    } else
                    {
                        print " Got bogus 85 deg C, retrying in 2s\n";
                        sleep 2;
                    }
                } else
                {
                    print "$sensors{$sensor}{name} not responding, retrying in 2 seconds\n";
                    sleep 2;
                }
            }
        }
        if ( !$passed )
        {
            print "$sensor: $sensors{$sensor}{name} not responding\n";
            # Insert last valid value.
            $sensors{$sensor}{temp} = "U";
            $failed_sensors++;
        }
        # Trim any leading whitespace
        $sensors{$sensor}{temp} =~ s/^\s+//;
        $update_string .= ":$sensors{$sensor}{temp}";
    }
    
    if ( $failed_sensors == keys(%sensors) )
    {
        # All failed, try restarting owserver
        #system( "killall owserver");
        #system ( "/etc/init.d/owfser");
    }
    
    print "\n";
    #rrdtool update $DIR/temps.rrd N:${temp[0]}:${temp[1]}:${temp[2]}:${temp[3]}:${temp[4]}:${temp[5]}:${temp[6]}:${temp[7]}
    # Now we can submit the data as one set.
#    RRDs::update( "$db","N:".$sensors{"10.C59A3B000800"}{temp}.":".$sensors{"22.738803000000"}{temp}.":".$sensors{"22.398703000000"}{temp}.":".$sensors{"10.791D6B000800"}{temp}.":".$sensors{"10.F38C3B000800"}{temp}.":".$sensors{"10.37D96A000800"}{temp}.":".$sensors{"28.81B350000000"}{temp}.":".$sensors{"10.B0FB3E010800"}{temp} );
#my $err = RRDs::error;
#    print "ERROR while updating DB: $err\n" if $err;
    #print "\n$update_string\n";
}

sub graph_summary_temps()
{
    my $result_arr = ();
    my $xsize = 0;
    my $ysize = 0;
    my $time = "3h";
    my $PERIOD = "Last_3_Hours";
    print "Graphing\n";
    ($result_arr,$xsize,$ysize) = RRDs::graph( "$IMAGE", "-A", "-s", "-$time", "-e", "now", "-a", "PNG",
    "-t", "Paul and Helen's House Temps For $PERIOD",
    "-v", "°C",
    "-w", "$width",
    "-h", "$height",
    "-W", "$watermark",
    "-z", "-Y",
    "DEF:Basement=$db:theatre:AVERAGE",
    "DEF:HTPC=$db:htpc:AVERAGE",
    "DEF:Furnace=$db:furnace:AVERAGE",
    "DEF:Nook=$db:nook:AVERAGE",
    "DEF:Garage=$db:garage:AVERAGE",
    "DEF:Bedroom=$db:bedroom:AVERAGE",
    "DEF:Attic=$db:attic:AVERAGE",
    "DEF:Outside=$db:outside:AVERAGE",
    "CDEF:nightplus=LTIME,86400,%,$sunrise_secs,LT,INF,LTIME,86400,%,$sunset_secs,GT,INF,UNKN,Basement,*,IF,IF",
    "CDEF:nightminus=LTIME,86400,%,$sunrise_secs,LT,NEGINF,LTIME,86400,%,$sunset_secs,GT,NEGINF,UNKN,Basement,*,IF,IF",
    "AREA:nightplus#CCCCCCAA",
    "AREA:nightminus#CCCCCCAA",
    "COMMENT:\t\t\tnow       avg.      max.      min.\n",
    "LINE1:Basement#0000FF:Theatre\t",
    "GPRINT:Basement:LAST:%5.1lf °C",
    "GPRINT:Basement:AVERAGE:%5.1lf °C",
    "GPRINT:Basement:MAX:%5.1lf °C",
    "GPRINT:Basement:MIN:%5.1lf °C\n",
    "LINE1:HTPC#FF0000:HTPC\t",
    "GPRINT:HTPC:LAST:%5.1lf °C",
    "GPRINT:HTPC:AVERAGE:%5.1lf °C",
    "GPRINT:HTPC:MAX:%5.1lf °C",
    "GPRINT:HTPC:MIN:%5.1lf °C\n",
    "LINE1:Furnace#9900FF:Furnace\t",
    "GPRINT:Furnace:LAST:%5.1lf °C",
    "GPRINT:Furnace:AVERAGE:%5.1lf °C",
    "GPRINT:Furnace:MAX:%5.1lf °C",
    "GPRINT:Furnace:MIN:%5.1lf °C\n",
    "LINE1:Nook#33CCCC:Nook\t",
    "GPRINT:Nook:LAST:%5.1lf °C",
    "GPRINT:Nook:AVERAGE:%5.1lf °C",
    "GPRINT:Nook:MAX:%5.1lf °C",
    "GPRINT:Nook:MIN:%5.1lf °C\n",
    "LINE1:Garage#FF00FF:Garage\t",
    "GPRINT:Garage:LAST:%5.1lf °C",
    "GPRINT:Garage:AVERAGE:%5.1lf °C",
    "GPRINT:Garage:MAX:%5.1lf °C",
    "GPRINT:Garage:MIN:%5.1lf °C\n",
    "LINE1:Bedroom#ffff00:Bedroom\t",
    "GPRINT:Bedroom:LAST:%5.1lf °C",
    "GPRINT:Bedroom:AVERAGE:%5.1lf °C",
    "GPRINT:Bedroom:MAX:%5.1lf °C",
    "GPRINT:Bedroom:MIN:%5.1lf °C\n",
    "LINE1:Attic#865F00:Attic\t",
    "GPRINT:Attic:LAST:%5.1lf °C",
    "GPRINT:Attic:AVERAGE:%5.1lf °C",
    "GPRINT:Attic:MAX:%5.1lf °C",
    "GPRINT:Attic:MIN:%5.1lf °C\n",
    "LINE2:Outside#00FF00:Outside\t",
    "GPRINT:Outside:LAST:%5.1lf °C",
    "GPRINT:Outside:AVERAGE:%5.1lf °C",
    "GPRINT:Outside:MAX:%5.1lf °C",
    "GPRINT:Outside:MIN:%5.1lf °C\n",
    "HRULE:0#00FFFF:Freezing\n",
    "COMMENT:$SUNS\n",
    "COMMENT:$COMMENT");
    print "Imagesize: $xsize x $ysize\n";
    print Dumper($result_arr);
}

#
# Main processing starts here
#
get_sunrise_sunset();

get_temps();

# Escape the colons which screw up the shell script
$SUNS =~ s/:/\:/g;
#print "$SUNS\n";

# Need to migrate this function to perl as well, for now
# just exec the old graphtemp shell script.
#graph_summary_temps();
#exec("/bin/bash /var/www/html/temps/graphtemp.sh $sunrise_secs $sunset_secs");
