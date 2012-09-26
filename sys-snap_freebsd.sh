#!/usr/local/bin/bash
#This is a very simple system monitoring script - ONLY FOR USE ON FREEBSD!.
#v.0.1 Originally by RS-MikeK
#v.0.2 Adapted by RS-Nate 06/18/03
#v.0.3 Modified by NateC @ HG 08/28/07
#      Updates suggested by Pat P @ HG 06/13/08
#v.0.4 Updates by Mary M @ AR 08/26/08, 09/07/08
#v.0.5 Updates by Mary M @ AR 09/18/08
#      Merged in Robin Holec's 24 hour log retention 
#      Set up variable control over frequently commented or uncommented lines
#      started version numbers
#v.0.6 Modified for FreeBSD by Greg H @ CP 08/28/10
#
#####
#ToDo
#
# * replace netstat with a single tcpdump
#   and then a series of greps through it for sumaries
# * set options through command line options

#######
#GPL v2
#######

##############
# Set Options
#-------------

# Set the time between snapshots for formating see: man sleep
SLEEP_TIME="1m"

# The base directory under which to build the directory where snapshots are stored.
# You *MUST* put a slash at the end.
ROOT_DIR="~/"

# Set to 1 if you would like sections separated by labels
LABELS=1

# Sometimes you won't have mysql and/or you won't have the root password to put in a .my.cnf file
# if that's the case, set this to "" (0 evals true in bash)
#
# IF you have a non-standard install path to any of the below you may specify the path to each
# by setting the variable below, otherwise OS defaults will be used!
MYSQL=1
MYSQL_PATH=""
# If the server has lighttpd or some other webserver, set this to ""
APACHE=1
APACHE_PATH=""
# If the server has cpanel set this to 1
CPANEL=1
CPANEL_PATH=""
LYNX_PATH=""
# If you want extended data, set this to 1
MAX_DATA=1
LSOF_PATH=""

################################################################################
#  If you don't know what your doing, don't change anything below this line
################################################################################
#######################
# Variable Conventions
# --------------------
# Variables that do not change in the main loop are in all caps.
# Variables that do get updated in the main loop are in all lowercase.
# Use underscores not dashes

##########
# Set Up
# ------

# Set optional paths -- DO NOT EDIT THIS -- USE ABOVE TO EDIT PATHS!
if [ "$MYSQL_PATH" == "" ]; then
   MYSQL_PATH="/usr/local/bin/mysql"
   else
   printf "MySQL Path manually set!" >> /dev/null
   if [ ! -e "$MYSQL_PATH" ]; then
      printf "Manually set MySQL path of $MYSQL_PATH does not exist!\n"
   fi
fi
if [ "$APACHE_PATH" == "" ]; then
   APACHE_PATH="/usr/local/sbin/httpd"
   else
   printf "Apache Path manually set!" >> /dev/null
   if [ ! -e "$APACHE_PATH" ]; then
      printf "Manually set Apache path of $APACHE_PATH does not exist!\n"
   fi
fi
if [ "$CPANEL_PATH" == "" ]; then
   CPANEL_PATH="/usr/local/cpanel/cpsrvd"
   else
   printf "cPanel Path manually set!" >> /dev/null
   if [ ! -e "$CPANEL_PATH" ]; then
      printf "Manually set cPanel path of $CPANEL_PATH does not exist!\n"
   fi
fi
if [ "$LYNX_PATH" == "" ]; then
   LYNX_PATH="/usr/local/bin/lynx"
   else
   printf "lynx Path manually set!" >> /dev/null
   if [ ! -e "$LYNX_PATH" ]; then
      printf "Manually set lynx path of $LYNX_PATH does not exist!\n"
   fi
fi
if [ "$LSOF_PATH" == "" ]; then
   LSOF_PATH="/usr/local/sbin/lsof"
   else
   printf "lsof path manually set!" >> /dev/null
   if [ ! -e "$LSOF_PATH" ]; then
      printf "Manually set lsof path of $LSOF_PATH does not exist!\n"
   fi
fi


