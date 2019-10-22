#!/bin/bash
source constants.sh
set -ev

DB="${OUT}/vascular-pubs.sqlite3"

rm -f $DB
sqlite3 $DB .quit

csvsql --db "sqlite:///$DB" $OUT/vascular-pubs.csv --tables 'vascular_pubs' --insert
csvsql --db "sqlite:///$DB" $OUT/vascular-pubs.for-sci2-coauth-using-title+year+source.csv --tables 'vascular_coauth_pubs' --insert

sqlite3 $DB << EOF
DROP TABLE IF EXISTS vascular_author_pubs;
CREATE TABLE vascular_author_pubs (
  SrcAuthor VARCHAR,
  Cites INTEGER,
  Year Integer
);
INSERT INTO vascular_author_pubs
  WITH RECURSIVE neat(
      id, author, etc
    ) AS (
      SELECT
        rowid
        , ''
        , authors || '|'
      FROM vascular_coauth_pubs
      WHERE rowid
      UNION ALL

      SELECT 
        id
        , SUBSTR(etc, 0, INSTR(etc, '|'))
        , SUBSTR(etc, INSTR(etc, '|')+1)
      FROM neat
      WHERE etc <> ''
    )
    -- SELECT from the recursive table ----------------------
    SELECT author as SrcAuthor, Cites, Year
    FROM neat JOIN vascular_coauth_pubs P ON (neat.id = P.rowid)
    WHERE author <> ''
    ORDER BY id ASC, author ASC;
EOF

sqlite3 $DB << EOF
DROP TABLE IF EXISTS vascular_stats;
CREATE TABLE vascular_stats (
  Statistic, Result
);
INSERT INTO vascular_stats
  SELECT 'Num Authors' L, count(distinct(SrcAuthor)) C FROM vascular_author_pubs WHERE Year >= 1990
  UNION
  SELECT 'Num Papers' L, sum(Year_1990to2019) C FROM vascular_coauth_pubs WHERE Year >= 1990
  UNION
  SELECT 'Num Cites' L, sum(Cites_1990to2019) C FROM vascular_coauth_pubs WHERE Year >= 1990
  UNION
  SELECT 'Num Zero Cites' L, count(*) C FROM vascular_coauth_pubs WHERE Cites_1990to2019 = 0 AND Year >= 1990
  UNION
  SELECT 'Most Prolific Author' L, SrcAuthor || ' - #Papers ' || Papers || ', #Cites ' || Cites C FROM (
    SELECT SrcAuthor, count(*) AS Papers, sum(Cites) Cites 
    FROM vascular_author_pubs WHERE Year >= 1990 
    GROUP BY SrcAuthor  ORDER BY Cites DESC LIMIT 1
  ) a
  UNION
  SELECT 'Num Authors < 10 pubs', count(*) C FROM (
    SELECT SrcAuthor, count(*) Papers FROM vascular_author_pubs WHERE Year >= 1990 GROUP BY SrcAuthor
  ) a
  WHERE Papers < 10
EOF

sqlite3 $DB > $OUT/vascular_stats.csv << EOF
.headers ON
.mode csv
SELECT * FROM vascular_stats ORDER BY Statistic ASC;
EOF
