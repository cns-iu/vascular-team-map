#!/bin/bash

psql -h dbdev.cns.iu.edu -d wos_2017 -c "\i 02-extract-author-publications.sql"
