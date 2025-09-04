# Parallel Matrix Inversion using MPI and Gauss-Jordan Elimination

## Approach

### MPI-Based Parallel Gauss-Jordan Elimination
The parallel implementation distributes the computational workload as follows:

1. **Process Distribution**: Each MPI process is assigned a subset of matrix rows
2. **Coordinated Elimination**: Processes work together to perform elimination steps
3. **Communication**: Pivot rows are broadcast to all processes for synchronized elimination
4. **Result Gathering**: Final inverse matrix is collected by the root process

### Algorithm Steps

#### Step 1: MPI Initialization and Setup
- Initialize MPI environment
- Determine process rank and total number of processes
- Distribute matrix size to all processes
- Calculate row distribution per process

#### Step 2: Matrix Distribution
- Process 0 reads the input matrix
- Create augmented matrix [A|I] where I is the identity matrix
- Distribute relevant rows to each process based on workload assignment

#### Step 3: Parallel Gauss-Jordan Elimination
For each pivot column (0 to n-1):
1. **Pivot Selection**: Determine which process owns the pivot row
2. **Normalization**: The pivot owner normalizes its pivot row
3. **Broadcasting**: Pivot row is broadcast to all processes via `MPI_Bcast`
4. **Parallel Elimination**: Each process eliminates the pivot column in its assigned rows
5. **Synchronization**: Processes coordinate to ensure consistent elimination

#### Step 4: Result Collection
- Each process sends its computed rows back to process 0
- Process 0 assembles the complete inverse matrix
- Output the result with 2 decimal precision

## Implementation Details

### Class Structure
```cpp
class MPIMatrixInverter {
private:
    int n;                              // Matrix size
    vector<vector<double>> augmented;   // Augmented matrix [A|I]
    int rank, size;                     // MPI process rank and total processes
    int rows_per_process;               // Base rows per process
    int start_row, end_row;             // Row range for this process
    
public:
    MPIMatrixInverter(int matrix_size, int proc_rank, int proc_size);
    void readMatrix();                  // Read input (process 0 only)
    void distributeMatrix();            // Distribute rows to processes
    void gaussJordanElimination();      // Parallel elimination algorithm
    void gatherResult();                // Collect results to process 0
    void printInverse();                // Output result (process 0 only)
};
```

### Key MPI Features

1. **Load Balancing**: Distributes rows evenly across processes with remainder handling
2. **Broadcast Communication**: Uses `MPI_Bcast` for efficient pivot row distribution
3. **Point-to-Point Communication**: Uses `MPI_Send`/`MPI_Recv` for matrix distribution and collection
4. **Process Coordination**: Synchronizes elimination steps across all processes
5. **Memory Efficiency**: Each process only stores its assigned rows (except process 0)

### Workload Distribution
- **Rows per process**: `n / number_of_processes`
- **Remainder handling**: First `n % number_of_processes` processes get one extra row
- **Example**: For n=10 matrix with 3 processes:
  - Process 0: rows 0-3 (4 rows)
  - Process 1: rows 4-7 (4 rows)  
  - Process 2: rows 8-9 (2 rows)

### Parallel Complexity
- **Time**: O(n³/p + n²log(p)) where p = number of processes
- **Communication**: O(n²) for broadcasting pivot rows
- **Space**: O(n²/p) per process (except process 0 which needs O(n²))

## MPI Communication Pattern

### Process 0 (Root Process):
1. Reads input matrix and matrix size
2. Distributes rows to other processes
3. Participates in parallel elimination
4. Collects results from all processes
5. Outputs the final inverse matrix

### Other Processes:
1. Receive matrix size via broadcast
2. Receive assigned rows from process 0
3. Participate in parallel elimination
4. Send computed results back to process 0

### Communication Flow:
```
Initial: Process 0 → All: Matrix size (MPI_Bcast)
Setup:   Process 0 → Others: Row data (MPI_Send)
Loop:    Pivot Owner → All: Pivot row (MPI_Bcast)
Final:   Others → Process 0: Results (MPI_Send)
```

## Detailed Function Analysis

### 1. Constructor: `MPIMatrixInverter(int matrix_size, int proc_rank, int proc_size)`
**Purpose**: Initialize the MPI matrix inverter with workload distribution

