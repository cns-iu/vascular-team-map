import sys, csv
from collections import defaultdict

IN_CSV = sys.argv[1]
OUT_CSV = sys.argv[2]
JOIN_FIELDS = sys.argv[3].split(',')

with open(IN_CSV) as in_f:
  reader = csv.DictReader(in_f)

  x2cites = {}
  x2authors = defaultdict(set)

  for pub in reader:
    joiner = '|'.join([ pub[f] for f in JOIN_FIELDS ])
    x2cites[joiner] = pub['Cites']
    x2authors[joiner].add(pub['SrcAuthor'])
  
  with open(OUT_CSV, 'w') as out_f:
    out = csv.writer(out_f)
    out.writerow(['Cites','Authors'])

    for (joiner, cites) in x2cites.items():
      authors = '|'.join(x2authors[joiner])
      if len(authors) > 0:
        out.writerow([cites, authors])
