import sys, csv
from collections import defaultdict

IN_CSV = sys.argv[1]
OUT_CSV = sys.argv[2]
JOIN_FIELDS = sys.argv[3].split(',')
MIN_YEAR = 1990

with open(IN_CSV) as in_f:
  reader = csv.DictReader(in_f)

  x2row = {}
  x2authors = defaultdict(set)

  for pub in reader:
    joiner = '|'.join([ pub[f] for f in JOIN_FIELDS ])
    x2row[joiner] = pub
    x2authors[joiner].add(pub['SrcAuthor'])
  
  with open(OUT_CSV, 'w') as out_f:
    out = csv.writer(out_f)
    header = None

    for (joiner, row) in x2row.items():
      if header == None:
        header = row.keys()
        out.writerow(header)

      authors = ', '.join(x2authors[joiner])
      year = row['Year']
      if len(authors) > 0 and year.isdigit() and int(year) >= MIN_YEAR:
        row['Authors'] = authors
        out.writerow([row[f] for f in header])
