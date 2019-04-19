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

  -- CREATE INDEX wos_summary_names_email_addr_email_search_idx ON wos_summary_names_email_addr(lower(email_addr), id);
  -- CREATE INDEX wos_summary_names_lastn_search_idx ON wos_summary_names(lower(last_name), first_name, id);

  DROP TABLE IF EXISTS matched_author_publications;

  CREATE TABLE matched_author_publications AS (
      SELECT K.id, 'email'::text AS matched_by
      FROM wos_summary_names_email_addr AS K, authors_for_search AS A
      WHERE lower(K.email_addr) = lower(A.email_address)
  );

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
      SELECT A.id, T.title AS titles
      FROM wos_titles AS T, matched_author_publications AS A
      WHERE T.id = A.id AND T.title_type = 'item' 
    ), 
    affiliations AS ( 
      SELECT A.id, array_to_string(array_agg(O.organization), '|') AS affiliated 
      FROM wos_address_organizations AS O, matched_author_publications AS A 
      WHERE O.id = A.id AND O.org_id = 1
      GROUP BY A.id
    ),
    journals AS (
      SELECT A.id, T.title AS journal
      FROM wos_titles AS T, matched_author_publications AS A
      WHERE title_type='source' AND T.id = A.id
    ),
    issn AS (
      SELECT A.id, identifier_value AS issns 
      FROM wos_dynamic_identifiers AS I, matched_author_publications AS A
      WHERE identifier_type='issn' AND I.id = A.id
    ),
    eissn AS (
      SELECT A.id, identifier_value AS eissns
      FROM wos_dynamic_identifiers AS I, matched_author_publications AS A
      WHERE identifier_type='eissn' AND I.id = A.id
    )
    SELECT DISTINCT A.id, 
      wos_summary.pubyear, titles.titles, authors.author, affiliations.affiliated, 
      wos_times_cited.wos_total AS times_cited, journals.journal, issn.issns, eissn.eissns
    FROM matched_author_publications AS A,
      wos_summary, titles, authors, affiliations, wos_times_cited, journals, issn, eissn
    WHERE titles.id = A.id AND authors.id = A.id AND titles.id = A.id AND 
      affiliations.id = A.id AND journals.id = A.id AND issn.id = A.id AND 
      eissn.id = A.id AND wos_times_cited.id = A.id AND wos_summary.id = A.id;

  \COPY ( SELECT * FROM author_publications_export ) TO '${2}' Delimiter ',' CSV HEADER Encoding 'SQL-ASCII'

EOF
