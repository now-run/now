#!/bin/bash

set -e

echo "library> $0 spawned" >&2
echo "library> arguments: $*" >&2

while read msg;do
    echo "library> msg: $msg" >&2

    request_id=$(echo $msg | jq -rc ".id")
    method=$(echo $msg | jq -rc ".method")
    args=$(echo $msg | jq -rc ".params")
    echo "library> method=${method} args=${args}" >&2

    if [[ $method == "err" ]];then
        echo "{\"jsonrpc\":\"2.0\",\"id\":$request_id,\"error\":\"self inflicted error\"}"
    elif [[ $method == "unhandled_error" ]];then
        echo "library> unhandled_error called! exit 1" >&2
        exit 1
    elif [[ $method == "start" ]];then
        echo "{\"jsonrpc\":\"2.0\",\"id\":$request_id,\"result\":\"started\"}"
    elif [[ $method == "ping" ]];then
        echo "{\"jsonrpc\":\"2.0\",\"id\":$request_id,\"result\":\"pong\"}"
    elif [[ $method == "sum" ]];then
        arg1=$(echo $args | jq -rc .[0])
        arg2=$(echo $args | jq -rc .[1])
        result=$(( $arg1 + $arg2 ))
        echo "{\"jsonrpc\":\"2.0\",\"id\":$request_id,\"result\":$result}"
    else
        echo "{\"jsonrpc\":\"2.0\",\"id\":$request_id,\"error\":\"method not found\"}"
    fi
done
