#!/usr/bin/env bash

if [[ $# < 3 ]]
    then echo "./add-iot-device.sh <device id> <iothub account name> <iothubowner primary key>"
    exit
fi

device_id=$1
account=$2
key=$(echo -n $3 | base64 --decode)

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
sig=${sig/!/%21}
sig=${sig/\'/%27}
sig=${sig/\(/%28}
sig=${sig/\)/%29}
sig=${sig/\*/%2a}
sas="SharedAccessSignature sr=${account}.azure-devices.net&sig=${sig}&se=${se}&skn=iothubowner"
curl -X PUT -H "Authorization: ${sas}" -H "Content-Type: application/json" -d "{\"deviceId\":\"${device_id}\"}" $url
echo ""