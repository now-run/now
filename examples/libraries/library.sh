#!/bin/bash

set -e

echo "library> $0 spawned" >&2
echo "library> arguments: $*" >&2

while read msg;do
    echo "library> msg: $msg" >&2

    op=$(echo $msg | jq -rc ".[0]")
    procedure=$(echo $msg | jq -rc ".[1]")
    args=$(echo $msg | jq -rc ".[2]")
    kwargs=$(echo $msg | jq -rc ".[3]")
    echo "library> op=${op} procedure=${procedure} args=${args} kwargs=${kwargs}" >&2

    if [[ $procedure == "err" ]];then
        echo "[\"error\",\"${procedure}\",[\"self inflicted error\"],{}]"
        continue
    elif [[ $procedure == "test_calls" ]];then
        call="[\"call\",\"sum\",$args,{},{}]"
        echo $call
        read response
        echo "library> response=$response" >&2

        response_op=$(echo $response | jq -rc ".[0]")
        echo "library> response.rpc.op=$response_op" >&2

        response_result=$(echo $response | jq -rc ".[2]")
        echo "library> response.result=$response_result" >&2

        # Fallthrough to respond initial call, that's still open.
        response="[\"return\",\"${procedure}\",$response_result,{}]"
        echo $response
        continue
    elif [[ $procedure == "unhandled_error" ]];then
        echo "library> unhandled_error called! exit 1" >&2
        exit 1
    fi

    response="[\"return\", \"${procedure}\", [$args], {}]"
    echo "library> response:$response" >&2
    echo $response
done
