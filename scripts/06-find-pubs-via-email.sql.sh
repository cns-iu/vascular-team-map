#!/bin/bash
source constants.sh
source db-config.sh
set -ev

psql << EOF
  SET enable_seqscan = OFF;
  SET enable_hashjoin = OFF;

  DROP TABLE IF EXISTS $s.matched_email_author_publications;

  CREATE TABLE $s.matched_email_author_publications AS
    SELECT DISTINCT K.id, K.name_id, A.author_id, 'email'::text AS matched_by
    FROM wos_summary_names_email_addr AS K, $s.authors_for_search AS A
    WHERE lower(K.email_addr) = lower(A.email_address);

  CREATE UNIQUE INDEX ON $s.matched_email_author_publications(id, name_id, author_id);

  DROP TABLE IF EXISTS $s.matched_email_author_publications_plus;

  CREATE TABLE $s.matched_email_author_publications_plus AS
    WITH dais_for_search AS (
      SELECT DISTINCT dais_id, A.author_id
      FROM wos_summary_names AS S, $s.matched_email_author_publications AS A
      WHERE S.id = A.id AND S.name_id = A.name_id AND dais_id IS NOT NULL
    ),
    orcid_for_search AS (
      SELECT DISTINCT coalesce(orcid_id, orcid_id_tr) AS orcid_id, A.author_id
      FROM wos_summary_names AS S, $s.matched_email_author_publications AS A
      WHERE S.id = A.id AND S.name_id = A.name_id AND coalesce(orcid_id, orcid_id_tr) IS NOT NULL
    ),
    researcherid_for_search AS (
      SELECT DISTINCT coalesce(r_id, r_id_tr) AS r_id, A.author_id
      FROM wos_summary_names AS S, $s.matched_email_author_publications AS A
      WHERE S.id = A.id AND S.name_id = A.name_id AND coalesce(r_id, r_id_tr) IS NOT NULL
    ),

    dais_authors AS (
      SELECT S.id, S.name_id, A.author_id, 'dais-via-email'::text as matched_by
      FROM wos_summary_names AS S, dais_for_search AS A
      WHERE S.dais_id = A.dais_id
    ),
    orcid_authors AS (
      SELECT S.id, S.name_id, A.author_id, 'orcid-via-email'::text as matched_by
      FROM wos_summary_names AS S, orcid_for_search AS A
      WHERE S.orcid_id = A.orcid_id OR S.orcid_id_tr = A.orcid_id
    ),
    researcherid_authors AS (
      SELECT S.id, S.name_id, A.author_id, 'researcherid-via-email'::text as matched_by
      FROM wos_summary_names AS S, researcherid_for_search AS A
      WHERE S.r_id = A.r_id OR S.r_id_tr = A.r_id
    )
    SELECT id, name_id, author_id, array_to_string(array_agg(matched_by), '|') AS matched_by
    FROM (
      SELECT id, name_id, author_id, matched_by FROM $s.matched_email_author_publications
      UNION
      SELECT id, name_id, author_id, matched_by FROM dais_authors
      UNION
      SELECT id, name_id, author_id, matched_by FROM orcid_authors
      UNION
      SELECT id, name_id, author_id, matched_by FROM researcherid_authors
    ) AS A
    GROUP BY id, name_id, author_id;

  CREATE INDEX ON $s.matched_email_author_publications_plus(id, name_id);
EOF