**What it does**:
- Stores matrix size `n`, process rank, and total processes
- Calculates `rows_per_process = n / size` (base rows per process)
- Handles remainder: `remainder = n % size`
- Calculates row range for this process:
  - `start_row = rank * rows_per_process + min(rank, remainder)`
  - `end_row = start_row + rows_per_process + (rank < remainder ? 1 : 0)`
- Allocates memory:
  - Process 0: Full matrix `n × 2n` (for coordination)
  - Other processes: Only their assigned rows `(end_row - start_row) × 2n`

**Example**: For n=5 matrix with 3 processes:
- Process 0: rows 0-1 (2 rows), start_row=0, end_row=2
- Process 1: rows 2-3 (2 rows), start_row=2, end_row=4  
- Process 2: row 4 (1 row), start_row=4, end_row=5

### 2. `readMatrix()`
**Purpose**: Read input matrix from user (Process 0 only)

**What it does**:
- Only process 0 executes this function
- Reads n×n matrix elements from standard input
- Stores elements in the left half of augmented matrix: `augmented[i][j]` for j=0 to n-1
- Initializes identity matrix in right half: `augmented[i][n+i] = 1.0`
- Creates augmented matrix [A|I] where A is input matrix, I is identity

**Memory layout after this step** (Process 0):
```
[a11 a12 a13 | 1 0 0]
[a21 a22 a23 | 0 1 0]  
[a31 a32 a33 | 0 0 1]
```

### 3. `distributeMatrix()`
**Purpose**: Distribute matrix rows from Process 0 to all other processes

**What it does**:

**Process 0 (Sender)**:
- For each process (1 to size-1):
  - Calculates that process's row range
  - Sends each assigned row using `MPI_Send(&augmented[i][0], 2*n, MPI_DOUBLE, proc, i, MPI_COMM_WORLD)`
  - Tag = row index for identification

**Other Processes (Receivers)**:
- Receive their assigned rows using `MPI_Recv`
- Store in local `augmented` matrix (smaller size)
- Each process now has only its portion of the full matrix

**Example**: 3×3 matrix with 2 processes:
- Process 0 sends rows 2 to Process 1
- Process 1 receives row 2
- Process 0 keeps rows 0,1; Process 1 has row 2

### 4. `gaussJordanElimination()`
**Purpose**: Main parallel algorithm to perform Gauss-Jordan elimination

**What it does** (for each pivot column 0 to n-1):

**Step 4a: Find Pivot Owner**
- Calls `findPivotOwner(pivot_col)` to determine which process owns pivot row
- Uses cumulative row distribution to find owner

**Step 4b: Normalize Pivot Row**
- Pivot owner process:
  - Finds local row index: `local_row = pivot_col - start_row`
  - Gets pivot element: `pivot = augmented[local_row][pivot_col]`
  - Normalizes entire row: `augmented[local_row][j] /= pivot` for all j
  - Copies to `pivot_row` buffer

**Step 4c: Broadcast Pivot Row**
- Pivot owner broadcasts normalized row to all processes using:
  `MPI_Bcast(&pivot_row[0], 2*n, MPI_DOUBLE, pivot_owner, MPI_COMM_WORLD)`

**Step 4d: Parallel Elimination**
- Each process eliminates pivot column in its assigned rows:
  - For each local row i (except pivot row):
    - Calculate elimination factor: `factor = augmented[i][pivot_col]`
    - Update row: `augmented[i][j] -= factor * pivot_row[j]` for all j

### 5. `findPivotOwner(int pivot_col)`
**Purpose**: Determine which process owns a specific row (pivot_col)

**What it does**:
- Iterates through processes 0 to size-1
- For each process, calculates how many rows it owns
- Maintains cumulative count of rows
- Returns the process number when pivot_col falls within that process's range

**Example**: n=5, 3 processes
- Process 0: rows 0-1 (cumulative: 0-1)
- Process 1: rows 2-3 (cumulative: 2-3)
- Process 2: row 4 (cumulative: 4)
- `findPivotOwner(3)` returns 1 (Process 1 owns row 3)

### 6. `gatherResult()`
**Purpose**: Collect computed results from all processes back to Process 0

**What it does**:

**Process 0 (Collector)**:
- For each process (1 to size-1):
  - Calculates that process's row range
  - Receives each row using `MPI_Recv(&augmented[i][0], 2*n, MPI_DOUBLE, proc, i, MPI_COMM_WORLD)`
  - Assembles complete result matrix

