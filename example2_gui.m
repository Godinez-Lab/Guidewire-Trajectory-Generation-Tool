%% GTG Example 2: pick the ranges of the moving points with the mouse
% Shows the guidewire control points on the simulated body coil electric
% field. For each moving point, you draw a box around it in two views; the
% box sets how far that point may move in x, y and z. wire_function then
% generates randomized trajectories within those ranges.
%
% Requirements: MATLAB R2022a or later, Curve Fitting Toolbox,
%               Image Processing Toolbox (getrect, imshow, imfuse).
% Data:         sample_Efield.mat (in the same folder as this script)
%
% How to use:
%   Run the script. For each moving point, two figures open in turn:
%     1) x-z view: click and drag a box around the highlighted (green) point.
%        The box height sets the x range and its width sets the z range.
%     2) y-z view: click and drag a box around the same point.
%        The box height sets the y range.
%   After each box is drawn, it is redrawn in yellow and, if save_figures is
%   true, the view is saved as example2_point<N>_xz.png / _yz.png.
%   The selected ranges are saved in example2_selected_ranges.mat so the
%   run can be repeated without picking again (set use_saved_ranges = true).
%   The repository includes an example example2_selected_ranges.mat, so
%   you can also run this example without picking by setting
%   use_saved_ranges = true.
%
% Expected output:
%   - the electric field overlay of each trajectory (coronal and sagittal)
%   - a histogram of the original and modified wire lengths
%   - num_moving x num_steps^3 trajectories (2 x 125 = 250 with the defaults),
%     with modified lengths within about 1 cm of nom_length

clc; clearvars; close all

%% Settings
here = fileparts(mfilename('fullpath'));
field_file = fullfile(here, 'sample_Efield.mat');
ranges_file = fullfile(here, 'example2_selected_ranges.mat');

use_saved_ranges = false;  % true: skip picking and reuse the last saved ranges
changing   = [1 2];        % control points whose ranges you will pick
nom_length = 1.2;          % nominal wire length (m)
num_steps  = 5;            % random values per range and dimension
save_figures = true;       % true: draw each selected box and save the view as a PNG (e.g. for figures)

%% Load the electric field
s = load(field_file);
E_display = abs(s.E(:, :, :, 1));
E_display(E_display > 5) = 5;   % clip for display only

%% Control points (meters, field coordinates); each row is one point [x y z]
points = [-0.0217 -0.0667 -0.0942;
           0.0233 -0.0017  0.0758;
           0.0233 -0.0417  0.3358;
          -0.2467 -0.2367  1.1658];
num_points = size(points, 1);

% Fixed points do not move: their minimum and maximum are the point itself
ranges = [points(:,1) points(:,1) points(:,2) points(:,2) points(:,3) points(:,3)];

%% Pick the ranges of the moving points
if use_saved_ranges && isfile(ranges_file)
    load(ranges_file, 'ranges', 'changing');
    fprintf('Using saved ranges from %s\n', ranges_file);
