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
for i in *
do
    test -d "$i" || continue
    build_config "$i" "$COMMAND" "$SUDO" "$i"
done
