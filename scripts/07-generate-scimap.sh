#!/bin/bash
source constants.sh
set -ev

if [ ! -e $OUT/vascular-pubs.scimap.ps ]
then
  read -p "Press Enter when $OUT/vascular-pubs.scimap.ps is created..."
fi

ps2pdf $OUT/vascular-pubs.scimap.ps $OUT/vascular-pubs.scimap.pdf
pdftocairo -f 1 -l 1 -png -singlefile $OUT/vascular-pubs.scimap.pdf $OUT/vascular-pubs.scimap
