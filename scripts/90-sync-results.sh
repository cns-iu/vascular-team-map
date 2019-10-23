#!/bin/bash
source constants.sh
set -ev

if [ "${DOSYNC}" == "false" ]
then
  exit
fi

if [ -z "$LFTP_PASSWORD" ]
then
  read -s -p "Password: " LFTP_PASSWORD
fi

lftp << EOF
set ftps:initial-prot "";
set ftp:ssl-force true;
set ftp:ssl-protect-data true;
open --user ${BOX_USER} --password "${LFTP_PASSWORD}" ftps://ftp.box.com:990;
mirror -R --delete --no-perms --verbose "${OUT}" "${REMOTE_RESULTS_DIR}";
EOF
