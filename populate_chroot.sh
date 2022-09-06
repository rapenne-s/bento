#!/bin/sh

if test -f config.sh
then
    . ./config.sh
else
    echo "You are missing config.sh"
    exit 2
fi

. ./libs.sh

if [ "$(id -u)" -ne 0 ]
then
  echo "you need to be root to run this script"
  exit 1
fi

cd hosts

# load all hosts or the one defined in environment variable NAME
if [ -z "$NAME" ]
then
  NAME=*
fi

for i in $NAME
do
    deploy_files "$i"
    if [ -f ../states.txt ]
    then
        cp ../states.txt "${CHROOT_DIR}/states.txt"
    fi
done
