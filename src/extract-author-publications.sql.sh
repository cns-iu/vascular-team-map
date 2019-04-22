#!/bin/bash

psql << EOF
  SET enable_seqscan = OFF;
  SET enable_hashjoin = OFF;

  DROP TABLE IF EXISTS authors_for_search;
  CREATE TABLE authors_for_search (
    first_name character varying,
    middle_name character varying,
    last_name character varying,
    email_address character varying
  );

  \COPY authors_for_search FROM '${1}' WITH Delimiter ',' CSV HEADER Encoding 'SQL-ASCII'

  -- CREATE INDEX wos_summary_names_email_addr_email_search_idx ON wos_summary_names_email_addr(lower(email_addr), id, name_id);
  -- CREATE INDEX wos_summary_names_lastn_search_idx ON wos_summary_names(lower(last_name), first_name, id);

  DROP TABLE IF EXISTS matched_author_publications;
  CREATE TABLE matched_author_publications AS (
    WITH email_authors AS (
      SELECT K.id, K.name_id, 'email'::text AS matched_by
      FROM wos_summary_names_email_addr AS K, authors_for_search AS A
      WHERE lower(K.email_addr) = lower(A.email_address)
    ),
    dais_for_search AS (
      SELECT DISTINCT dais_id
      FROM wos_summary_names AS S, email_authors AS A
      WHERE S.id = A.id AND S.name_id = A.name_id AND dais_id IS NOT NULL
    ),
    orcid_for_search AS (
      SELECT DISTINCT coalesce(orcid_id, orcid_id_tr) AS orcid_id
      FROM wos_summary_names AS S, email_authors AS A
      WHERE S.id = A.id AND S.name_id = A.name_id AND coalesce(orcid_id, orcid_id_tr) IS NOT NULL
    ),
    researcherid_for_search AS (
      SELECT DISTINCT coalesce(r_id, r_id_tr) AS r_id
      FROM wos_summary_names AS S, email_authors AS A
      WHERE S.id = A.id AND S.name_id = A.name_id AND coalesce(r_id, r_id_tr) IS NOT NULL
    ),
    display_name_for_search AS (
      SELECT DISTINCT display_name
      FROM wos_summary_names AS S, email_authors AS A
      WHERE S.id = A.id AND S.name_id = A.name_id AND display_name IS NOT NULL
    ),
    wos_standard_for_search AS (
      SELECT DISTINCT wos_standard
      FROM wos_summary_names AS S, email_authors AS A
      WHERE S.id = A.id AND S.name_id = A.name_id AND wos_standard IS NOT NULL
    ),

    dais_authors AS (
      SELECT S.id, S.name_id, 'dais-via-email'::text as matched_by
      FROM wos_summary_names AS S, dais_for_search AS A
      WHERE S.dais_id = A.dais_id
    ),
    orcid_authors AS (
      SELECT S.id, S.name_id, 'orcid-via-email'::text as matched_by
      FROM wos_summary_names AS S, orcid_for_search AS A
      WHERE S.orcid_id = A.orcid_id OR S.orcid_id_tr = A.orcid_id
    ),
    researcherid_authors AS (
      SELECT S.id, S.name_id, 'researcherid-via-email'::text as matched_by
      FROM wos_summary_names AS S, researcherid_for_search AS A
      WHERE S.r_id = A.r_id OR S.r_id_tr = A.r_id
    ),
    display_name_authors AS (
      SELECT S.id, S.name_id, 'display-name-via-email'::text as matched_by
      FROM wos_summary_names AS S, display_name_for_search AS A
      WHERE S.display_name = A.display_name
    ),
    wos_standard_authors AS (
      SELECT S.id, S.name_id, 'wos-standard-via-email'::text as matched_by
      FROM wos_summary_names AS S, wos_standard_for_search AS A
      WHERE S.wos_standard = A.wos_standard
    )
    SELECT id, array_to_string(array_agg(matched_by), '|') AS matched_by
    FROM (
      SELECT id, matched_by FROM email_authors
      UNION
      SELECT id, matched_by FROM dais_authors
      UNION
      SELECT id, matched_by FROM orcid_authors
      UNION
      SELECT id, matched_by FROM researcherid_authors
      -- UNION
      -- SELECT id, matched_by FROM display_name_authors
      UNION
      SELECT id, matched_by FROM wos_standard_authors
    ) AS A
    GROUP BY id
  );

  -- CREATE TABLE matched_author_publications AS (
  --     SELECT K.id, 'email'::text AS matched_by
  --     FROM wos_summary_names_email_addr AS K, authors_for_search AS A
  --     WHERE lower(K.email_addr) = lower(A.email_address)
  -- );

  -- More complicated search if we are doing multiple search criteria to find publications
  -- CREATE TABLE matched_author_publications AS (
  --   SELECT id, array_to_string(array_agg(match), '|') AS matched_by
  --   FROM (
  --     -- Match by email addres
  --     SELECT K.id, 'email' AS match
  --     FROM wos_summary_names_email_addr AS K, authors_for_search AS A
  --     WHERE lower(K.email_addr) = lower(A.email_address)

  --     UNION

  --     -- Match by last name plus first initial
  --     SELECT id, 'last_plus_first_initial' AS match
  --     FROM (
  --       SELECT S.id, S.first_name AS S_first, A.first_name AS A_first
  --       FROM wos_summary_names AS S, authors_for_search AS A
  --       WHERE lower(S.last_name) = lower(A.last_name)
  --     ) AS N
  --     WHERE lower(LEFT(A_first, 1)) = lower(LEFT(S_first, 1))
  --   ) AS A
  --   GROUP BY id
  -- );
  CREATE UNIQUE INDEX ON matched_author_publications(id);

  -- CREATE INDEX wos_summary_names_wos_id_idx ON wos_summary_names(id);
  -- CREATE INDEX wos_titles_wos_id_idx ON wos_titles(id);
  -- CREATE INDEX wos_address_organizations_wos_id_idx ON wos_address_organizations(id);
  -- CREATE INDEX wos_dynamic_identifiers_wos_id_idx ON wos_dynamic_identifiers(id);

  CREATE INDEX wos_titles_title_type_idx ON wos_titles(title_type);
  CREATE INDEX wos_dynamic_identifiers_identifier_type_idx ON wos_dynamic_identifiers(identifier_type);

  DROP TABLE IF EXISTS author_publications_export;
  CREATE TABLE author_publications_export AS
    WITH authors AS ( 
      SELECT S.id, array_to_string(array_agg(S.display_name), '|') AS author 
      FROM wos_summary_names AS S, matched_author_publications AS A
      WHERE S.id = A.id AND S.role = 'author'
      GROUP BY S.id
    ),
    titles AS ( 
      SELECT A.id, T.title
      FROM wos_titles AS T, matched_author_publications AS A
      WHERE T.id = A.id AND T.title_type = 'item' 
    ), 
    organizations AS ( 
      SELECT A.id, array_to_string(array_agg(O.organization), '|') AS organizations 
      FROM wos_address_organizations AS O, matched_author_publications AS A 
      WHERE O.id = A.id AND O.org_id = 1
      GROUP BY A.id
    ),
    journals AS (
      SELECT A.id, T.title AS journal
      FROM wos_titles AS T, matched_author_publications AS A
      WHERE T.id = A.id AND title_type='source'
    ),
    issn AS (
      SELECT A.id, identifier_value AS issn
      FROM wos_dynamic_identifiers AS I, matched_author_publications AS A
      WHERE I.id = A.id AND identifier_type='issn'
    ),
    eissn AS (
      SELECT A.id, identifier_value AS eissn
      FROM wos_dynamic_identifiers AS I, matched_author_publications AS A
      WHERE I.id = A.id AND identifier_type='eissn'
    ),
    pubyear as (
      SELECT A.id, S.pubyear as publication_year
      FROM wos_summary AS S, matched_author_publications AS A
      WHERE S.id = A.id
    ),
    times_cited as (
      SELECT A.id, S.wos_total as times_cited
      FROM wos_times_cited AS S, matched_author_publications AS A
      WHERE S.id = A.id
    )
    SELECT 
      A.id, publication_year, title, author, organizations, times_cited, journal, issn, eissn
    FROM
      matched_author_publications AS A 
      LEFT JOIN pubyear ON (pubyear.id = A.id)
      LEFT JOIN titles ON (titles.id = A.id)
      LEFT JOIN authors ON (authors.id = A.id)
      LEFT JOIN organizations ON (organizations.id = A.id)
      LEFT JOIN times_cited ON (times_cited.id = A.id)
      LEFT JOIN journals ON (journals.id = A.id)
      LEFT JOIN issn ON (issn.id = A.id)
      LEFT JOIN eissn ON (eissn.id = A.id);

  \COPY ( SELECT * FROM author_publications_export ) TO '${2}' Delimiter ',' CSV HEADER Encoding 'SQL-ASCII'

EOF
