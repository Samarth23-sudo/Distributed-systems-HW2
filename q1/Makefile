# Makefile for MPI Matrix Inversion

CXX = mpic++
CXXFLAGS = -std=c++11 -O3 -Wall
TARGET = matrix_inverse
SOURCE = q1.cpp

# Default target
all: $(TARGET)

# Compile the program
$(TARGET): $(SOURCE)
	$(CXX) $(CXXFLAGS) -o $(TARGET) $(SOURCE)

# Clean compiled files
clean:
	rm -f $(TARGET)

# Run with 4 processes (example)
run: $(TARGET)
	mpirun -np 4 ./$(TARGET)

# Run with 2 processes
run2: $(TARGET)
	mpirun -np 2 ./$(TARGET)

# Run sequential (1 process)
run1: $(TARGET)
	mpirun -np 1 ./$(TARGET)

# Test with example input
test: $(TARGET)
	echo "3\n4.00 7.00 2.00\n3.00 6.00 1.00\n2.00 5.00 3.00" | mpirun -np 2 ./$(TARGET)

# Check MPI installation
check-mpi:
	@echo "Checking MPI installation..."
	@which mpirun || echo "MPI not found. Please install OpenMPI or MPICH."
	@which mpic++ || echo "MPI C++ compiler not found."

.PHONY: all clean run run1 run2 test check-mpi
