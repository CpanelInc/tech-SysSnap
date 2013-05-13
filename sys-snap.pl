#!/usr/bin/perl
########################################################################
# SysSnap is a very simple system monitoring script.
########################################################################
#    Copyright (C) 2012
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License along
#    with this program; if not, write to the Free Software Foundation, Inc.,
#    51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
########################################################################

###########################
# Author: Paul Trost      #
# Company: cPanel     #
# Version: 0.1        #
# 2013-05-13          #
###########################

use warnings;
use strict;
use File::Path qw(remove_tree);

##############
# Set Options
##############

# Set the time between snapshots for formating see: man sleep
my $sleep_time = 300;

# The base directory under which to build the directory where snapshots are stored.
# You *MUST* put a slash at the end.
my $root_dir = '/root';

# Sometimes you won't have mysql and/or you won't have the root password to put in a .my.cnf file
# if that's the case, set this to 0
my $mysql = 1;
# If the server has lighttpd or some other webserver, set this to 0
my $apache = 1;
# If the server has cpanel set this to 1
my $cpanel = 1;
# If you want extended data, set this to 1
my $max_data = 1;

################################################################################
#  If you don't know what your doing, don't change anything below this line
################################################################################

##########
# Set Up
##########

# Get the date, hour, and min for various tasks
chomp( my $date = `date +%Y%m%d` );
chomp( my $hour = `date +%H` );
chomp( my $min  = `date +%M` );

if ( !-d $root_dir ) {
    print "$root_dir is not a directory\n";
    die;
}

if ( !-w $root_dir ) {
   print "$root_dir is not writable\n"; 
   die;
}

if ( -d "$root_dir/system-snapshot" ) {
    system 'tar', 'czf', "${root_dir}/system-snapshot.${date}.${hour}${min}.tar.gz", "${root_dir}/system-snapshot";
    remove_tree( "$root_dir/system-snapshot" );
}

mkdir "$root_dir/system-snapshot" if !-d "$root_dir/system-snapshot";


################
# Main()
################

while (1) {

    # update time
    chomp( my $date = `date +%Y%m%d` );
    chomp( my $hour = `date +%H` );
    chomp( my $min  = `date +%M` );

    # go to the next log file
    mkdir "$root_dir/system-snapshot/$hour";
    my $current_interval = "$hour/$min";

    my $logfile = "$root_dir/system-snapshot/$current_interval.log";
    open( my $LOG, '>', $logfile ) or die "Could not open log file $logfile, $!\n";

    # ### start actually logging ### #
    
    # basic stuff
    my $load = qx(cat /proc/loadavg); # least cpu
    print $LOG "$date $hour $min --> load: $load\n";
    print $LOG qx(cat /proc/meminfo), "\n";
    print $LOG qx(vmstat 1 10), "\n";
    print $LOG qx(ps auwwxf), "\n";
    print $LOG qx(netstat -anp), "\n";

    # optional logging
    print $LOG qx(mysqladmin proc), "\n" if $mysql;

    if ($cpanel) {
        print $LOG qx(lynx --dump localhost/whm-server-status), "\n";
    }
    elsif ($apache) {
        print $LOG qx#lynx -width=1024 -dump http://localhost/server-status | egrep '(Client.+Request|GET|POST|HEAD)'#, "\n";
    }

    if ($max_data) {
        my @process_list = qx(ps aux | grep [n]obody | awk '{print \$2}');
        foreach my $process (@process_list) {
            print $LOG qx(ls -al /proc/$process | grep cwd | grep home);
        }
        print $LOG qx(lsof), "\n";
    }

    close $LOG;

    # rotate the "current" pointer
    system 'rm', '-rf', "$root_dir/system-snapshot/current";
    system 'ln', '-s', "${current_interval}.log", "$root_dir/system-snapshot/current";

    sleep($sleep_time);

}
#EOF
