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

echo "we are in $DIR"

if [ "$1" != "" ]; then
  if [ -f "$1" ]; then
    echo "Using config-file $1"
    echo "Using config-file $1" >> ${DIR}/updatelog.txt
    CONFIG_FILE=$1
  else
    echo "config-file $1 does not exist: falling back to 'setenv'"
    echo "config-file $1 does not exist: falling back to 'setenv'" >> ${DIR}/updatelog.txt
    CONFIG_FILE="setenv"
  fi
else
  CONFIG_FILE="setenv"
fi

if [ ! -f ${DIR}/${CONFIG_FILE} ]; then
    echo "Missing $CONFIG_FILE. Aborting"
    echo "Missing $CONFIG_FILE. Aborting" >> ${DIR}/updatelog.txt
    exit 1
 else
    set -e
    . ${DIR}/${CONFIG_FILE}
    set +e
fi 

if [[ -z $appId || -z $password ]]; then
    echo "appId or password can not be empty"
    echo "appId or password can not be empty" >> ${DIR}/updatelog.txt
    exit 1
fi

if [ "$IP_FILE" == "" ]; then
  IP_FILE="/tmp/my-ip"
fi

echo "Using IP_FILE=$IP_FILE"

if [ "$TESTING" == "1" ]; then
  echo "We are simulating. No changes will be made"
fi

MY_IP=$(curl -s http://whatismijnip.nl |cut -d " " -f 5)

if [ -f "$IP_FILE" ]; then
  MY_OLD_IP=$(cat $IP_FILE)
else
  MY_OLD_IP=""
fi

if [ "$MY_IP" == "" ]; then
    echo "`date +%F_%R` : IP was empty. Aborting" >> ${DIR}/updatelog.txt
    exit 1
fi

if [ "$MY_IP" != "$MY_OLD_IP" ]; then
  echo "IP has changed"	
  az login --service-principal -u $appId --password $password --tenant $tenant
  if [ $? != 0 ]; then
    echo "an error occurred logging-in. Aborting"
    exit 1
  fi

  for REQUESTED_NAME in "${REQUESTED_NAMES[@]}"
  do
    echo "Processing \"$REQUESTED_NAME\""  
    echo "External IP has changed. '$MY_IP' is not the same as '$MY_OLD_IP'"
    if [ "$REQUESTED_NAME" != "" ]; then
      echo "`date +%F_%R` : updating *.${REQUESTED_NAME} and ${REQUESTED_NAME} with new IP $MY_IP" >> ${DIR}/updatelog.txt	    
      echo "`date +%F_%R` : updating *.${REQUESTED_NAME} and ${REQUESTED_NAME} with new IP $MY_IP"
      if [ "$TESTING" != "1" ]; then
        az network dns record-set a delete --name *.${REQUESTED_NAME} --resource-group $AZ_DNS_RG --zone-name $PARENT_DOMAIN --subscription $SUBSCRIPTION --yes
        az network dns record-set a delete --name ${REQUESTED_NAME} --resource-group $AZ_DNS_RG --zone-name $PARENT_DOMAIN --subscription $SUBSCRIPTION --yes
        # update the DNS zone with this IP
        az network dns record-set a add-record --ipv4-address $MY_IP --record-set-name *.${REQUESTED_NAME} --resource-group $AZ_DNS_RG --zone-name $PARENT_DOMAIN --subscription $SUBSCRIPTION
        az network dns record-set a add-record --ipv4-address $MY_IP --record-set-name ${REQUESTED_NAME} --resource-group $AZ_DNS_RG --zone-name $PARENT_DOMAIN --subscription $SUBSCRIPTION
        az network dns record-set a update --set ttl=60 --name *.${REQUESTED_NAME} --resource-group $AZ_DNS_RG --zone-name $PARENT_DOMAIN --subscription $SUBSCRIPTION
        az network dns record-set a update --set ttl=60 --name ${REQUESTED_NAME} --resource-group $AZ_DNS_RG --zone-name $PARENT_DOMAIN --subscription $SUBSCRIPTION
      fi	
    else
      echo "`date +%F_%R` : updating '*' and '@' with new IP $MY_IP" >> ${DIR}/updatelog.txt
      echo "`date +%F_%R` : updating '*' and '@' with new IP $MY_IP"
      if [ "$TESTING" != "1" ]; then
        az network dns record-set a delete --name "*" --resource-group $AZ_DNS_RG --zone-name $PARENT_DOMAIN --subscription $SUBSCRIPTION --yes
        az network dns record-set a delete --name "@" --resource-group $AZ_DNS_RG --zone-name $PARENT_DOMAIN --subscription $SUBSCRIPTION --yes
        # update the DNS zone with this IP
        az network dns record-set a add-record --ipv4-address $MY_IP --record-set-name "*" --resource-group $AZ_DNS_RG --zone-name $PARENT_DOMAIN --subscription $SUBSCRIPTION
        az network dns record-set a add-record --ipv4-address $MY_IP --record-set-name "@" --resource-group $AZ_DNS_RG --zone-name $PARENT_DOMAIN --subscription $SUBSCRIPTION
        az network dns record-set a update --set ttl=60 --name "*" --resource-group $AZ_DNS_RG --zone-name $PARENT_DOMAIN --subscription $SUBSCRIPTION
        az network dns record-set a update --set ttl=60 --name "@" --resource-group $AZ_DNS_RG --zone-name $PARENT_DOMAIN --subscription $SUBSCRIPTION
      fi	
    fi
    echo $MY_IP > $IP_FILE
    echo "`date +%F_%R` : Updated to IP $MY_IP" >> ${DIR}/updatelog.txt
  done  
else
    echo "IPs are the same: no action"
    if [ "$DEBUG" != 0 ]; then
	      # more logging    
        echo "`date +%F_%R` : IPs are the same: no action" >> ${DIR}/updatelog.txt
    fi
fi
