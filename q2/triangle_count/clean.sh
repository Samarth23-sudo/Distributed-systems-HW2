#!/bin/bash
# Cleanup script for triangle counting pipeline
# Deletes all intermediate .txt files but keeps Python scripts and SLURM scripts

echo "Cleaning up intermediate txt files..."

# Remove common intermediate files
rm -f  edges_part_* edges2_part_* edges3_part_* adj_part_* red*_part_* \
      *.map *.out *.err *.wedges *.edges combined.txt map*_all_sorted.txt \
      increments.txt adj_out.txt deg_out.txt triangle_count.out triangle_count.err final.txt wedges.txt edges_mapped.txt part-*.txt part-*.txt.sorted

echo "Cleanup complete!"

