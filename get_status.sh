#!/bin/sh

. ./config.sh
. ./libs.sh

cd "${CHROOT_DIR}" || exit 5

display_table() {
    size_hostname=$1
    machine=$2
    local_version=$3
    remote_version=$4
    state=$5
    time=$6

    printf "%${size_hostname}s %15s %18s %20s %40s\n" \
        "$machine" "$local_version" "$remote_version" "$state" "$time"
}

PRETTY_OUT_COLUMN=$(ls -1 | awk '{ if(length($1) > max) { max = length($1) }} END { print max }')

# printf isn't aware of emojis, need -2 chars per emoji
printf "%${PRETTY_OUT_COLUMN}s %15s %16s %18s %40s\n" \
	"machine" "local version" "remote version" "state" "elapsed time since"

printf "%${PRETTY_OUT_COLUMN}s %15s %16s %18s %40s\n" \
	"-------" "---------" "-----------" "-------------" "-------------"

for i in *
do
    test -d "${i}" || continue
    RESULT=$(find "${i}/logs/" -type f -cnewer "${i}/last_change_date" | sort -n)

    # date calculation
    LASTLOG=$(find "${i}/logs/" -type f | sort -n | tail -n 1)
    LASTLOGVERSION="$(echo "$LASTLOG" | awk -F '_' '{ print $2 }' | awk -F '-' '{ print $1 }' )"
    NIXPKGS_DATE="$(echo "$LASTLOG" | awk -F '_' '{ print $2 }' | awk -F '-' '{ printf("%s", $NF) }' )"
    LASTTIME=$(date -r "$LASTLOG" "+%s")
    LASTCONFIG=$(date -r "${i}/last_change_date" "+%s")
    ELAPSED_SINCE_UPDATE="build $(elapsed_time $(( $(date +%s) - "$LASTTIME" )))"
    ELAPSED_SINCE_LATE="new config $(elapsed_time $(( $(date +%s) - "$LASTCONFIG")))"

    EXPECTED_CONFIG="$(awk -F '=' -v host="${i}" 'host == $1 { print $2 }' states.txt | cut -b 1-8)"

    if grep "^${i}=${LASTLOGVERSION}" states.txt >/dev/null
    then
        MATCH="💚"
        MATCH_IF=1
    else
        MATCH="🛑"
        MATCH_IF=0
    fi

    SHORT_VERSION="$(echo "$LASTLOGVERSION" | cut -b 1-8)"

    # Too many logs while there should be only one
    if [ "$(echo "$RESULT" | awk 'END { print NR }')" -gt 1 ]
    then
        display_table "$PRETTY_OUT_COLUMN" "$i" "${EXPECTED_CONFIG}" "${SHORT_VERSION} ${MATCH}" "extra logs 🔥" "($ELAPSED_SINCE_UPDATE) ($ELAPSED_SINCE_LATE)"
        continue
    fi

    # no result since we updated configuration files
    # the client is not up to date
    if [ -z "$RESULT" ]
    then
        if [ "${MATCH_IF}" -eq 0 ]
        then
            display_table "$PRETTY_OUT_COLUMN" "$i" "${EXPECTED_CONFIG}" "${SHORT_VERSION} ${MATCH}" "rebuild pending 🚩" "($ELAPSED_SINCE_UPDATE) ($ELAPSED_SINCE_LATE)"
        else
            display_table "$PRETTY_OUT_COLUMN" "$i" "${EXPECTED_CONFIG}" "${SHORT_VERSION} ${MATCH}" "sync pending 🚩" "($ELAPSED_SINCE_UPDATE) ($ELAPSED_SINCE_LATE)"
        fi
        # if no new log
        # then it can't be in another further state
        continue
    fi

    # check if latest log contains rollback
    if echo "$LASTLOG" | grep rollback >/dev/null
    then
        display_table "$PRETTY_OUT_COLUMN" "$i" "${EXPECTED_CONFIG}" "${SHORT_VERSION} ${MATCH}" "    rollbacked ⏪" "($ELAPSED_SINCE_UPDATE)"
    fi

    # check if latest log contains success
    if echo "$LASTLOG" | grep success >/dev/null
    then
        display_table "$PRETTY_OUT_COLUMN" "$i" "${EXPECTED_CONFIG}" "${SHORT_VERSION} ${MATCH}" "    up to date 💚" "($ELAPSED_SINCE_UPDATE)"
    fi

    # check if latest log contains failure
    if echo "$LASTLOG" | grep failure >/dev/null
    then
        display_table "$PRETTY_OUT_COLUMN" "$i" "${EXPECTED_CONFIG}" "${SHORT_VERSION} ${MATCH}" "       failing 🔥" "($ELAPSED_SINCE_UPDATE) ($ELAPSED_SINCE_LATE)"
    fi

done

