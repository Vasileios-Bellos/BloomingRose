%% Blooming Rose
% Rose head geometry adapted from Eric Ludlam's "Blooming Rose" (MATLAB Flipbook Mini Hack, 2023)
%
% Ref: https://uk.mathworks.com/matlabcentral/communitycontests/contests/6/entries/13857
%      https://github.com/zappo2/digital-art-with-matlab/tree/master/flowers
%
% Vasilis Bellos, 2026

[fig, ax] = initRose();

% ── Flower ──
nFrames  = 120;
n        = 250;
A        = 1.995653;
B        = 1.27689;
petalNum = 3.6;

% ── Stem ──
stemLength    = 3.2;
stemRadiusTop = 0.055;
stemRadiusBot = 0.042;
stemCurveX    = 0.25;
stemCurveY    = 0.12;
nStemLen      = 50;
nStemCirc     = 20;

% ── Sepals ──
nSepals     = 5;
sepalLength = 0.35;
sepalWidth  = 0.10;
sepalDroop  = 0.10;

% ── Thorns ──
nThorns     = 6;
thornHeight = 0.14;
thornRadius = 0.028;

% ── Colors ──
stemColor  = [0.18 0.42 0.15];
sepalColor = [0.22 0.50 0.18];
thornColor = [0.30 0.25 0.12];

% ── Scene preset ──
% 'custom' | 'classic' | 'matte red' | 'dark velvet' | 'rose gold' |
% 'aurora' | 'neon' | 'frozen' | 'solar' | 'phantom' | 'radioactive' |
% 'winter' | 'turbo'
scenePreset = 'classic';

% ── Manual overrides (used when scenePreset = 'custom') ──
colormapMode   = 'dynamic';       % 'static' | 'dynamic' | 'custom'
customColormap = roseColormap('aobara');
customCLim     = 'auto';          % 'auto' | [lo hi]
lightingMode   = 'full';          % 'full' | 'hybrid' | 'none'

% ═══════════════════════════════════════════════════════════════════════════

if ~strcmp(scenePreset, 'custom')
    [colormapMode, customColormap, customCLim, lightingMode] = rosePreset(scenePreset);
end

cfg = struct( ...
    'n',n, 'nFrames',nFrames, 'A',A, 'B',B, 'petalNum',petalNum, ...
    'stemLength',stemLength, 'stemRadiusTop',stemRadiusTop, 'stemRadiusBot',stemRadiusBot, ...
    'stemCurveX',stemCurveX, 'stemCurveY',stemCurveY, 'nStemLen',nStemLen, 'nStemCirc',nStemCirc, ...
    'nSepals',nSepals, 'sepalLength',sepalLength, 'sepalWidth',sepalWidth, 'sepalDroop',sepalDroop, ...
    'nThorns',nThorns, 'thornHeight',thornHeight, 'thornRadius',thornRadius, ...
    'stemColor',stemColor, 'sepalColor',sepalColor, 'thornColor',thornColor, ...
    'colormapMode',colormapMode, 'customCLim',customCLim, 'lightingMode',lightingMode);
cfg.customColormap = customColormap;

[hRose, frames] = drawRose(ax, cfg);
animateRose(fig, ax, hRose, frames, cfg);

%% Functions

function [fig, ax] = initRose()
%INITROSE  Create (or reuse) the figure and axes for the rose.
    fig = findobj('Type', 'figure', 'Tag', 'BloomingRose');
    if isempty(fig) || ~isvalid(fig)
        fig = figure('Color', 'k', 'Tag', 'BloomingRose');
    end
    clf(fig);
    ax = axes('Parent', fig);
    hold(ax, 'on');
end

