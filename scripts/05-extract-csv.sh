#!/bin/bash
source constants.sh
set -ev

mkdir -p $OUT

OUT_PUBS="${OUT}/vascular-pubs.csv"
FOR_COAUTH="${OUT}/vascular-pubs.for-sci2-coauth.csv"
FOR_COAUTH_SHRINK="${OUT}/vascular-pubs.for-sci2-coauth-with-cites.csv"
FOR_SCIMAP="${OUT}/vascular-pubs.for-sci2-scimap.csv"
COOC_PROPS="${OUT}/vascular-pubs.coauth.properties"

# Merge all CSV files into a single CSV file and do some file cleanup for ease of loading into Sci2
python3 src/merge-publications.py $ORIG/author-data $OUT_PUBS

# Keep only Cites, Year, and Authors columns for even easier loading into Sci2 for coauthor
csvcut -x -e utf-8 -c Cites,Authors,Year $OUT_PUBS | perl -pe 's/\,\ /\|/g;s/\ \.\.\.//g;s/\|\.\.\.//g;s/…//g;' > $FOR_COAUTH

# Keep only pubs whic have at least one citation
grep -v -P '^0,' $FOR_COAUTH > $FOR_COAUTH_SHRINK

# Generate a .properties file for using Sci2's co-occurance network generator
cat > $COOC_PROPS << EOF
node.numberOfWorks = Authors.count
edge.numberOfCoAuthoredWorks = Authors.count
node.timesCited = Cites.sum
edge.timesCited = Cites.sum
node.minYear = Year.min
edge.minYear = Year.min
node.maxYear = Year.max
edge.maxYear = Year.max
EOF

# Keep only Source and Publisher columns for even easier loading into Sci2 for science mapping
csvcut -e utf-8 -c Source,Publisher $OUT_PUBS > $FOR_SCIMAP
