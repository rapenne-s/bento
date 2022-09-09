#!/bin/sh

if test -f config.sh
then
    . ./config.sh
else
    echo "You are missing config.sh"
    exit 2
fi

. ./libs.sh

cd hosts

# load all hosts or the one defined in environment variable NAME
FLAKES=$(
for flakes in $(find . -name flake.nix)
do
    TARGET="$(dirname $flakes)"
    nix flake show --json "path:$TARGET" | jq -r '.nixosConfigurations | keys[]'
done
)

if [ -z "${NAME}" ]
then
    NAME=*
    PRETTY_OUT_COLUMN=$( ( ls -1 ; echo $FLAKES ) | awk '{ if(length($1) > max) { max = length($1) }} END { print max }')
else
    MATCH=$(echo "$FLAKES" | awk -v name="${NAME}" 'BEGIN { sum = 0 } name == $1 { sum=sum+1 } END { print sum }')
    if [ "$MATCH" -ne 1 ]
    then
        echo "Found ${MATCH} system with this name"
        exit 2
    else
        for flakes in $(find . -name flake.nix)
        do
            TARGET="$(dirname $flakes)"
            FLAKES_IN_DIR=$(nix flake show --json "path:$TARGET" | jq -r '.nixosConfigurations | keys[]')
            if echo "${FLAKES_IN_DIR}" | grep "^${NAME}$" >/dev/null
            then
                # store the configuration name
                SINGLE_FLAKE="${NAME}"
                # store the directory containing it
                NAME="$(basename ${TARGET})"
            fi
        done
    fi
fi

if [ "$1" = "build" ]
then
    if [ -z "$2" ]
    then
      COMMAND="dry-build"
    else
      COMMAND="$2"
    fi

    if [ "$COMMAND" = "switch" ] || [ "$COMMAND" = "test" ]
    then

        # we only allow these commands if you have only one name
        if [ -n "$NAME" ]
        then
            SUDO="sudo"
            echo "you are about to $COMMAND $NAME, are you sure? Ctrl+C to abort"
            read a
        else
            echo "you can't use $COMMAND without giving a single configuration to use with variable NAME"
        fi

    else # not using switch or test
        SUDO=""
    fi
    for i in $NAME
    do
        test -d "$i" || continue
        if [ -f "$i/flake.nix" ]
        then
            for host in $(nix flake show --json "path:${i}" | jq -r '.nixosConfigurations | keys[]')
            do
                test -n "${SINGLE_FLAKE}" && ! [ "$host" = "${SINGLE_FLAKE}" ] && continue
                printf "%${PRETTY_OUT_COLUMN}s " "${host}"
                build_config "$i" "$COMMAND" "$SUDO" "$host"
            done
        else
            printf "%${PRETTY_OUT_COLUMN}s " "${i}"
            build_config "$i" "$COMMAND" "$SUDO" "$i"
        fi
    done
    exit 0
fi

if [ "$1" = "deploy" ]
then
    if [ "$(id -u)" -ne 0 ]
    then
      echo "you need to be root to run this script"
      exit 1
    fi

    for i in $NAME
    do
        if [ -f "$i/flake.nix" ]
        then
            for host in $(nix flake show --json "path:${i}" | jq -r '.nixosConfigurations | keys[]')
            do
                test -n "${SINGLE_FLAKE}" && ! [ "$host" = "${SINGLE_FLAKE}" ] && continue
                deploy_files "$i" "${host}" "${host}"
            done
        else
            deploy_files "$i" "$i"
        fi

    done

    if [ -f ../states.txt ]
    then
        cp ../states.txt "${CHROOT_DIR}/states.txt"
    fi
fi
