import altair, sys, pandas
from altair import datum
from csv import DictReader
from os.path import join

IN_CSV=sys.argv[1]
OUT_DIR=sys.argv[2]

data = pandas.read_csv(IN_CSV)

authorCount = altair.Chart(data).mark_bar().encode(
  altair.X('AuthorCount:O'),
  y = 'count()'
).properties(
  width = 500,
  height = 500
)

numCites = altair.Chart(data).mark_point().encode(
  altair.X('Cites:Q', scale=altair.Scale(type='log')),
  altair.Y('count(*):Q', scale=altair.Scale(type='log')),
  # color=altair.Color('average(AuthorCount):Q', bin=True),
  opacity=altair.value(0.5)
).transform_filter(
  (datum.Cites > 0)
).properties(
  width = 900,
  height = 500
)

combined = altair.vconcat(authorCount, numCites)

authorCount.save(join(OUT_DIR, 'AuthorCount.distribution.png'), webdriver='firefox')
numCites.save(join(OUT_DIR, 'Cites.distribution.png'), webdriver='firefox')

authorCount.save(join(OUT_DIR, 'AuthorCount.distribution.svg'), webdriver='firefox')
numCites.save(join(OUT_DIR, 'Cites.distribution.svg'), webdriver='firefox')

# altair.Chart(data).mark_area(
#   opacity=0.5
# ).encode(
#   altair.X('Cites:Q', bin=altair.Bin(maxbins=150)),
#   altair.Y('count(*):Q', scale=altair.Scale(type='log'))
# ).serve()
