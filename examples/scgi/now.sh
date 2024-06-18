#!/bin/bash

# This file must be a shell script because
# that's what "/docker-entrypoint.sh" expects.

cd /
while true;do
    echo "Starting Now backend..." >&2
    now scgi
    sleep 5
done &
