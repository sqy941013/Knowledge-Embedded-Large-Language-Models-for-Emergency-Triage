#!/bin/bash

# Specify the directory to process
input_dir="results"

# Iterate over all CSV files in the directory
for file in "$input_dir"/exp*.csv; do
    # Call the Python script and pass the file path as a parameter
    echo "Processing $file ..."
    python eval_new.py "$file"
done

echo "All files have been processed."