**Other Processes (Senders)**:
- Send all their computed rows back to Process 0 using `MPI_Send`
- After this, Process 0 has the complete inverse matrix

### 7. `printInverse()`
**Purpose**: Output the final inverse matrix (Process 0 only)

**What it does**:
- Only Process 0 executes this function
- Sets output precision: `cout << fixed << setprecision(2)`
- Prints right half of augmented matrix (columns n to 2n-1)
- This right half contains the inverse matrix A⁻¹
- Outputs exactly 2 decimal places as required

## Complete Flow Example

Let's trace through a 3×3 matrix with 2 MPI processes:

### Input:
```
3
4.00 7.00 2.00
3.00 6.00 1.00  
2.00 5.00 3.00
```

### Step-by-Step Execution:

#### **Phase 1: Initialization**
```
Process 0: rank=0, size=2, n=3
Process 1: rank=1, size=2, n=3

Workload Distribution:
- rows_per_process = 3/2 = 1
- remainder = 3%2 = 1
- Process 0: start_row=0, end_row=2 (rows 0,1)
- Process 1: start_row=2, end_row=3 (row 2)
```

#### **Phase 2: Matrix Reading & Distribution**

**Process 0 reads and creates augmented matrix**:
```
[4.00 7.00 2.00 | 1.00 0.00 0.00]
[3.00 6.00 1.00 | 0.00 1.00 0.00]
[2.00 5.00 3.00 | 0.00 0.00 1.00]
```

**Distribution**:
- Process 0 keeps rows 0,1
- Process 0 sends row 2 to Process 1
- Process 1 receives: `[2.00 5.00 3.00 | 0.00 0.00 1.00]`

#### **Phase 3: Parallel Gauss-Jordan Elimination**

**Iteration 1 (pivot_col = 0)**:
1. `findPivotOwner(0)` returns 0 (Process 0 owns row 0)
2. Process 0 normalizes row 0: divide by pivot=4.00
   ```
   Row 0: [1.00 1.75 0.50 | 0.25 0.00 0.00]
   ```
3. Process 0 broadcasts this pivot row to Process 1
4. Both processes eliminate column 0:
   - Process 0 eliminates row 1: `row1 = row1 - 3.00*pivot_row`
   - Process 1 eliminates its row: `row2 = row2 - 2.00*pivot_row`

**After iteration 1**:
```
Process 0:
[1.00 1.75 0.50 | 0.25 0.00 0.00]
[0.00 0.75 -0.50 | -0.75 1.00 0.00]

Process 1:
[0.00 1.50 2.00 | -0.50 0.00 1.00]
```

**Iteration 2 (pivot_col = 1)**:
1. `findPivotOwner(1)` returns 0 (Process 0 owns row 1)
2. Process 0 normalizes row 1: divide by pivot=0.75
   ```
   Row 1: [0.00 1.00 -0.67 | -1.00 1.33 0.00]
   ```
3. Process 0 broadcasts this pivot row
4. Both processes eliminate column 1:
   - Process 0 eliminates row 0: `row0 = row0 - 1.75*pivot_row`
   - Process 1 eliminates its row: `row2 = row2 - 1.50*pivot_row`

**Iteration 3 (pivot_col = 2)**:
1. `findPivotOwner(2)` returns 1 (Process 1 owns row 2)  
2. Process 1 normalizes row 2: divide by pivot value
3. Process 1 broadcasts this pivot row
4. Both processes eliminate column 2

#### **Phase 4: Result Collection**
- Process 1 sends its computed row 2 back to Process 0
- Process 0 assembles complete inverse matrix

#### **Phase 5: Output**
Process 0 prints the right half (inverse matrix):
```
1.44 -1.22 -0.56
-0.78 0.89 0.22  
0.33 -0.67 0.33
```

### Communication Summary for this Example:
1. **MPI_Bcast**: Matrix size (1 int)
2. **MPI_Send/Recv**: 1 row (6 doubles) from Process 0 to Process 1
3. **MPI_Bcast**: 3 pivot rows (6 doubles each) during elimination
4. **MPI_Send/Recv**: 1 result row (6 doubles) from Process 1 to Process 0

**Total Communication**: ~150 bytes for a 3×3 matrix with 2 processes

This demonstrates how the parallel algorithm distributes work while maintaining mathematical correctness through coordinated communication.
