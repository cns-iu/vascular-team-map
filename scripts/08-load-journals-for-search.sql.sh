#!/bin/bash
source constants.sh
source db-config.sh
set -ev

in=$OUT/journals-for-search.csv

psql << EOF
  DROP TABLE IF EXISTS $s.journals_for_search;

  CREATE TABLE $s.journals_for_search (
    journal character varying
  );

  \COPY $s.journals_for_search FROM '${in}' WITH Delimiter ',' CSV HEADER Encoding 'SQL-ASCII'

  CREATE UNIQUE INDEX ON $s.journals_for_search(journal);
EOF
