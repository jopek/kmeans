#!/bin/bash

INF=$1
OUTF=$2
TERM=${OUTF##*.}

gnuplot << EOF
set terminal $TERM
set output "$OUTF"

set key above
p "< grep '^S' $INF" usi 2:3:4 lc variable,\
  "< grep '^IC' $INF" usi 3:4:2 with labels font "monospace" textcolor rgbcolor "#aaaaaa",\
  "< grep '^C' $INF" usi 3:4:2 with labels

EOF

