import sys
from collections import Counter
from csv import DictReader, writer

IN_CSVs = sys.argv[1:-1]
OUT_CSV = sys.argv[-1]


def clean(s):
  """strips out extraneous spaces, commas, and periods from a string"""
  return s.replace('.', '').replace(',', '').strip()

authors = Counter()
for csvFile in IN_CSVs:
  # Go through each CSV and extract authors
  for row in DictReader(open(csvFile)):
    # Extract and clean the data fields we are interested in
    record = [
      clean(row.get('First', '')),
      clean(row.get('MI', '')),
      clean(row.get('Last', '')),
      row.get('E-Mail', '').strip().lower()
    ]

    # If the first name contains the middle name elements,
    # extract those to the separate middle name slot.
    if record[1] == '' and ' ' in record[0]:
      first, middle = record[0].split(None, 1)

      # If the middle name has two initials, combine them
      if len(middle) == 3 and middle[1] == ' ':
        middle = middle.replace(' ', '')
      
      # Remove american names that fell into middle name slot
      if middle[0] + middle[-1] == '()':
        middle = ''

      record[0] = first
      record[1] = middle

    authors[tuple(record)]+=1

with open(OUT_CSV, 'w') as outStream:
  out = writer(outStream, lineterminator='\n')
  out.writerow(('author_id', 'first', 'middle', 'last', 'email'))
  for aid, record in enumerate(sorted(authors, key=lambda x: x[2]), 1):
    out.writerow(tuple([aid])+record)
