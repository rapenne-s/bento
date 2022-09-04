#!/bin/sh

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

# load all hosts or the one defined in environment variable NAME
if [ -z "$NAME" ]
then
  NAME=*
fi

SUCCESS=0
for i in $NAME
do
  if test -d "$i"
  then
    TMP="$(mktemp -d /tmp/bento-build.XXXXXXXXXXXX)"
    TMPLOG="$(mktemp /tmp/bento-build-log.XXXXXXXXXXXX)"
    rsync -aL "$i/" "$TMP/"

    printf "${COMMAND} ${i}: "

    if test -f "$i/flake.nix"
    then
        cd "$TMP" || exit 5
        # add files to a git repo
        test -d .git || git init >/dev/null 2>/dev/null
        git add . >/dev/null
        $SUDO nixos-rebuild "${COMMAND}" --flake .#bento-machine 2>${TMPLOG} >${TMPLOG}
        if [ $? -eq 0 ]; then echo "success"  ; else echo "failure" ; SUCCESS=$(( SUCCESS + 1 )) ; cat ${TMPLOG} ; fi

    else
        cd "$TMP" || exit 5
        $SUDO nixos-rebuild "${COMMAND}" --no-flake -I nixos-config="$TMP/configuration.nix" 2>${TMPLOG} >${TMPLOG}
        if [ $? -eq 0 ]; then echo "success"  ; else echo "failure" ; SUCCESS=$(( SUCCESS + 1 )) ; cat ${TMPLOG} ; fi
    fi
    cd - >/dev/null || exit 5
    rm -fr "$TMP"
  fi
done

# we don't want to allow this script to chain
# with another if it failed
if [ "$SUCCESS" -ne 0 ]
then
    exit 1
fi
