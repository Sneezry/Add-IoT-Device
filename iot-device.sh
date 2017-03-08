#!/usr/bin/env bash

if [[ $# < 3 ]]
    then echo "./iot-device.sh <add/del> <device id> <iothub account name> <iothubowner primary key>"
    exit
fi

action=$1
device_id=$2
account=$3
key=$(echo -n $4 | base64 --decode)

urlencode() {
    old_lc_collate=$LC_COLLATE
    LC_COLLATE=C
    
    local length="${#1}"
    for (( i = 0; i < length; i++ )); do
        local c="${1:i:1}"
        case $c in
            [a-zA-Z0-9.~_-]) printf "$c" ;;
            *) printf '%%%02X' "'$c" ;;
        esac
    done
    
    LC_COLLATE=$old_lc_collate
}

base64_encode() {
    declare INPUT=${1:-$(</dev/stdin)};
    echo -n "$INPUT" | openssl enc -base64
}

hmacsha256_sign() {
    declare INPUT=${1:-$(</dev/stdin)};
    echo -n "$INPUT" | openssl dgst -binary -sha256 -hmac "${key}"
}

url="https://${account}.azure-devices.net/devices/${device_id}?api-version=2016-11-14"
timestamp=$(date +%s)
se=$(($timestamp+3600))
sig=$(echo -n "${account}.azure-devices.net&${se}" | tr '&' '\n' | hmacsha256_sign | base64_encode)
sig=$(urlencode $sig)
sas="SharedAccessSignature sr=${account}.azure-devices.net&sig=${sig}&se=${se}&skn=iothubowner"
if [[ $action == "add" ]]
    then curl -X PUT -H "Authorization: ${sas}" -H "Content-Type: application/json" -d "{\"deviceId\":\"${device_id}\"}" $url
elif [[ $action == "del" ]]
    then curl -X DELETE -H "If-Match:*" -H "Authorization:${sas}" $url
else
    echo -n "Unknown action. Only support add and del."
fi
echo ""