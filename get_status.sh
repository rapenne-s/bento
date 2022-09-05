#!/bin/sh

. ./config.sh
. ./libs.sh

cd "${CHROOT_DIR}" || exit 5

PRETTY_OUT_COLUMN=$(ls -1 | awk '{ if(length($1) > max) { max = length($1) }} END { print max }')

for i in *
do
    printf "status of %${PRETTY_OUT_COLUMN}s " "${i}"
    RESULT=$(find "${i}/logs/" -type f -cnewer "${i}/last_change_date" | sort -n)

    # date calculation
    LASTLOG=$(find "${i}/logs/" -type f | sort -n | tail -n 1)
    LASTTIME=$(date -r "$LASTLOG" "+%s")
    LASTCONFIG=$(date -r "${i}/last_change_date" "+%s")
    ELAPSED_SINCE_UPDATE="last_update $(elapsed_time $(( $(date +%s) - $LASTTIME ))) ago"
    ELAPSED_SINCE_LATE="since config change $(elapsed_time $(( $(date +%s) - $LASTCONFIG))) ago"


    if [ "$(echo "$RESULT" | awk 'END { print NR }')" -gt 1 ]
    then
        echo " problem, multiple logs files found 🔥🧯🧯 ($ELAPSED_SINCE_UPDATE) ($ELAPSED_SINCE_LATE)"
    fi

    if [ -z "$RESULT" ]
    then
        echo " not up to date 🚩 ($ELAPSED_SINCE_UPDATE) ($ELAPSED_SINCE_LATE)"
    fi

    if echo "$RESULT" | grep success >/dev/null
    then
        echo " up to date 💚 ($ELAPSED_SINCE_UPDATE)"
    fi

    if echo "$RESULT" | grep failure >/dev/null
    then
        echo " failing 🔥🔥🧯 ($ELAPSED_SINCE_UPDATE) ($ELAPSED_SINCE_LATE)"
    fi

done

