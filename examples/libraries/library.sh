#!/bin/bash

set -e

echo "$0 spawned" >&2

while read msg;do
    echo "lib/msg:$msg" >&2

    rpc_name=$(echo $msg | jq -r ".rpc.name")
    if [[ $rpc_name == "err" ]];then
        echo '{"rpc":{"op":"error"},"result":{"message":"Self inflicted error"}}'
        continue
    fi
    args=$(echo $msg | jq -r ".args")
    kwargs=$(echo $msg | jq -r ".kwargs")

    response="{\"rpc\":{\"op\":\"return\"},\"result\":[$args,$kwargs]}"

    echo "lib/response:$response" >&2
    echo $response
done