# Check to make sure enabled options have proper software installed
if [ $MYSQL == "1" ]; then
   if [ -f $MYSQL_PATH ]; then
      # MySQL is installed, do nothing
      printf "MySQL Logging ENABLED" >> /dev/null
   else
      # MySQL isn't installed?
      printf "I can't find MySQL!\n"
      printf "MySQL logging DISABLED!\n\n"
      MYSQL=0
   fi
fi

if [ $APACHE == "1" ]; then
   if [ -f $APACHE_PATH ]; then
      # Apache is installed, do nothing
      printf "Apache Logging ENABLED" >> /dev/null
   else
      printf "I can't find Apache!\n"
      printf "Apache logging DISABLED!\n\n"
      APACHE=0
   fi
fi

if [ $CPANEL == "1" ]; then
   if [ -f $CPANEL_PATH ]; then
      # cPanel is installed, do nothing
      printf "cPanel Logging ENABLED" >> /dev/null
   else
      if [ -f $LYNX_PATH ]; then
      printf "cPanel not found, but lynx is -- using alternate Apache logging method!\n"
      CPANEL=0
      else
      printf "I can't find cPanel or lynx!\n"
      printf "cPanel Apache logging DISABLED!\n\n"
      CPANEL=0
      fi
   fi
fi

if [ $MAX_DATA == "1" ]; then
   if [ -f $LSOF_PATH ]; then
      # lsof is installed, do nothing
      printf "Maximum Logging ENABLED" >> /dev/null
   else
      printf "I can't find lsof -- required for Max Logging!\n"
      printf "Max logging DISABLED!\n\n"
      MAX_DATA=0
   fi
fi

# Get the date, hour, and min for various tasks
date=`date +%m%d`
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

# make sure we can create the logs where we want them
[ ! -d ${ROOT_DIR}system-snapshot ] && mkdir ${ROOT_DIR}system-snapshot

