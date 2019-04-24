#!/bin/bash
source constants.sh
source db-config.sh
set -ev

in=$OUT/authors-for-search.csv

psql << EOF
  DROP TABLE IF EXISTS $s.authors_for_search;

  CREATE TABLE $s.authors_for_search (
    author_id integer,
    first_name character varying,
    middle_name character varying,
    last_name character varying,
    email_address character varying
  );

  \COPY $s.authors_for_search FROM '${in}' WITH Delimiter ',' CSV HEADER Encoding 'SQL-ASCII'

  CREATE UNIQUE INDEX ON $s.authors_for_search(author_id);
EOF
