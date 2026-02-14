%% BloomingRose.m
% Rose head geometry adapted from Eric Ludlam's "Blooming Rose" (MATLAB Flipbook Mini Hack, 2023)
% Ref: https://uk.mathworks.com/matlabcentral/communitycontests/contests/6/entries/13857
%      https://github.com/zappo2/digital-art-with-matlab/tree/master/flowers
%
% Vasilis Bellos, 2026

%% ========== EXPORT PARAMETERS ==========
nFrames      = 120;        % animation frames (bud → full bloom)
recordFrames = false;       % set to true to capture frames for Video/GIF/PNG Sequence
cropFrames   = true;       % false | true (15% L, 15% R, 10% T, 15% B) | [L R T B] fractions

%% ========== FLOWER PARAMETERS ==========
n        = 250;            % mesh resolution (n × n grid)
A        = 1.995653;       % petal height coefficient
B        = 1.27689;        % petal curl coefficient
petalNum = 3.6;            % number of petals per revolution

%% ========== STEM PARAMETERS ==========
% Stem geometry
stemLength    = 3.2;       % total stem length downwards
stemRadiusTop = 0.055;     % radius near calyx
stemRadiusBot = 0.042;     % radius at base
stemCurveX    = 0.25;      % lateral curve displacement
stemCurveY    = 0.12;      % forward curve displacement
nStemLen      = 50;        % segments along stem
nStemCirc     = 20;        % segments around stem

% Calyx (sepals)
nSepals      = 5;          % number of sepals
sepalLength  = 0.35;       % tip-to-base length
sepalWidth   = 0.10;       % max width at midpoint
sepalDroop   = 0.10;       % outward droop

% Thorns
nThorns      = 6;          % number of thorns
thornHeight  = 0.14;       % cone height
thornRadius  = 0.028;      % cone base radius

% Colors
stemColor    = [0.18 0.42 0.15];   % dark green
sepalColor   = [0.22 0.50 0.18];   % slightly brighter green
thornColor   = [0.30 0.25 0.12];   % brownish-green

%% ========== SCENE PRESETS ==========
% Quick-start bundles that override colormapMode, customColormap, customCLim
% and lightingMode below. Set to 'custom' to use the individual settings instead.
%
%   'classic'        — dynamic red ramp, full lighting (default look)
%   'matte red'      — dynamic red, matte (no lighting)
%   'dark velvet'    — black baccara, full lighting, fixed CLim
%   'rose gold'      — rose gold, full lighting, auto CLim
%   'aurora'         — aurora borealis, full lighting, auto CLim
%   'neon'           — cyberwave, matte (no lighting), auto CLim
%   'frozen'         — frozen palette, hybrid lighting, fixed CLim
%   'solar'          — solar flare, matte, fixed CLim
%   'phantom'        — phantom orchid, hybrid lighting, fixed CLim
%   'radioactive'    — radioactive green, matte, fixed CLim
%   'winter'         — MATLAB winter, full lighting, fixed CLim
%   'turbo'          — MATLAB turbo, full lighting, auto CLim
scenePreset = 'custom';

%% ========== COLORMAP PARAMETERS ==========
% colormapMode controls how the rose gets its color:
%   'static'  — Fixed 10-entry red colormap; depth comes purely from lights.
%   'dynamic' — Distance-based CData through an evolving colormap that
%               starts nearly flat red (hiding depth when closed) and
%               introduces dark values as the rose opens, giving fake
%               shadow on top of lights.
%   'custom'  — User-defined colormap with distance-based CData (no
%               evolution). Select a preset by name using roseColormap().
colormapMode = 'dynamic';

% Custom colormap preset (used when colormapMode = 'custom').
% Call roseColormap('name') — see the function at the end of this file
% for the full list of available presets, or pass your own 256×3 matrix.
%
% ──── Real rose varieties ────
%   'aobara'         — deep violet-blue to soft lavender (Suntory Applause)
%   'true blue'      — deep navy to bright cobalt (dyed Ecuadorian)
%   'mint green'     — fresh mint to bright green
%   'black baccara'  — near-black burgundy to deep velvety red
%   'classic red'    — dark crimson to bright scarlet
%   'juliet'         — warm apricot to soft peach (David Austin)
%   'amnesia'        — dusty lavender-grey to soft mauve-pink
%   'quicksand'      — sandy champagne to warm blush
%   'sahara'         — pale sand to golden cream
%   'coral reef'     — deep coral to warm salmon-pink
%   'hot pink'       — deep magenta to vibrant hot pink
%   'blush'          — pale dusty rose to soft baby pink
%   'ocean song'     — cool lilac-purple to silvery lavender
%   'golden mustard' — deep amber to buttery gold
%   'ivory'          — warm cream to pale white
%   'free spirit'    — burnt orange to bright tangerine
%   'burgundy'       — near-black plum to deep wine
%   'rose gold'      — coppery bronze to soft metallic pink
%   'white mondial'  — pale sage to pure white (green-tinted)
%   'shocking blue'  — deep plum-purple to bright magenta-violet
%   'cafe latte'     — espresso brown to warm beige
%
% ──── Imaginary / Exotic ──── (better with fixed CLim)
%   'cyberwave'      — electric cyan to hot magenta
%   'solar flare'    — deep molten red through orange to white-hot
%   'abyssal'        — ocean trench black to bioluminescent teal
%   'nebula'         — deep space indigo through violet to rose-pink
%   'molten gold'    — black through amber to white gold
%   'frozen'         — deep steel-blue through ice-white to faint violet
%   'radioactive'    — blackish green to neon lime
%   'obsidian flame' — jet black through dark cherry to bright ember
%   'aurora borealis'— deep navy through teal and green to violet
%   'phantom orchid' — ghostly silver-white to deep violet

