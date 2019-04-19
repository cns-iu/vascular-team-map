#!/bin/bash
source constants.sh
source db-config.sh
set -ev

bash src/extract-author-publications.sql.sh $OUT/authors-for-search.csv $OUT/author-publications-raw.csv
