build_config()
{
    SOURCES=$1
    COMMAND="$2"
    SUDO="$3"
    NAME="$4"

    SUCCESS=0
    TMP="$(mktemp -d /tmp/bento-build.XXXXXXXXXXXX)"
    TMPLOG="$(mktemp /tmp/bento-build-log.XXXXXXXXXXXX)"
    rsync -aL "$SOURCES/" "$TMP/"

    SECONDS=0
    if test -f "$SOURCES/flake.nix"
    then
        cd "$TMP" || exit 5

        # add files to a git repo
        test -d .git || git init >/dev/null 2>/dev/null
        git add . >/dev/null

        $SUDO nixos-rebuild "${COMMAND}" --flake .#bento-machine 2>${TMPLOG} >${TMPLOG}
        if [ $? -eq 0 ]; then printf "success " ; else printf "failure " ; BAD_HOSTS="${NAME} ${BAD_HOSTS}" ; SUCCESS=$(( SUCCESS + 1 )) ; cat ${TMPLOG} ; fi
        ELAPSED=$(elapsed_time $SECONDS)
        printf "($ELAPSED)"
        if [ "${COMMAND}" = "build" ]
        then
            touch ${OLDPWD}/../states.txt
            VERSION="$(readlink -f result | tr -d '\n' | sed 's,/nix/store/,,')"
            printf " %s" "${VERSION}"
            sed -i "/^${NAME}/d" $OLDPWD/../states.txt >/dev/null
            echo "${NAME}=${VERSION}" >> $OLDPWD/../states.txt
        fi
        echo ""
    else
        cd "${TMP}" || exit 5
        $SUDO nixos-rebuild "${COMMAND}" --no-flake -I nixos-config="$TMP/configuration.nix" 2>${TMPLOG} >${TMPLOG}
        if [ $? -eq 0 ]; then printf "success "  ; else printf "failure " ; BAD_HOSTS="${NAME} ${BAD_HOSTS}" ; SUCCESS=$(( SUCCESS + 1 )) ; cat ${TMPLOG} ; fi
        ELAPSED=$(elapsed_time $SECONDS)
        printf "($ELAPSED)"
        if [ "${COMMAND}" = "build" ]
        then
            touch "${OLDPWD}/../states.txt"
            VERSION="$(readlink -f result | tr -d '\n' | sed 's,/nix/store/,,')"
            printf " %s" "${VERSION}"
            sed -i '/^"${NAME}"/d' "${OLDPWD}/../states.txt" >/dev/null
            echo "${NAME}=${VERSION}" >> "${OLDPWD}/../states.txt"
        fi
        echo ""
    fi
    cd - >/dev/null || exit 5
    rm -fr "$TMP"

    return "${SUCCESS}"
}

