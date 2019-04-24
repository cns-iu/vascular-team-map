shopt -s expand_aliases

ORIG=./data/original
OUT=./data/derived/2019-04-11
mkdir -p $ORIG $OUT

SCHEMA=${SCHEMA-vascular}
s=$SCHEMA # A shortened form sql-scripts

MINYEAR=${MINYEAR-1989}
