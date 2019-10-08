shopt -s expand_aliases

TS="2019-10-08"             # Timestamp
ORIG=raw-data/original      # Raw CSV Data
OUT=raw-data/derived/$TS    # Where to place the generated data
mkdir -p $ORIG $OUT

source env.sh