customColormap = roseColormap('aobara');

% Color limits for custom mode.
%   'auto'   — MATLAB rescales CLim each frame (mapping shifts as rose opens)
%   [lo hi]  — Fixed mapping so colors stay consistent across all frames
%              [0 1.6] is a good default for most presets.
customCLim = 'auto';

%% ========== LIGHTING PARAMETERS ==========
% lightingMode controls which surfaces receive Gouraud shading:
%   'full'   — Everything lit (rose + stem + sepals + thorns)
%   'hybrid' — Only stem/sepals/thorns lit; rose relies on colormap for depth
%   'none'   — Nothing lit; all depth from colormap or flat shading (matte)
lightingMode = 'full';

switch lightingMode
    case 'full',   roseLighting = 'gouraud'; stemLighting = 'gouraud';
    case 'hybrid', roseLighting = 'none';    stemLighting = 'gouraud';
    case 'none',   roseLighting = 'none';    stemLighting = 'none';
end

% --- Apply scene preset (overrides the settings above) ---
if ~strcmp(scenePreset, 'custom')
    [colormapMode, customColormap, customCLim, lightingMode] = rosePreset(scenePreset);
    switch lightingMode
        case 'full',   roseLighting = 'gouraud'; stemLighting = 'gouraud';
        case 'hybrid', roseLighting = 'none';    stemLighting = 'gouraud';
        case 'none',   roseLighting = 'none';    stemLighting = 'none';
    end
end

%% ========== ROSE GEOMETRY ==========
r     = linspace(0, 1, n);
theta = linspace(-2, 20*pi, n);
[R, THETA] = ndgrid(r, theta);
x = 1 - (1/2)*((5/4)*(1 - mod(petalNum*THETA, 2*pi)/pi).^2 - 1/4).^2;

% Animation curves (Ludlam)
f_norm     = linspace(1, 48, nFrames);
openness   = 1.05 - cospi(f_norm/(48/2.5)) .* (1 - f_norm/48).^2;
opencenter = openness * 0.2;

%% Precompute rose frames
XFrames = zeros(n, n, nFrames);
YFrames = zeros(n, n, nFrames);
ZFrames = zeros(n, n, nFrames);

for k = 1:nFrames
    phi = (pi/2) * linspace(opencenter(k), openness(k), n).^2;
    y   = A*(R.^2).*(B*R - 1).^2.*sin(phi);
    R2  = x.*(R.*sin(phi) + y.*cos(phi));
    XFrames(:,:,k) = R2.*sin(THETA);
    YFrames(:,:,k) = R2.*cos(THETA);
    ZFrames(:,:,k) = x.*(R.*cos(phi) - y.*sin(phi));
end

%% ========== STEM CONSTRUCTION ==========
% Bézier spine: gentle S-curve from rose base downward
% Control points: P0 at rose center, P3 at bottom
P0 = [0,          0,          0];
P1 = [0,          0,         -stemLength*0.35];
P2 = [stemCurveX, stemCurveY, -stemLength*0.65];
P3 = [stemCurveX*0.8, stemCurveY*0.6, -stemLength];

t_bez = linspace(0, 1, nStemLen)';
% Bézier curve
spine = (1-t_bez).^3 .* P0 + ...
        3*(1-t_bez).^2 .* t_bez .* P1 + ...
        3*(1-t_bez) .* t_bez.^2 .* P2 + ...
        t_bez.^3 .* P3;

% Tangent vector (derivative of cubic Bézier)
tangent = 3*(1-t_bez).^2 .* (P1-P0) + ...
          6*(1-t_bez) .* t_bez .* (P2-P1) + ...
          3*t_bez.^2 .* (P3-P2);
tangent = tangent ./ vecnorm(tangent, 2, 2);

% Build Frenet-like frame using a fixed reference direction
refVec = [1, 0, 0];
normal   = cross(tangent, repmat(refVec, nStemLen, 1), 2);
normal   = normal ./ vecnorm(normal, 2, 2);
binormal = cross(tangent, normal, 2);
binormal = binormal ./ vecnorm(binormal, 2, 2);

% Radius profile: slight bulge near top (calyx base), then taper
r_profile = stemRadiusTop + (stemRadiusBot - stemRadiusTop) * t_bez;
% Add a subtle bulge at the very top for the calyx junction
r_profile = r_profile + 0.02 * exp(-((t_bez)/0.06).^2);

% Sweep circle along spine
phi_circ = linspace(0, 2*pi, nStemCirc);
Xstem = zeros(nStemLen, nStemCirc);
Ystem = zeros(nStemLen, nStemCirc);
Zstem = zeros(nStemLen, nStemCirc);

for i = 1:nStemLen
    for j = 1:nStemCirc
        offset = r_profile(i) * (normal(i,:)*cos(phi_circ(j)) + binormal(i,:)*sin(phi_circ(j)));
        Xstem(i,j) = spine(i,1) + offset(1);
        Ystem(i,j) = spine(i,2) + offset(2);
        Zstem(i,j) = spine(i,3) + offset(3);
    end
