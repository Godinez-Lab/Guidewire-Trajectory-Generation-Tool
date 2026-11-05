%% GTG Example 1: length accuracy and runtime of wire_function
% Runs wire_function on a simulated body coil electric field with fixed
% control points and ranges, and measures how the length accuracy and the
% runtime change with the number of interpolated spline points.
% This reproduces the accuracy and runtime evaluation in the paper (Fig. 5).
%
% Requirements: MATLAB R2022a or later, Curve Fitting Toolbox,
%               Image Processing Toolbox.
% Data:         sample_Efield.mat (in the same folder as this script)
%
% Each run generates 3000 trajectories (3 moving control points x
% num_steps^3 = 3 x 10^3). All displays are turned off so that only the
% computation is timed.
%
% Expected output:
%   - a table of length accuracy (mean and SD across the 3000 trajectories)
%     and runtime (s) for 10 to 3000 interpolated points
%   - a two-panel figure: (A) accuracy (mean +/- SD, log x axis) and
%     (B) runtime vs. number of points, saved as example1_timing.png
%   - results saved in example1_timing_results.mat
%
%   Reference results (Intel MacBook Pro, MATLAB R2022a):
%     points   accuracy (%)        runtime (s, 3000 trajectories)
%        10    93.89 +/- 1.99        2.8
%       100    99.09 +/- 0.49        3.9
%       500    99.82 +/- 0.10        7.7
%      1000    99.91 +/- 0.05       11.9
%      3000    99.97 +/- 0.02       32.9
%   Accuracy should match closely; runtime depends on the computer.
%   The full sweep takes about 2.5 minutes on this machine.

clc; clearvars; close all

%% Settings
here = fileparts(mfilename('fullpath'));
field_file = fullfile(here, 'sample_Efield.mat');

nom_length    = 1.2;                                % nominal wire length (m)
num_steps     = 10;                                 % 3 moving points x 10^3 = 3000 trajectories per run
interp_points = [10 50 100 200 300 500 750 1000 1500 2000 2500 3000]; % number of interpolated spline points to test

%% Load the electric field
s = load(field_file);

%% Control points (meters, field coordinates); each row is one point [x y z]
points = [-0.0217 -0.0667 -0.0942;
           0.0233 -0.0017  0.0758;
           0.0233 -0.0417  0.3358;
          -0.2467 -0.2367  1.1658];

%% Range within which each control point may move
x_ranges = [-0.0717  0.0483;
            -0.0217  0.0633;
            -0.0317  0.0733;
            -0.2817 -0.2067];
y_ranges = [-0.1167 -0.0117;
            -0.0517  0.0483;
            -0.1117 -0.0117;
            -0.2917 -0.1867];
z_ranges = [-0.1592 -0.0742;
             0.0008  0.1108;
             0.2808  0.4208;
             1.1208  1.2208];
ranges = [x_ranges y_ranges z_ranges];

changing = [1 2 3];   % control points that are randomized

% Options shared by all runs (all displays off for timing)
opts = {'nom_length', nom_length, ...
        'num_steps', num_steps, ...
        'intersecting_index', 3, ...
        'direction', "Right", ...
        'show_plot', false, ...
        'show_electric', false, ...
        'show_graph', false, ...
        'give_warnings', false};

%% Warm-up run (excluded from timing; MATLAB is slower the first time code runs)
rng(1);
wire_function(points', ranges, 1, s, opts{:}, 'num_steps', 2);

%% Sweep the number of interpolated points
% One run of 3000 trajectories per setting. The accuracy error bars show the
% standard deviation across the 3000 trajectories of each run.
n = numel(interp_points);
acc_mean = zeros(1, n);  acc_std = zeros(1, n);  acc_min = zeros(1, n);
runtime  = zeros(1, n);
n_traj   = zeros(1, n);

for k = 1:n
    rng(1);   % same random trajectories for every setting
    tic
    [~, Lmod] = wire_function(points', ranges, changing, s, opts{:}, ...
        'num_interp_points', interp_points(k));
    runtime(k) = toc;

    acc = 100 * Lmod / nom_length;
    acc_mean(k) = mean(acc);
    acc_std(k)  = std(acc);
    acc_min(k)  = min(acc);
    n_traj(k)   = numel(Lmod);
    fprintf('%5d points: accuracy %.3f +/- %.3f%% (min %.2f%%), runtime %.1f s for %d trajectories\n', ...
        interp_points(k), acc_mean(k), acc_std(k), acc_min(k), runtime(k), n_traj(k));
end

%% Results table
results = table(interp_points', n_traj', acc_mean', acc_std', acc_min', runtime', ...
    runtime' ./ n_traj' * 1000, ...
    'VariableNames', {'InterpPoints', 'Trajectories', 'MeanAccuracy_pct', 'SDAccuracy_pct', ...
                      'MinAccuracy_pct', 'Runtime_s', 'ms_per_trajectory'});
disp(results)

%% Figure: (A) accuracy (mean +/- SD) and (B) runtime vs. number of interpolated points
fig = figure('Position', [100 100 1000 400]);
subplot(1, 2, 1)
errorbar(interp_points, acc_mean, acc_std, 'o-', 'LineWidth', 1.5, 'CapSize', 6)
set(gca, 'XScale', 'log')
xticks([10 50 100 500 1000 3000])
xlim([interp_points(1) * 0.9, interp_points(end) * 1.1])
xlabel('number of interpolated points (log scale)')
ylabel('length accuracy (%)')
title('(A) Length accuracy (mean \pm SD)')
grid on

subplot(1, 2, 2)
plot(interp_points, runtime, 'o-', 'LineWidth', 1.5)
xlabel('number of interpolated points')
ylabel(sprintf('runtime for %d trajectories (s)', n_traj(1)))
title('(B) Runtime')
xlim([interp_points(1) - 200, interp_points(end) + 200])
grid on

exportgraphics(fig, fullfile(here, 'example1_timing.png'), 'Resolution', 300);

%% Save the results
save(fullfile(here, 'example1_timing_results.mat'), 'results', 'interp_points', 'acc_mean', 'acc_std', 'acc_min', 'runtime', 'n_traj');
