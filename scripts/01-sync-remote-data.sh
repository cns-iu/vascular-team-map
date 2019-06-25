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

mkdir -p ${ORIG}/author-data

lftp << EOF
set ftps:initial-prot "";
set ftp:ssl-force true;
set ftp:ssl-protect-data true;
open --user ${BOX_USER} --password "${LFTP_PASSWORD}" ftps://ftp.box.com:990;
mirror --delete --no-perms --verbose "${REMOTE_DIR}" "${ORIG}/author-data";
EOF
