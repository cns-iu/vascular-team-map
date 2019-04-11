#!/bin/bash
source constants.sh
set -ev

python src/extract_authors_for_search.py $ORIG/*.csv $OUT/authors-for-search.csv
