#!/bin/bash
source constants.sh
source db-config.sh
set -ev

psql << EOF
  SET enable_seqscan = OFF;
  SET enable_hashjoin = OFF;

  DROP TABLE IF EXISTS $s.author_publications_export;

  CREATE TABLE $s.author_publications_export AS
    WITH source_authors AS ( 
      SELECT id, array_to_string(array_agg(first_name || ' ' || last_name), '|') AS source_authors
      FROM $s.matched_author_publications AS A
        INNER JOIN $s.authors_for_search AS S ON (A.author_id = S.author_id)
      GROUP BY id
    )
    SELECT 
      A.id, A.author_id, source_authors, publication_year, title, authors, organizations, times_cited, journal, issn, eissn
    FROM
      $s.matched_author_publications AS A 
      INNER JOIN source_authors AS S ON (S.id = A.id)
      INNER JOIN wosx_publications_export AS P ON (P.id = A.id);

  CREATE INDEX ON $s.author_publications_export(author_id);
  CREATE INDEX ON $s.author_publications_export(id);

  DROP TABLE IF EXISTS $s.author_publications_export_rollup;

  CREATE TABLE $s.author_publications_export_rollup AS
    SELECT DISTINCT ON(id) id, source_authors, publication_year, title, authors, organizations, times_cited, journal, issn, eissn
    FROM $s.author_publications_export;
EOF