function [hRose, frames] = drawRose(ax, cfg)
%DRAWROSE  Compute geometry, draw all surfaces, return rose handle and frame data.

    % Resolve lighting
    switch cfg.lightingMode
        case 'full',   roseLit = 'gouraud'; stemLit = 'gouraud';
        case 'hybrid', roseLit = 'none';    stemLit = 'gouraud';
        case 'none',   roseLit = 'none';    stemLit = 'none';
    end

    % Compute geometry
    [XF, YF, ZF, f_norm] = computeRoseFrames(cfg.n, cfg.nFrames, cfg.A, cfg.B, cfg.petalNum);
    [Xst, Yst, Zst, sepals, thorns] = computeStemSystem(cfg);

    % Draw stem
    surf(ax, Xst, Yst, Zst, ...
        'FaceColor', cfg.stemColor, 'EdgeColor', 'none', ...
        'FaceLighting', stemLit, 'AmbientStrength', 0.4, ...
        'DiffuseStrength', 0.7, 'SpecularStrength', 0.2);
    patch(ax, 'Vertices', [Xst(end,:)' Yst(end,:)' Zst(end,:)'], ...
        'Faces', 1:cfg.nStemCirc, 'FaceColor', cfg.stemColor, 'EdgeColor', 'none', ...
        'FaceLighting', stemLit);

    % Draw sepals
    for s = 1:cfg.nSepals
        surf(ax, sepals(s).X, sepals(s).Y, sepals(s).Z, ...
            'FaceColor', cfg.sepalColor, 'EdgeColor', 'none', ...
            'FaceLighting', stemLit, 'AmbientStrength', 0.4, ...
            'DiffuseStrength', 0.7, 'BackFaceLighting', 'lit');
    end

    % Draw thorns
    for th = 1:cfg.nThorns
        surf(ax, thorns(th).X, thorns(th).Y, thorns(th).Z, ...
            'FaceColor', cfg.thornColor, 'EdgeColor', 'none', ...
            'FaceLighting', stemLit, 'AmbientStrength', 0.3);
    end

    % Draw rose (bud)
    Xr = XF(:,:,1);  Yr = YF(:,:,1);  Zr = ZF(:,:,1);
    C0 = hypot(hypot(Xr, Yr), Zr*0.9);
    hRose = surf(ax, Xr, Yr, Zr, C0, ...
        'LineStyle', 'none', 'FaceColor', 'interp', 'FaceLighting', roseLit);

    % Colormap
    if strcmp(cfg.colormapMode, 'static')
        colormap(ax, [linspace(1, 0.25, 256)', zeros(256, 2)]);
    elseif strcmp(cfg.colormapMode, 'custom')
        colormap(ax, cfg.customColormap);
        if isnumeric(cfg.customCLim), caxis(ax, cfg.customCLim); end %#ok<CAXIS>
    end

    % Camera & lights
    view(ax, [-40.50 30.00]);
    axis(ax, 'equal', 'off');
    pad = 0.15;
    ax.XLim = [min(min(XF(:,:,end),[],'all'), min(Xst(:)))-pad, max(max(XF(:,:,end),[],'all'), max(Xst(:)))+pad];
    ax.YLim = [min(min(YF(:,:,end),[],'all'), min(Yst(:)))-pad, max(max(YF(:,:,end),[],'all'), max(Yst(:)))+pad];
    ax.ZLim = [min(min(ZF(:,:,end),[],'all'), min(Zst(:)))-pad, max(max(ZF(:,:,end),[],'all'), max(Zst(:)))+pad];
    ax.Position = [0 0 1 1];
    camlight('headlight');
    light(ax, 'Position', [0 0 5],  'Style', 'infinite');
    light(ax, 'Position', [2 2 3],  'Style', 'infinite');
    light(ax, 'Position', [-2 -1 -1], 'Style', 'infinite', 'Color', [0.3 0.3 0.3]);

    % Pack frame data for animation
    frames.XF = XF;
    frames.YF = YF;
    frames.ZF = ZF;
    frames.f_norm = f_norm;
end

function animateRose(fig, ax, hRose, frames, cfg)
%ANIMATEROSE  Play a single bloom pass.
    XF = frames.XF;  YF = frames.YF;  ZF = frames.ZF;
    f_norm = frames.f_norm;

    for k = 1:cfg.nFrames
        if ~isvalid(fig), break; end

        Xr = XF(:,:,k);  Yr = YF(:,:,k);  Zr = ZF(:,:,k);

        if strcmp(cfg.colormapMode, 'dynamic')
            C = hypot(hypot(Xr, Yr), Zr*0.9);
            set(hRose, 'XData', Xr, 'YData', Yr, 'ZData', Zr, 'CData', C);
            colormap(ax, [linspace((48-f_norm(k))/48, 1, 256).^2; zeros(1,256); zeros(1,256)]');
        elseif strcmp(cfg.colormapMode, 'custom')
            C = hypot(hypot(Xr, Yr), Zr*0.9);
            set(hRose, 'XData', Xr, 'YData', Yr, 'ZData', Zr, 'CData', C);
        else
            set(hRose, 'XData', Xr, 'YData', Yr, 'ZData', Zr);
        end
        drawnow;
    end
end

function [XF, YF, ZF, f_norm] = computeRoseFrames(n, nFrames, A, B, petalNum)
    r_    = linspace(0, 1, n);
    theta_ = linspace(-2, 20*pi, n);
    [R, THETA] = ndgrid(r_, theta_);
    xEnv = 1 - (1/2)*((5/4)*(1 - mod(petalNum*THETA, 2*pi)/pi).^2 - 1/4).^2;

    f_norm     = linspace(1, 48, nFrames);
    openness   = 1.05 - cospi(f_norm/(48/2.5)) .* (1 - f_norm/48).^2;
    opencenter = openness * 0.2;

    XF = zeros(n, n, nFrames);
    YF = zeros(n, n, nFrames);
    ZF = zeros(n, n, nFrames);

    for k = 1:nFrames
        phi = (pi/2) * linspace(opencenter(k), openness(k), n).^2;
        y_  = A*(R.^2).*(B*R - 1).^2.*sin(phi);
        R2  = xEnv.*(R.*sin(phi) + y_.*cos(phi));
        XF(:,:,k) = R2.*sin(THETA);
        YF(:,:,k) = R2.*cos(THETA);
        ZF(:,:,k) = xEnv.*(R.*cos(phi) - y_.*sin(phi));
    end
end

function [Xst, Yst, Zst, sepals, thorns] = computeStemSystem(cfg)
    stemLength    = cfg.stemLength;
    stemRadiusTop = cfg.stemRadiusTop;
    stemRadiusBot = cfg.stemRadiusBot;
    stemCurveX    = cfg.stemCurveX;
    stemCurveY    = cfg.stemCurveY;
    nStemLen      = cfg.nStemLen;
    nStemCirc     = cfg.nStemCirc;
    nSepals       = cfg.nSepals;
    sepalLength   = cfg.sepalLength;
    sepalWidth    = cfg.sepalWidth;
    sepalDroop    = cfg.sepalDroop;
    nThorns       = cfg.nThorns;
    thornHeight   = cfg.thornHeight;
    thornRadius   = cfg.thornRadius;

    % Stem spine (cubic Bézier)
    P0 = [0, 0, 0];
    P1 = [0, 0, -stemLength*0.35];
    P2 = [stemCurveX, stemCurveY, -stemLength*0.65];
    P3 = [stemCurveX*0.8, stemCurveY*0.6, -stemLength];

    t_bez = linspace(0, 1, nStemLen)';
    spine = (1-t_bez).^3.*P0 + 3*(1-t_bez).^2.*t_bez.*P1 + ...
            3*(1-t_bez).*t_bez.^2.*P2 + t_bez.^3.*P3;

    tangent_ = 3*(1-t_bez).^2.*(P1-P0) + 6*(1-t_bez).*t_bez.*(P2-P1) + ...
               3*t_bez.^2.*(P3-P2);
    tangent_ = tangent_ ./ vecnorm(tangent_, 2, 2);

    refVec = [1, 0, 0];
    normal_  = cross(tangent_, repmat(refVec, nStemLen, 1), 2);
    normal_  = normal_ ./ vecnorm(normal_, 2, 2);
    binormal_ = cross(tangent_, normal_, 2);
    binormal_ = binormal_ ./ vecnorm(binormal_, 2, 2);

    r_profile = stemRadiusTop + (stemRadiusBot - stemRadiusTop)*t_bez;
    r_profile = r_profile + 0.02*exp(-((t_bez)/0.06).^2);

    % Stem tube
    phi_circ = linspace(0, 2*pi, nStemCirc);
    Xst = zeros(nStemLen, nStemCirc);
    Yst = zeros(nStemLen, nStemCirc);
    Zst = zeros(nStemLen, nStemCirc);
    for i = 1:nStemLen
        for j = 1:nStemCirc
            offset = r_profile(i)*(normal_(i,:)*cos(phi_circ(j)) + binormal_(i,:)*sin(phi_circ(j)));
            Xst(i,j) = spine(i,1) + offset(1);
            Yst(i,j) = spine(i,2) + offset(2);
            Zst(i,j) = spine(i,3) + offset(3);
        end
    end

    % Sepals
    nSu = 15;  nSv = 10;
    u_sep = linspace(0, 1, nSu)';
    v_sep = linspace(-1, 1, nSv);
    swp = sepalWidth * sin(pi*u_sep).^0.6 .* (1 - u_sep.^3);
    xLocal = swp .* v_sep;
    zLocal = sepalLength*u_sep.*(1 - 0.5*u_sep) + sepalDroop*u_sep.^2;
    rLocal = stemRadiusTop*(1 - u_sep*0.3) + sepalLength*0.4*u_sep.^1.5;

    sepals = struct('X', {}, 'Y', {}, 'Z', {});
    for s = 1:nSepals
        ang = (s-1)*2*pi/nSepals + pi/10;
        sepals(s).X = rLocal.*cos(ang) + xLocal*(-sin(ang));
        sepals(s).Y = rLocal.*sin(ang) + xLocal*cos(ang);
        sepals(s).Z = zLocal + 0.02*(1 - v_sep.^2).*u_sep;
    end

    % Thorns
    nTu = 8;  nTv = 10;
    [Uth, Vth] = meshgrid(linspace(0,1,nTu), linspace(0,2*pi,nTv));
    R_cone = thornRadius*(1 - Uth).^1.5;
    X_cone = R_cone.*cos(Vth);
    Y_cone = R_cone.*sin(Vth);
    Z_cone = thornHeight*Uth;

    tPos = linspace(0.12, 0.85, nThorns);
    tAng = linspace(0, 2*pi, nThorns+1); tAng(end) = [];
    tAng = tAng + pi/7;

    thorns = struct('X', {}, 'Y', {}, 'Z', {});
    for th = 1:nThorns
        idx = round(tPos(th)*(nStemLen-1)) + 1;
        basePos = spine(idx,:);
        T_ = tangent_(idx,:);
        N_ = normal_(idx,:);
        B_ = binormal_(idx,:);
        outDir = N_*cos(tAng(th)) + B_*sin(tAng(th));
        thornAxis = outDir*cos(pi/6) + (-T_)*sin(pi/6);
        thornAxis = thornAxis/norm(thornAxis);
        if abs(dot(thornAxis,[1,0,0])) < 0.9, perpRef = [1,0,0]; else, perpRef = [0,1,0]; end
        thornN = cross(thornAxis, perpRef); thornN = thornN/norm(thornN);
        thornB = cross(thornAxis, thornN);  thornB = thornB/norm(thornB);
        Xt = zeros(size(X_cone)); Yt = Xt; Zt = Xt;
        for i = 1:numel(X_cone)
            pt = X_cone(i)*thornN + Y_cone(i)*thornB + Z_cone(i)*thornAxis;
            w  = basePos + r_profile(idx)*outDir + pt;
            Xt(i) = w(1); Yt(i) = w(2); Zt(i) = w(3);
        end
        thorns(th).X = Xt;
        thorns(th).Y = Yt;
        thorns(th).Z = Zt;
    end
end

function [cMode, cMap, cLim, lMode] = rosePreset(name)
    switch lower(name)
        case 'classic'
            cMode = 'dynamic';  cMap = [];                              cLim = 'auto';    lMode = 'full';
        case 'matte red'
            cMode = 'dynamic';  cMap = [];                              cLim = 'auto';    lMode = 'none';
        case 'dark velvet'
            cMode = 'custom';   cMap = roseColormap('black baccara');   cLim = [0 1.6];   lMode = 'full';
        case 'rose gold'
            cMode = 'custom';   cMap = roseColormap('rose gold');       cLim = 'auto';    lMode = 'full';
        case 'aurora'
            cMode = 'custom';   cMap = roseColormap('aurora borealis'); cLim = 'auto';    lMode = 'full';
        case 'neon'
            cMode = 'custom';   cMap = roseColormap('cyberwave');       cLim = 'auto';    lMode = 'none';
        case 'frozen'
            cMode = 'custom';   cMap = roseColormap('frozen');          cLim = [0 1.6];   lMode = 'hybrid';
        case 'solar'
            cMode = 'custom';   cMap = roseColormap('solar flare');     cLim = [0 1.6];   lMode = 'none';
        case 'phantom'
            cMode = 'custom';   cMap = roseColormap('phantom orchid');  cLim = [0 1.6];   lMode = 'hybrid';
        case 'radioactive'
            cMode = 'custom';   cMap = roseColormap('radioactive');     cLim = [0 1.6];   lMode = 'none';
        case 'winter'
            cMode = 'custom';   cMap = roseColormap('winter');          cLim = [0 1.6];   lMode = 'full';
        case 'turbo'
            cMode = 'custom';   cMap = roseColormap('turbo');           cLim = 'auto';    lMode = 'full';
        otherwise
            error('rosePreset:unknownName', ...
                'Unknown preset "%s".\nAvailable: classic, matte red, dark velvet, rose gold, aurora, neon, frozen, solar, phantom, radioactive, winter, turbo.', name);
    end
end

function cmap = roseColormap(name)
    t = linspace(0, 1, 256)';
    switch lower(name)
        case 'aobara',         cmap = [lerp(0.12,0.72,t), lerp(0.05,0.45,t), lerp(0.28,0.82,t)];
        case 'true blue',      cmap = [lerp(0.02,0.18,t), lerp(0.04,0.38,t), lerp(0.18,0.78,t)];
        case 'mint green',     cmap = [lerp(0.1,0.85,t), lerp(0.35,1,t), lerp(0.25,0.75,t)];
        case 'black baccara',  cmap = [lerp(0.08,0.55,t), lerp(0.01,0.02,t), lerp(0.03,0.06,t)];
        case 'classic red',    cmap = [lerp(0.25,1.0,t), lerp(0.0,0.08,t), lerp(0.02,0.05,t)];
        case 'juliet',         cmap = [lerp(0.55,1.0,t), lerp(0.22,0.72,t), lerp(0.10,0.50,t)];
        case 'amnesia',        cmap = [lerp(0.35,0.76,t), lerp(0.28,0.58,t), lerp(0.38,0.64,t)];
        case 'quicksand',      cmap = [lerp(0.45,0.90,t), lerp(0.32,0.72,t), lerp(0.28,0.62,t)];
        case 'sahara',         cmap = [lerp(0.50,0.95,t), lerp(0.38,0.82,t), lerp(0.18,0.55,t)];
        case 'coral reef',     cmap = [lerp(0.45,0.98,t), lerp(0.12,0.52,t), lerp(0.10,0.45,t)];
        case 'hot pink',       cmap = [lerp(0.35,1.0,t), lerp(0.02,0.28,t), lerp(0.18,0.52,t)];
        case 'blush',          cmap = [lerp(0.55,0.96,t), lerp(0.35,0.75,t), lerp(0.38,0.76,t)];
        case 'ocean song',     cmap = [lerp(0.28,0.68,t), lerp(0.18,0.52,t), lerp(0.42,0.78,t)];
        case 'golden mustard', cmap = [lerp(0.45,0.95,t), lerp(0.28,0.75,t), lerp(0.02,0.12,t)];
        case 'ivory',          cmap = [lerp(0.65,1.0,t), lerp(0.58,0.96,t), lerp(0.45,0.88,t)];
        case 'free spirit',    cmap = [lerp(0.50,1.0,t), lerp(0.15,0.55,t), lerp(0.02,0.12,t)];
        case 'burgundy',       cmap = [lerp(0.12,0.50,t), lerp(0.02,0.05,t), lerp(0.06,0.15,t)];
        case 'rose gold',      cmap = [lerp(0.42,0.92,t), lerp(0.22,0.58,t), lerp(0.18,0.48,t)];
        case 'white mondial',  cmap = [lerp(0.60,1.0,t), lerp(0.68,1.0,t), lerp(0.55,0.95,t)];
        case 'shocking blue',  cmap = [lerp(0.20,0.60,t), lerp(0.05,0.18,t), lerp(0.30,0.65,t)];
        case 'cafe latte',     cmap = [lerp(0.25,0.75,t), lerp(0.15,0.58,t), lerp(0.08,0.42,t)];
        case 'cyberwave',      cmap = [lerp(0.0,1.0,t), lerp(0.85,0.10,t), lerp(0.90,0.80,t)];
        case 'solar flare',    cmap = [lerp(0.30,1.0,t).^0.7, lerp(0.0,0.95,t).^1.5, lerp(0.0,0.70,t).^2.5];
        case 'abyssal',        cmap = [lerp(0.0,0.10,t), lerp(0.02,0.85,t), lerp(0.05,0.65,t)];
        case 'nebula',         cmap = [lerp(0.08,0.85,t), lerp(0.02,0.30,t), lerp(0.22,0.55,t)];
        case 'molten gold',    cmap = [lerp(0.05,1.0,t).^0.8, lerp(0.02,0.88,t).^1.2, lerp(0.0,0.40,t).^2.0];
        case 'frozen',         cmap = [lerp(0.10,0.88,t), lerp(0.15,0.92,t), lerp(0.30,1.0,t)];
        case 'radioactive',    cmap = [lerp(0.02,0.45,t), lerp(0.08,1.0,t), lerp(0.0,0.15,t)];
        case 'obsidian flame', cmap = [lerp(0.03,1.0,t).^1.8, lerp(0.0,0.25,t).^1.5, lerp(0.02,0.05,t)];
        case 'aurora borealis',cmap = [0.5*sin(2*pi*t+4)+0.5, 0.5*sin(2*pi*t*0.8)+0.5, 0.5*sin(2*pi*t*0.6+2)+0.5];
        case 'phantom orchid', cmap = [lerp(0.85,0.30,t), lerp(0.85,0.08,t), lerp(0.88,0.55,t)];
        otherwise
            try
                fn = str2func(name);
                cmap = fn(256);
            catch
                allNames = {'aobara','true blue','mint green','black baccara','classic red','juliet','amnesia','quicksand','sahara','coral reef','hot pink','blush','ocean song','golden mustard','ivory','free spirit','burgundy','rose gold','white mondial','shocking blue','cafe latte','cyberwave','solar flare','abyssal','nebula','molten gold','frozen','radioactive','obsidian flame','aurora borealis','phantom orchid'};
                error('roseColormap:unknownName', 'Unknown colormap "%s".\nAvailable presets:\n  %s\n\nOr use any MATLAB built-in.', name, strjoin(allNames, ', '));
            end
    end
end

function v = lerp(a, b, t)
    v = a + (b - a) * t;
end