end

%% ========== CALYX (SEPALS) ==========
% Each sepal: a small pointed leaf surface that cups the rose base
% Parametric surface: u = along length (0=base, 1=tip), v = across width
nSu = 15;  nSv = 10;
u_sep = linspace(0, 1, nSu)';
v_sep = linspace(-1, 1, nSv);

% Sepal shape: pointed at tip, widest at ~40% along length
sepalWidthProfile = sepalWidth * sin(pi * u_sep).^0.6;
% Taper to point
sepalWidthProfile = sepalWidthProfile .* (1 - u_sep.^3);

% Local coordinates (before rotation)
% x_local: width direction
% y_local: not used (radial outward handled by rotation)
% z_local: upward + outward curve
xLocal = sepalWidthProfile .* v_sep;
% Sepal curves upward from stem, then droops outward
zLocal = sepalLength * u_sep .* (1 - 0.5*u_sep) + sepalDroop * u_sep.^2;
% Radial outward displacement increases along length
rLocal = stemRadiusTop * (1 - u_sep*0.3) + sepalLength * 0.4 * u_sep.^1.5;

% Store all sepal surfaces
sepalSurfs = struct('X', {}, 'Y', {}, 'Z', {});

for s = 1:nSepals
    ang = (s-1) * 2*pi/nSepals + pi/10;  % slight offset so sepals don't align with thorns

    Xs = rLocal .* cos(ang) + xLocal * (-sin(ang));
    Ys = rLocal .* sin(ang) + xLocal * cos(ang);
    Zs = zLocal;

    % Add slight cupping: inner surface curves inward
    cupFactor = 0.02 * (1 - v_sep.^2);
    Zs = Zs + cupFactor .* u_sep;

    sepalSurfs(s).X = Xs;
    sepalSurfs(s).Y = Ys;
    sepalSurfs(s).Z = Zs;
end

%% ========== THORNS ==========
% Each thorn: a small cone surface, positioned along the stem
% Placed at alternating rotational positions
nTu = 8;  nTv = 10;
u_th = linspace(0, 1, nTu);
v_th = linspace(0, 2*pi, nTv);
[Uth, Vth] = meshgrid(u_th, v_th);

% Basic cone (radius decreases to 0 at tip, slight curve upward)
R_cone = thornRadius * (1 - Uth).^1.5;
X_cone = R_cone .* cos(Vth);
Y_cone = R_cone .* sin(Vth);
Z_cone = thornHeight * Uth;

% Place thorns at specific spine positions (avoid top/bottom extremes)
thornPositions = linspace(0.12, 0.85, nThorns);
thornAngles    = linspace(0, 2*pi, nThorns+1); thornAngles(end) = [];
thornAngles    = thornAngles + pi/7;  % offset from sepals

thornSurfs = struct('X', {}, 'Y', {}, 'Z', {});

for th = 1:nThorns
    % Find spine position
    idx = round(thornPositions(th) * (nStemLen-1)) + 1;
    basePos = spine(idx, :);
    T = tangent(idx, :);
    N = normal(idx, :);
    B_vec = binormal(idx, :);

    % Outward direction for this thorn
    ang = thornAngles(th);
    outDir = N * cos(ang) + B_vec * sin(ang);

    % Thorn points upward-outward: blend outDir with slight upward
    % The thorn axis tilts ~30° upward from the outward direction
    thornAxis = outDir * cos(pi/6) + (-T) * sin(pi/6);  % -T is upward (stem goes down)
    thornAxis = thornAxis / norm(thornAxis);

    % Build a local frame for the thorn
    % thornAxis is the main direction, need two perpendicular vectors
    if abs(dot(thornAxis, [1,0,0])) < 0.9
        perpRef = [1,0,0];
    else
        perpRef = [0,1,0];
    end
    thornN = cross(thornAxis, perpRef);
    thornN = thornN / norm(thornN);
    thornB = cross(thornAxis, thornN);
    thornB = thornB / norm(thornB);

    % Transform cone to world coordinates
    Xt = zeros(size(X_cone));
    Yt = zeros(size(X_cone));
    Zt = zeros(size(X_cone));

    for i = 1:numel(X_cone)
        localPt = X_cone(i)*thornN + Y_cone(i)*thornB + Z_cone(i)*thornAxis;
        worldPt = basePos + r_profile(idx)*outDir + localPt;
        Xt(i) = worldPt(1);
        Yt(i) = worldPt(2);
        Zt(i) = worldPt(3);
    end

    thornSurfs(th).X = Xt;
    thornSurfs(th).Y = Yt;
    thornSurfs(th).Z = Zt;
end

%% ========== FIGURE SETUP ==========
close all
fig = figure('Color', 'k', 'Units', 'pixels', 'Name', 'Blooming Rose', 'NumberTitle', 'off');
fig.Position(3:4) = [600 700];
movegui(fig, 'center');
ax  = axes('Parent', fig);
hold(ax, 'on');

% --- Draw stem ---
hStem = surf(ax, Xstem, Ystem, Zstem, ...
    'FaceColor', stemColor, 'EdgeColor', 'none', ...
    'FaceLighting', stemLighting, 'AmbientStrength', 0.4, ...
    'DiffuseStrength', 0.7, 'SpecularStrength', 0.2);

