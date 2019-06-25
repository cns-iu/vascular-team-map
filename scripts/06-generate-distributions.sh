#!/bin/bash
source constants.sh
set -ev

python src/get-distributions.py $OUT/vascular-pubs.csv $OUT
