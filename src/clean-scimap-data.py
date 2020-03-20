import sys, csv, re
from pprint import pprint

IN_CSV = sys.argv[1]
OUT_CSV = sys.argv[2]

with open(IN_CSV,'r') as f:
    reader = csv.DictReader(f)
    year = []; publisher = []; journals = []
    for row in reader:
        journals.extend([row['Source'].replace('…','')])
        year.extend([row['Year']])
        publisher.extend([row['Publisher']])
#pprint(journals[:1000])    

# Cleaning data like removing special characters
for i in range(len(journals)):
    journals[i] = re.sub('[0-9]*\xa0', '', journals[i])
    journals[i] = re.sub(r'\\x[a-z0-9][a-z0-9]', '', journals[i])
    journals[i] = re.sub('\W+', ' ', journals[i]).strip()
    if re.sub('[0-9]+','',journals[i]).strip() == '':
        journals[i] = ''

#pprint(journals[1000:1050])

# Writing cleaned to a new csv file
with open(OUT_CSV,'w') as f2:
    writer = csv.writer(f2)
    writer.writerow(['Source','Publisher','Year'])
    for i in range(len(journals)):
        writer.writerow([journals[i],publisher[i],year[i]])