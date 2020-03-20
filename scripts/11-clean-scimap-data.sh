#!/usr/bin/env python3

source constants.sh
set -ev

python3 src/clean-scimap-data.py $OUT/vascular-pubs.for-sci2-scimap.csv $OUT/vascular-pubs.for-sci2-cleaned-scimap.csv
