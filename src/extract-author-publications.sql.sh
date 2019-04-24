#!/bin/bash

### TO BE DELETED ONCE THE NEW WORKFLOW IS VERIFIED ###

psql << EOF
  SET enable_seqscan = OFF;
  SET enable_hashjoin = OFF;

  DROP TABLE IF EXISTS authors_for_search;
  CREATE TABLE authors_for_search (
    author_id integer,
    first_name character varying,
    middle_name character varying,
    last_name character varying,
    email_address character varying
  );

  \COPY authors_for_search FROM '${1}' WITH Delimiter ',' CSV HEADER Encoding 'SQL-ASCII'

  -- CREATE INDEX wos_summary_names_email_addr_email_search_idx ON wos_summary_names_email_addr(lower(email_addr), id, name_id);
  -- CREATE INDEX wos_summary_names_lastn_search_idx ON wos_summary_names(lower(last_name), first_name, id);

  DROP TABLE IF EXISTS matched_email_author_publications;
  CREATE TABLE matched_email_author_publications AS
    SELECT DISTINCT K.id, K.name_id, A.author_id, 'email'::text AS matched_by
    FROM wos_summary_names_email_addr AS K, authors_for_search AS A
    WHERE lower(K.email_addr) = lower(A.email_address);
  CREATE UNIQUE INDEX ON matched_email_author_publications(id, name_id, author_id);

  DROP TABLE IF EXISTS matched_email_author_publications_plus;
  CREATE TABLE matched_email_author_publications_plus AS
    WITH dais_for_search AS (
      SELECT DISTINCT dais_id, A.author_id
      FROM wos_summary_names AS S, matched_email_author_publications AS A
      WHERE S.id = A.id AND S.name_id = A.name_id AND dais_id IS NOT NULL
    ),
    orcid_for_search AS (
      SELECT DISTINCT coalesce(orcid_id, orcid_id_tr) AS orcid_id, A.author_id
      FROM wos_summary_names AS S, matched_email_author_publications AS A
      WHERE S.id = A.id AND S.name_id = A.name_id AND coalesce(orcid_id, orcid_id_tr) IS NOT NULL
    ),
    researcherid_for_search AS (
      SELECT DISTINCT coalesce(r_id, r_id_tr) AS r_id, A.author_id
      FROM wos_summary_names AS S, matched_email_author_publications AS A
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
      SELECT id, name_id, author_id, matched_by FROM matched_email_author_publications
      UNION
      SELECT id, name_id, author_id, matched_by FROM dais_authors
      UNION
      SELECT id, name_id, author_id, matched_by FROM orcid_authors
      UNION
      SELECT id, name_id, author_id, matched_by FROM researcherid_authors
    ) AS A
    GROUP BY id, name_id, author_id;
  CREATE INDEX ON matched_email_author_publications_plus(id, name_id);

  DROP TABLE IF EXISTS journals_for_search;
  CREATE TABLE journals_for_search AS
    SELECT DISTINCT T.title AS journal
    FROM matched_email_author_publications_plus AS A
      INNER JOIN wos_titles AS T ON (A.id = T.id AND T.title_type='source')
  CREATE UNIQUE INDEX ON journals_for_search(journal);

  DROP TABLE IF EXISTS publication_search_space;
  CREATE TABLE publication_search_space AS
    SELECT DISTINCT T.id
    FROM wos_titles AS T, journals_for_search AS J, wos_summary AS S
    WHERE T.id = S.id AND T.title = J.journal
      AND coalesce(S.pubyear, '0')::integer >= 1989
      AND T.title_type='source';
  CREATE UNIQUE INDEX ON publication_search_space(id);

  DROP TABLE IF EXISTS matched_author_publications;
  CREATE TABLE matched_author_publications AS
    WITH email_matches AS (
      SELECT P.*
      FROM matched_email_author_publications_plus AS P
        INNER JOIN publication_search_space S ON (P.id = S.id)
    ),
    wos_standard_matches AS (
      SELECT DISTINCT P.id, name_id, author_id, 'wos_standard'::text AS matched_by
      FROM wos_summary_names AS P 
        INNER JOIN publication_search_space AS S ON (P.id = S.id)
        INNER JOIN authors_for_search AS A ON (
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
  CREATE INDEX ON matched_author_publications(id);
  CREATE INDEX ON matched_author_publications(author_id);
  
  -- CREATE INDEX wos_titles_title_type_idx ON wos_titles(title_type);
  -- CREATE INDEX wos_dynamic_identifiers_identifier_type_idx ON wos_dynamic_identifiers(identifier_type);

  DROP TABLE IF EXISTS author_publications_export;
  CREATE TABLE author_publications_export AS
    WITH source_authors AS ( 
      SELECT id, array_to_string(array_agg(first_name || ' ' || last_name), '|') AS source_authors
      FROM matched_author_publications AS A
        INNER JOIN authors_for_search AS S ON (A.author_id = S.author_id)
      GROUP BY id
    ),
    authors AS ( 
      SELECT S.id, array_to_string(array_agg(S.display_name), '|') AS authors
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
      WHERE T.id = A.id AND title_type = 'source'
    ),
    issn AS (
      SELECT A.id, identifier_value AS issn
      FROM wos_dynamic_identifiers AS I, matched_author_publications AS A
      WHERE I.id = A.id AND identifier_type = 'issn'
    ),
    eissn AS (
      SELECT A.id, identifier_value AS eissn
      FROM wos_dynamic_identifiers AS I, matched_author_publications AS A
      WHERE I.id = A.id AND identifier_type = 'eissn'
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
      A.id, A.author_id, source_authors, publication_year, title, authors, organizations, times_cited, journal, issn, eissn
    FROM
      matched_author_publications AS A 
      LEFT JOIN source_authors ON (source_authors.id = A.id)
      LEFT JOIN pubyear ON (pubyear.id = A.id)
      LEFT JOIN titles ON (titles.id = A.id)
      LEFT JOIN authors ON (authors.id = A.id)
      LEFT JOIN organizations ON (organizations.id = A.id)
      LEFT JOIN times_cited ON (times_cited.id = A.id)
      LEFT JOIN journals ON (journals.id = A.id)
      LEFT JOIN issn ON (issn.id = A.id)
      LEFT JOIN eissn ON (eissn.id = A.id);
    CREATE INDEX ON author_publications_export(author_id);

  DROP TABLE IF EXISTS author_publications_export_rollup;
  CREATE TABLE author_publications_export_rollup AS
    SELECT DISTINCT ON (id) id, source_authors, publication_year, title, authors, organizations, times_cited, journal, issn, eissn
    FROM author_publications_export;

  \COPY ( SELECT * FROM author_publications_export_rollup ) TO '${2}' Delimiter ',' CSV HEADER Encoding 'SQL-ASCII'
EOF
