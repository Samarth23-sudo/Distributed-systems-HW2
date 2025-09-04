#!/bin/bash
#SBATCH --job-name=matrix_scalability
#SBATCH --nodes=1
#SBATCH --ntasks=24
#SBATCH --time=00:15:00
#SBATCH --output=scalability_%j.txt
#SBATCH --error=scalability_error_%j.txt

module load openmpi/4.1.5

# Create larger test matrix (10x10)
cat > large_input.txt << MATRIX_EOF
10
4.00 7.00 2.00 1.00 3.00 5.00 2.00 8.00 1.00 4.00
3.00 6.00 1.00 2.00 4.00 7.00 3.00 1.00 5.00 2.00
2.00 5.00 3.00 1.00 6.00 2.00 4.00 3.00 7.00 1.00
1.00 2.00 4.00 5.00 1.00 3.00 6.00 2.00 4.00 8.00
5.00 1.00 2.00 3.00 7.00 4.00 1.00 6.00 2.00 3.00
6.00 3.00 1.00 4.00 2.00 8.00 5.00 1.00 3.00 7.00
2.00 4.00 6.00 1.00 3.00 5.00 9.00 2.00 1.00 4.00
8.00 1.00 3.00 2.00 6.00 1.00 2.00 7.00 4.00 5.00
1.00 5.00 7.00 4.00 2.00 3.00 1.00 4.00 8.00 2.00
4.00 2.00 1.00 8.00 3.00 7.00 4.00 5.00 2.00 6.00
MATRIX_EOF

# Store sequential result for comparison
echo "=== Computing Sequential Reference Result ==="
mpirun -np 1 ./matrix_inverse < large_input.txt > sequential_result.txt
echo "Sequential result stored for comparison"

# Test different process counts with comprehensive analysis
echo "=== Comprehensive Scalability Analysis ==="
echo "Matrix Size: 10x10"
echo "Test Date: $(date)"
echo "Node Info: $(uname -n)"
echo "Processor Info: $(nproc) cores available"
echo ""

# Header for results table
printf "%-10s %-12s %-12s %-12s %-12s %-15s %-10s\n" \
    "Processes" "Real_Time" "User_Time" "Sys_Time" "Speedup" "Efficiency(%)" "Correct"
echo "=================================================================================="

# Store sequential time for speedup calculation
seq_time=""

for np in 1 2 4 8 16 24; do
    echo "Testing with $np processes..."
    
    # Capture detailed timing
    start_time=$(date +%s.%N)
    { time mpirun -np $np ./matrix_inverse < large_input.txt > result_${np}.txt; } 2> time_${np}.txt
    end_time=$(date +%s.%N)
    
    # Calculate wall clock time
    wall_time=$(echo "$end_time - $start_time" | bc -l)
    
    # Extract timing info
    real_time=$(grep "real" time_${np}.txt | awk '{print $2}' | sed 's/[ms]//g')
    user_time=$(grep "user" time_${np}.txt | awk '{print $2}' | sed 's/[ms]//g')
    sys_time=$(grep "sys" time_${np}.txt | awk '{print $2}' | sed 's/[ms]//g')
    
    # Convert time to seconds if needed (handle m:s format)
    if [[ $real_time == *":"* ]]; then
        real_seconds=$(echo $real_time | awk -F: '{print $1*60 + $2}')
    else
        real_seconds=$real_time
    fi
    
    # Store sequential time for speedup calculation
    if [ $np -eq 1 ]; then
        seq_time=$real_seconds
    fi
    
    # Calculate speedup and efficiency
    if [ $np -eq 1 ]; then
        speedup="1.00"
        efficiency="100.00"
    else
        speedup=$(echo "scale=2; $seq_time / $real_seconds" | bc -l)
        efficiency=$(echo "scale=2; ($speedup / $np) * 100" | bc -l)
    fi
    
    # Check correctness by comparing with sequential result
    if diff -q result_${np}.txt sequential_result.txt > /dev/null; then
        correct="YES"
    else
        correct="NO"
    fi
    
    # Print results in table format
    printf "%-10d %-12.3f %-12s %-12s %-12.2f %-15.2f %-10s\n" \
        $np $real_seconds "$user_time" "$sys_time" $speedup $efficiency $correct
done

echo ""
echo "=== Detailed Analysis ==="

# Calculate optimal process count
echo "Performance Analysis:"
echo "- Sequential Time: ${seq_time}s"

# Find best speedup
best_speedup=0
best_np=1
for np in 2 4 8 16 24; do
    if [ -f "time_${np}.txt" ]; then
        real_time=$(grep "real" time_${np}.txt | awk '{print $2}' | sed 's/[ms]//g')
        if [[ $real_time == *":"* ]]; then
            real_seconds=$(echo $real_time | awk -F: '{print $1*60 + $2}')
        else
            real_seconds=$real_time
        fi
        current_speedup=$(echo "scale=2; $seq_time / $real_seconds" | bc -l)
        if (( $(echo "$current_speedup > $best_speedup" | bc -l) )); then
            best_speedup=$current_speedup
            best_np=$np
        fi
    fi
done

echo "- Best Speedup: ${best_speedup}x with ${best_np} processes"
echo "- Communication Overhead: Evident when efficiency drops below 80%"

# Show actual output samples
echo ""
echo "=== Correctness Verification ==="
echo "Sequential Result (first 3 rows):"
head -3 sequential_result.txt

echo ""
echo "Parallel Result with ${best_np} processes (first 3 rows):"
head -3 result_${best_np}.txt

# Show any differences if they exist
echo ""
echo "=== Output Verification ==="
for np in 2 4 8 16 24; do
    if [ -f "result_${np}.txt" ]; then
        if ! diff -q result_${np}.txt sequential_result.txt > /dev/null; then
            echo "WARNING: Result with $np processes differs from sequential!"
            echo "Differences:"
            diff result_${np}.txt sequential_result.txt | head -5
        fi
    fi
done

echo ""
echo "=== Resource Utilization ==="
echo "Memory Usage per Process (estimated):"
for np in 1 2 4 8 16 24; do
    # Estimate memory usage: O(n²) for matrix, distributed across processes
    memory_per_process=$(echo "scale=2; (10 * 10 * 8 * 2) / $np" | bc -l)
    echo "- $np processes: ~${memory_per_process} bytes per process"
done

echo ""
echo "=== Communication Analysis ==="
echo "Total MPI Communications per iteration:"
echo "- Broadcasts: $(echo "10 * 24" | bc) (n * max_processes)"
echo "- Point-to-Point: $(echo "2 * 23 * 10" | bc) (distribution + gathering)"
echo ""
echo "Test completed at $(date)"

