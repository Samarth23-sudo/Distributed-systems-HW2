#include <iostream>
#include <vector>
#include <iomanip>
#include <cmath>
#include <mpi.h>

using namespace std;

class MPIMatrixInverter {
private:
    int n;
    vector<vector<double>> augmented;
    int rank, size;
    int rows_per_process;
    int start_row, end_row;
    
public:
    MPIMatrixInverter(int matrix_size, int proc_rank, int proc_size) 
        : n(matrix_size), rank(proc_rank), size(proc_size) {
        
        // Calculate workload distribution
        rows_per_process = n / size;
        int remainder = n % size;
        
        start_row = rank * rows_per_process + min(rank, remainder);
        end_row = start_row + rows_per_process + (rank < remainder ? 1 : 0);
        
        // Only allocate memory for the rows this process handles
        if (rank == 0) {
            // Process 0 holds the entire matrix for coordination
            augmented.resize(n, vector<double>(2 * n, 0.0));
        } else {
            // Other processes only need their assigned rows
            augmented.resize(end_row - start_row, vector<double>(2 * n, 0.0));
        }
    }
    
    void readMatrix() {
        if (rank == 0) {
            // Only process 0 reads the input
            for (int i = 0; i < n; i++) {
                for (int j = 0; j < n; j++) {
                    cin >> augmented[i][j];
                }
                // Initialize identity matrix part
                augmented[i][n + i] = 1.0;
            }
        }
    }
    
    void distributeMatrix() {
        if (rank == 0) {
            // Send relevant rows to other processes
            for (int proc = 1; proc < size; proc++) {
                int proc_start = proc * rows_per_process + min(proc, n % size);
                int proc_end = proc_start + rows_per_process + (proc < (n % size) ? 1 : 0);
                
                for (int i = proc_start; i < proc_end; i++) {
                    MPI_Send(&augmented[i][0], 2 * n, MPI_DOUBLE, proc, i, MPI_COMM_WORLD);
                }
            }
        } else {
            // Receive assigned rows from process 0
            for (int i = 0; i < end_row - start_row; i++) {
                augmented[i].resize(2 * n);
                MPI_Recv(&augmented[i][0], 2 * n, MPI_DOUBLE, 0, start_row + i, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
            }
        }
    }
    
    void gaussJordanElimination() {
        vector<double> pivot_row(2 * n);
        
        for (int pivot_col = 0; pivot_col < n; pivot_col++) {
            int pivot_owner = findPivotOwner(pivot_col);
            
            // Get the pivot row
            if (rank == pivot_owner) {
                int local_row = pivot_col - start_row;
                double pivot = augmented[local_row][pivot_col];
                
                // Normalize the pivot row
                for (int j = 0; j < 2 * n; j++) {
                    augmented[local_row][j] /= pivot;
                    pivot_row[j] = augmented[local_row][j];
                }
            }
            
            // Broadcast the pivot row to all processes
            MPI_Bcast(&pivot_row[0], 2 * n, MPI_DOUBLE, pivot_owner, MPI_COMM_WORLD);
            
            // Each process eliminates its assigned rows
            for (int i = 0; i < end_row - start_row; i++) {
                int global_row = start_row + i;
                if (global_row != pivot_col) {
                    double factor = augmented[i][pivot_col];
                    for (int j = 0; j < 2 * n; j++) {
                        augmented[i][j] -= factor * pivot_row[j];
                    }
                }
            }
        }
    }
    
    int findPivotOwner(int pivot_col) {
        // Determine which process owns the pivot row
        int cumulative_rows = 0;
        for (int proc = 0; proc < size; proc++) {
            int proc_rows = rows_per_process + (proc < (n % size) ? 1 : 0);
            if (pivot_col < cumulative_rows + proc_rows) {
                return proc;
            }
            cumulative_rows += proc_rows;
        }
        return 0; // Should never reach here
    }
    
    void gatherResult() {
        if (rank == 0) {
            // Collect results from other processes
            for (int proc = 1; proc < size; proc++) {
                int proc_start = proc * rows_per_process + min(proc, n % size);
                int proc_end = proc_start + rows_per_process + (proc < (n % size) ? 1 : 0);
                
                for (int i = proc_start; i < proc_end; i++) {
                    MPI_Recv(&augmented[i][0], 2 * n, MPI_DOUBLE, proc, i, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
                }
            }
        } else {
            // Send results back to process 0
            for (int i = 0; i < end_row - start_row; i++) {
                MPI_Send(&augmented[i][0], 2 * n, MPI_DOUBLE, 0, start_row + i, MPI_COMM_WORLD);
            }
        }
    }
    
    void printInverse() {
        if (rank == 0) {
            cout << fixed << setprecision(2);
            
            // Print the inverse matrix (right half of augmented matrix)
            for (int i = 0; i < n; i++) {
                for (int j = n; j < 2 * n; j++) {
                    cout << augmented[i][j];
                    if (j < 2 * n - 1) cout << " ";
                }
                cout << endl;
            }
        }
    }
};

int main(int argc, char* argv[]) {
    // Initialize MPI
    MPI_Init(&argc, &argv);
    
    int rank, size;
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);
    
    int n;
    
    // Only process 0 reads the matrix size
    if (rank == 0) {
        cin >> n;
    }
    
    // Broadcast matrix size to all processes
    MPI_Bcast(&n, 1, MPI_INT, 0, MPI_COMM_WORLD);
    
    // Create the MPI matrix inverter
    MPIMatrixInverter inverter(n, rank, size);
    
    // Read and distribute the matrix
    inverter.readMatrix();
    inverter.distributeMatrix();
    
    // Perform parallel Gauss-Jordan elimination
    inverter.gaussJordanElimination();
    
    // Gather results and print
    inverter.gatherResult();
    inverter.printInverse();
    
    // Finalize MPI
    MPI_Finalize();
    
    return 0;
}