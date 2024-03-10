#!/bin/bash

set -e

echo "$0 spawned" >&2
echo "  arguments: $*" >&2

while read msg;do
    echo "lib/msg:$msg" >&2

    rpc_op=$(echo $msg | jq -r ".rpc.op")
    procedure=$(echo $msg | jq -r ".procedure")
    args=$(echo $msg | jq -r ".args")
    kwargs=$(echo $msg | jq -r ".kwargs")

    if [[ $procedure == "err" ]];then
        echo '{"rpc":{"op":"error"},"message":"self_inflicted_error"}'
        continue
    elif [[ $procedure == "test_calls" ]];then
        call="{\"rpc\":{\"op\":\"call\"},\"procedure\":\"sum\",\"args\":[1,2],\"kwargs\":{}, \"user_data\":null}"
        echo $call
        read response
        response_op=$(echo $response | jq -r ".rpc.op")
        echo "response.rpc.op:$response_op" >&2
        response_result=$(echo $response | jq -r ".result")
        echo "response.result:$response_result" >&2
        # Fallthrough to respond initial call, that's still open.
    fi

    response="{\"rpc\":{\"op\":\"return\"},\"result\":[$args,$kwargs]}"

    echo "lib/response:$response" >&2
    echo $response
done
