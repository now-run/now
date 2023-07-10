#!/bin/bash

set -e

echo "$0 spawned" >&2

while read msg;do
    echo "lib/msg:$msg" >&2

    rpc_name=$(echo $msg | jq -r ".rpc.name")
    args=$(echo $msg | jq -r ".args")
    kwargs=$(echo $msg | jq -r ".kwargs")

    response="[$args,$kwargs]"

    echo "lib/response:$response" >&2
    echo $response
done
