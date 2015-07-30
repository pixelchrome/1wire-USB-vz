#!/bin/bash

############## Settings #################
PROG_PATH="/home/pi/1wire"	# Directory of 1wire-USB
DATA_PATH="/tmp" #
#UUID_S0_1=aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee

#UUID_S0_1 Power Meter Photovoltaik -> Gain
UUID_S0_1=750602c0-2c59-11e5-8441-3d75560f9f85

#UUID_S0_2 Power Meter House -> Consumption
UUID_S0_2=8a2fc2f0-2c52-11e5-8451-27b03dfe6eb8

#UUID_SUM Consumption (Consumption + Photovoltaik)
UUID_SUM=83d96f20-2c59-11e5-b0bd-b1217f8f51d7

LIMIT_PV=25 #Limiting PV at 1500W, be aware, this is for 1-Minute CRON Interval!!! -> showing previous value
LIMIT_HOUSE=1000  #Limiting House PM at 60kW, be aware, this is for 1-Minute CRON Interval!!!-> showing previous value
############# Settings End #############

if [[ ! -f /tmp/L1v.txt ]]; then
  echo `date` "L1v.txt doesnt exist" >> /tmp/debug.log
  exit 0
fi

if [[ ! -f /tmp/L2v.txt ]]; then
  echo `date` "L2v.txt doesnt exist" >> /tmp/debug.log
  exit 0
fi

if [[ ! -f /tmp/L1v.txt.old ]]; then
  echo `date` "L1v.txt.old doesnt exist" >> /tmp/debug.log
  cp /tmp/L1v.txt /tmp/L1v.txt.old
fi

if [[ ! -f /tmp/L2v.txt.old ]]; then
  echo `date` "L2v.txt.old doesnt exist" >> /tmp/debug.log
  cp /tmp/L2v.txt /tmp/L2v.txt.old
fi

############## Photovoltaik #################
PM_PV_NOW=`cat /tmp/L1v.txt`
PM_PV_PREV=`cat /tmp/L1v.txt.old`

PM_PV_GAIN=$((PM_PV_NOW - PM_PV_PREV))

if [[ $PM_PV_GAIN -gt $LIMIT_PV ]]; then
  echo `date` "##### PV OVER LIMIT! #####" $PM_PV_GAIN >> /tmp/limit.log
  PM_PV_GAIN=`cat /tmp/PM_PV.txt`
  echo `date` "##### PV OVER LIMIT! ##### CORRECTED TO" $PM_PV_GAIN >> /tmp/limit.log
else
  if [[ $PM_PV_GAIN -lt 0 ]]; then
    echo `date` "##### PV LESS THAN 0! #####" $PM_PV_GAIN >> /tmp/limit.log
    PM_PV_GAIN=`cat /tmp/PM_PV.txt`
    echo `date` "##### PV LESS THAN 0! ##### CORRECTED TO" $PM_PV_GAIN >> /tmp/limit.log
  else
    echo $PM_PV_GAIN > /tmp/PM_PV.txt
    echo `date` "- PV OK -" $PM_PV_GAIN >> /tmp/limit.log
  fi
fi

PM_PV_NEG_GAIN=$((- PM_PV_GAIN)) # To show Power from PV as 'minus' value on Y-Axis

############## Power Consumption House #################
PM_HOUSE_NOW=`cat /tmp/L2v.txt`
PM_HOUSE_PREV=`cat /tmp/L2v.txt.old`

PM_HOUSE_CON=$((PM_HOUSE_NOW - PM_HOUSE_PREV))

if [[ $PM_HOUSE_CON -gt $LIMIT_HOUSE ]]; then
  echo `date` "##### HOUSE OVER LIMIT! #####" $PM_HOUSE_CON >> /tmp/limit.log
  PM_HOUSE_CON=`cat /tmp/PM_HOUSE.txt`
  echo `date` "##### HOUSE OVER LIMIT! ##### CORRECTED TO" $PM_HOUSE_CON >> /tmp/limit.log
else
  if [[ $PM_HOUSE_CON -lt 0 ]]; then
    echo `date` "##### HOUSE LESS THAN 0! #####" $PM_HOUSE_CON >> /tmp/limit.log
    PM_HOUSE_CON=`cat /tmp/PM_HOUSE.txt`
    echo `date` "##### HOUSE LESS THAN 0! ##### CORRECTED TO" $PM_HOUSE_CON >> /tmp/limit.log
  else
    echo $PM_HOUSE_CON > /tmp/PM_HOUSE.txt
    echo `date` "- HOUSE OK -" $PM_HOUSE_CON >> /tmp/limit.log
  fi
fi

############## Complete Power Consumption including PV #################
COMPLETE_CONS=$((PM_HOUSE_CON + PM_PV_GAIN))

############## Uploading Data to Volkszaehler (localhost) #################
wget -o /var/log/wget.log -O-  "http://localhost/middleware.php/data/$UUID_S0_1.json?operation=add&value=$PM_PV_NEG_GAIN&ts=`date +%s000`"
wget -o /var/log/wget.log -O-  "http://localhost/middleware.php/data/$UUID_S0_2.json?operation=add&value=$PM_HOUSE_CON&ts=`date +%s000`"
wget -o /var/log/wget.log -O-  "http://localhost/middleware.php/data/$UUID_SUM.json?operation=add&value=$COMPLETE_CONS&ts=`date +%s000`"

############## Saving Data #################
cp /tmp/L1v.txt /tmp/L1v.txt.old
cp /tmp/L2v.txt /tmp/L2v.txt.old

exit 0
