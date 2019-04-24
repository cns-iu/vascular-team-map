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
    ),
    authors AS ( 
      SELECT S.id, array_to_string(array_agg(S.display_name), '|') AS authors
      FROM wos_summary_names AS S, $s.matched_author_publications AS A
      WHERE S.id = A.id AND S.role = 'author'
      GROUP BY S.id
    ),
    titles AS ( 
      SELECT A.id, T.title
      FROM wos_titles AS T, $s.matched_author_publications AS A
      WHERE T.id = A.id AND T.title_type = 'item' 
    ), 
    organizations AS ( 
      SELECT A.id, array_to_string(array_agg(O.organization), '|') AS organizations 
      FROM wos_address_organizations AS O, $s.matched_author_publications AS A 
      WHERE O.id = A.id AND O.org_id = 1
      GROUP BY A.id
    ),
    journals AS (
      SELECT A.id, T.title AS journal
      FROM wos_titles AS T, $s.matched_author_publications AS A
      WHERE T.id = A.id AND title_type = 'source'
    ),
    issn AS (
      SELECT A.id, identifier_value AS issn
      FROM wos_dynamic_identifiers AS I, $s.matched_author_publications AS A
      WHERE I.id = A.id AND identifier_type = 'issn'
    ),
    eissn AS (
      SELECT A.id, identifier_value AS eissn
      FROM wos_dynamic_identifiers AS I, $s.matched_author_publications AS A
      WHERE I.id = A.id AND identifier_type = 'eissn'
    ),
    pubyear as (
      SELECT A.id, S.pubyear as publication_year
      FROM wos_summary AS S, $s.matched_author_publications AS A
      WHERE S.id = A.id
    ),
    times_cited as (
      SELECT A.id, S.wos_total as times_cited
      FROM wos_times_cited AS S, $s.matched_author_publications AS A
      WHERE S.id = A.id
    )
    SELECT 
      A.id, A.author_id, source_authors, publication_year, title, authors, organizations, times_cited, journal, issn, eissn
    FROM
      $s.matched_author_publications AS A 
      LEFT JOIN source_authors ON (source_authors.id = A.id)
      LEFT JOIN pubyear ON (pubyear.id = A.id)
      LEFT JOIN titles ON (titles.id = A.id)
      LEFT JOIN authors ON (authors.id = A.id)
      LEFT JOIN organizations ON (organizations.id = A.id)
      LEFT JOIN times_cited ON (times_cited.id = A.id)
      LEFT JOIN journals ON (journals.id = A.id)
      LEFT JOIN issn ON (issn.id = A.id)
      LEFT JOIN eissn ON (eissn.id = A.id);

  CREATE INDEX ON $s.author_publications_export(author_id);

  DROP TABLE IF EXISTS $s.author_publications_export_rollup;

  CREATE TABLE $s.author_publications_export_rollup AS
    SELECT DISTINCT ON (id) id, source_authors, publication_year, title, authors, organizations, times_cited, journal, issn, eissn
    FROM $s.author_publications_export;
EOF
