function [output_wire_lengths, output_modified_wire_lengths, output_coordinates] = wire_function(starting_points, ranges, points_changing, s, varargin)
% WIRE_FUNCTION  Generate randomized guidewire trajectories in an electric field.
%
% Guidewire Trajectory Generation (GTG) tool
% https://github.com/Godinez-Lab/Guidewire-Trajectory-Generation-Tool
% License: GNU General Public License v3.0
%
% Authors:
%   Fatima Ben Haj
%   Felipe Godinez, PhD, University of California Davis
% Date created: September 2022
% Version: 1.0 (based on development version 8, Jan 24, 2024)
%
% Requires: MATLAB R2022a or later, Curve Fitting Toolbox (cscvn, fnplt),
%           Image Processing Toolbox (imfuse, imshow).
%
%%%%%<<<<<<<<<<<<<<<<<<<<<<REQUIRED INPUTS>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
% starting_points: 3 x N array with the original control points of the
%                  spline (rows are x, y, z), in the same units as the
%                  electric field axes in s. If you want the spline to be
%                  displayed in the spatial field plot, x should be between
%                  -2 and 2, and y and z between -1 and 1.
%
%          ranges: N x 6 array. Columns 1-2 are the x minimum and maximum,
%                  columns 3-4 the y minimum and maximum, and columns 5-6
%                  the z minimum and maximum, for each control point.
%                  Ex: ranges = [[p1x_min, p1x_max; p2x_min, p2x_max], ...
%                                [p1y_min, p1y_max; p2y_min, p2y_max], ...
%                                [p1z_min, p1z_max; p2z_min, p2z_max]];
%                  If a point does not move, its minimum and maximum should
%                  be the same.
%
% points_changing: indices of the control points that are randomized.
%                  For example, [3 4 5] means that the ranges of points 3,
%                  4 and 5 are used to move the spline. Points are
%                  randomized one at a time, in the order given; each moved
%                  point keeps its last sampled position while the next
%                  point is randomized.
%
%               s: electric field data structure with fields
%                  s.axis0, s.axis1, s.axis2 (grid edges along x, y, z) and
%                  s.E (field magnitude array). Must correspond with the
%                  input points.
%
%%%%%<<<<<<<<<<<<<<<<<OPTIONAL INPUTS (NAME-VALUE PAIRS)>>>>>>>>>>>>>>>>>>>>
%         num_steps: number of random values drawn within each range, per
%                    dimension. Each randomized point produces num_steps^3
%                    trajectories. Default: 5
%
%        nom_length: desired length of the wire in meters. Each trajectory
%                    is shortened (never lengthened) by removing points from
%                    the proximal end, so that its final length is equal to
%                    or just below nom_length (within one segment). The
%                    accuracy therefore increases with num_interp_points.
%                    nom_length should be less than the unmodified length of
%                    the spline. Default: 2
%
% num_interp_points: number of points used to sample each spline. More
%                    points give higher length accuracy at the cost of
%                    runtime. Default: 500
%
%        show_graph: true to show a histogram of the original and modified
%                    wire lengths. Default: false
%
%         show_plot: true to show the original and modified splines in 3D
%                    with their lengths. Default: true
%
% intersecting_index: index of the control point where the wire enters the
%                    body. If given, the inserted and external lengths of
%                    the wire are calculated and shown. Default: 0 (not used)
%
%     give_warnings: true to warn when spline points fall outside the
%                    electric field grid. Default: true
%
%         direction: side of the spline that is the proximal end (outside
%                    the body), from which points are removed. "Left" means
%                    the first control point is proximal; "Right" means the
%                    last control point is proximal. Default: "Left"
%
%     show_electric: true to show the wire overlaid on the electric field in
%                    coronal and sagittal views. Default: true
%
%    save_snapshot: true to save the last electric field overlay as
%                    efield_snapshot.png and efield_snapshot.fig in the
%                    current folder. Default: false
%
%<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<OUTPUTS>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
%          output_wire_lengths: 1 x T vector, length of each unmodified wire
% output_modified_wire_lengths: 1 x T vector, length of each wire after
%                               shortening to nom_length
%           output_coordinates: 1 x T cell array. Each cell is a 3 x P array
%                               of electric field grid indices (x, y, z)
%                               along the modified wire. Cells are empty for
%                               trajectories that fall outside the grid.
%   T is the total number of trajectories generated.
%
% Example (see example1_timing.m and example2_gui.m for complete examples):
%   s = load('sample_Efield.mat');          % fields E, axis0, axis1, axis2
%   points = [-0.0217 -0.0667 -0.0942;      % control points [x y z] (m)
%              0.0233 -0.0017  0.0758;
%              0.0233 -0.0417  0.3358;
%             -0.2467 -0.2367  1.1658];
%   ranges = [points(:,[1 1]) points(:,[2 2]) points(:,[3 3])];  % fixed points
%   ranges(1,:) = [-0.0717 0.0483 -0.1167 -0.0117 -0.1592 -0.0742]; % point 1 moves
%   [L, Lmod, idx] = wire_function(points', ranges, 1, s, ...
%       'nom_length', 1.2, 'direction', "Right", 'show_graph', true);
%<<<<<<<<<<<<<<<<<<<<<<<<<<<<CODE BODY>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

