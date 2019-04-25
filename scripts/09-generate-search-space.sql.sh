#!/bin/bash
source constants.sh
source db-config.sh
set -ev

psql << EOF
  SET enable_seqscan = OFF;
  SET enable_hashjoin = OFF;

  DROP TABLE IF EXISTS $s.publication_search_space;

  CREATE TABLE $s.publication_search_space AS
    SELECT DISTINCT T.id
    FROM wos_titles AS T, $s.journals_for_search AS J, wos_summary AS S
    WHERE T.id = S.id AND T.title = J.journal
      AND coalesce(S.pubyear, '0')::integer >= $MINYEAR
      AND T.title_type='source';

  CREATE UNIQUE INDEX ON $s.publication_search_space(id);
EOF
