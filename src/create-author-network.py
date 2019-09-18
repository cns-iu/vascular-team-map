import sys, csv
from collections import defaultdict

IN_CSV = sys.argv[1]
OUT_CSV = sys.argv[2]
JOIN_FIELDS = sys.argv[3].split(',')
TIME_SLICES = [(1990, 1994), (1990, 2004), (1990, 2019)]

with open(IN_CSV) as in_f:
  reader = csv.DictReader(in_f)

  x2cites = {}
  x2year = {}
  x2authors = defaultdict(set)

  for pub in reader:
    joiner = '|'.join([ pub[f] for f in JOIN_FIELDS ])
    x2cites[joiner] = pub['Cites']
    x2year[joiner] = pub['Year']
    x2authors[joiner].add(pub['SrcAuthor'])
  
  with open(OUT_CSV, 'w') as out_f:
    out = csv.writer(out_f)
    header = ['Cites','Authors','Year']
    for (minYr, maxYr) in TIME_SLICES:
      header.append(f'Year_{minYr}to{maxYr}')
      header.append(f'Cites_{minYr}to{maxYr}')
    out.writerow(header)

    for (joiner, cites) in x2cites.items():
      authors = '|'.join(x2authors[joiner])
      year = x2year[joiner]
      if len(authors) > 0 and year.isdigit():
        row = [cites, authors, year]
        year = int(year)
        for (minYr, maxYr) in TIME_SLICES:
          in_slice = year >= minYr and year <= maxYr
          row.append(1 if in_slice else 0)
          row.append(cites if in_slice else 0)

        out.writerow(row)

with open(OUT_CSV+'.sci2.properties', 'w') as out:
  props = '''node.numberOfWorks = Authors.count
edge.numberOfCoAuthoredWorks = Authors.count
node.timesCited = Cites.sum
edge.timesCited = Cites.sum
node.minYear = Year.min
edge.minYear = Year.min
node.maxYear = Year.max
edge.maxYear = Year.max
'''
  for (minYr, maxYr) in TIME_SLICES:
    props += f'''node.numberOfWorks{minYr}to{maxYr} = Year_{minYr}to{maxYr}.sum
edge.numberOfCoAuthoredWorks{minYr}to{maxYr} = Year_{minYr}to{maxYr}.sum
node.timesCited{minYr}to{maxYr} = Cites_{minYr}to{maxYr}.sum
edge.timesCited{minYr}to{maxYr} = Cites_{minYr}to{maxYr}.sum
'''
  out.write(props)