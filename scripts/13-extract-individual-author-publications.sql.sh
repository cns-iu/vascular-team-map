#!/bin/bash
source constants.sh
source db-config.sh
set -ev

dir=$OUT/publications-by-author
mkdir -p $dir

psql --no-align --tuples-only --field-separator ' ' -c "SELECT author_id, replace(lower(first_name || ' ' || last_name), ' ', '-') AS name FROM $s.authors_for_search" | while read author_id name
do

echo $author_id $name
psql << EOF

  CREATE TEMPORARY VIEW author_export AS
    SELECT id, source_authors, publication_year, title, authors, organizations, times_cited, journal, issn, eissn
    FROM $s.author_publications_export
    WHERE author_id = '${author_id}';

  \COPY (SELECT * FROM author_export) TO '${dir}/${author_id}-${name}-publications.csv' Delimiter ',' CSV HEADER Encoding 'SQL-ASCII'

EOF

done