% Cap the bottom of the stem with a patch
patch(ax, 'Vertices', [Xstem(end,:)' Ystem(end,:)' Zstem(end,:)'], ...
    'Faces', 1:nStemCirc, ...
    'FaceColor', stemColor, 'EdgeColor', 'none', ...
    'FaceLighting', stemLighting);

% --- Draw sepals ---
for s = 1:nSepals
    surf(ax, sepalSurfs(s).X, sepalSurfs(s).Y, sepalSurfs(s).Z, ...
        'FaceColor', sepalColor, 'EdgeColor', 'none', ...
        'FaceLighting', stemLighting, 'AmbientStrength', 0.4, ...
        'DiffuseStrength', 0.7, 'BackFaceLighting', 'lit');
end

% --- Draw thorns ---
for th = 1:nThorns
    surf(ax, thornSurfs(th).X, thornSurfs(th).Y, thornSurfs(th).Z, ...
        'FaceColor', thornColor, 'EdgeColor', 'none', ...
        'FaceLighting', stemLighting, 'AmbientStrength', 0.3);
end

% --- Draw rose ---
if ismember(colormapMode, {'dynamic', 'custom'})
    C0 = hypot(hypot(XFrames(:,:,1), YFrames(:,:,1)), ZFrames(:,:,1)*0.9);
    hSurf = surf(ax, XFrames(:,:,1), YFrames(:,:,1), ZFrames(:,:,1), C0, ...
        'LineStyle', 'none', 'FaceColor', 'interp', 'FaceLighting', roseLighting);
    if strcmp(colormapMode, 'dynamic')
        colormap(ax, [linspace((48-1)/48, 1, 256).^2; zeros(1,256); zeros(1,256)]');
    else
        colormap(ax, customColormap);
        if isnumeric(customCLim)
            caxis(ax, customCLim); %#ok<CAXIS>
        end
    end
else % static
    red_map = linspace(1, 0.25, 10)';
    red_map(:,2) = 0;
    red_map(:,3) = 0;
    hSurf = surf(ax, XFrames(:,:,1), YFrames(:,:,1), ZFrames(:,:,1), ...
        'LineStyle', 'none', 'FaceLighting', roseLighting);
    colormap(ax, red_map);
end

% --- Lighting and camera ---
view(ax, [-40.50 30.00]);
axis(ax, 'equal', 'off');

% Axis limits: accommodate both rose and stem
pad = 0.15;
ax.XLim = [min(min(XFrames(:,:,end),[],'all'), min(Xstem(:)))-pad, max(max(XFrames(:,:,end),[],'all'), max(Xstem(:)))+pad];
ax.YLim = [min(min(YFrames(:,:,end),[],'all'), min(Ystem(:)))-pad, max(max(YFrames(:,:,end),[],'all'), max(Ystem(:)))+pad];
ax.ZLim = [min(min(ZFrames(:,:,end),[],'all'), min(Zstem(:)))-pad, max(max(ZFrames(:,:,end),[],'all'), max(Zstem(:)))+pad];

% Lights — active surfaces controlled by roseLighting / stemLighting
camlight('headlight');
light(ax, 'Position', [0 0 5],  'Style', 'infinite');
light(ax, 'Position', [2 2 3],  'Style', 'infinite');
light(ax, 'Position', [-2 -1 -1], 'Style', 'infinite', 'Color', [0.3 0.3 0.3]);

% Prevent hover lag
ax.Toolbar = [];
ax.Interactions = rotateInteraction;
enableDefaultInteractivity(ax)
fig.Pointer = 'arrow';

%% ========== PLAYBACK ==========
% Loops until q / x / Esc. Press Space to pause/unpause.
fig.UserData.stop  = false;
fig.UserData.pause = false;
fig.KeyPressFcn = @(~,evt) localKeyHandler(evt, fig);

ax.Position = [0 0 1 1];

if recordFrames
    frames = {};
end

while isvalid(fig) && ~fig.UserData.stop
    for k = 1:nFrames
        if ~isvalid(fig) || fig.UserData.stop, break; end

        % Spin while paused
        while isvalid(fig) && fig.UserData.pause && ~fig.UserData.stop
            drawnow;
            pause(0.05);
        end

        Xr = XFrames(:,:,k);
        Yr = YFrames(:,:,k);
        Zr = ZFrames(:,:,k);

        if strcmp(colormapMode, 'dynamic')
            C = hypot(hypot(Xr, Yr), Zr*0.9);
            set(hSurf, 'XData', Xr, 'YData', Yr, 'ZData', Zr, 'CData', C);
            colormap(ax, [linspace((48-f_norm(k))/48, 1, 256).^2; zeros(1,256); zeros(1,256)]');
        elseif strcmp(colormapMode, 'custom')
            C = hypot(hypot(Xr, Yr), Zr*0.9);
            set(hSurf, 'XData', Xr, 'YData', Yr, 'ZData', Zr, 'CData', C);
        else
            set(hSurf, 'XData', Xr, 'YData', Yr, 'ZData', Zr);
        end

        drawnow;

        if recordFrames && isvalid(ax)
            frames{end+1} = getframe(ax); %#ok<SAGROW>
        end
    end

    % Only record one pass
    if recordFrames
        break;
    end
end

if isvalid(fig), close(fig); end

% --- Crop recorded frames (vectorized) ---
recordingComplete = recordFrames && numel(frames) == nFrames;
if recordingComplete && ~isequal(cropFrames, false)
    if isnumeric(cropFrames) && numel(cropFrames) == 4
        margins = cropFrames;          % [Left Right Top Bottom]
    else
        margins = [0.15 0.15 0.10 0.15];
    end
    [h, w, ~] = size(frames{1}.cdata);
    c1 = round(w * margins(1)) + 1;   c2 = round(w * (1 - margins(2)));
    r1 = round(h * margins(3)) + 1;   r2 = round(h * (1 - margins(4)));
    cdataCell = cellfun(@(f) f.cdata, frames, 'UniformOutput', false);
    allData = cat(4, cdataCell{:});               % H × W × 3 × nFrames
    allData = allData(r1:r2, c1:c2, :, :);        % crop once
    for k = 1:numel(frames)
        frames{k}.cdata = allData(:,:,:,k);
    end
    clear allData
end

% --- Show export dialog (loops until user cancels) ---
if recordingComplete
    frameData = cellfun(@(f) f.cdata, frames, 'UniformOutput', false);
    while true
        [fmt, fps, dith] = showExportDialog(numel(frameData));
        if isempty(fmt), break; end
        try
            switch fmt
                case 'mp4'
                    [file, path] = uiputfile('*.mp4', 'Save Video', 'BloomingRose.mp4');
                    if file ~= 0
                        exportToVideo(frameData, fullfile(path, file), fps);
                    end
                case 'gif'
                    [file, path] = uiputfile('*.gif', 'Save GIF', 'BloomingRose.gif');
                    if file ~= 0
                        exportToGIF(frameData, fullfile(path, file), fps, dith);
                    end
                case 'png'
                    folder = uigetdir(pwd, 'Select Folder for PNG Sequence');
                    if folder ~= 0
                        exportToPNG(frameData, folder);
                    end
            end
        catch ME
            h = errordlg(sprintf('Export failed:\n%s', ME.message), 'Export Error');
            centerDialog(h);
            uiwait(h);
        end
    end
end

%% ========== LOCAL FUNCTIONS ==========

function localKeyHandler(evt, fig)
%LOCALKEYHANDLER  Handle keyboard input for playback control.
    if ismember(evt.Key, {'q', 'x', 'escape'})
        fig.UserData.stop = true;
    elseif strcmp(evt.Key, 'space')
        fig.UserData.pause = ~fig.UserData.pause;
    end
end

function [fmt, fps, dith] = showExportDialog(frameCount)
%SHOWEXPORTDIALOG  Modal dialog to choose export format, FPS, and dithering.
    fmt  = [];
    fps  = 60;
    dith = true;

    baseW = 220;  expandedW = 330;  dlgH = 160;

    dlg = uifigure('Name', 'Export Recording', ...
        'Position', [0 0 expandedW dlgH], ...
        'Resize', 'off', 'WindowStyle', 'modal', ...
        'Color', [0.15 0.15 0.15], ...
        'Visible', 'off');

    uilabel(dlg, 'Text', sprintf('Export %d frames as:', frameCount), ...
        'Position', [0 120 baseW 22], ...
        'FontColor', 'w', 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center');

    fmtDrop = uidropdown(dlg, ...
        'Items', {'MP4 Video', 'Animated GIF', 'PNG Sequence'}, ...
        'ItemsData', {'mp4', 'gif', 'png'}, ...
        'Value', 'mp4', ...
        'Position', [(baseW-160)/2 80 160 26], ...
        'ValueChangedFcn', @(~,~) updateLayout());

    % MP4: clapper icon (right panel)
    fpsIcon = uilabel(dlg, 'Text', char([55356 57260]), ...
        'Position', [225 95 80 45], 'FontSize', 38, ...
        'HorizontalAlignment', 'center');
    fpsLbl = uilabel(dlg, 'Text', 'Video FPS:', ...
        'Position', [225 58 80 20], ...
        'FontColor', [0.7 0.7 0.7], ...
        'HorizontalAlignment', 'center');
    fpsSpin = uispinner(dlg, ...
        'Position', [225 25 80 30], ...
        'Value', 60, 'Limits', [1 240], 'Step', 5, ...
        'ValueDisplayFormat', '%.0f fps');

    % GIF: artist palette icon (right panel)
    gifIcon = uilabel(dlg, 'Text', char([55356 57256]), ...
        'Position', [225 105 80 40], 'FontSize', 34, ...
        'HorizontalAlignment', 'center', 'Visible', 'off');
    dithCheck = uicheckbox(dlg, ...
        'Text', 'Dithering', ...
        'Value', true, ...
        'Position', [235 18 80 22], ...
        'FontColor', [0.7 0.7 0.7], ...
        'Visible', 'off');

    uibutton(dlg, 'push', 'Text', 'Cancel', ...
        'Position', [25 25 70 30], ...
        'ButtonPushedFcn', @(~,~) close(dlg));
    uibutton(dlg, 'push', 'Text', 'Export', ...
        'Position', [115 25 70 30], ...
        'BackgroundColor', [0.2 0.5 0.3], 'FontColor', 'w', ...
        'ButtonPushedFcn', @(~,~) onExport());

    movegui(dlg, 'center');
    dlg.Visible = 'on';
    uiwait(dlg);

    function updateLayout()
        isMp4 = strcmp(fmtDrop.Value, 'mp4');
        isGif = strcmp(fmtDrop.Value, 'gif');
        showExtra = isMp4 || isGif;
        if showExtra
            dlg.Position(3) = expandedW;
        else
            dlg.Position(3) = baseW;
        end
        fpsIcon.Visible   = matlab.lang.OnOffSwitchState(isMp4);
        gifIcon.Visible   = matlab.lang.OnOffSwitchState(isGif);
        fpsLbl.Visible    = matlab.lang.OnOffSwitchState(isMp4 || isGif);
        fpsSpin.Visible   = matlab.lang.OnOffSwitchState(isMp4 || isGif);
        dithCheck.Visible = matlab.lang.OnOffSwitchState(isGif);
        if isGif
            fpsLbl.Text = 'FPS:';
            fpsLbl.Position(2) = 72;
            fpsSpin.Position(2) = 44;
        else
            fpsLbl.Text = 'Video FPS:';
            fpsLbl.Position(2) = 58;
            fpsSpin.Position(2) = 25;
        end
    end

    function onExport()
        fmt  = fmtDrop.Value;
        fps  = fpsSpin.Value;
        dith = dithCheck.Value;
        close(dlg);
    end
end

function exportToVideo(frameData, filepath, fps)
%EXPORTTOVIDEO  Write frames to an MP4 file.
    try
        nF = numel(frameData);
        wb = waitbar(0, 'Exporting video...');
        v = VideoWriter(filepath, 'MPEG-4');
        v.FrameRate = fps;
        v.Quality   = 95;
        open(v);
        for i = 1:nF
            writeVideo(v, frameData{i});
            if mod(i, 20) == 0 || i == nF
                waitbar(i/nF, wb, sprintf('Exporting video... %d/%d', i, nF));
            end
        end
        close(v);
        close(wb);
        h = msgbox(sprintf('Video saved to:\n%s\n(%d fps)', filepath, fps), ...
            'Export Complete', 'help');
        centerDialog(h);
        uiwait(h);
    catch ME
        if exist('wb', 'var') && isvalid(wb), close(wb); end
        errordlg(ME.message, 'Export Error');
    end
end

function exportToGIF(frameData, filepath, fps, useDither)
%EXPORTTOGIF  Write frames to an animated GIF with optional dithering.
    try
        nF = numel(frameData);
        delayTime = 1 / fps;
        if useDither
            ditherMode = 'dither';
        else
            ditherMode = 'nodither';
        end

        wb = waitbar(0, 'Exporting GIF (building colormap)...');

        % Build global colormap from sampled frames
        sampleIdx = unique(round(linspace(1, nF, min(10, nF))));
        sampledPix = [];
        for idx = sampleIdx
            img = frameData{idx};
            sampled = img(1:4:end, 1:4:end, :);
            sampledPix = [sampledPix; reshape(sampled, [], 3)]; %#ok<AGROW>
        end
        [~, globalCmap] = rgb2ind(reshape(sampledPix, [], 1, 3), 256, ditherMode);

        waitbar(0, wb, 'Exporting GIF...');
        for i = 1:nF
            indexedImg = rgb2ind(frameData{i}, globalCmap, ditherMode);
            if i == 1
                imwrite(indexedImg, globalCmap, filepath, 'gif', ...
                    'LoopCount', Inf, 'DelayTime', delayTime);
            else
                imwrite(indexedImg, globalCmap, filepath, 'gif', ...
                    'WriteMode', 'append', 'DelayTime', delayTime);
            end
            if mod(i, 20) == 0 || i == nF
                waitbar(i/nF, wb, sprintf('Exporting GIF... %d/%d', i, nF));
            end
        end
        close(wb);
        h = msgbox(sprintf('GIF saved to:\n%s', filepath), 'Export Complete', 'help');
        centerDialog(h);
        uiwait(h);
    catch ME
        if exist('wb', 'var') && isvalid(wb), close(wb); end
        errordlg(ME.message, 'Export Error');
    end
end

function exportToPNG(frameData, folderpath)
%EXPORTTOPNG  Write frames as a numbered PNG sequence.
    try
        nF = numel(frameData);
        wb = waitbar(0, 'Exporting PNG sequence...');
        numDigits = max(4, ceil(log10(nF + 1)));
        fmtStr = sprintf('frame_%%0%dd.png', numDigits);
        for i = 1:nF
            imwrite(frameData{i}, fullfile(folderpath, sprintf(fmtStr, i)));
            if mod(i, 20) == 0 || i == nF
                waitbar(i/nF, wb, sprintf('Exporting PNG... %d/%d', i, nF));
            end
        end
        close(wb);
        h = msgbox(sprintf('%d frames saved to:\n%s', nF, folderpath), ...
            'Export Complete', 'help');
        centerDialog(h);
        uiwait(h);
    catch ME
        if exist('wb', 'var') && isvalid(wb), close(wb); end
        errordlg(ME.message, 'Export Error');
    end
end

function centerDialog(h)
%CENTERDIALOG  Move a dialog figure to the center of the current monitor.
    if isvalid(h)
        movegui(h, 'center');
    end
end

function [cMode, cMap, cLim, lMode] = rosePreset(name)
%ROSEPRESET  Return bundled colormap/lighting settings for a scene preset.
%
%   [colormapMode, customColormap, customCLim, lightingMode] = rosePreset(NAME)

    switch lower(name)
        case 'classic'
            cMode = 'dynamic';  cMap = [];                          cLim = 'auto';     lMode = 'full';
        case 'dark velvet'
            cMode = 'custom';   cMap = roseColormap('black baccara'); cLim = [0 1.6];  lMode = 'full';
        case 'rose gold'
            cMode = 'custom';   cMap = roseColormap('rose gold');    cLim = 'auto';    lMode = 'full';
        case 'aurora'
            cMode = 'custom';   cMap = roseColormap('aurora borealis'); cLim = 'auto'; lMode = 'full';
        case 'neon'
            cMode = 'custom';   cMap = roseColormap('cyberwave');    cLim = 'auto';    lMode = 'none';
        case 'frozen'
            cMode = 'custom';   cMap = roseColormap('frozen');       cLim = [0 1.6];   lMode = 'hybrid';
        case 'solar'
            cMode = 'custom';   cMap = roseColormap('solar flare');  cLim = [0 1.6];   lMode = 'none';
        case 'matte red'
            cMode = 'dynamic';  cMap = [];                          cLim = 'auto';     lMode = 'none';
        case 'phantom'
            cMode = 'custom';   cMap = roseColormap('phantom orchid'); cLim = [0 1.6]; lMode = 'hybrid';
        case 'radioactive'
            cMode = 'custom';   cMap = roseColormap('radioactive');  cLim = [0 1.6];   lMode = 'none';
        case 'winter'
            cMode = 'custom';   cMap = roseColormap('winter');       cLim = [0 1.6];   lMode = 'full';
        case 'turbo'
            cMode = 'custom';   cMap = roseColormap('turbo');        cLim = 'auto';    lMode = 'full';
        otherwise
            error('rosePreset:unknownName', ...
                'Unknown preset "%s".\nAvailable: classic, matte red, dark velvet, rose gold, aurora, neon, frozen, solar, phantom, radioactive, winter, turbo.', name);
    end
end

function cmap = roseColormap(name)
%ROSECOLORMAP  Return a 256×3 colormap for the blooming rose.
%
%   cmap = roseColormap(NAME) returns one of 31 preset colormaps.
%   Presets are divided into two families:
%
%     REAL ROSE VARIETIES — colors modeled after actual cultivars.
%     IMAGINARY / EXOTIC  — artistic palettes (often better with fixed CLim).
%
%   If NAME is not recognized, the function tries it as a MATLAB built-in
%   colormap name (e.g. 'turbo', 'hot', 'winter'). If that also fails,
%   it lists all available presets and throws an error.
%
%   Examples:
%       colormap(roseColormap('black baccara'));
%       colormap(roseColormap('solar flare'));
%       colormap(roseColormap('turbo'));

    t = linspace(0, 1, 256)';

    switch lower(name)

        % ──────────── REAL ROSE VARIETIES ────────────

        case 'aobara'
            % Deep violet-blue to soft lavender (Suntory Applause)
            cmap = [lerp(0.12, 0.72, t), lerp(0.05, 0.45, t), lerp(0.28, 0.82, t)];

        case 'true blue'
            % Deep navy to bright cobalt (dyed Ecuadorian)
            cmap = [lerp(0.02, 0.18, t), lerp(0.04, 0.38, t), lerp(0.18, 0.78, t)];

        case 'mint green'
            % Fresh mint to bright green
            cmap = [lerp(0.1, 0.85, t), lerp(0.35, 1, t), lerp(0.25, 0.75, t)];

        case 'black baccara'
            % Near-black burgundy to deep velvety red
            cmap = [lerp(0.08, 0.55, t), lerp(0.01, 0.02, t), lerp(0.03, 0.06, t)];

        case 'classic red'
            % Dark crimson to bright scarlet
            cmap = [lerp(0.25, 1.0, t), lerp(0.0, 0.08, t), lerp(0.02, 0.05, t)];

        case 'juliet'
            % Warm apricot to soft peach (David Austin)
            cmap = [lerp(0.55, 1.0, t), lerp(0.22, 0.72, t), lerp(0.10, 0.50, t)];

        case 'amnesia'
            % Dusty lavender-grey to soft mauve-pink
            cmap = [lerp(0.35, 0.76, t), lerp(0.28, 0.58, t), lerp(0.38, 0.64, t)];

        case 'quicksand'
            % Sandy champagne to warm blush
            cmap = [lerp(0.45, 0.90, t), lerp(0.32, 0.72, t), lerp(0.28, 0.62, t)];

        case 'sahara'
            % Pale sand to golden cream
            cmap = [lerp(0.50, 0.95, t), lerp(0.38, 0.82, t), lerp(0.18, 0.55, t)];

        case 'coral reef'
            % Deep coral to warm salmon-pink
            cmap = [lerp(0.45, 0.98, t), lerp(0.12, 0.52, t), lerp(0.10, 0.45, t)];

        case 'hot pink'
            % Deep magenta to vibrant hot pink
            cmap = [lerp(0.35, 1.0, t), lerp(0.02, 0.28, t), lerp(0.18, 0.52, t)];

        case 'blush'
            % Pale dusty rose to soft baby pink
            cmap = [lerp(0.55, 0.96, t), lerp(0.35, 0.75, t), lerp(0.38, 0.76, t)];

        case 'ocean song'
            % Cool lilac-purple to silvery lavender
            cmap = [lerp(0.28, 0.68, t), lerp(0.18, 0.52, t), lerp(0.42, 0.78, t)];

        case 'golden mustard'
            % Deep amber to buttery gold
            cmap = [lerp(0.45, 0.95, t), lerp(0.28, 0.75, t), lerp(0.02, 0.12, t)];

        case 'ivory'
            % Warm cream to pale white
            cmap = [lerp(0.65, 1.0, t), lerp(0.58, 0.96, t), lerp(0.45, 0.88, t)];

        case 'free spirit'
            % Burnt orange to bright tangerine
            cmap = [lerp(0.50, 1.0, t), lerp(0.15, 0.55, t), lerp(0.02, 0.12, t)];

        case 'burgundy'
            % Near-black plum to deep wine
            cmap = [lerp(0.12, 0.50, t), lerp(0.02, 0.05, t), lerp(0.06, 0.15, t)];

        case 'rose gold'
            % Coppery bronze to soft metallic pink
            cmap = [lerp(0.42, 0.92, t), lerp(0.22, 0.58, t), lerp(0.18, 0.48, t)];

        case 'white mondial'
            % Pale sage to pure white (green-tinted, like Mondial)
            cmap = [lerp(0.60, 1.0, t), lerp(0.68, 1.0, t), lerp(0.55, 0.95, t)];

        case 'shocking blue'
            % Deep plum-purple to bright magenta-violet
            cmap = [lerp(0.20, 0.60, t), lerp(0.05, 0.18, t), lerp(0.30, 0.65, t)];

        case 'cafe latte'
            % Espresso brown to warm beige
            cmap = [lerp(0.25, 0.75, t), lerp(0.15, 0.58, t), lerp(0.08, 0.42, t)];

        % ──────────── IMAGINARY / EXOTIC ────────────

        case 'cyberwave'
            % Electric cyan to hot magenta
            cmap = [lerp(0.0, 1.0, t), lerp(0.85, 0.10, t), lerp(0.90, 0.80, t)];

        case 'solar flare'
            % Deep molten red through orange to white-hot
            cmap = [lerp(0.30, 1.0, t).^0.7, lerp(0.0, 0.95, t).^1.5, lerp(0.0, 0.70, t).^2.5];

        case 'abyssal'
            % Ocean trench black to bioluminescent teal
            cmap = [lerp(0.0, 0.10, t), lerp(0.02, 0.85, t), lerp(0.05, 0.65, t)];

        case 'nebula'
            % Deep space indigo through violet to rose-pink
            cmap = [lerp(0.08, 0.85, t), lerp(0.02, 0.30, t), lerp(0.22, 0.55, t)];

        case 'molten gold'
            % Black through amber to white gold
            cmap = [lerp(0.05, 1.0, t).^0.8, lerp(0.02, 0.88, t).^1.2, lerp(0.0, 0.40, t).^2.0];

        case 'frozen'
            % Deep steel-blue through ice-white to faint violet
            cmap = [lerp(0.10, 0.88, t), lerp(0.15, 0.92, t), lerp(0.30, 1.0, t)];

        case 'radioactive'
            % Blackish green to neon lime
            cmap = [lerp(0.02, 0.45, t), lerp(0.08, 1.0, t), lerp(0.0, 0.15, t)];

        case 'obsidian flame'
            % Jet black through dark cherry to bright ember
            cmap = [lerp(0.03, 1.0, t).^1.8, lerp(0.0, 0.25, t).^1.5, lerp(0.02, 0.05, t)];

        case 'aurora borealis'
            % Deep navy through teal and green to violet
            cmap = [0.5*sin(2*pi*t+4)+0.5, 0.5*sin(2*pi*t*0.8)+0.5, 0.5*sin(2*pi*t*0.6+2)+0.5];

        case 'phantom orchid'
            % Ghostly silver-white to deep violet
            cmap = [lerp(0.85, 0.30, t), lerp(0.85, 0.08, t), lerp(0.88, 0.55, t)];

        otherwise
            % Try as a MATLAB built-in colormap name
            try
                fn = str2func(name);
                cmap = fn(256);
            catch
                allNames = { ...
                    'aobara', 'true blue', 'mint green', 'black baccara', ...
                    'classic red', 'juliet', 'amnesia', 'quicksand', ...
                    'sahara', 'coral reef', 'hot pink', 'blush', ...
                    'ocean song', 'golden mustard', 'ivory', 'free spirit', ...
                    'burgundy', 'rose gold', 'white mondial', 'shocking blue', ...
                    'cafe latte', ...
                    'cyberwave', 'solar flare', 'abyssal', 'nebula', ...
                    'molten gold', 'frozen', 'radioactive', 'obsidian flame', ...
                    'aurora borealis', 'phantom orchid'};
                error('roseColormap:unknownName', ...
                    'Unknown colormap "%s".\nAvailable presets:\n  %s\n\nOr use any MATLAB built-in (e.g. ''turbo'', ''hot'', ''winter'').', ...
                    name, strjoin(allNames, ', '));
            end
    end
end

function v = lerp(a, b, t)
%LERP  Linear interpolation from A to B over parameter T.
    v = a + (b - a) * t;
end
