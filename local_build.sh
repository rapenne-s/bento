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

for i in $NAME
do
  TMP="$(mktemp -d /tmp/bento-build.XXXXXXXXXXXX)"
  rsync -aL "$i/" "$TMP/"
  if test -f "$i/flake.nix"
  then

      # add files to a git repo
      cd "$TMP"
      test -d .git || git init >/dev/null 2>/dev/null
      git add . >/dev/null
      $SUDO nixos-rebuild "${COMMAND}" --flake .#bento-machine 2>log >log
      if [ $? -eq 0 ]; then echo "$COMMAND ${i}: success"  ; else echo "$COMMAND ${i}: failure" ; cat log ; fi
      cd - >/dev/null

  else
      $SUDO nixos-rebuild "${COMMAND}" --no-flake -I nixos-config="$TMP/configuration.nix" 2>log >log
      if [ $? -eq 0 ]; then echo "$COMMAND ${i}: success"  ; else echo "$COMMAND ${i}: failure" ; cat log ; fi
  fi
  rm -fr "$TMP"
done