#save and compress data from previous runs
if [ -d ${ROOT_DIR}system-snapshot ]; then
        tar -czPf ${ROOT_DIR}system-snapshot.${date}.${hour}${min}.tar.gz ${ROOT_DIR}system-snapshot
        rm -fr ${ROOT_DIR}system-snapshot/*
fi

################
# The Main Loop
# -------------
for ((;;)) ; do
        # update time
        date=`date`
        hour=`date +%H`
        min=`date +%M`

        # go to the next log file
        mkdir -p ${ROOT_DIR}system-snapshot/$hour
        current_interval=$hour/$min

        # clear the log if it already exists
        [ -e ${ROOT_DIR}system-snapshot/$current_interval.log ] && rm ${ROOT_DIR}system-snapshot/$current_interval.log


   # Gather & calculate FreeBSD memory/swap info
   bsd_memhw=`sysctl hw.physmem|cut -d : -f 2|sed 's/^[ \t]*//'`
   bsd_meminactive=`sysctl vm.stats.vm.v_inactive_count|cut -d : -f 2|sed 's/^[ \t]*//'`
   bsd_memcache=`sysctl vm.stats.vm.v_cache_count|cut -d : -f 2|sed 's/^[ \t]*//'`
   bsd_usedmem=`sysctl vm.stats.vm.v_free_count|cut -d : -f 2|sed 's/^[ \t]*//'`
   bsd_freemem=$(($bsd_memhw-$bsd_usedmem))
   bsdswap=`sysctl vm.swap_enabled|cut -d : -f 2|sed 's/^[ \t]*//'`

   if [ "$bsdswap" == "1" ]; then
      bsdswap2="Yes"
   else
      bsdswap2="No"
   fi
   
        # ### start actually logging ### #

        # basic stuff
        load=`sysctl vm.loadavg|cut -d : -f 2| sed 's/^[ \t]*//'` #least cpu
        echo "$date $hour $min --> load: $load" >> ${ROOT_DIR}system-snapshot/$current_interval.log
   if [ "$LABELS" == "1" ]; then
   printf "============ VIRTUAL MEMORY STATISTICS ============\n" >> ${ROOT_DIR}system-snapshot/$current_interval.log
   fi
        vmstat 1 10 >> ${ROOT_DIR}system-snapshot/$current_interval.log
   if [ "$LABELS" == "1" ]; then
   printf "============ SWAP INFORMATION ============\n" >> ${ROOT_DIR}system-snapshot/$current_interval.log
   fi
        printf "Swap Enabled:     $bsdswap2\n" >> ${ROOT_DIR}system-snapshot/$current_interval.log
   printf "Swap Information:\n" >> ${ROOT_DIR}system-snapshot/$current_interval.log
   swapinfo -k >> ${ROOT_DIR}system-snapshot/$current_interval.log
   if [ "$LABELS" == "1" ]; then
        printf "============ PHYSICAL MEMORY INFORMATION ============\n" >> ${ROOT_DIR}system-snapshot/$current_interval.log                
   fi              
   printf "Phys. Memory:     $bsd_memhw\n" >> ${ROOT_DIR}system-snapshot/$current_interval.log
   printf "Used Memory:      $bsd_usedmem\n" >> ${ROOT_DIR}system-snapshot/$current_interval.log
   printf "Free Memory:      $bsd_freemem\n" >> ${ROOT_DIR}system-snapshot/$current_interval.log
        printf "Inactive Memory:  $bsd_meminactive\n" >> ${ROOT_DIR}system-snapshot/$current_interval.log
   printf "Cached Memory:    $bsd_memcache\n" >> ${ROOT_DIR}system-snapshot/$current_interval.log
   if [ "$LABELS" == "1" ]; then
   printf "============ RUNNING PROCESSES SNAPSHOT ============\n" >> ${ROOT_DIR}system-snapshot/$current_interval.log
   fi
        ps auwwxf >> ${ROOT_DIR}system-snapshot/$current_interval.log
   if [ "$LABELS" == "1" ]; then
   printf "============ NETWORK INFORMATION ============\n" >> ${ROOT_DIR}system-snapshot/$current_interval.log
   fi
        netstat -an >> ${ROOT_DIR}system-snapshot/$current_interval.log #could be replaced with tcpdump and stats

        # optional logging
        if [ "$MYSQL" == "1" ]; then
                if [ "$LABELS" == "1" ]; then
                printf "============ MySQL Logging ============\n" >> ${ROOT_DIR}system-snapshot/$current_interval.log
                fi
                mysqladmin proc  >> ${ROOT_DIR}system-snapshot/$current_interval.log
        fi
        if [ "$CPANEL" == "1" ]; then
           if [ "$LABELS" == "1" ]; then
           printf "============ cPanel Status ============\n" >> ${ROOT_DIR}system-snapshot/$current_interval.log
           fi
                lynx --dump localhost/whm-server-status  >> ${ROOT_DIR}system-snapshot/$current_interval.log
   fi
        if [[ "$APACHE" == "1" && "$CPANEL" == "0" ]]; then
           if [ "$LABELS" == "1" ]; then
           printf "============ Apache Status ============\n" >> ${ROOT_DIR}system-snapshot/$current_interval.log
           fi
                lynx -width=1024 -dump http://localhost/server-status|egrep '(Client.+Request|GET|POST|HEAD)' >> ${ROOT_DIR}system-snapshot/$current_interval.log
        fi
        if [ "$MAX_DATA" == "1" ]; then
                # Who's running processes as nobody?
                if [ "$LABELS" == "1" ]; then
                printf "============ Processes Run as 'nobody' ============\n" >> ${ROOT_DIR}system-snapshot/$current_interval.log
                fi
                for i in `ps aux | grep nobody | awk '{print $2}'` ; do lsof -p $i | grep cwd | grep home; done >> ${ROOT_DIR}system-snapshot/$current_interval.log
      # A bunch of other useful info (lots of info!)
      if [ "$LABELS" == "1" ]; then
      printf "============ lsof Data ============\n" >> ${ROOT_DIR}system-snapshot/$current_interval.log
      fi
                lsof >> ${ROOT_DIR}system-snapshot/$current_interval.log 
        fi

        # rotate the "current" pointer
        rm -rf ${ROOT_DIR}system-snapshot/current
        ln -s ${ROOT_DIR}system-snapshot/$current_interval.log ${ROOT_DIR}system-snapshot/current

        sleep $SLEEP_TIME

done

#EOF
