# Triangle Counting with MapReduce

This repository implements a MapReduce pipeline to count triangles in an undirected graph. It produces:

- total number of triangles in the graph, and
- per-vertex triangle participation counts.

The design orients edges by degree to ensure every triangle is counted exactly once, even at scale.


## Input format

- File: `edges.txt` at the project root
- Each line: `u v` (space-separated integers) with the convention `u < v`

Example:

```
1 2
2 3
1 3
```


## Output format

Job 4 aggregates and emits:

- `total_triangles <count>` — global triangle count
- One line per vertex: `<vertex_id> <count>` — triangles the vertex participates in

Example output for the above input:

```
total_triangles 1
1 1
2 1
3 1
```


## Algorithm overview

The pipeline runs four MapReduce jobs.

### Job 1 — Degree Count

- Mapper: For each edge `(u, v)`, emit `(u, 1)` and `(v, 1)`
- Combiner: Locally sums counts to reduce shuffle size
- Reducer: Sums counts to produce the degree of each vertex

This degree information is used to orient edges.

### Job 2 — Oriented Adjacency

- Orientation rule: lower-ranked → higher-ranked vertex, where rank is `(degree, then vertex id)`
- Reducer collects oriented adjacency lists for each vertex

This ensures each triangle has a unique “lowest-ranked” vertex that will be responsible for emitting its wedges.

### Job 3 — Wedge Closure

Two mappers feed the same reducers:

- Adjacency mapper: For vertex `u` with oriented neighbors `[v1, v2, …, vk]` (all `u → vi`), emit wedges `(vi, vj)` with witness `u`
- Edge mapper: For each (undirected) edge `(v, w)`, emit `(v, w)` as an existing edge `E`

Reducer logic: If both a wedge `(v, w)` with witness `u` and the edge `(v, w)` are present, a triangle `(u, v, w)` exists. Emit

```
G 1        # contributes to global triangle count
V u 1      # per-vertex participation
V v 1
V w 1
```

### Job 4 — Aggregation

- Sum all `G` emissions to get `total_triangles`
- Sum `V x 1` per vertex `x` to get per-vertex counts


## Correctness sketch

For any triangle `(u, v, w)`, let `u` be the lowest-ranked vertex (by degree, then by id). Job 2 orients `u → v` and `u → w`. Only this `u` emits the wedge `(v, w)` in Job 3. The reducer closes the wedge if edge `(v, w)` exists and counts the triangle once. Therefore:

- No triangle is missed (every triangle has a lowest-ranked vertex)
- No triangle is double-counted (only the lowest-ranked vertex emits its wedge)
- Per-vertex counts are exact (each triangle contributes 1 to its three vertices)


## Scalability notes

- High-degree vertices yield many wedges `O(d^2)`; orienting edges reduces duplicates and balances load
- Partitioning by key ensures wedges and their corresponding edges meet at the same reducer
- Job 1 uses a combiner to shrink shuffle for high-degree nodes
- Tested up to ~100k vertices and ~1M edges on a cluster; outputs remained correct and finite


## Examples

### Single triangle (K3)

Input:

```
1 2
2 3
1 3
```

Output:

```
total_triangles 1
1 1
2 1
3 1
```

### Complete graph on 4 vertices (K4)

Edges:

```
1 2
1 3
1 4
2 3
2 4
3 4
```

There are `C(4, 3) = 4` triangles. Orientation causes only the smallest-ranked vertex of each triangle to emit wedges.

Expected output:

```
total_triangles 4
1 3
2 3
3 3
4 3
```


## How to run

This repository includes SLURM batch scripts for running the pipeline end-to-end on a cluster (e.g., with Hadoop Streaming or a similar MapReduce environment). Adapt paths and modules as needed for your environment.

- End-to-end pipeline: `triangle_pipeline.slrum` (and `triangle_pipeline1.slrum` variant)
- Per-job debug scripts: `Job1/job1_debug.slrum`, `Job2/job2_debug.slrum`, `Job3/job3_debug.slrum`, `job4_debug.slrum`

Typical usage on a SLURM-managed cluster:

```
sbatch triangle_pipeline.slrum
```

Notes:

- Ensure `edges.txt` exists at the expected input location (local or HDFS) as configured in the scripts
- The mappers/reducers are the Python files under `Job1/`, `Job2/`, `Job3/`, and `job4_reducer.py`
- Use `clean.sh` to clear previous outputs (adapt as needed)


## Repository layout

- `edges.txt`, `edges1.txt`, `edges3.txt` — example edge lists
- `Job1/`
  - `job1_mapper.py`, `job1_combiner.py`, `job1_reducer.py`, 
  - `partition.py` - partitioner for Job1
- `Job2/`
  - `job2_mapper.py`, `job2_reducer.py`
- `Job3/`
  - `job3_mapper_adj.py`, `job3_mapper_edges.py`, `job3_reducer.py`
- `Job4/`
  - `job4_reducer.py` — final aggregation reducer
- `SLrum_files_final/`
  - `triangle_pipeline.slrum`, `triangle_pipeline1.slrum` — end-to-end SLURM pipelines
- `SLrum_files_final/job4_debug.slrum`, `Job*/job*_debug.slrum` — per-job debug scripts
- `clean.sh` — helper to remove outputs
- `Edge_Files/`
  - `gen_graph.py`, `skew_gen_graphs.py` — synthetic graph generators


## Development notes

- Python mappers/reducers are standard streaming programs reading from stdin and writing to stdout
- Ensure executability and shebang lines where required by your environment
- When adapting to different clusters, verify module paths, Python version, and HDFS locations in the SLURM scripts


## License

This project is provided for educational and research purposes. Add a license file if you intend to distribute or reuse.
