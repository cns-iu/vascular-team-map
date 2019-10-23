#!/bin/bash
source constants.sh
set -ev

OUT_PUBS="${OUT}/vascular-pubs.csv"

mkdir -p $OUT/for-pubvis

python3 src/recode-authors.py $OUT_PUBS $OUT/for-pubvis/pop-extract.csv Title,Year,Source
