# Guidewire Trajectory Generation (GTG) Tool

GTG is an open-source MATLAB tool that generates large numbers of randomized, length-controlled 3D guidewire trajectories within user-defined bounds in an anatomical model. It was developed for studying radiofrequency (RF)-induced tip heating of guidewires in interventional MRI.

Each trajectory is a smooth 3D spline through a set of control points. Some of the points move at random within ranges you set, and every trajectory is trimmed to a chosen wire length. The trajectories are returned on the grid of an electric field map. You can combine them with an electric-field transfer function to estimate the tip heating of each trajectory, without a new full-wave simulation for every trajectory.

On a 2020 MacBook Pro (Intel Core i5), GTG generates 3000 trajectories in about 8 seconds with a length accuracy of 99.8%.

> Ben Haj F, Hand J, Malik S, Godinez F. A Guidewire Trajectory Generation Tool for Interventional MRI Simulations. *Magnetic Resonance in Medicine* (submitted).

---

## Contents

| File | Description |
|---|---|
| `wire_function.m` | The tool: generates the trajectories |
| `example1_timing.m` | Example 1: length accuracy and runtime evaluation (reproduces Figure 5 of the paper) |
| `example2_gui.m` | Example 2: pick the ranges of the moving points with the mouse |
| `sample_Efield.mat` | Sample data: simulated body coil electric field magnitude (64 MHz, 1.5 T) in the Duke model, 5 mm grid |
| `example2_selected_ranges.mat` | Saved ranges for Example 2, so it can run without picking |
| `docs/` | Images used in this README |
| `LICENSE` | GNU General Public License v3.0 |

## Requirements

- MATLAB R2022a or later
- Curve Fitting Toolbox (`cscvn`, `fnplt`)
- Image Processing Toolbox (`imshow`, `imfuse`, `getrect`)

GTG has been tested on macOS with MATLAB R2022a. No other software or compilation is needed.

## Installation

1. Download the repository: click **Code → Download ZIP** and unzip it, or clone it:
   ```
   git clone https://github.com/Godinez-Lab/Guidewire-Trajectory-Generation-Tool.git
   ```
2. In MATLAB, go to the repository folder, or add it to the path:
   ```matlab
   addpath('path/to/Guidewire-Trajectory-Generation-Tool')
   ```

## Quick start

```matlab
s = load('sample_Efield.mat');            % fields: E, axis0, axis1, axis2

% Control points [x y z] in meters, one row per point
points = [-0.0217 -0.0667 -0.0942;
           0.0233 -0.0017  0.0758;
           0.0233 -0.0417  0.3358;
          -0.2467 -0.2367  1.1658];

% Ranges [xmin xmax ymin ymax zmin zmax] for each point.
% Fixed points use their own position as min and max.
ranges = [points(:,[1 1]) points(:,[2 2]) points(:,[3 3])];
ranges(1,:) = [-0.0717 0.0483 -0.1167 -0.0117 -0.1592 -0.0742];   % point 1 moves

[L, Lmod, idx] = wire_function(points', ranges, 1, s, ...
    'nom_length', 1.2, 'direction', "Right", 'show_graph', true);
```

This generates 125 trajectories (1 moving point × 5³), each trimmed to just under 1.2 m.

## Example 1: length accuracy and runtime

```matlab
example1_timing
```

This example uses 4 control points, 3 of which move, to generate 3000 trajectories. It repeats the run with 10 to 3000 interpolated points per spline. All displays are turned off, so only the computation is timed. It prints a table, saves `example1_timing_results.mat`, and saves the figure below as `example1_timing.png`.

![Example 1 results](docs/example1_timing.png)

**Expected results** (2020 MacBook Pro, 2 GHz quad-core Intel Core i5, 32 GB, MATLAB R2022a):

| Interpolated points | Length accuracy (mean ± SD, %) | Runtime for 3000 trajectories (s) |
|---:|---:|---:|
| 10 | 93.89 ± 1.99 | 2.8 |
| 100 | 99.09 ± 0.49 | 3.9 |
| 500 (default) | 99.82 ± 0.10 | 7.7 |
| 1000 | 99.91 ± 0.05 | 11.9 |
| 3000 | 99.97 ± 0.02 | 32.9 |

The accuracies should match closely, because the random seed is fixed. The runtimes depend on your computer. The full sweep takes about 2.5 minutes.

## Example 2: pick the ranges with the mouse

```matlab
example2_gui
```

For each moving point (points 1 and 2 by default), two views of the electric field open in turn. In each view, the point you are editing is green and the other control points are red.

