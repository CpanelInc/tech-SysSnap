#!/usr/bin/perl
##############################################################################
# SysSnap is a very simple system monitoring script.                         #
##############################################################################
#    Copyright (C) 2012                                                      #
#                                                                            #
#    This program is free software; you can redistribute it and/or modify    #
#    it under the terms of the GNU General Public License as published by    #
#    the Free Software Foundation; either version 2 of the License, or       #
#    (at your option) any later version.                                     #
#                                                                            #
#    This program is distributed in the hope that it will be useful,         #
#    but WITHOUT ANY WARRANTY; without even the implied warranty of          #
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the           #
#    GNU General Public License for more details.                            #
#                                                                            #
#    You should have received a copy of the GNU General Public License along #
#    with this program; if not, write to the Free Software Foundation, Inc., #
#    51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.             #
##############################################################################

######################
# Author: Paul Trost #
# Version: 0.3.2     #
# 2013-07-31
######################

use warnings;
use strict;
use File::Path qw(remove_tree);

###############
# Set Options #
###############

# Set the time between snapshots in seconds
my $sleep_time = 300;

# The base directory under which to build the directory where snapshots are stored.
my $root_dir = '/root';

# Sometimes you won't have mysql and/or you won't have the root password to put in a .my.cnf file
# if that's the case, set this to 0
my $mysql = 1;

# If the server has lighttpd or some other webserver, set this to 0
# cPanel is autodetected later, so this setting is not used if running cPanel.
my $apache = 1;

# If you want extended data, set this to 1
my $max_data = 0;

############################################################################
# If you don't know what your doing, don't change anything below this line #
############################################################################

##########
# Set Up #
##########

# Get the date, hour, and min for various tasks
my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime(time);
$year += 1900;    # Format year correctly
$mon++;           # Format month correctly
$mon  = 0 . $mon  if $mon < 10;
$mday = 0 . $mday if $mday < 10;
my $date = $year . $mon . $mday;

# Ensure target directory exists and is writable
if ( !-d $root_dir ) {
    die "$root_dir is not a directory\n";
}
elsif ( !-w $root_dir ) {
   die "$root_dir is not writable\n"; 
}

if ( -d "$root_dir/system-snapshot" ) {
    system 'tar', 'czf', "${root_dir}/system-snapshot.${date}.${hour}${min}.tar.gz", "${root_dir}/system-snapshot";
    remove_tree( "$root_dir/system-snapshot" );
}

if ( !-d "$root_dir/system-snapshot" ) {
    mkdir "$root_dir/system-snapshot";
}


##########
# Main() #
##########

while (1) {

    # Ensure we have a current date/time
    ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime(time);
    $year += 1900;    # Format year correctly
    $mon++;           # Format month correctly
    $mon  = 0 . $mon  if $mon < 10;
    $mday = 0 . $mday if $mday < 10;
    $date = $year . $mon . $mday;

    # go to the next log file
    mkdir "$root_dir/system-snapshot/$hour";
    my $current_interval = "$hour/$min";

    my $logfile = "$root_dir/system-snapshot/$current_interval.log";
    open( my $LOG, '>', $logfile )
        or die "Could not open log file $logfile, $!\n";

    # start actually logging #
    my $load = qx(cat /proc/loadavg);
    #print $LOG "Load Average:\n\n";  # without this line, you can get historical loads with head -n1 *
    print $LOG "$date $hour $min Load Average: $load\n";

    print $LOG "Memory Usage:\n\n";
    print $LOG qx(cat /proc/meminfo), "\n";

    print $LOG "Virtual Memory Stats:\n\n";
    print $LOG qx(vmstat 1 10), "\n";

    print $LOG "Process List:\n\n";
    print $LOG qx(ps auwwxf), "\n";

    print $LOG "Network Connections:\n\n";
    print $LOG qx(netstat -anp), "\n";

    # optional logging
    if ($mysql) {
        print $LOG "MYSQL Processes:\n\n";
        print $LOG qx(mysqladmin proc), "\n";
    }

    print $LOG "Apache Processes\n\n";
    if ( -f '/usr/local/cpanel/cpanel' ) {
        print $LOG qx(lynx --dump localhost/whm-server-status), "\n";
    }
    elsif ($apache) {
        print $LOG qx#lynx -width=1024 -dump http://localhost/server-status | egrep '(Client.+Request|GET|POST|HEAD)'#, "\n";
    }

    if ($max_data) {
        print $LOG "Process List for user Nobody:\n\n";
        my @process_list = qx(ps aux | grep [n]obody | awk '{print \$2}');
        foreach my $process (@process_list) {
            print $LOG qx(ls -al /proc/$process | grep cwd | grep home);
        }
        print $LOG "List of Open Files:\n\n";
        print $LOG qx(lsof), "\n";
    }

    close $LOG;

    # rotate the "current" pointer
    remove_tree( "$root_dir/system-snapshot/current" );
    symlink "${current_interval}.log", "$root_dir/system-snapshot/current";

    sleep($sleep_time);

}
#EOF
