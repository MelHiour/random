#!/bin/ksh

# FIRST AND SECOND OCTET IN PTP SUBNET 10.10.XX.X/31
FIRST_OCTET="10"
SECOND_OCTET="10"

# GETTING NECESSARY DATA
LOCAL_HOSTNAME=$(hostname)
LOCAL_PREFIX=$(hostname|egrep -o "[A-Z]{1,2}")
LOCAL_INDEX=$(hostname|egrep -o "[0-9]")
set -A NEIGHBORS $(lldpctl | egrep -o "(SysName.*)" | cut -d":" -f2)
set -A INTERFACES $(lldpctl | egrep -o "(Interface.*vio[0-9])" | cut -d":" -f2)

# GENERATING INTERFACE CONFIG
i=0
len=${#NEIGHBORS[@]}
while [ $i -lt $len ]; do
   # THIRD OCTET IS ALWAYS A COMBINATION OF DEVICE IDS 
   # IT WILL START WITH THE LOWEST ID
   # N1 <-> F3 = 10.10.13.XXX/31
   #                   ^^
   # S7 <-> F5 = 10.10.57.XXX/31
   #                   ^^
   # FOURTH OCTET IS O ON DEVICE WITH LOWEST DEVICE ID
   # N1 <-> F3 = 10.10.13.0/31 <-> 10.10.13.1/31
   NEIGHBOR_INDEX=$(echo ${NEIGHBORS[$i]}|egrep -o "[0-9]")
   if [[ 
     "$LOCAL_INDEX" -lt "$NEIGHBOR_INDEX" 
   ]]; then
      THIRD_OCTET=$LOCAL_INDEX$NEIGHBOR_INDEX
      FOURTH_OCTET=0
   else
      THIRD_OCTET=$NEIGHBOR_INDEX$LOCAL_INDEX
      FOURTH_OCTET=1
   fi

   # GENERATING LOCAL ADDRESS
   LOCAL_ADDRESS=$FIRST_OCTET.$SECOND_OCTET.$THIRD_OCTET.$FOURTH_OCTET

   # PUSHING CONFIG TO FILE
   cat > "/etc/hostname.${INTERFACES[$i]}" <<EOF
   inet $LOCAL_ADDRESS 255.255.255.254
EOF
   
   # RESTARTING NETWORK
   sh /etc/netstart ${INTERFACES[$i]}
   ((i++))
done
