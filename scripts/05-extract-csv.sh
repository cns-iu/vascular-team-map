#!/bin/bash
source constants.sh
set -ev

mkdir -p $OUT

OUT_PUBS="${OUT}/vascular-pubs.csv"
FOR_SCI2="${OUT}/vascular-pubs.for-sci2-coauth.csv"
FOR_SCIMAP="${OUT}/vascular-pubs.for-sci2-scimap.csv"
COOC_PROPS="${OUT}/vascular-pubs.coauth.properties"

# Merge all CSV files into a single CSV file and do some file cleanup for ease of loading into Sci2
head -1 $ORIG/author-data/'Zorina Galis  5-15-19.csv' | perl -CSD -pe 's/^\x{feff}//' > $OUT_PUBS
find $ORIG/author-data -name '*.csv' -exec tail -n +2 {} \; | tr -d '\000' >> $OUT_PUBS

# Keep only Cites and Authors columns for even easier loading into Sci2 for coauthor
csvcut -x -e utf-8 -c 1,2 $OUT_PUBS | perl -pe 's/\,\ /\|/g;s/\ \.\.\.//g;s/\|\.\.\.//g;s/…//g;' > $FOR_SCI2

# Generate a .properties file for using Sci2's co-occurance network generator
cat > $COOC_PROPS << EOF
node.numberOfWorks = Authors.count
edge.numberOfCoAuthoredWorks = Authors.count
node.timesCited = Cites.sum
EOF

# Keep only Source and Publisher columns for even easier loading into Sci2 for science mapping
csvcut -e utf-8 -c Source,Publisher $OUT_PUBS > $FOR_SCIMAP
