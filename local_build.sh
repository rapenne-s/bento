#!/bin/sh

. ./libs.sh

if [ -z "$1" ]
then
  COMMAND="dry-build"
else
  COMMAND="$1"
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

cd hosts
if [ -z "${NAME}" ]
then
    NAME=*
    PRETTY_OUT_COLUMN=$(ls -1 | awk '{ if(length($1) > max) { max = length($1) }} END { print max }')
fi

for i in $NAME
do
    printf "%${PRETTY_OUT_COLUMN}s " "${i}"
    test -d "$i" || continue
    build_config "$i" "$COMMAND" "$SUDO" "$i"
done