else
    % Control points as grid indices, for display
    idx = zeros(num_points, 3);
    for p = 1:num_points
        idx(p, :) = fieldToPixels(points(p, :), s);
    end

    for p = changing
        % x-z view through the y position of this point
        figure('Name', sprintf('Point %d: x-z view', p), 'Position', [100 300 900 350]);
        imshow(squeeze(E_display(:, idx(p,2), :)), [])
        hold on
        plot(idx(:,3), idx(:,1), 'ro', 'MarkerSize', 8, 'LineWidth', 1.5)
        plot(idx(p,3), idx(p,1), 'go', 'MarkerSize', 12, 'LineWidth', 2)
        hold off
        title(sprintf('Point %d (green): drag a box to set its x range (height) and z range (width)', p))
        rect = getrect;                                   % [col_min row_min width height]
        xz_rows = [rect(2), rect(2) + rect(4)];           % x direction (image rows)
        xz_cols = [rect(1), rect(1) + rect(3)];           % z direction (image columns)
        showSelection(rect, sprintf('Point %d: selected x and z range', p), ...
            fullfile(here, sprintf('example2_point%d_xz.png', p)), save_figures)

        % y-z view through the x position of this point
        figure('Name', sprintf('Point %d: y-z view', p), 'Position', [100 300 900 350]);
        imshow(squeeze(E_display(idx(p,1), :, :)), [])
        hold on
        plot(idx(:,3), idx(:,2), 'ro', 'MarkerSize', 8, 'LineWidth', 1.5)
        plot(idx(p,3), idx(p,2), 'go', 'MarkerSize', 12, 'LineWidth', 2)
        hold off
        title(sprintf('Point %d (green): drag a box to set its y range (height)', p))
        rect = getrect;
        yz_rows = [rect(2), rect(2) + rect(4)];           % y direction (image rows)
        showSelection(rect, sprintf('Point %d: selected y range', p), ...
            fullfile(here, sprintf('example2_point%d_yz.png', p)), save_figures)

        % Convert the boxes to meters
        ranges(p, 1:2) = pixelRangeToField(xz_rows, s.axis0);
        ranges(p, 3:4) = pixelRangeToField(yz_rows, s.axis1);
        ranges(p, 5:6) = pixelRangeToField(xz_cols, s.axis2);

        % Check that the point lies inside its box
        inside = points(p,1) >= ranges(p,1) && points(p,1) <= ranges(p,2) && ...
                 points(p,2) >= ranges(p,3) && points(p,2) <= ranges(p,4) && ...
                 points(p,3) >= ranges(p,5) && points(p,3) <= ranges(p,6);
        if ~inside
            warning('Point %d is outside the box you drew; trajectories will not pass through its original position.', p)
        end
        fprintf('Point %d ranges (m): x [%.4f %.4f], y [%.4f %.4f], z [%.4f %.4f]\n', p, ranges(p, :));
    end
    save(ranges_file, 'ranges', 'changing', 'points');
end

%% Run the tool
rng(1);
[wire_lengths, modified_wire_lengths, coordinates] = wire_function( ...
    points', ranges, changing, s, ...
    'nom_length', nom_length, ...
    'num_steps', num_steps, ...
    'intersecting_index', 3, ...
    'direction', "Right", ...
    'show_plot', false, ...
    'show_electric', true, ...
    'show_graph', true, ...
    'give_warnings', false);

fprintf('\nTrajectories generated: %d\n', numel(modified_wire_lengths));
fprintf('Modified length (m): mean %.4f, range %.4f-%.4f\n', ...
    mean(modified_wire_lengths), min(modified_wire_lengths), max(modified_wire_lengths));

%% Local functions

function showSelection(rect, label, png_file, save_figures)
% Draw the selected box on the current view, save it as a PNG if requested,
% and close the figure. The box drawn by getrect disappears when the mouse
% is released, so it is redrawn here.
hold on
rectangle('Position', rect, 'EdgeColor', 'y', 'LineWidth', 2)
hold off
title(label)
drawnow
if save_figures
    exportgraphics(gca, png_file, 'Resolution', 300);
    pause(0.5)   % brief look at the selection before the next view opens
end
close(gcf)
end

function idx = fieldToPixels(pt, s)
% Grid indices [ix iy iz] of the voxel nearest to a point [x y z] in meters.
[~, ix] = min(abs(s.axis0(1:end-1) - pt(1)));
[~, iy] = min(abs(s.axis1(1:end-1) - pt(2)));
[~, iz] = min(abs(s.axis2(1:end-1) - pt(3)));
idx = [ix iy iz];
end

function r = pixelRangeToField(pix, ax)
% Convert a [min max] range in pixels along one axis to meters.
n = numel(ax) - 1;
pix = min(max(round(pix), 1), n);   % keep inside the grid
r = sort(ax(pix));
r = r(:)';
end
