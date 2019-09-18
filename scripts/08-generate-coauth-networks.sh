#!/bin/bash
source constants.sh
set -ev

OUT_PUBS="${OUT}/vascular-pubs.csv"

python3 src/create-author-network.py $OUT_PUBS $OUT/vascular-pubs.for-sci2-coauth-using-title.csv Title
python3 src/create-author-network.py $OUT_PUBS $OUT/vascular-pubs.for-sci2-coauth-using-title+year.csv Title,Year
python3 src/create-author-network.py $OUT_PUBS $OUT/vascular-pubs.for-sci2-coauth-using-title+year+source.csv Title,Year,Source