% Check the number of inputs
if nargin < 4
    error('wire_function:NotEnoughInputs', 'Requires at least 4 inputs: starting_points, ranges, points_changing, s.')
end
if mod(numel(varargin), 2) ~= 0
    error('wire_function:BadOptionalInputs', 'Optional inputs must be given as name-value pairs.')
end

% Default values for optional inputs
num_steps = 5;
nom_length = 2;
num_interp_points = 500;
show_graph = false;
show_plot = true;
intersecting_index = 0;
give_warnings = true;
direction = "Left";
show_electric = true;
save_snapshot = false;

% Read optional name-value inputs
for n = 1:2:numel(varargin)
    name = varargin{n};
    value = varargin{n+1};
    switch lower(string(name))
        case "num_steps",          num_steps = value;
        case "nom_length",         nom_length = value;
        case "num_interp_points",  num_interp_points = value;
        case "show_graph",         show_graph = value;
        case "show_plot",          show_plot = value;
        case "intersecting_index", intersecting_index = value;
        case "give_warnings",      give_warnings = value;
        case "direction",          direction = string(value);
        case "show_electric",      show_electric = value;
        case "save_snapshot",      save_snapshot = value;
        otherwise
            error('wire_function:UnknownOption', 'Unknown optional input "%s".', string(name))
    end
end
if ~ismember(direction, ["Left", "Right"])
    error('wire_function:BadDirection', 'direction must be "Left" or "Right".')
end

% Electric field
eField0 = s.axis0;
eField1 = s.axis1;
eField2 = s.axis2;
eField = s.E;
eField_display = eField;
eField_display(abs(eField_display) > 5) = 5;   % clip for display only

% Ranges of random points for each coordinate
num_points = size(starting_points, 2);
x_ranges = ranges(1:num_points, 1:2);
y_ranges = ranges(1:num_points, 3:4);
z_ranges = ranges(1:num_points, 5:6);

% Number of elements in the field for each dimension
nx = length(eField0(1:end-1));
ny = length(eField1(1:end-1));
nz = length(eField2(1:end-1));

% Slices used for the coronal and sagittal displays (centre of the grid)
mid_y = round(ny/2);
mid_x = round(nx/2);

% Initialize variables
points = starting_points;
wire_lengths = [];
modified_lengths = [];
list_vals = {};
c = 0;   % trajectory counter

if show_electric, f1 = figure; end   % electric field plot
if show_plot,     f2 = figure; end   % spatial field plot

