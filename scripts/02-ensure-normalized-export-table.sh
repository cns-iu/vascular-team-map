#!/bin/bash
source constants.sh
source db-config.sh
set -ev

table_exists=$(
  psql --no-align --tuples-only --field-separator ' ' << EOF
    SELECT EXISTS (
      SELECT 1
      FROM information_schema.tables 
      WHERE table_schema = 'public' AND table_name = 'wosx_publications_export'
    );
EOF
);

if [ "$table_exists" == 't' ] && [ ! "$1" == 'clean' ]; then
  echo Normalized export table already exists
  exit
fi

psql << EOF
  DROP SCHEMA IF EXISTS export_temp;
  CREATE SCHEMA export_temp;
  
  CREATE TABLE export_temp.authors AS
    SELECT id, array_to_string(array_agg(display_name), '|') AS authors, array_to_string(array_agg(wos_standard), '|') AS normalized_authors
    FROM wos_summary_names AS S
    WHERE role = 'author'
    GROUP BY id;
  CREATE UNIQUE INDEX ON export_temp.authors(id);

  CREATE TABLE export_temp.titles AS
    SELECT DISTINCT ON(id) id, title
    FROM wos_titles
    WHERE title_type = 'item';
  CREATE UNIQUE INDEX ON export_temp.titles(id);

  CREATE TABLE export_temp.organizations AS
    SELECT id, array_to_string(array_agg(organization), '|') AS organizations
    FROM wos_address_organizations
    WHERE org_id = 1
    GROUP BY id;
  CREATE UNIQUE INDEX ON export_temp.organizations(id);

  CREATE TABLE export_temp.journals AS
    SELECT DISTINCT ON(id) id, title AS journal
    FROM wos_titles
    WHERE title_type = 'source';
  CREATE UNIQUE INDEX ON export_temp.journals(id);

  CREATE TABLE export_temp.issn AS
    SELECT DISTINCT ON(id) id, identifier_value AS issn
    FROM wos_dynamic_identifiers
    WHERE identifier_type = 'issn';
  CREATE UNIQUE INDEX ON export_temp.issn(id);

  CREATE TABLE export_temp.eissn AS
    SELECT DISTINCT ON(id) id, identifier_value AS eissn
    FROM wos_dynamic_identifiers
    WHERE identifier_type = 'eissn';
  CREATE UNIQUE INDEX ON export_temp.eissn(id);

  CREATE TABLE export_temp.pubyear AS
    SELECT DISTINCT ON(id) id, pubyear::integer as publication_year
    FROM wos_summary;
  CREATE UNIQUE INDEX ON export_temp.pubyear(id);

  CREATE TABLE export_temp.times_cited AS
    SELECT DISTINCT ON(id) id, wos_total as times_cited
    FROM wos_times_cited;
  CREATE UNIQUE INDEX ON export_temp.times_cited(id);

  DROP TABLE IF EXISTS wosx_publications_export;

  CREATE TABLE wosx_publications_export AS
    SELECT 
      A.id, publication_year, title, authors, organizations, times_cited, journal, issn, eissn
    FROM
      export_temp.pubyear AS A
      LEFT JOIN export_temp.titles ON (export_temp.titles.id = A.id)
      LEFT JOIN export_temp.authors ON (export_temp.authors.id = A.id)
      LEFT JOIN export_temp.organizations ON (export_temp.organizations.id = A.id)
      LEFT JOIN export_temp.times_cited ON (export_temp.times_cited.id = A.id)
      LEFT JOIN export_temp.journals ON (export_temp.journals.id = A.id)
      LEFT JOIN export_temp.issn ON (export_temp.issn.id = A.id)
      LEFT JOIN export_temp.eissn ON (export_temp.eissn.id = A.id);

  COMMENT ON TABLE wosx_publications_export IS 'Normalized publication export table';

  ALTER TABLE ONLY wosx_publications_export
    ADD CONSTRAINT fk_wosx_publications_export FOREIGN KEY (id) REFERENCES wos_summary(id) ON DELETE CASCADE;
  ALTER TABLE ONLY wosx_publications_export
    ADD CONSTRAINT idx_wosx_publications_export UNIQUE (id);

  GRANT ALL ON TABLE wosx_publications_export TO postgres;
  GRANT ALL ON VIEW wosx_publications_export_view TO postgres;

  DROP SCHEMA export_temp;
EOF
