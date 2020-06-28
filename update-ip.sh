#!/bin/bash

## determine where we run
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
###

# Set logging either to file or to console
if [ "$TWELVE_FACTORS" != 1 ]; then
    echo "`date +%F_%R` : Output to log" >&1
    exec 1>${DIR}/updatelog.txt 2>&1
fi

echo "`date +%F_%R` : we are in $DIR"

if [ "$1" != "" ]; then
  if [ -f "$1" ]; then
    echo "`date +%F_%R` : Using config-file $1" >&1
    CONFIG_FILE=$1
  else
    echo "`date +%F_%R` : config-file $1 does not exist: falling back to 'setenv'" >&1
    CONFIG_FILE="setenv"
  fi
else
  CONFIG_FILE="setenv"
fi

# Only load config if the vars are not set already, e.g. when running in a container
if [ "$INITIALIZED" != "1" ]; then
  if [ ! -f ${DIR}/${CONFIG_FILE} ]; then
      echo "`date +%F_%R` : Missing $CONFIG_FILE. Aborting" >&2
      exit 1
  else
      echo "`date +%F_%R` : Reading config by sourcing ${DIR}/${CONFIG_FILE}" >&1
      set -e
      . ${DIR}/${CONFIG_FILE}
      set +e
  fi 
else
      echo "`date +%F_%R` : Config already set" >&1    
fi

if [[ -z $appId || -z $password ]]; then
    echo "`date +%F_%R` : appId or password can not be empty" >&2
    exit 1
fi

if [[ -z $REQUESTED_NAMES || -z $PARENT_DOMAIN ]]; then
    echo "`date +%F_%R` : REQUESTED_NAMES or PARENT_DOMAIN can not be empty" >&2
    exit 1
fi

if [ "$STATELESS" == "1"  ]; then
    echo "`date +%F_%R` : STATELESS is set to $STATELESS: using DNS to determine old IP"
else
    if [ "$IP_FILE" == "" ]; then
      IP_FILE="/tmp/my-ip"
    fi

    echo "`date +%F_%R` : Using IP_FILE=$IP_FILE" >&1
fi

if [ "$TESTING" == "1" ]; then
  echo "`date +%F_%R` : We are simulating. No changes will be made" >&1
fi

MY_IP=$(curl -s http://whatismijnip.nl |cut -d " " -f 5)
echo "`date +%F_%R` : Current IP is $MY_IP" >&1

readarray -td, NAMES <<<"$REQUESTED_NAMES,"; unset 'NAMES[-1]'

# if STATELESS we use DNS to get the current stored (old) IP
# otherwise we use the state-file
if [ "$STATELESS" == "1"  ]; then
    set -e
    MY_OLD_IP=$(dig +short ${NAMES[0]}.${PARENT_DOMAIN})
    set +e
else
    if [ -f "$IP_FILE" ]; then
      MY_OLD_IP=$(cat $IP_FILE)
    else
      MY_OLD_IP=""
    fi
fi
echo "`date +%F_%R` : Old IP for ${NAMES[0]} is $MY_OLD_IP" >&1   

if [ "$MY_IP" == "" ]; then
    echo "`date +%F_%R` : IP was empty. Aborting" >&2
    exit 1
fi

if [ "$MY_IP" != "$MY_OLD_IP" ]; then
  echo "`date +%F_%R` : IP has changed"	 >&1
  az login --service-principal -u $appId --password $password --tenant $tenant
  if [ $? != 0 ]; then
    echo "`date +%F_%R` : an error occurred logging-in. Aborting" >&2
    exit 1
  fi

  for REQUESTED_NAME in "${NAMES[@]}"
  do
    echo "`date +%F_%R` : Processing \"$REQUESTED_NAME\"" >&1
    echo "`date +%F_%R` : External IP has changed. '$MY_IP' is not the same as '$MY_OLD_IP'" >&1
    if [ "$REQUESTED_NAME" != "" ]; then
      echo "`date +%F_%R` : updating *.${REQUESTED_NAME} and ${REQUESTED_NAME} with new IP $MY_IP" >&1
      if [ "$TESTING" != "1" ]; then
        set -e
        az network dns record-set a delete --name *.${REQUESTED_NAME} --resource-group $AZ_DNS_RG --zone-name $PARENT_DOMAIN --subscription $SUBSCRIPTION --yes
        az network dns record-set a delete --name ${REQUESTED_NAME} --resource-group $AZ_DNS_RG --zone-name $PARENT_DOMAIN --subscription $SUBSCRIPTION --yes
        # update the DNS zone with this IP
        az network dns record-set a add-record --ipv4-address $MY_IP --record-set-name *.${REQUESTED_NAME} --resource-group $AZ_DNS_RG --zone-name $PARENT_DOMAIN --subscription $SUBSCRIPTION
        az network dns record-set a add-record --ipv4-address $MY_IP --record-set-name ${REQUESTED_NAME} --resource-group $AZ_DNS_RG --zone-name $PARENT_DOMAIN --subscription $SUBSCRIPTION
        az network dns record-set a update --set ttl=60 --name *.${REQUESTED_NAME} --resource-group $AZ_DNS_RG --zone-name $PARENT_DOMAIN --subscription $SUBSCRIPTION
        az network dns record-set a update --set ttl=60 --name ${REQUESTED_NAME} --resource-group $AZ_DNS_RG --zone-name $PARENT_DOMAIN --subscription $SUBSCRIPTION
        set +e
      fi	
    else
      echo "`date +%F_%R` : updating '*' and '@' with new IP $MY_IP" >&1
      if [ "$TESTING" != "1" ]; then
        set -e
        az network dns record-set a delete --name "*" --resource-group $AZ_DNS_RG --zone-name $PARENT_DOMAIN --subscription $SUBSCRIPTION --yes
        az network dns record-set a delete --name "@" --resource-group $AZ_DNS_RG --zone-name $PARENT_DOMAIN --subscription $SUBSCRIPTION --yes
        # update the DNS zone with this IP
        az network dns record-set a add-record --ipv4-address $MY_IP --record-set-name "*" --resource-group $AZ_DNS_RG --zone-name $PARENT_DOMAIN --subscription $SUBSCRIPTION
        az network dns record-set a add-record --ipv4-address $MY_IP --record-set-name "@" --resource-group $AZ_DNS_RG --zone-name $PARENT_DOMAIN --subscription $SUBSCRIPTION
        az network dns record-set a update --set ttl=60 --name "*" --resource-group $AZ_DNS_RG --zone-name $PARENT_DOMAIN --subscription $SUBSCRIPTION
        az network dns record-set a update --set ttl=60 --name "@" --resource-group $AZ_DNS_RG --zone-name $PARENT_DOMAIN --subscription $SUBSCRIPTION
        set +e
      fi	
    fi

    if [ "$STATELESS" != "1"  ]; then
        echo $MY_IP > $IP_FILE
        echo "`date +%F_%R` : Updated to IP $MY_IP" >&1
    fi    
  done  
else
    echo "`date +%F_%R` : IPs are the same: no action" >&1
fi
