#!/bin/bash
source constants.sh
source db-config.sh
set -ev

psql << EOF
  DROP SCHEMA IF EXISTS $s CASCADE;
  CREATE SCHEMA $s;
EOF
