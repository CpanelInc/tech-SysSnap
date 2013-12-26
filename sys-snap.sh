#!/bin/bash
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

##############
# Set Options
##############

# Set the time between snapshots for formating see: man sleep
SLEEP_TIME="1m"

# The base directory under which to build the directory where snapshots are stored.
# You *MUST* put a slash at the end.
ROOT_DIR="~/"

# Sometimes you won't have mysql and/or you won't have the root password to put in a .my.cnf file
# if that's the case, set this to "" (0 evals true in bash)
MYSQL=1
# If the server has lighttpd or some other webserver, set this to ""
APACHE=1
# If the server has cpanel set this to 1
CPANEL=1
# If you want extended data, set this to 1
MAX_DATA=""

################################################################################
#  If you don't know what your doing, don't change anything below this line
################################################################################

#######################
# Variable Conventions
# --------------------
# Variables that do not change in the main loop are in all caps.
# Variables that do get updated in the main loop are in all lowercase.
# Use underscores not dashes
#######################

##########
# Set Up
##########

# Get the date, hour, and min for various tasks
date=`date +%Y%m%d`
hour=`date +%H`
min=`date +%M`

# Expand ~ characters
T1=$(echo sa\~a${HOME}a)
T2=$(echo $ROOT_DIR | sed -e $T1)
ROOT_DIR=$T2

if [ ! -d ${ROOT_DIR} ] ; then
        echo $ROOT_DIR is not a directory
        exit 1
fi

if [ ! -w ${ROOT_DIR} ] ; then
        echo $ROOT_DIR is not writable
        exit 1
fi

# if a system-snapshot directory exists, save the data and empty it.
# if it does't, create it.  
if [ -d ${ROOT_DIR}system-snapshot ]; then
        tar -czf ${ROOT_DIR}system-snapshot.${date}.${hour}${min}.tar.gz ${ROOT_DIR}system-snapshot
        rm -fr ${ROOT_DIR}system-snapshot/*
else
	mkdir ${ROOT_DIR}system-snapshot
fi

################
# Main()
################

for ((;;)) ; do
        # update time
        date=`date`
        hour=`date +%H`
        min=`date +%M`

        # go to the next log file
        mkdir -p ${ROOT_DIR}system-snapshot/$hour
        current_interval=$hour/$min

	LOG=${ROOT_DIR}system-snapshot/$current_interval.log
	
        # clear the log if it already exists
        [ -e $LOG ] && rm $LOG

        # ### start actually logging ### #

        # basic stuff
        load=`cat /proc/loadavg` #least cpu
        echo "$date $hour $min --> load: $load" >> $LOG
        cat /proc/meminfo >> $LOG
        vmstat 1 10 >> $LOG
        ps auwwxf >> $LOG
        netstat -anp >> $LOG

        # optional logging
        if [ $MYSQL ]; then
                mysqladmin proc  >> $LOG
        fi
        if [ $CPANEL ] ; then
                lynx --dump localhost/whm-server-status  >> $LOG
        else if [ $APACHE ]; then
                lynx -width=1024 -dump http://localhost/server-status|egrep '(Client.+Request|GET|POST|HEAD)' >> $LOG
             fi
        fi
        if [ $MAX_DATA ]; then
                for i in `ps aux | grep nobody | awk '{print $2}'` ; do ls -al /proc/$i | grep cwd | grep home; done >> $LOG
                lsof >> $LOG  #a lot more data, useful to track down random processes
        fi

        # rotate the "current" pointer
        rm -rf ${ROOT_DIR}system-snapshot/current
        ln -s $LOG ${ROOT_DIR}system-snapshot/current

        sleep $SLEEP_TIME

done
#EOF

