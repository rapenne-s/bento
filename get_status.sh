#!/bin/sh

. ./config.sh

cd "${CHROOT_DIR}" || exit 5

PRETTY_OUT_COLUMN=$(ls -1 | awk '{ if(length($1) > max) { max = length($1) }} END { print max }')

for i in *
do
    printf "status of %${PRETTY_OUT_COLUMN}s " "${i}"
    RESULT=$(find "${i}/logs/" -type f -cnewer "${i}/last_change_date" | sort -n)

    if [ "$(echo "$RESULT" | awk 'END { print NR }')" -gt 1 ]
    then
        echo " problem, multiple logs files found 🔥🧯🧯"
    fi

    if [ -z "$RESULT" ]
    then
        echo " not up to date 🚩"
    fi

    if echo "$RESULT" | grep success >/dev/null
    then
        echo " up to date 💚"
    fi

    if echo "$RESULT" | grep failure >/dev/null
    then
        echo " failing 🔥🔥🧯"
    fi

done