% Iterate over control points, randomizing those listed in points_changing
for x = 1:num_points
    if ~ismember(x, points_changing)
        continue
    end

    % num_steps random values between the minimum and maximum of each range
    current_xrange = x_ranges(x,1) + rand(1,num_steps)*(x_ranges(x,2)-x_ranges(x,1));
    current_yrange = y_ranges(x,1) + rand(1,num_steps)*(y_ranges(x,2)-y_ranges(x,1));
    current_zrange = z_ranges(x,1) + rand(1,num_steps)*(z_ranges(x,2)-z_ranges(x,1));

    for i = 1:num_steps
        points(1, x) = current_xrange(i);
        for j = 1:num_steps
            points(2, x) = current_yrange(j);
            for k = 1:num_steps
                points(3, x) = current_zrange(k);
                c = c + 1;

                % Fit the spline through the control points
                all_points = fnplt(cscvn(points));

                % Resample the spline at num_interp_points points
                t_new = linspace(1, size(all_points, 2), num_interp_points);
                pts_x = interp1(all_points(1,:), t_new, "spline");
                pts_y = interp1(all_points(2,:), t_new, "spline");
                pts_z = interp1(all_points(3,:), t_new, "spline");
                all_points = [pts_x; pts_y; pts_z];

                % Length of the unmodified wire
                wire_length = curveLength(all_points);
                wire_lengths(c) = wire_length; %#ok<AGROW>

                % Shorten the wire to nom_length from the proximal end
                [modified_points, modified_lengths(c)] = modifyWireLength(all_points, nom_length, direction); %#ok<AGROW>

                % Length of wire inside and outside the body
                distance_inside = getInsertedLength(modified_points, points, intersecting_index, direction);
                outside_length = modified_lengths(c) - distance_inside;

                % Plot the spline in the spatial field
                if show_plot
                    figure(f2);
                    plotfunc(all_points, points, modified_points, wire_length, modified_lengths(c), distance_inside, outside_length)
                end

                % Electric field grid indices along the modified wire
                nn = size(modified_points, 2);
                mm = 1:.025:nn;
                l = interp1(1:nn, modified_points', mm);
                ddx = interp1(eField0(1:end-1), 1:nx, l(:,1), 'nearest');
                ddy = interp1(eField1(1:end-1), 1:ny, l(:,2), 'nearest');
                ddz = interp1(eField2(1:end-1), 1:nz, l(:,3), 'nearest');

                if ~any(isnan(ddx) | isnan(ddy) | isnan(ddz))
                    list_vals{c} = [ddx, ddy, ddz]'; %#ok<AGROW>

                    if show_electric
                        vol = zeros(nx, ny, nz);
                        vol(sub2ind([nx ny nz], ddx, ddy, ddz)) = 50;

                        t = tiledlayout(f1, 2, 1);

                        % Coronal view
                        nexttile(t)
                        coronal = imfuse(squeeze(sum(vol, 2)), squeeze(abs(eField_display(:, mid_y, :, 1))), 'Scaling', 'independent');
                        imshow(coronal);
                        axis on
                        title('coronal view')
                        ylabel('pixels along X direction')
                        xlabel('pixels along Z direction')

                        % Sagittal view
                        nexttile(t)
                        sagittal = imfuse(squeeze(sum(vol, 1)), squeeze(abs(eField_display(mid_x, :, :, 1))), 'Scaling', 'independent');
                        imshow(sagittal);
                        axis on
                        title('sagittal view')
                        ylabel('pixels along Y direction')
                        xlabel('pixels along Z direction')
                    end
                else
                    list_vals{c} = []; %#ok<AGROW>
                    if give_warnings
                        warning('wire_function:OutsideField', ...
                            'Trajectory %d has spline points outside the electric field grid.', c)
                    end
                end

                if show_plot || show_electric
                    drawnow
                end
            end
        end
    end
end

% Save the last electric field overlay if requested
if show_electric && save_snapshot
    savefig(f1, 'efield_snapshot.fig')
    print(f1, 'efield_snapshot', '-dpng')
end

% Histogram of original and modified lengths
if show_graph
    edges = linspace(0.2, max([wire_lengths, 2]), 150);
    figure;
    histogram(wire_lengths, edges)
    hold on
    histogram(modified_lengths, edges)
    hold off
    legend('unmodified', 'modified');
    xlabel('wire length (m)')
    ylabel('number of wires')
end

% Outputs
output_wire_lengths = wire_lengths;
output_modified_wire_lengths = modified_lengths;
output_coordinates = list_vals;

end

%% Local functions

function L = curveLength(P)
% Length of a 3D curve given as a 3 x N array of points: the sum of the
% straight-line distances between consecutive points. Equivalent to
% arclength(x, y, z) with its default 'linear' method.
L = sum(vecnorm(diff(P, 1, 2)));
end

function [modified_points, new_length] = modifyWireLength(all_points, nom_length, direction)
% Shorten the wire to nom_length by removing points from the proximal end.
% The length of each segment is computed once; the number of points to
% remove is then found in a single step as the fewest points whose removal
% brings the wire to nom_length or just below it (within one segment).
seg = vecnorm(diff(all_points, 1, 2));        % length of each segment
total = sum(seg);
if direction == "Left"                         % proximal end is the first point
    removed = cumsum(seg);
else                                           % proximal end is the last point
    removed = cumsum(fliplr(seg));
end
remaining = [total, total - removed];          % length left after removing 0, 1, 2, ... points
k = find(remaining <= nom_length, 1) - 1;      % fewest points to remove
k = min(k, size(all_points, 2) - 2);           % always keep at least two points
if direction == "Left"
    modified_points = all_points(:, k+1:end);
else
    modified_points = all_points(:, 1:end-k);
end
new_length = curveLength(modified_points);
end

function distance_inside = getInsertedLength(modified_points, points, intersecting_index, direction)
% Length of wire inside the body: from the spline point closest to the entry
% control point to the distal end of the wire.
distance_inside = 0;
if intersecting_index == 0
    return
end
entry = points(:, intersecting_index);
[~, idx] = min(vecnorm(modified_points - entry));
if direction == "Left"      % proximal end is the start, distal end is the end
    inside = modified_points(:, idx:end);
else                        % proximal end is the end, distal end is the start
    inside = modified_points(:, 1:idx);
end
if size(inside, 2) >= 2
    distance_inside = curveLength(inside);
end
end

function plotfunc(all_points, points, modified_points, wire_length, new_length, distance_inside, outside_length)
% Plot the original and modified splines in the spatial field.
x_axis = [-2 2];
y_axis = [-1 1];
z_axis = [-1 1];

% Resample the spline so the plotted points are close to evenly spaced
t_plot = linspace(1, size(all_points, 2));
spline_x = interp1(all_points(1,:), t_plot, "spline");
spline_y = interp1(all_points(2,:), t_plot, "spline");
spline_z = interp1(all_points(3,:), t_plot, "spline");

% Original spline and control points
spline_line = plot3(spline_z, spline_y, spline_x);
spline_line.LineWidth = 1;
hold on
plot3(points(3,:), points(2,:), points(1,:), 'ro');
grid on
view(-50, 10)
title('local wire MRI (units are in meters)')

% Modified spline
new_line = plot3(modified_points(3,:), modified_points(2,:), modified_points(1,:), ".", 'markersize', 12);
set(new_line, "Color", '#EDB120')

% Lengths
t = text(-0.8, 0.9, 0.7, {'Modified length of wire:', num2str(new_length)});
t1 = text(-0.8, 0.9, 0.5, {'Original length of wire:', num2str(wire_length)});
t.FontSize = 10;  set(t, 'Color', '#EDB120');
t1.FontSize = 10; set(t1, 'Color', 'b');
t2 = text(0.5, 0.3, 0.7, {'Distance of wire inside body:', num2str(distance_inside)});
t2.FontSize = 10;
t3 = text(0.5, 0.3, 0.5, {'Distance of modified wire outside body:', num2str(outside_length)});
t3.FontSize = 10;

% Line representing the body
ll = line([-2, 2], [0, 0], [0, 0], 'linewidth', 3);
set(ll, 'Color', 'm')
hold off

xlim(x_axis); ylim(y_axis); zlim(z_axis)
% In the MRI the z axis is along the bore and the x axis is horizontal
xlabel('z (axial)')
ylabel('y (vertical)')
zlabel('x (horizontal)')
axis square
legend('original spline', 'control points', 'modified spline', 'body');
end
