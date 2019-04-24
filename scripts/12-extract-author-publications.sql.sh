#!/bin/bash
source constants.sh
source db-config.sh
set -ev

out=$OUT/author-publications-raw.csv

psql << EOF
  \COPY ( SELECT * FROM $s.author_publications_export_rollup ORDER BY publication_year DESC ) TO '${out}' Delimiter ',' CSV HEADER Encoding 'SQL-ASCII'
EOF
