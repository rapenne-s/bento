#!/bin/sh

if test -f config.sh
then
    . ./config.sh
else
    echo "You are missing config.sh"
    exit 2
fi

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
    echo "Copying $i"

    # we only want directories
    if [ -d "$i" ]
    then

      # create the script that will check for updates
      cat > "$i/update.sh" <<EOF
#!/bin/sh
set -e

install -d -o root -g root -m 700 /var/bento
cd /var/bento
touch .state

STATE="\$(echo "ls -l last_change_date" | sftp ${i}@${REMOTE_IP})"
CURRENT_STATE="\$(cat /var/bento/.state)"

if [ "\$STATE" = "\$CURRENT_STATE" ]
then
    echo "no update required"
else
    echo "update required"
    sftp ${i}@${REMOTE_IP}:/bootstrap.sh .
    /bin/sh bootstrap.sh
    echo "\$STATE" > /var/bento/.state
fi
EOF

      # script used to download changes and rebuild
      # also used to run it manually the first time to configure the system
      cat > "$i/bootstrap.sh" <<EOF
#!/bin/sh
set -e

# accept the remote ssh fingerprint if not already known
ssh-keygen -F "${REMOTE_IP}" || ssh-keyscan "${REMOTE_IP}" >> /root/.ssh/known_hosts

install -d -o root -g root -m 700 /var/bento
cd /var/bento

sftp -r ${i}@${REMOTE_IP}:/ .

# for flakes
test -d .git || git init
git add .

# check the current build if it exists
if test -L result
then
    RESULT="\$(readlink -f result)"
fi

if test -f flake.nix
then
    nixos-rebuild build --flake .#bento-machine
    if [ ! "\${RESULT}" = "\$(readlink -f result)" ]
    then
        nixos-rebuild switch --flake .#bento-machine
    fi
else
    export NIX_PATH=/root/.nix-defexpr/channels:nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos:nixos-config=/var/bento/configuration.nix:/nix/var/nix/profiles/per-user/root/channels
    nixos-rebuild build --no-flake --upgrade
    if [ ! "\${RESULT}" = "\$(readlink -f result)" ]
    then
        nixos-rebuild switch --no-flake --upgrade
    fi
fi
EOF

      # to make flakes using caching, we must avoid repositories to change everytime
      # we must ignore files that change everytime
      cat > "$i/.gitignore" <<EOF
bootstrap.sh
update.sh
.state
result
last_change_date
EOF

      # copy files in the chroot
      rsync --delete -avL "$i/" "${CHROOT_DIR}/${i}/"

      # sftp chroot requires the home directory to be owned by root
      install -d -o root -g root -m 755 "${CHROOT_DIR}/${i}"
      touch "${CHROOT_DIR}/${i}/last_change_date"
    fi
done
