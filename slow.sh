#!/bin/bash

# Runs for N seconds
for i in {1..15}; do
  echo "Slow script running for $i seconds"
  sleep 1
done
echo "Slow script done"
