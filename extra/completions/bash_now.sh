#!/bin/bash

function _now {
    COMPREPLY=($(
        COMP_WORDS=$COMP_WORDS COMP_LINE=$COMP_LINE COMP_POINT=$COMP_POINT \
            now :bash-complete
    ))
}
complete -F _now now
