#!/bin/bash
source constants.sh
source db-config.sh
set -ev

psql << EOF
  SET enable_seqscan = OFF;
  SET enable_hashjoin = OFF;

  DROP TABLE IF EXISTS $s.matched_author_publications;

  CREATE TABLE $s.matched_author_publications AS
    WITH email_matches AS (
      SELECT P.*
      FROM $s.matched_email_author_publications_plus AS P
        INNER JOIN $s.publication_search_space S ON (P.id = S.id)
    ),
    wos_standard_matches AS (
      SELECT DISTINCT P.id, name_id, author_id, 'wos_standard'::text AS matched_by
      FROM wos_summary_names AS P 
        INNER JOIN $s.publication_search_space AS S ON (P.id = S.id)
        INNER JOIN $s.authors_for_search AS A ON (
          lower(P.last_name) = lower(A.last_name) AND lower(LEFT(P.first_name, 1)) = lower(LEFT(A.first_name, 1))
        )
      WHERE coalesce(A.middle_name, '') = '' -- OR coalesce(P.middle_name, '') = ''
          OR lower(LEFT(A.middle_name, 1)) = lower(LEFT(P.middle_name, 1))
    )
    SELECT id, name_id, author_id, array_to_string(array_agg(matched_by), '|') AS matched_by
    FROM (
      SELECT * FROM email_matches
      UNION
      SELECT * FROM wos_standard_matches
    ) AS A
    GROUP BY id, name_id, author_id;

  CREATE INDEX ON $s.matched_author_publications(id);
  CREATE INDEX ON $s.matched_author_publications(author_id);
EOF
