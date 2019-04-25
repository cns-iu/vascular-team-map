#!/bin/bash
source constants.sh
source db-config.sh
set -ev

table_exists=$(
  psql --no-align --tuples-only --field-separator ' ' << EOF
    SELECT EXISTS (
      SELECT 1
      FROM information_schema.tables 
      WHERE table_schema = 'public' AND table_name = 'wosx_publication_export'
    );
EOF
);

if [ "$table_exists" == 't' ] && [ ! "$1" == 'clean' ]; then
  echo Normalized export table already exists
  exit
fi

psql << EOF
  DROP VIEW IF EXISTS wosx_publication_export_view;

  CREATE VIEW wosx_publication_export_view AS
    WITH authors AS ( 
      SELECT id, array_to_string(array_agg(display_name), '|') AS authors
      FROM wos_summary_names AS S
      WHERE role = 'author'
      GROUP BY id
    ),
    titles AS (
      SELECT DISTINCT ON(id) id, title
      FROM wos_titles
      WHERE title_type = 'item' 
    ),
    organizations AS ( 
      SELECT id, array_to_string(array_agg(organization), '|') AS organizations
      FROM wos_address_organizations
      WHERE org_id = 1
      GROUP BY id
    ),
    journals AS (
      SELECT DISTINCT ON(id) id, title AS journal
      FROM wos_titles
      WHERE title_type = 'source'
    ),
    issn AS (
      SELECT DISTINCT ON(id) id, identifier_value AS issn
      FROM wos_dynamic_identifiers
      WHERE identifier_type = 'issn'
    ),
    eissn AS (
      SELECT DISTINCT ON(id) id, identifier_value AS eissn
      FROM wos_dynamic_identifiers
      WHERE identifier_type = 'eissn'
    ),
    pubyear as (
      SELECT DISTINCT ON(id) id, pubyear::integer as publication_year
      FROM wos_summary
    ),
    times_cited as (
      SELECT DISTINCT ON(id) id, wos_total as times_cited
      FROM wos_times_cited
    )
    SELECT 
      A.id, publication_year, title, authors, organizations, times_cited, journal, issn, eissn
    FROM
      pubyear AS A
      LEFT JOIN titles ON (titles.id = A.id)
      LEFT JOIN authors ON (authors.id = A.id)
      LEFT JOIN organizations ON (organizations.id = A.id)
      LEFT JOIN times_cited ON (times_cited.id = A.id)
      LEFT JOIN journals ON (journals.id = A.id)
      LEFT JOIN issn ON (issn.id = A.id)
      LEFT JOIN eissn ON (eissn.id = A.id);

  DROP TABLE IF EXISTS wosx_publication_export;

  CREATE TABLE wosx_publication_export (
    id character varying NOT NULL,
    publication_year integer,
    title character varying,
    authors character varying,
    organizations character varying,
    times_cited integer,
    journal character varying,
    issn character varying,
    eissn character varying
  );

  COMMENT ON TABLE wosx_publication_export IS 'Normalized publication export table. Generated from the VIEW: wosx_publication_export_view';

  INSERT INTO wosx_publication_export SELECT * FROM wosx_publication_export_view;

  ALTER TABLE ONLY wosx_publication_export
    ADD CONSTRAINT fk_wosx_publication_export FOREIGN KEY (id) REFERENCES wos_summary(id) ON DELETE CASCADE;
  ALTER TABLE ONLY wosx_publication_export
    ADD CONSTRAINT idx_wosx_publication_export UNIQUE (id);

  GRANT ALL ON TABLE wosx_publication_export TO postgres;
  GRANT ALL ON VIEW wosx_publication_export_view TO postgres;
EOF
