import sys, csv
from pathlib import Path

IN_DIR = sys.argv[1]
OUT_CSV = sys.argv[2]

with open(OUT_CSV, 'w') as out_f:
  out = csv.writer(out_f)

  header = None
  for filename in Path(IN_DIR).glob('**/*.csv'):
    author = ' '.join(filename.name.split()[:-1])

    with open(filename, mode='r', encoding='utf-8-sig') as in_csv:
      pubs = list(csv.reader(x.replace('\0', '') for x in in_csv))
      if not header:
        header = pubs[0]
        out.writerow(['SrcAuthor'] + pubs[0])

      for pub in pubs[1:]:
        out.writerow([author] + pub)
