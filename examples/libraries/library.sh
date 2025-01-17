#!/bin/bash

set -e

echo "$0 spawned" >&2
echo "  arguments: $*" >&2

while read msg;do
    echo "lib/msg:$msg" >&2

    rpc_op=$(echo $msg | jq -rc ".rpc.op")
    procedure=$(echo $msg | jq -rc ".procedure")
    args=$(echo $msg | jq -rc ".args")
    kwargs=$(echo $msg | jq -rc ".kwargs")

    if [[ $procedure == "err" ]];then
        echo '{"rpc":{"op":"error"},"message":"self_inflicted_error"}'
        continue
    elif [[ $procedure == "test_calls" ]];then
        call="{\"rpc\":{\"op\":\"call\"},\"procedure\":\"sum\",\"args\":$args,\"kwargs\":{}, \"user_data\":null}"
        echo $call
        read response
        response_op=$(echo $response | jq -r ".rpc.op")
        echo "response.rpc.op:$response_op" >&2
        response_result=$(echo $response | jq -r ".result")
        echo "response.result:$response_result" >&2
        # Fallthrough to respond initial call, that's still open.
        response="{\"rpc\":{\"op\":\"return\"},\"result\":$response_result}"
        echo $response
        continue
    elif [[ $procedure == "unhandled_error" ]];then
        echo "Unhandled error!" >&2
        exit 1
    fi

    response="{\"rpc\":{\"op\":\"return\"},\"result\":[$args,$kwargs]}"
    echo "lib/response:$response" >&2
    echo $response
done
