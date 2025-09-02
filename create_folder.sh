#!/bin/bash

planes=(2 3)             # plane indices
bitrates=(1 2 4 8)         # in Mbps

for p in "${planes[@]}"; do
  for b in "${bitrates[@]}"; do
    dirname="dataset/cave${p}_${b}mbps"
    mkdir -p "$dirname"
    echo "Created $dirname"
  done
done