deploy_files() {
    i="$1"
    printf "Copying $i: "

    # we only want directories
    if [ -d "$i" ]
    then

        STAGING_DIR="$(mktemp -d /tmp/bento-staging-dispatch.XXXXXXXXXXXXXX)"

        # sftp chroot requires the home directory to be owned by root
        install -d -o root   -g sftp_users -m 755 "${STAGING_DIR}"
        install -d -o root   -g sftp_users -m 755 "${STAGING_DIR}/${i}"
        install -d -o root   -g sftp_users -m 755 "${STAGING_DIR}/${i}/config"
        install -d -o "${i}" -g sftp_users -m 755 "${STAGING_DIR}/${i}/logs"

        # copy files in the chroot
        rsync --delete -rltgoDL "$i/" "${STAGING_DIR}/${i}/config/"

        # create the script that will check for updates
        cat > "${STAGING_DIR}/${i}/config/update.sh" <<EOF
#!/bin/sh

install -d -o root -g root -m 700 /var/bento
cd /var/bento || exit 5
touch .state

STATEFILE="\$(mktemp /tmp/bento-state.XXXXXXXXXXXXXXXX)"
echo "ls -l last_change_date" | sftp ${i}@${REMOTE_IP} >"\${STATEFILE}"

if [ \$? -ne 0 ]
then
    echo "There is certainly a network problem with ${REMOTE_IP}"
    echo "Aborting"
    rm "\${STATEFILE}"
    exit 1
fi

STATE="\$(cat "\${STATEFILE}")"
CURRENT_STATE="\$(cat /var/bento/.state)"

if [ "\$STATE" = "\$CURRENT_STATE" ]
then
    echo "no update required"
else
    echo "update required"
    sftp ${i}@${REMOTE_IP}:/config/bootstrap.sh .
    /bin/sh bootstrap.sh
    echo "\$STATE" > /var/bento/.state
fi
rm "\${STATEFILE}"
EOF

        # script used to download changes and rebuild
        # also used to run it manually the first time to configure the system
        cat > "${STAGING_DIR}/${i}/config/bootstrap.sh" <<EOF
#!/bin/sh

# accept the remote ssh fingerprint if not already known
ssh-keygen -F "${REMOTE_IP}" >/dev/null || ssh-keyscan "${REMOTE_IP}" >> /root/.ssh/known_hosts

install -d -o root -g root -m 700 /var/bento
cd /var/bento || exit 5

find . -maxdepth 1 -type d -exec rm -fr {} \;
find . -maxdepth 1 -type f -not -name .state -and -not -name update.sh -and -not -name bootstrap.sh -exec rm {} \;

printf "%s\n" "cd config" "get -R ." | sftp -r ${i}@${REMOTE_IP}:

# required by flakes
test -d .git || git init
git add .

# check the current build if it exists
OSVERSION="\$(basename \$(readlink -f /nix/var/nix/profiles/system))"

LOGFILE=\$(mktemp /tmp/build-log.XXXXXXXXXXXXXXXXXXXX)

SUCCESS=2
if test -f flake.nix
then
    nixos-rebuild build --flake .#bento-machine
    SUCCESS=\$?
    if [ "\${SUCCESS}" -eq 0 ]
    then
        if [ ! "\${OSVERSION}" = "\$(basename \$(readlink -f result))" ]
        then
            nixos-rebuild switch --flake .#bento-machine 2>&1 | tee \$LOGFILE
            SUCCESS=\$(( SUCCESS + \$? ))

            # did we change the OSVERSION?
            NEWVERSION="\$(basename \$(readlink -f /nix/var/nix/profiles/system))"
            if [ "\${OSVERSION}" = "\${NEWVERSION}" ]
            then
                SUCCESS=1
            else
                OSVERSION="\${NEWVERSION}"
            fi
        else
            # we want to report a success log
            # no configuration changed but Bento did
            SUCCESS=0
        fi
    fi
else
    export NIX_PATH=/root/.nix-defexpr/channels:nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos:nixos-config=/var/bento/configuration.nix:/nix/var/nix/profiles/per-user/root/channels
    nixos-rebuild build --no-flake --upgrade 2>&1 | tee \$LOGFILE
    SUCCESS=\$?
    if [ "\${SUCCESS}" -eq 0 ]
    then
        if [ ! "\${OSVERSION}" = "\$(basename \$(readlink -f result))" ]
        then
            nixos-rebuild switch --no-flake --upgrade 2>&1 | tee -a \$LOGFILE
            SUCCESS=\$(( SUCCESS + \$? ))

            # did we change the OSVERSION?
            NEWVERSION="\$(basename \$(readlink -f /nix/var/nix/profiles/system))"
            if [ "\${OSVERSION}" = "\${NEWVERSION}" ]
            then
                SUCCESS=1
            else
                OSVERSION="\${NEWVERSION}"
            fi
        else
            # we want to report a success log
            # no configuration changed but Bento did
            SUCCESS=0
        fi
    fi
fi

# nixos-rebuild doesn't report an error in case of lack of disk space on /boot
# see #189966
if [ "\$SUCCESS" -eq 0 ]
then
    if grep "No space left" "\$LOGFILE"
    then
        SUCCESS=1
        # we don't want to skip a rebuild next time
        rm result
    fi
fi

gzip -9 \$LOGFILE
if [ "\$SUCCESS" -eq 0 ]
then
    echo "put \${LOGFILE}.gz /logs/\$(date +%Y%m%d-%H%M)_\${OSVERSION}_success.log.gz" | sftp ${i}@${REMOTE_IP}:
else
    echo "put \${LOGFILE}.gz /logs/\$(date +%Y%m%d-%H%M)_\${OSVERSION}_failure.log.gz" | sftp ${i}@${REMOTE_IP}:
fi
rm "\${LOGFILE}.gz"
EOF

        # to make flakes using caching, we must avoid repositories to change everytime
        # we must ignore files that change everytime
        cat > "${STAGING_DIR}/${i}/config/.gitignore" <<EOF
bootstrap.sh
update.sh
.state
result
last_change_date
EOF

        # only distribute changes if they changed
        # this avoids bumping the time and trigger a rebuild for nothing
        diff -r "${STAGING_DIR}/${i}/config/" "${CHROOT_DIR}/${i}/config/" >/dev/null
        CHANGES=$?

        if [ "$CHANGES" -ne 0 ]
        then
            build_config "${STAGING_DIR}/${i}/config/" "build" "" "${i}"
            echo " update required"
            # copy files in the chroot
            install -d -o root -g sftp_users -m 755 "${CHROOT_DIR}"
            install -d -o root -g sftp_users -m 755 "${CHROOT_DIR}/${i}"
            install -d -o root -g sftp_users -m 755 "${CHROOT_DIR}/${i}/config"
            install -d -o "${i}" -g sftp_users -m 755 "${CHROOT_DIR}/${i}/logs"
            rsync --delete -rltgoDL "${STAGING_DIR}/${i}/config/" "${CHROOT_DIR}/${i}/config/"
            touch "${CHROOT_DIR}/${i}/last_change_date"
        else
            echo " no changes"
        fi

        rm -fr "${STAGING_DIR}"
        fi
}

elapsed_time() {
    RAW="$1"

    DAYS=$(( RAW / (24 * 60 * 60) ))
    RAW=$(( RAW % (24 * 60 * 60) ))

    HOURS=$(( RAW / (60 * 60) ))
    RAW=$(( RAW % (60 * 60) ))

    MINUTES=$(( RAW / 60 ))
    RAW=$(( RAW % 60 ))

    SEC=$RAW

    if [ "$DAYS" -ne 0 ]; then DURATION="${DAYS}d " ; fi
    if [ "$HOURS" -ne 0 ]; then DURATION="${DURATION}${HOURS}h " ; fi
    if [ "$MINUTES" -ne 0 ]; then DURATION="${DURATION}${MINUTES}m " ; fi
    if [ "$SEC" -ne 0 ]; then DURATION="${DURATION}${SEC}s" ; fi

    if [ -z "$DURATION" ]; then DURATION="0s" ; fi

    echo "$DURATION"
}

