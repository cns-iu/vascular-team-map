#!/bin/bash
source constants.sh
source db-config.sh
set -ev

out=$OUT/journals-for-search.csv

psql << EOF
  SET enable_seqscan = OFF;
  SET enable_hashjoin = OFF;

  DROP TABLE IF EXISTS $s.journals_for_search;

  CREATE TABLE $s.journals_for_search AS
    SELECT DISTINCT T.title AS journal
    FROM $s.matched_email_author_publications_plus AS A
      INNER JOIN wos_titles AS T ON (A.id = T.id AND T.title_type='source');

  CREATE UNIQUE INDEX ON $s.journals_for_search(journal);

  \COPY ( SELECT journal FROM $s.journals_for_search ORDER BY journal ASC ) TO '${out}' Delimiter ',' CSV HEADER Encoding 'SQL-ASCII'
EOF
