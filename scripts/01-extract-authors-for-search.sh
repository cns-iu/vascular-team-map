#!/bin/bash
source constants.sh
set -ev

python src/extract_authors_for_search.py $ORIG/*.csv $OUT/authors-for-search.csv
python src/extract_authors_for_wos_query.py $OUT/authors-for-search.csv $OUT/authors-for-wos-query.txt
