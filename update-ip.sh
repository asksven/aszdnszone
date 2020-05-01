#!/bin/bash
IP_FILE="/tmp/my-ip"

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

if [ ! -f ${DIR}/setenv ]; then
    echo "Missing setenv. Aborting"
    echo "Missing setenv. Aborting" >> ${DIR}/updatelog.txt
    exit 1
 else
    set -e
    . ${DIR}/setenv
    set +e
fi 

if [[ -z $appId || -z $password ]]; then
    echo "appId or password can not be empty"
    echo "appId or password can not be empty" >> ${DIR}/updatelog.txt
    exit 1
fi

az login --service-principal -u $appId --password $password --tenant $tenant
if [ $? != 0 ]; then
  echo "an error occurred logging-in. Aborting"
  exit 1
fi  

MY_IP=$(curl -s http://whatismijnip.nl |cut -d " " -f 5)

if [ "$MY_IP" == "" ]; then
    echo "`date +%F_%R` : IP $MY_IP was empty" >> ${DIR}/updatelog.txt
    exit 1
fi	

MY_OLD_IP=$(cat $IP_FILE)

if [ "$MY_IP" != "$MY_OLD_IP" ]; then
    echo "External IP has changed. '$MY_IP' is not the same as '$MY_OLD_IP'"
    # delete the entries if there are old IPs
    if [ "$REQUESTED_NAME" != "" ]; then
      az network dns record-set a delete --name *.${REQUESTED_NAME} --resource-group $AZ_DNS_RG --zone-name $PARENT_DOMAIN --subscription $SUBSCRIPTION --yes
      az network dns record-set a delete --name ${REQUESTED_NAME} --resource-group $AZ_DNS_RG --zone-name $PARENT_DOMAIN --subscription $SUBSCRIPTION --yes
      # update the DNS zone with this IP
      az network dns record-set a add-record --ipv4-address $MY_IP --record-set-name *.${REQUESTED_NAME} --resource-group $AZ_DNS_RG --zone-name $PARENT_DOMAIN --subscription $SUBSCRIPTION
      az network dns record-set a add-record --ipv4-address $MY_IP --record-set-name ${REQUESTED_NAME} --resource-group $AZ_DNS_RG --zone-name $PARENT_DOMAIN --subscription $SUBSCRIPTION
      az network dns record-set a update --set ttl=60 --name *.${REQUESTED_NAME} --resource-group $AZ_DNS_RG --zone-name $PARENT_DOMAIN --subscription $SUBSCRIPTION
      az network dns record-set a update --set ttl=60 --name ${REQUESTED_NAME} --resource-group $AZ_DNS_RG --zone-name $PARENT_DOMAIN --subscription $SUBSCRIPTION
    else
      az network dns record-set a delete --name "*" --resource-group $AZ_DNS_RG --zone-name $PARENT_DOMAIN --subscription $SUBSCRIPTION --yes
      az network dns record-set a delete --name "@" --resource-group $AZ_DNS_RG --zone-name $PARENT_DOMAIN --subscription $SUBSCRIPTION --yes
      # update the DNS zone with this IP
      az network dns record-set a add-record --ipv4-address $MY_IP --record-set-name "*" --resource-group $AZ_DNS_RG --zone-name $PARENT_DOMAIN --subscription $SUBSCRIPTION
      az network dns record-set a add-record --ipv4-address $MY_IP --record-set-name "@" --resource-group $AZ_DNS_RG --zone-name $PARENT_DOMAIN --subscription $SUBSCRIPTION
      az network dns record-set a update --set ttl=60 --name "*" --resource-group $AZ_DNS_RG --zone-name $PARENT_DOMAIN --subscription $SUBSCRIPTION
      az network dns record-set a update --set ttl=60 --name "@" --resource-group $AZ_DNS_RG --zone-name $PARENT_DOMAIN --subscription $SUBSCRIPTION      
    fi

    echo $MY_IP > $IP_FILE
    echo "`date +%F_%R` : Updated from $MY_OLD_IP to IP $MY_IP" >> ${DIR}/updatelog.txt
else
    echo "IPs are the same: no action"
    if [ "$DEBUG" != 0 ]; then
	# more logging    
        echo "`date +%F_%R` : IPs are the same: no action" >> ${DIR}/updatelog.txt
    fi	
fi

