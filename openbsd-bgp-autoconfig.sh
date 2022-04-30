#!/bin/ksh

# PREFIX-TO-AS MAPPING
ND=64501
N=64501
F=64500
S=64502
SD=64502

# FIRST AND SECOND OCTET IN PTP SUBNET 10.10.XX.X/31
FIRST_OCTET="10"
SECOND_OCTET="10"

# GETTING NECESSARY DATA
LOCAL_HOSTNAME=$(hostname)
LOCAL_PREFIX=$(hostname|egrep -o "[A-Z]{1,2}")
LOCAL_INDEX=$(hostname|egrep -o "[0-9]")
NEIGHBORS=$(lldpctl | egrep -o "(SysName.*)" | cut -d":" -f2)

# LOCAL AS DEPENDS ON DEVICE PREXIS
case $LOCAL_PREFIX in
   ND) AS=$ND;;
   N)  AS=$N;;
   F)  AS=$F;;
   S)  AS=$S;;
   SD) AS=$SD;;
   *)  print "Wrong name...";;
esac

# BASIC BGP CONFIG
cat > "/etc/bgpd.conf" <<EOF
# LOCAL AS
AS $AS

# ALLOWING UPDATES
allow from ebgp
allow to ebgp
allow from ibgp
allow to ibgp

# ANOUNCE IPV4 STATICS 
network inet static
EOF

# GENERATING NEIGHBOR CONFIG
for NEIGHBOR in $NEIGHBORS; do
   # THIRD OCTET IS ALWAYS A COMBINATION OF DEVICE IDS 
   # IT WILL START WITH THE LOWEST ID
   # N1 <-> F3 = 10.10.13.XXX/31
   #                   ^^
   # S7 <-> F5 = 10.10.57.XXX/31
   #                   ^^
   # FOURTH OCTET IS O ON DEVICE WITH LOWEST DEVICE ID
   # N1 <-> F3 = 10.10.13.0/31 <-> 10.10.13.1/31
   NEIGHBOR_INDEX=$(echo $NEIGHBOR|egrep -o "[0-9]")
   if [[ 
     "$LOCAL_INDEX" -lt "$NEIGHBOR_INDEX" 
   ]]; then
      THIRD_OCTET=$LOCAL_INDEX$NEIGHBOR_INDEX
      FOURTH_OCTET=1
   else
      THIRD_OCTET=$NEIGHBOR_INDEX$LOCAL_INDEX
      FOURTH_OCTET=0
   fi

   THIRD_OCTET=$(echo $THIRD_OCTET | sed 's/^0*//')

   # NEIGHBOR AS DEPENDS ON NEIGHBOR DEVICE PREFIX
   NEIGHBOR_PREFIX=$(echo $NEIGHBOR|egrep -o "[A-Z]{1,2}")
   case $NEIGHBOR_PREFIX in
   ND) REMOTE_AS=$ND;;
   N)  REMOTE_AS=$N;;
   F)  REMOTE_AS=$F;;
   S)  REMOTE_AS=$S;;
   SD) REMOTE_AS=$SD;;
   *)  print "Wrong name...";;
   esac

   # NEIGHBOR CONFIG
   cat >> "/etc/bgpd.conf" <<EOF
   neighbor $FIRST_OCTET.$SECOND_OCTET.$THIRD_OCTET.$FOURTH_OCTET {
   descr '$NEIGHBOR'
   remote-as $REMOTE_AS
   set nexthop self
   }
EOF

done

# ENABLING ROUTING
sysctl net.inet.ip.forwarding=1
echo "net.inet.ip.forwarding=1" > /etc/sysctl.conf
# ENABLING ECMP
sysctl net.inet.ip.multipath=1
echo "net.inet.ip.multipath=1" >> /etc/sysctl.conf

# ENABLING AND STARTING BGP
rcctl enable bgpd 
rcctl restart bgpd 