1. **Coronal (x–z) view:** click and drag a box around the green point. The box height sets the x range, and its width sets the z range.
2. **Sagittal (y–z) view:** drag a box around the same point. The box height sets the y range.

![Example 2 interface](docs/example2_gui.png)

Each selected box is redrawn in yellow and saved as a PNG (`example2_point<N>_xz.png`, `_yz.png`). The ranges are saved in `example2_selected_ranges.mat`. GTG then generates the trajectories and shows each one on the electric field, followed by a histogram of the wire lengths.

**Expected output:** 250 trajectories (2 moving points × 5³), all inside the field, with trimmed lengths just under 1.2 m.

**To run without picking:** set `use_saved_ranges = true` at the top of the script to reuse the saved ranges.

## Using your own electric field

The field must be a MATLAB structure, or a `.mat` file loaded with `s = load(...)`, with these fields:

| Field | Description |
|---|---|
| `E` | Electric field magnitude, nx × ny × nz (an optional 4th dimension is allowed; the first component is used for display) |
| `axis0`, `axis1`, `axis2` | Grid edges along x, y and z in meters (lengths nx+1, ny+1, nz+1) |

Give the control points and ranges in the same coordinates as the axes.

## `wire_function` reference

```matlab
[wire_lengths, modified_wire_lengths, coordinates] = wire_function(starting_points, ranges, points_changing, s, Name, Value, ...)
```

**Required inputs**

| Input | Description |
|---|---|
| `starting_points` | 3 × N control points (rows x, y, z) |
| `ranges` | N × 6 array `[xmin xmax ymin ymax zmin zmax]`. Use equal min and max for points that do not move |
| `points_changing` | Indices of the points that move |
| `s` | Electric field structure (see above) |

**Optional name–value inputs**

| Name | Default | Description |
|---|---|---|
| `num_steps` | 5 | Random values drawn per range and dimension. Each moving point gives `num_steps`³ trajectories |
| `nom_length` | 2 | Wire length in meters. Each trajectory is trimmed from the proximal end to this length or just below it |
| `num_interp_points` | 500 | Points per spline. More points give higher length accuracy but a longer runtime |
| `direction` | `"Left"` | Proximal end of the wire (outside the body): `"Left"` = first point, `"Right"` = last point |
| `intersecting_index` | 0 | Index of the point where the wire enters the body (0 = not used) |
| `show_plot` | `true` | Show a 3D plot of each wire |
| `show_electric` | `true` | Show each wire on the electric field. **Turn off for large batches**, because drawing dominates the runtime |
| `show_graph` | `false` | Show a histogram of the original and trimmed lengths |
| `give_warnings` | `true` | Warn when a trajectory falls outside the field grid |
| `save_snapshot` | `false` | Save the last electric field display as `efield_snapshot.png` |

**Outputs**

| Output | Description |
|---|---|
| `wire_lengths` | Length of each trajectory before trimming (m) |
| `modified_wire_lengths` | Length of each trajectory after trimming (m) |
| `coordinates` | Cell array with one cell per trajectory, holding a 3 × P array of electric-field grid indices along the trimmed wire. A cell is empty if the trajectory falls outside the grid |

**How it works:** the moving points are randomized one at a time. Each moving point is sampled at `num_steps` random positions in each dimension and keeps its last position while the next point is randomized. For each set of points, GTG fits a cubic spline (`cscvn`) and resamples it at `num_interp_points` points. It then trims the wire from the proximal end to `nom_length`. The wire length is the sum of the distances between consecutive points.

## Support and maintenance

GTG is maintained by the Godinez Lab, Department of Radiology, University of California Davis. We plan to support it for at least 10 years after publication.

- **Bugs and feature requests:** open an [issue](https://github.com/Godinez-Lab/Guidewire-Trajectory-Generation-Tool/issues)
- **Questions:** fgodinez@health.ucdavis.edu

Changes are released as numbered versions. The version described in the paper is **v1.0**.

## Citation

If you use GTG, please cite the paper above and the software:

> Ben Haj F, Hand J, Malik S, Godinez F. Guidewire Trajectory Generation (GTG) Tool, version 1.0. Zenodo. doi:https://doi.org/10.5281/zenodo.24357489

## License

GTG is released under the [GNU General Public License v3.0](LICENSE).

The sample electric field was simulated in the Duke model of the IT'IS Foundation Virtual Population. The Duke model itself is not included, and is available from the IT'IS Foundation under its own license.

## Acknowledgements

This work was supported by the UC Davis Comprehensive Cancer Center through the Paul Calabresi Career Development Award for Clinical Oncology (5K12CA138464-14), and by the UK Medical Research Council Developmental Pathway Funding Scheme (MR/N027949/1).
