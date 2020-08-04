# Vascular Team Map

A map of NAVBO team members and their evolution. This repository includes code to reproduce the workflows to get from raw data to visualizations.

## System Requirements

* bash
* python 3.6+
* [Sci2](https://sci2.cns.iu.edu/) v1.3
* [GEPHI](https://gephi.org/) (optional)
* sqlite3

## Running the workflow

The [scripts](scripts) directory has a set of bash scripts numbered in the order they should executed.

You can run the full workflow from end to end using the [run.sh](run.sh) file in the root directory.

## Data

Publication data was collected for 502 members of North American Vascular Biology Organization (NAVBO) using Harzing's Publish or Perish software [Harzing, A.W. (2007) Publish or Perish, available from https://harzing.com/resources/publish-or-perish] by entering name of each member and exporting each member's publication data into a csv file which can be found in data/original data folder. Publication data of all members is then merged into a single csv file 'vascular-pubs.csv' by running the scripts found in script folder. After running all the scripts, 'vascular-pubs.for-sci2-cleaned-scimap.csv' is used for creating map of science and 'vascular-pubs.for-sci2-coauth-using-title+year+source.csv' is used for creating a co-author network.
