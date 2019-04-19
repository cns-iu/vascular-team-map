from csv import DictReader
import sys

INPUT=sys.argv[1]
OUTPUT=sys.argv[2]

authors = []
for author in DictReader(open(INPUT)):
  last = author['last'].upper()
  first = author['first'][0].upper()
  middle = author['middle'][0].upper() if len(author['middle']) > 0 else ''
  middle = '*' # do a wildcard search instead of searching middle name

  au = "AU=({0} {1}{2})".format(last, first, middle)
  authors.append(au)

query = " OR\n".join(authors)
open(OUTPUT, 'w').write(query)
