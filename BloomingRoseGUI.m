classdef BloomingRoseGUI < handle
    %BLOOMINGROSEGUI  Interactive GUI for the Blooming Rose animation.
    %   Provides a uifigure with a 3D axes on the left and collapsible
    %   accordion controls on the right. All geometry and appearance
    %   parameters are exposed via sliders, spinners, dropdowns, and
    %   color pickers. While-loop animation with play/pause/loop/speed.
    %
    %   Rose head geometry adapted from Eric Ludlam's "Blooming Rose"
    %   (MATLAB Flipbook Mini Hack, 2023).
    %
    %   Usage:
    %       app = BloomingRoseGUI();
    %
    %   Vasilis Bellos, 2026

    %% ═══════════════════════════════════════════════════════════════════
    %  PROPERTIES
    %  ═══════════════════════════════════════════════════════════════════

    properties (Constant, Access = private)
        % Theme
        PANEL_COLOR  = [0.20, 0.20, 0.20]
        TEXT_COLOR   = [0.90, 0.90, 0.90]
        ACCENT_COLOR = [0.30, 0.60, 0.90]
        HEADER_COLOR = [0.25, 0.25, 0.25]

        % Accordion
        SECTION_NAMES   = {'Playback', 'Appearance', 'Flower', 'Stem', 'Sepals', 'Thorns'}
        SECTION_HEIGHTS = [292, 270, 114, 284, 190, 154]
        HEADER_HEIGHT   = 28
        SECTION_PAD     = 5
        SCROLLBAR_WIDTH = 20

        % Colormap catalogue
        COLORMAP_NAMES = { ...
            'aobara', 'true blue', 'mint green', 'black baccara', 'classic red', ...
            'juliet', 'amnesia', 'quicksand', 'sahara', 'coral reef', 'hot pink', ...
            'blush', 'ocean song', 'golden mustard', 'ivory', 'free spirit', ...
            'burgundy', 'rose gold', 'white mondial', 'shocking blue', 'cafe latte', ...
            'cyberwave', 'solar flare', 'abyssal', 'nebula', 'molten gold', 'frozen', ...
            'radioactive', 'obsidian flame', 'aurora borealis', 'phantom orchid', ...
            'winter', 'turbo'}

        % Built-in MATLAB colormaps (always available)
        BUILTIN_CMAPS = {'parula','jet','hsv','hot','cool','spring','summer', ...
            'autumn','gray','bone','copper','pink'}

        PRESET_NAMES = {'custom', 'classic', 'matte red', 'dark velvet', 'rose gold', ...
            'aurora', 'neon', 'frozen', 'solar', 'phantom', 'radioactive', 'winter', 'turbo'}
    end

    properties (Access = private)
        % --- UI handles ---
        Fig
        Ax
        AxPanel
        MainGrid
        ControlPanel

        % Accordion
        AccordionScroll
        SectionHeaders
        SectionPanels
        SectionExpanded

        % --- Graphics handles ---
        hRose
        hStem
        hStemCap
        hSepals         % gobjects array
        hThorns         % gobjects array

        % --- Precomputed geometry ---
        XFrames
        YFrames
        ZFrames
        f_norm
        StemSurfs       % struct with X, Y, Z for the stem tube
        SepalSurfs      % struct array
        ThornSurfs      % struct array
        StemSpine       % struct: spine, tangent, normal, binormal, r_profile

        % --- Animation state ---
        CurrentFrame            = 1
        IsPlaying               = false
        IsLooping               = true
        AnimSpeed               = 1.0
        FrameAccum              = 0
        WasPlayingBeforeDrag    = false
        IsDraggingSlider        = false
        MeasuredFps             = 0

        % --- Recording ---
        IsRecording      = false
        RecordToggling   = false   % re-entry guard
        LastCaptured     = 0       % frame number of last captured frame
        RecordedFrames   = {}
        DeferTimer                 % timer handle for deferred start

        % --- Playback widgets ---
        PlayButton
        FrameBackButton
        FrameForwardButton
        LoopCheckbox
        SpeedSlider
        SpeedLabel
        TimeSlider
        TimeLabel
        BloomLabel
        RecordButton
        ScreenshotButton
        ExportButton
        CropCheckbox
        StatusLabel
        wNFrames
        wN

        % --- Flower widgets ---
        wA
        wB
        wPetalNum

        % --- Stem widgets ---
        wStemLength
        wStemRadTop
        wStemRadBot
        wStemCurveX
        wStemCurveY
        wNStemLen
        wNStemCirc
        wStemColor

        % --- Sepal widgets ---
        wNSepals
        wSepalLength
        wSepalWidth
        wSepalDroop
        wSepalColor

        % --- Thorn widgets ---
        wNThorns
        wThornHeight
        wThornRadius
        wThornColor

        % --- Appearance widgets ---
        wPreset
        wColormapMode
        wColormapName
        wRoseColor
        wRow3Label
        wLightingMode
        wAutoClim
        wClimRange
        wBgColor

        % Runtime colormap list (custom + available built-in)
        ColormapItems

        % --- Current parameters ---
        P   % struct holding all rose parameters
    end

    %% ═══════════════════════════════════════════════════════════════════
    %  PUBLIC
    %  ═══════════════════════════════════════════════════════════════════

    methods (Access = public)
        function obj = BloomingRoseGUI()
            obj.initParams();
            obj.buildColormapList();
            obj.buildUI();
            obj.computeAll();
            obj.drawScene();
            obj.updateTimeDisplay();
            obj.deferStart();
        end

        function delete(obj)
            obj.IsPlaying = false;
            if ~isempty(obj.Fig) && isvalid(obj.Fig)
                delete(obj.Fig);
            end
        end

        function resume(obj)
            %RESUME  Rebuild the GUI if the figure was closed.
            %   app.resume() reopens the window and resumes playback.
            if ~isempty(obj.Fig) && isvalid(obj.Fig)
                figure(obj.Fig);   % bring to front
                return;
            end
            obj.buildUI();
            obj.drawScene();
            obj.updateTimeDisplay();
            obj.deferStart();
        end
    end

    %% ═══════════════════════════════════════════════════════════════════
    %  INITIALISATION
    %  ═══════════════════════════════════════════════════════════════════

    methods (Access = private)
        function buildColormapList(obj)
            %BUILDCOLORMAPLIST Build runtime list of custom + available built-in colormaps.
            items = [obj.COLORMAP_NAMES, obj.BUILTIN_CMAPS];

            % Version-gated colormaps
            if ~isMATLABReleaseOlderThan('R2023b')
                items = [items, {'sky', 'abyss'}];
            end

            obj.ColormapItems = items;
        end

        function initParams(obj)
            p.nFrames       = 120;
            p.n             = 250;
            p.A             = 1.995653;
            p.B             = 1.27689;
            p.petalNum      = 3.6;
            p.roseColor     = [1.0, 0.0, 0.0];

            p.stemLength    = 3.2;
            p.stemRadiusTop = 0.055;
            p.stemRadiusBot = 0.042;
            p.stemCurveX    = 0.25;
            p.stemCurveY    = 0.12;
            p.nStemLen      = 50;
            p.nStemCirc     = 20;
            p.stemColor     = [0.18, 0.42, 0.15];

            p.nSepals       = 5;
            p.sepalLength   = 0.35;
            p.sepalWidth    = 0.10;
            p.sepalDroop    = 0.10;
            p.sepalColor    = [0.22, 0.50, 0.18];

            p.nThorns       = 6;
            p.thornHeight   = 0.14;
            p.thornRadius   = 0.028;
            p.thornColor    = [0.30, 0.25, 0.12];

            p.scenePreset   = 'classic';
            p.colormapMode  = 'dynamic';
            p.colormapName  = 'aobara';
            p.lightingMode  = 'full';
            p.autoClim      = true;
            p.climLo        = 0;
            p.climHi        = 1.6;
            p.bgColor       = [0, 0, 0];

            obj.P = p;
        end

        %% ═════════════════════════════════════════════════════════════
        %  UI CONSTRUCTION
        %  ═════════════════════════════════════════════════════════════

        function buildUI(obj)
            obj.Fig = uifigure('Name', 'Blooming Rose', ...
                'Color', 'k', ...
                'WindowState', 'maximized', ...
                'KeyPressFcn', @(~, evt) obj.onKeyPress(evt), ...
                'CloseRequestFcn', @(~, ~) obj.onFigureClose());

            obj.MainGrid = uigridlayout(obj.Fig, [1, 2]);
            obj.MainGrid.ColumnWidth = {'1x', 300};
            obj.MainGrid.RowHeight = {'1x'};
            obj.MainGrid.Padding = [5, 5, 5, 5];
            obj.MainGrid.ColumnSpacing = 5;
            obj.MainGrid.BackgroundColor = [0, 0, 0];

            % --- 3D Axes ---
            obj.AxPanel = uipanel(obj.MainGrid, ...
                'BackgroundColor', 'k', ...
                'BorderType', 'none', ...
                'AutoResizeChildren', 'off');
            obj.AxPanel.Layout.Row = 1;
            obj.AxPanel.Layout.Column = 1;

            obj.Ax = uiaxes('Parent', obj.AxPanel, ...
                'Color', 'k', ...
                'Visible', 'off', ...
                'Units', 'normalized', ...
                'OuterPosition', [0, 0, 1, 1], ...
                'Clipping', 'off');
            hold(obj.Ax, 'on');
            obj.Ax.Interactions = rotateInteraction;
            obj.Ax.Toolbar = [];
            enableDefaultInteractivity(obj.Ax);
            obj.Fig.Pointer = 'arrow';

            % --- Control panel ---
            obj.ControlPanel = uipanel(obj.MainGrid, ...
                'BackgroundColor', obj.PANEL_COLOR, 'BorderType', 'none');
            obj.ControlPanel.Layout.Row = 1;
            obj.ControlPanel.Layout.Column = 2;

            controlGrid = uigridlayout(obj.ControlPanel, [2, 1]);
            controlGrid.RowHeight = {'1x', 22};
            controlGrid.Padding = [0, 0, 0, 0];
            controlGrid.RowSpacing = 0;
            controlGrid.BackgroundColor = obj.PANEL_COLOR;

            obj.AccordionScroll = uipanel(controlGrid, ...
                'BackgroundColor', obj.PANEL_COLOR, ...
                'BorderType', 'none', ...
                'Scrollable', 'on', ...
                'AutoResizeChildren', 'off', ...
                'SizeChangedFcn', @(~, ~) obj.repositionSections());
            obj.AccordionScroll.Layout.Row = 1;
            obj.AccordionScroll.Layout.Column = 1;

            obj.createSections();
            obj.createBottomBar(controlGrid, 2);
        end

        %% ═════════════════════════════════════════════════════════════
        %  ACCORDION MANAGEMENT
        %  ═════════════════════════════════════════════════════════════

        function createSections(obj)
            nSec = numel(obj.SECTION_NAMES);
            obj.SectionHeaders  = cell(1, nSec);
            obj.SectionPanels   = cell(1, nSec);
            obj.SectionExpanded = false(1, nSec);
            obj.SectionExpanded(1) = true;   % Playback open
            obj.SectionExpanded(2) = true;   % Appearance open

            pad = obj.SECTION_PAD;
            hH  = obj.HEADER_HEIGHT;
            sbW = obj.SCROLLBAR_WIDTH;

            scrollPos = obj.AccordionScroll.Position;
            spW = max(scrollPos(3), 300);
            pW  = spW - 2*pad - sbW;

            cH = pad;
            for i = 1:nSec
                cH = cH + hH + pad;
                if obj.SectionExpanded(i)
                    cH = cH + obj.SECTION_HEIGHTS(i);
                end
            end
            spH = max(scrollPos(4), 700);
            cH  = max(cH, spH + 50);

            yPos = cH - pad;
            for i = 1:nSec
                if obj.SectionExpanded(i)
                    hText = [char(9660), ' ', obj.SECTION_NAMES{i}];
                else
                    hText = [char(9654), ' ', obj.SECTION_NAMES{i}];
                end

                yPos = yPos - hH;
                obj.SectionHeaders{i} = uibutton(obj.AccordionScroll, 'push', ...
                    'Text', hText, ...
                    'FontWeight', 'bold', 'FontSize', 12, ...
                    'HorizontalAlignment', 'left', ...
                    'BackgroundColor', obj.HEADER_COLOR, ...
                    'FontColor', obj.TEXT_COLOR, ...
                    'Position', [pad, yPos, pW, hH], ...
                    'ButtonPushedFcn', @(~, ~) obj.toggleSection(i));

                obj.SectionPanels{i} = uipanel(obj.AccordionScroll, ...
                    'BackgroundColor', obj.PANEL_COLOR, ...
                    'BorderType', 'none', ...
                    'Position', [pad, yPos - obj.SECTION_HEIGHTS(i), pW, obj.SECTION_HEIGHTS(i)], ...
                    'Visible', obj.SectionExpanded(i));

                if obj.SectionExpanded(i)
                    yPos = yPos - obj.SECTION_HEIGHTS(i);
                end
                yPos = yPos - pad;
            end

            obj.createPlaybackSection(obj.SectionPanels{1});
            obj.createAppearanceSection(obj.SectionPanels{2});
            obj.createFlowerSection(obj.SectionPanels{3});
            obj.createStemSection(obj.SectionPanels{4});
            obj.createSepalsSection(obj.SectionPanels{5});
            obj.createThornsSection(obj.SectionPanels{6});
        end

        function toggleSection(obj, idx)
            obj.SectionExpanded(idx) = ~obj.SectionExpanded(idx);
            if obj.SectionExpanded(idx)
                obj.SectionHeaders{idx}.Text = [char(9660), ' ', obj.SECTION_NAMES{idx}];
                obj.SectionPanels{idx}.Visible = 'on';
            else
                obj.SectionHeaders{idx}.Text = [char(9654), ' ', obj.SECTION_NAMES{idx}];
                obj.SectionPanels{idx}.Visible = 'off';
            end
            obj.repositionSections();
            obj.shiftFocus();
        end

        function repositionSections(obj)
            if isempty(obj.AccordionScroll) || ~isvalid(obj.AccordionScroll), return; end
            if isempty(obj.SectionHeaders) || isempty(obj.SectionHeaders{1}), return; end

            pad  = obj.SECTION_PAD;
            hH   = obj.HEADER_HEIGHT;
            sbW  = obj.SCROLLBAR_WIDTH;
            nSec = numel(obj.SECTION_NAMES);

            scrollPos = obj.AccordionScroll.Position;
            spW = max(scrollPos(3), 300);
            spH = max(scrollPos(4), 700);
            pW  = spW - 2*pad - sbW;

            cH = pad;
            for i = 1:nSec
                cH = cH + hH + pad;
                if obj.SectionExpanded(i)
                    cH = cH + obj.SECTION_HEIGHTS(i);
                end
            end
            cH = max(cH, spH + 50);

            yPos = cH - pad;
            for i = 1:nSec
                yPos = yPos - hH;
                obj.SectionHeaders{i}.Position = [pad, yPos, pW, hH];
                if obj.SectionExpanded(i)
                    yPos = yPos - obj.SECTION_HEIGHTS(i);
                    obj.SectionPanels{i}.Position = [pad, yPos, pW, obj.SECTION_HEIGHTS(i)];
                end
                yPos = yPos - pad;
            end
        end

        %% ═════════════════════════════════════════════════════════════
        %  SECTION CONTENT CREATORS
        %  ═════════════════════════════════════════════════════════════

        function createPlaybackSection(obj, parent)
            g = uigridlayout(parent, [12, 2]);
            g.RowHeight    = {30, 30, 30, 30, 14, 26, 24, 2, 20, 26, 14, 14};
            g.ColumnWidth  = {'1x', '1x'};
            g.Padding      = [5, 4, 5, 4];
            g.RowSpacing   = 2;
            g.BackgroundColor = obj.PANEL_COLOR;

            % Row 1: Play/Pause + Loop
            obj.PlayButton = uibutton(g, 'push', ...
                'Text', [char(9654), ' Play'], ...
                'FontWeight', 'bold', ...
                'BackgroundColor', [0.2, 0.6, 0.2], ...
                'FontColor', 'w', ...
                'Tooltip', 'Play/Pause (Space)', ...
                'ButtonPushedFcn', @(~, ~) obj.onPlayPause());
            obj.PlayButton.Layout.Row = 1;
            obj.PlayButton.Layout.Column = 1;

            obj.LoopCheckbox = uicheckbox(g, ...
                'Text', 'Loop', ...
                'Value', obj.IsLooping, ...
                'FontColor', obj.TEXT_COLOR, ...
                'Tooltip', 'Loop animation (L)', ...
                'ValueChangedFcn', @(src, ~) obj.onLoopChanged(src.Value));
            obj.LoopCheckbox.Layout.Row = 1;
            obj.LoopCheckbox.Layout.Column = 2;

            % Row 2: Screenshot + Crop
            obj.ScreenshotButton = uibutton(g, 'push', ...
                'Text', 'Screenshot', ...
                'BackgroundColor', [0.4, 0.4, 0.5], ...
                'FontColor', 'w', ...
                'Tooltip', 'Save current view as PNG (P)', ...
                'ButtonPushedFcn', @(~, ~) obj.onScreenshot());
            obj.ScreenshotButton.Layout.Row = 2;
            obj.ScreenshotButton.Layout.Column = 1;

            obj.CropCheckbox = uicheckbox(g, ...
                'Text', 'Crop', ...
                'Value', true, ...
                'FontColor', obj.TEXT_COLOR, ...
                'Tooltip', 'Toggle crop margins (C)');
            obj.CropCheckbox.Layout.Row = 2;
            obj.CropCheckbox.Layout.Column = 2;

            % Row 3: Record + Export
            obj.RecordButton = uibutton(g, 'state', ...
                'Text', [char(9210), ' Record'], ...
                'BackgroundColor', [0.5, 0.2, 0.2], ...
                'FontColor', 'w', ...
                'Tooltip', 'Record frames (R)', ...
                'ValueChangedFcn', @(src, ~) obj.onRecordToggle(src.Value));
            obj.RecordButton.Layout.Row = 3;
            obj.RecordButton.Layout.Column = 1;

            obj.ExportButton = uibutton(g, 'push', ...
                'Text', 'Export', ...
                'BackgroundColor', [0.3, 0.4, 0.5], ...
                'FontColor', 'w', ...
                'Enable', 'off', ...
                'Tooltip', 'Export recorded frames (E)', ...
                'ButtonPushedFcn', @(~, ~) obj.onExport());
            obj.ExportButton.Layout.Row = 3;
            obj.ExportButton.Layout.Column = 2;

            % Row 4: Frame stepper (full width)
            stepperGrid = uigridlayout(g, [1, 3]);
            stepperGrid.ColumnWidth = {30, '1x', 30};
            stepperGrid.Padding = [0, 0, 0, 0];
            stepperGrid.ColumnSpacing = 2;
            stepperGrid.BackgroundColor = obj.PANEL_COLOR;
            stepperGrid.Layout.Row = 4;
            stepperGrid.Layout.Column = [1, 2];

            obj.FrameBackButton = uibutton(stepperGrid, 'push', ...
                'Text', char(9664), 'FontSize', 12, ...
                'BackgroundColor', [0.3, 0.3, 0.4], 'FontColor', 'w', ...
                'Tooltip', 'Previous frame (<)', ...
                'ButtonPushedFcn', @(~, ~) obj.onFrameStep(-1));
            obj.FrameBackButton.Layout.Row = 1;
            obj.FrameBackButton.Layout.Column = 1;

            obj.TimeLabel = uilabel(stepperGrid, ...
                'Text', 'Frame 1 / 120', ...
                'FontColor', obj.ACCENT_COLOR, 'FontWeight', 'bold', ...
                'HorizontalAlignment', 'center');
            obj.TimeLabel.Layout.Row = 1;
            obj.TimeLabel.Layout.Column = 2;

            obj.FrameForwardButton = uibutton(stepperGrid, 'push', ...
                'Text', char(9654), 'FontSize', 12, ...
                'BackgroundColor', [0.3, 0.3, 0.4], 'FontColor', 'w', ...
                'Tooltip', 'Next frame (>)', ...
                'ButtonPushedFcn', @(~, ~) obj.onFrameStep(1));
            obj.FrameForwardButton.Layout.Row = 1;
            obj.FrameForwardButton.Layout.Column = 3;

            % Row 5: Bloom %
            obj.BloomLabel = uilabel(g, ...
                'Text', 'Bloom: 0%', ...
                'FontColor', [0.6, 0.6, 0.6], 'FontSize', 11, ...
                'HorizontalAlignment', 'center');
            obj.BloomLabel.Layout.Row = 5;
            obj.BloomLabel.Layout.Column = [1, 2];

            % Row 6: Time slider
            obj.TimeSlider = uislider(g, ...
                'Limits', [1, obj.P.nFrames], 'Value', 1, ...
                'MajorTicks', [], 'MinorTicks', [], ...
                'FontColor', 'w', ...
                'Tooltip', 'Seek through animation', ...
                'ValueChangingFcn', @(~, evt) obj.onTimeSliderDragging(round(evt.Value)), ...
                'ValueChangedFcn', @(src, ~) obj.onTimeSliderReleased(round(src.Value)));
            obj.TimeSlider.Layout.Row = 6;
            obj.TimeSlider.Layout.Column = [1, 2];

            % Row 7: Frames + Resolution
            paramGrid = uigridlayout(g, [1, 5]);
            paramGrid.ColumnWidth = {48, '1x', 10, 68, '1x'};
            paramGrid.Padding = [0, 0, 0, 0];
            paramGrid.ColumnSpacing = 4;
            paramGrid.BackgroundColor = obj.PANEL_COLOR;
            paramGrid.Layout.Row = 7;
            paramGrid.Layout.Column = [1, 2];

            frLbl = uilabel(paramGrid, 'Text', 'Frames', ...
                'FontColor', obj.TEXT_COLOR, 'FontSize', 12);
            frLbl.Layout.Row = 1;
            frLbl.Layout.Column = 1;

            obj.wNFrames = uispinner(paramGrid, ...
                'Limits', [30, 600], 'Value', obj.P.nFrames, 'Step', 10, ...
                'ValueChangedFcn', @(src, ~) obj.onFlowerChanged('nFrames', src.Value));
            obj.wNFrames.Layout.Row = 1;
            obj.wNFrames.Layout.Column = 2;

            resLbl = uilabel(paramGrid, 'Text', 'Resolution', ...
                'FontColor', obj.TEXT_COLOR, 'FontSize', 12);
            resLbl.Layout.Row = 1;
            resLbl.Layout.Column = 4;

            obj.wN = uispinner(paramGrid, ...
                'Limits', [50, 400], 'Value', obj.P.n, 'Step', 50, ...
                'ValueChangedFcn', @(src, ~) obj.onFlowerChanged('n', src.Value));
            obj.wN.Layout.Row = 1;
            obj.wN.Layout.Column = 5;

            % Row 8: Speed label + value
            speedLbl = uilabel(g, 'Text', 'Speed:', 'FontColor', obj.TEXT_COLOR, 'FontSize', 12);
            speedLbl.Layout.Row = 9;
            speedLbl.Layout.Column = 1;

            obj.SpeedLabel = uilabel(g, ...
                'Text', '1.0x', ...
                'FontColor', obj.ACCENT_COLOR, ...
                'FontWeight', 'bold', ...
                'HorizontalAlignment', 'right');
            obj.SpeedLabel.Layout.Row = 9;
            obj.SpeedLabel.Layout.Column = 2;

            % Row 9: Speed slider — snaps to 0.5 increments
            obj.SpeedSlider = uislider(g, ...
                'Limits', [0.5, 3.0], 'Value', 1.0, ...
                'MajorTicks', [0.5, 1.0, 1.5, 2.0, 2.5, 3.0], ...
                'MajorTickLabels', {'', '', '', '', '', ''}, ...
                'MinorTicks', [], ...
                'FontColor', 'w', ...
                'ValueChangingFcn', @(~, evt) obj.onSpeedChanging(evt.Value), ...
                'ValueChangedFcn', @(src, ~) obj.onSpeedChanged(src.Value));
            obj.SpeedSlider.Layout.Row = 10;
            obj.SpeedSlider.Layout.Column = [1, 2];

            % Rows 11-12: Keyboard hints (2 lines)
            hintLbl1 = uilabel(g, ...
                'Text', 'Space play/pause | <> step | ↑↓ speed | L loop', ...
                'FontColor', [0.45, 0.45, 0.45], 'FontSize', 11);
            hintLbl1.Layout.Row = 11;
            hintLbl1.Layout.Column = [1, 2];

            hintLbl2 = uilabel(g, ...
                'Text', 'P screenshot | R record | E export | C crop | Q quit', ...
                'FontColor', [0.45, 0.45, 0.45], 'FontSize', 11);
            hintLbl2.Layout.Row = 12;
            hintLbl2.Layout.Column = [1, 2];
        end

        function createAppearanceSection(obj, parent)
            g = uigridlayout(parent, [7, 3]);
            g.RowHeight   = {28, 28, 32, 28, 28, 44, 32};
            g.ColumnWidth = {80, '1x', 34};
            g.Padding     = [8, 6, 8, 6];
            g.RowSpacing  = 6;
            g.BackgroundColor = obj.PANEL_COLOR;

            obj.wPreset       = obj.addDropdownRow(g, 1, 'Preset',   obj.PRESET_NAMES,              obj.P.scenePreset,  @(v) obj.onPresetChanged(v));
            obj.wColormapMode = obj.addDropdownRow(g, 2, 'Map Mode', {'static','dynamic','custom'}, obj.P.colormapMode, @(v) obj.onMapModeChanged(v));

            % Row 3: swappable — color picker (static/dynamic) or colormap dropdown (custom)
            obj.wRow3Label = uilabel(g, 'Text', 'Color', ...
                'FontColor', obj.TEXT_COLOR, 'FontSize', 12);
            obj.wRow3Label.Layout.Row = 3;
            obj.wRow3Label.Layout.Column = 1;

            obj.wColormapName = uidropdown(g, ...
                'Items', obj.ColormapItems, 'Value', obj.P.colormapName, ...
                'ValueChangedFcn', @(src, ~) obj.onAppearanceChanged('colormapName', src.Value), ...
                'Visible', 'off');
            obj.wColormapName.Layout.Row = 3;
            obj.wColormapName.Layout.Column = [2, 3];

            obj.wRoseColor = uicolorpicker(g, 'Value', obj.P.roseColor, ...
                'ValueChangedFcn', @(src, ~) obj.onRoseColorChanged(src.Value));
            obj.wRoseColor.Layout.Row = 3;
            obj.wRoseColor.Layout.Column = [2, 3];

            obj.wLightingMode = obj.addDropdownRow(g, 4, 'Lighting', {'full','hybrid','none'}, obj.P.lightingMode, @(v) obj.onAppearanceChanged('lightingMode', v));

            % Auto CLim checkbox
            obj.wAutoClim = uicheckbox(g, ...
                'Text', 'Auto CLim', ...
                'Value', obj.P.autoClim, ...
                'FontColor', obj.TEXT_COLOR, ...
                'ValueChangedFcn', @(~, ~) obj.onClimChanged());
            obj.wAutoClim.Layout.Row = 5;
            obj.wAutoClim.Layout.Column = [1, 3];

            % CLim range slider
            obj.wClimRange = uislider(g, 'range', ...
                'Limits', [0, 2], ...
                'Value', [obj.P.climLo, obj.P.climHi], ...
                'MajorTicks', 0:0.5:2, ...
                'MinorTicks', [], ...
                'FontColor', 'w', ...
                'Enable', matlab.lang.OnOffSwitchState(~obj.P.autoClim), ...
                'ValueChangingFcn', @(~, evt) obj.onClimSliderChanging(evt.Value), ...
                'ValueChangedFcn', @(src, ~) obj.onClimSliderChanged(src.Value));
            obj.wClimRange.Layout.Row = 6;
            obj.wClimRange.Layout.Column = [1, 3];

            % Background color
            obj.wBgColor = obj.addColorPickerRow(g, 7, 'Background', obj.P.bgColor, @(c) obj.onBgColorChanged(c));

            obj.syncRow3Visibility();
            obj.applyPreset(obj.P.scenePreset);
        end

        function createFlowerSection(obj, parent)
            g = uigridlayout(parent, [3, 3]);
            g.RowHeight   = {28, 28, 28};
            g.ColumnWidth = {80, '1x', 34};
            g.Padding     = [8, 6, 8, 6];
            g.RowSpacing  = 8;
            g.BackgroundColor = obj.PANEL_COLOR;

            obj.wA        = obj.addSliderRow(g, 1, 'Petal Height', [0.5, 4.0], obj.P.A,       @(v) obj.onFlowerChanged('A', v));
            obj.wB        = obj.addSliderRow(g, 2, 'Petal Curl',  [0.5, 2.0], obj.P.B,        @(v) obj.onFlowerChanged('B', v));
            obj.wPetalNum = obj.addSliderRow(g, 3, 'Petals/Rev',  [1.0, 8.0], obj.P.petalNum, @(v) obj.onFlowerChanged('petalNum', v));
        end

        function createStemSection(obj, parent)
            g = uigridlayout(parent, [8, 3]);
            g.RowHeight   = {28, 28, 28, 28, 28, 28, 28, 32};
            g.ColumnWidth = {80, '1x', 34};
            g.Padding     = [8, 6, 8, 6];
            g.RowSpacing  = 6;
            g.BackgroundColor = obj.PANEL_COLOR;

            obj.wStemLength = obj.addSliderRow(g,  1, 'Length',     [1.0, 6.0],   obj.P.stemLength,    @(v) obj.onStemChanged('stemLength', v));
            obj.wStemRadTop = obj.addSliderRow(g,  2, 'Radius Top', [0.02, 0.12], obj.P.stemRadiusTop, @(v) obj.onStemChanged('stemRadiusTop', v));
            obj.wStemRadBot = obj.addSliderRow(g,  3, 'Radius Bottom', [0.02, 0.10], obj.P.stemRadiusBot, @(v) obj.onStemChanged('stemRadiusBot', v));
            obj.wStemCurveX = obj.addSliderRow(g,  4, 'Curve X',   [-0.5, 0.5],  obj.P.stemCurveX,    @(v) obj.onStemChanged('stemCurveX', v));
            obj.wStemCurveY = obj.addSliderRow(g,  5, 'Curve Y',   [-0.5, 0.5],  obj.P.stemCurveY,    @(v) obj.onStemChanged('stemCurveY', v));
            obj.wNStemLen   = obj.addSpinnerRow(g, 6, 'Segments L', [10, 100],    obj.P.nStemLen,  5,  @(v) obj.onStemChanged('nStemLen', v));
            obj.wNStemCirc  = obj.addSpinnerRow(g, 7, 'Segments C', [8, 40],      obj.P.nStemCirc, 2,  @(v) obj.onStemChanged('nStemCirc', v));
            obj.wStemColor  = obj.addColorPickerRow(g, 8, 'Stem Color', obj.P.stemColor, @(c) obj.onColorChanged('stemColor', c));
        end

        function createSepalsSection(obj, parent)
            g = uigridlayout(parent, [5, 3]);
            g.RowHeight   = {28, 28, 28, 28, 32};
            g.ColumnWidth = {80, '1x', 34};
            g.Padding     = [8, 6, 8, 6];
            g.RowSpacing  = 8;
            g.BackgroundColor = obj.PANEL_COLOR;

            obj.wNSepals     = obj.addSpinnerRow(g, 1, 'Count',   [3, 8],       obj.P.nSepals,     1, @(v) obj.onStemChanged('nSepals', v));
            obj.wSepalLength = obj.addSliderRow(g,  2, 'Length',  [0.1, 0.8],   obj.P.sepalLength,    @(v) obj.onStemChanged('sepalLength', v));
            obj.wSepalWidth  = obj.addSliderRow(g,  3, 'Width',   [0.03, 0.25], obj.P.sepalWidth,     @(v) obj.onStemChanged('sepalWidth', v));
            obj.wSepalDroop  = obj.addSliderRow(g,  4, 'Droop',   [0.0, 0.3],   obj.P.sepalDroop,     @(v) obj.onStemChanged('sepalDroop', v));
            obj.wSepalColor  = obj.addColorPickerRow(g, 5, 'Color', obj.P.sepalColor, @(c) obj.onColorChanged('sepalColor', c));
        end

        function createThornsSection(obj, parent)
            g = uigridlayout(parent, [4, 3]);
            g.RowHeight   = {28, 28, 28, 32};
            g.ColumnWidth = {80, '1x', 34};
            g.Padding     = [8, 6, 8, 6];
            g.RowSpacing  = 8;
            g.BackgroundColor = obj.PANEL_COLOR;

            obj.wNThorns     = obj.addSpinnerRow(g, 1, 'Count',   [0, 12],      obj.P.nThorns,     1, @(v) obj.onStemChanged('nThorns', v));
            obj.wThornHeight = obj.addSliderRow(g,  2, 'Height',  [0.05, 0.3],  obj.P.thornHeight,    @(v) obj.onStemChanged('thornHeight', v));
            obj.wThornRadius = obj.addSliderRow(g,  3, 'Radius',  [0.01, 0.06], obj.P.thornRadius,    @(v) obj.onStemChanged('thornRadius', v));
            obj.wThornColor  = obj.addColorPickerRow(g, 4, 'Color', obj.P.thornColor, @(c) obj.onColorChanged('thornColor', c));
        end

        function createBottomBar(obj, parentGrid, row)
            bottomGrid = uigridlayout(parentGrid, [1, 2]);
            bottomGrid.Layout.Row = row;
            bottomGrid.Layout.Column = 1;
            bottomGrid.ColumnWidth = {'1x', 22};
            bottomGrid.RowHeight = {22};
            bottomGrid.Padding = [5, 0, 0, 0];
            bottomGrid.ColumnSpacing = 2;
            bottomGrid.BackgroundColor = obj.PANEL_COLOR;

            obj.StatusLabel = uilabel(bottomGrid, ...
                'Text', 'Ready', ...
                'FontColor', obj.TEXT_COLOR, ...
                'FontSize', 10, ...
                'HorizontalAlignment', 'left');
            obj.StatusLabel.Layout.Row = 1;
            obj.StatusLabel.Layout.Column = 1;

            resetBtn = uibutton(bottomGrid, 'push', ...
                'Text', char(8634), ...
                'FontSize', 13, ...
                'FontColor', obj.TEXT_COLOR, ...
                'BackgroundColor', obj.PANEL_COLOR, ...
                'Tooltip', 'Reset to defaults', ...
                'ButtonPushedFcn', @(~, ~) obj.onResetToDefaults());
            resetBtn.Layout.Row = 1;
            resetBtn.Layout.Column = 2;
        end

        %% ═════════════════════════════════════════════════════════════
        %  WIDGET FACTORY HELPERS
        %  ═════════════════════════════════════════════════════════════

        function sl = addSliderRow(obj, grid, row, label, limits, value, callback)
            lbl = uilabel(grid, 'Text', label, ...
                'FontColor', obj.TEXT_COLOR, 'FontSize', 12);
            lbl.Layout.Row = row;
            lbl.Layout.Column = 1;

            sl = uislider(grid, 'Limits', limits, 'Value', value, ...
                'MajorTicks', [], 'MinorTicks', [], ...
                'FontColor', 'w', ...
                'ValueChangedFcn', @(src, ~) obj.onSliderDone(src, callback));
            sl.Layout.Row = row;
            sl.Layout.Column = 2;

            % Value label — stored in slider UserData for live updates
            valLbl = uilabel(grid, ...
                'Text', obj.fmtSliderVal(value, limits), ...
                'FontColor', obj.ACCENT_COLOR, ...
                'FontSize', 11, 'FontWeight', 'bold', ...
                'HorizontalAlignment', 'right');
            valLbl.Layout.Row = row;
            valLbl.Layout.Column = 3;

            sl.UserData = struct('valLabel', valLbl, 'limits', limits);
            sl.ValueChangingFcn = @(~, evt) set(valLbl, 'Text', obj.fmtSliderVal(evt.Value, limits));
        end

        function onSliderDone(obj, src, callback)
            % Update value label and invoke parameter callback
            info = src.UserData;
            info.valLabel.Text = obj.fmtSliderVal(src.Value, info.limits);
            callback(src.Value);
            obj.shiftFocus();
        end

        function txt = fmtSliderVal(~, val, limits)
            range = limits(2) - limits(1);
            if range < 0.5
                txt = sprintf('%.3f', val);
            elseif range < 2
                txt = sprintf('%.2f', val);
            else
                txt = sprintf('%.1f', val);
            end
        end

        function sp = addSpinnerRow(obj, grid, row, label, limits, value, step, callback)
            lbl = uilabel(grid, 'Text', label, ...
                'FontColor', obj.TEXT_COLOR, 'FontSize', 12);
            lbl.Layout.Row = row;
            lbl.Layout.Column = 1;

            sp = uispinner(grid, 'Limits', limits, 'Value', value, 'Step', step);
            if ~isempty(callback)
                sp.ValueChangedFcn = @(src, ~) obj.spinnerDone(src, callback);
            end
            sp.Layout.Row = row;
            sp.Layout.Column = [2, 3];
        end

        function spinnerDone(obj, src, callback)
            callback(src.Value);
            obj.shiftFocus();
        end

        function dd = addDropdownRow(obj, grid, row, label, items, value, callback)
            lbl = uilabel(grid, 'Text', label, ...
                'FontColor', obj.TEXT_COLOR, 'FontSize', 12);
            lbl.Layout.Row = row;
            lbl.Layout.Column = 1;

            dd = uidropdown(grid, 'Items', items, 'Value', value, ...
                'ValueChangedFcn', @(src, ~) obj.dropdownDone(src, callback));
            dd.Layout.Row = row;
            dd.Layout.Column = [2, 3];
        end

        function dropdownDone(obj, src, callback)
            callback(src.Value);
            obj.shiftFocus();
        end

        function cp = addColorPickerRow(obj, grid, row, label, color, callback)
            lbl = uilabel(grid, 'Text', label, ...
                'FontColor', obj.TEXT_COLOR, 'FontSize', 12);
            lbl.Layout.Row = row;
            lbl.Layout.Column = 1;

            cp = uicolorpicker(grid, 'Value', color, ...
                'ValueChangedFcn', @(src, ~) callback(src.Value));
            cp.Layout.Row = row;
            cp.Layout.Column = [2, 3];
        end

        function shiftFocus(obj)
            if ~isempty(obj.Fig) && isvalid(obj.Fig)
                focus(obj.Fig);
            end
        end

        %% ═════════════════════════════════════════════════════════════
        %  GEOMETRY COMPUTATION
        %  ═════════════════════════════════════════════════════════════

        function computeAll(obj)
            obj.computeRoseFrames();
            obj.computeStemSystem();
        end

        function computeRoseFrames(obj)
            p  = obj.P;
            n_ = p.n;
            r_ = linspace(0, 1, n_);
            theta_ = linspace(-2, 20*pi, n_);
            [R, THETA] = ndgrid(r_, theta_);
            xEnv = 1 - (1/2)*((5/4)*(1 - mod(p.petalNum*THETA, 2*pi)/pi).^2 - 1/4).^2;

            obj.f_norm   = linspace(1, 48, p.nFrames);
            openness     = 1.05 - cospi(obj.f_norm/(48/2.5)) .* (1 - obj.f_norm/48).^2;
            opencenter   = openness * 0.2;

            obj.XFrames = zeros(n_, n_, p.nFrames);
            obj.YFrames = zeros(n_, n_, p.nFrames);
            obj.ZFrames = zeros(n_, n_, p.nFrames);

            for k = 1:p.nFrames
                phi = (pi/2) * linspace(opencenter(k), openness(k), n_).^2;
                y_  = p.A * (R.^2) .* (p.B*R - 1).^2 .* sin(phi);
                R2  = xEnv .* (R.*sin(phi) + y_.*cos(phi));
                obj.XFrames(:,:,k) = R2 .* sin(THETA);
                obj.YFrames(:,:,k) = R2 .* cos(THETA);
                obj.ZFrames(:,:,k) = xEnv .* (R.*cos(phi) - y_.*sin(phi));
            end
        end

        function computeStemSystem(obj)
            p = obj.P;

            P0 = [0, 0, 0];
            P1 = [0, 0, -p.stemLength*0.35];
            P2 = [p.stemCurveX, p.stemCurveY, -p.stemLength*0.65];
            P3 = [p.stemCurveX*0.8, p.stemCurveY*0.6, -p.stemLength];

            t_bez = linspace(0, 1, p.nStemLen)';
            spine = (1-t_bez).^3.*P0 + 3*(1-t_bez).^2.*t_bez.*P1 + ...
                    3*(1-t_bez).*t_bez.^2.*P2 + t_bez.^3.*P3;

            tang = 3*(1-t_bez).^2.*(P1-P0) + 6*(1-t_bez).*t_bez.*(P2-P1) + ...
                   3*t_bez.^2.*(P3-P2);
            tang = tang ./ vecnorm(tang, 2, 2);

            refVec  = [1, 0, 0];
            norm_   = cross(tang, repmat(refVec, p.nStemLen, 1), 2);
            norm_   = norm_ ./ vecnorm(norm_, 2, 2);
            binorm_ = cross(tang, norm_, 2);
            binorm_ = binorm_ ./ vecnorm(binorm_, 2, 2);

            r_prof = p.stemRadiusTop + (p.stemRadiusBot - p.stemRadiusTop)*t_bez;
            r_prof = r_prof + 0.02*exp(-((t_bez)/0.06).^2);

            obj.StemSpine = struct('spine', spine, 'tangent', tang, ...
                'normal', norm_, 'binormal', binorm_, 'r_profile', r_prof);

            phi_c = linspace(0, 2*pi, p.nStemCirc);
            Xs = zeros(p.nStemLen, p.nStemCirc);
            Ys = zeros(p.nStemLen, p.nStemCirc);
            Zs = zeros(p.nStemLen, p.nStemCirc);
            for i = 1:p.nStemLen
                for j = 1:p.nStemCirc
                    off = r_prof(i)*(norm_(i,:)*cos(phi_c(j)) + binorm_(i,:)*sin(phi_c(j)));
                    Xs(i,j) = spine(i,1) + off(1);
                    Ys(i,j) = spine(i,2) + off(2);
                    Zs(i,j) = spine(i,3) + off(3);
                end
            end
            obj.StemSurfs = struct('X', Xs, 'Y', Ys, 'Z', Zs);

            nSu = 15;  nSv = 10;
            u_sep = linspace(0, 1, nSu)';
            v_sep = linspace(-1, 1, nSv);
            swp    = p.sepalWidth * sin(pi*u_sep).^0.6 .* (1 - u_sep.^3);
            xLocal = swp .* v_sep;
            zLocal = p.sepalLength*u_sep.*(1 - 0.5*u_sep) + p.sepalDroop*u_sep.^2;
            rLocal = p.stemRadiusTop*(1 - u_sep*0.3) + p.sepalLength*0.4*u_sep.^1.5;

            obj.SepalSurfs = struct('X', {}, 'Y', {}, 'Z', {});
            for s = 1:p.nSepals
                ang = (s-1)*2*pi/p.nSepals + pi/10;
                obj.SepalSurfs(s).X = rLocal.*cos(ang) + xLocal*(-sin(ang));
                obj.SepalSurfs(s).Y = rLocal.*sin(ang) + xLocal*cos(ang);
                obj.SepalSurfs(s).Z = zLocal + 0.02*(1 - v_sep.^2).*u_sep;
            end

            nTu = 8;  nTv = 10;
            [Uth, Vth] = meshgrid(linspace(0,1,nTu), linspace(0,2*pi,nTv));
            R_cone = p.thornRadius*(1 - Uth).^1.5;
            X_cone = R_cone.*cos(Vth);
            Y_cone = R_cone.*sin(Vth);
            Z_cone = p.thornHeight*Uth;

            tPos = linspace(0.12, 0.85, max(p.nThorns, 1));
            tAng = linspace(0, 2*pi, max(p.nThorns, 1)+1);  tAng(end) = [];
            tAng = tAng + pi/7;

            obj.ThornSurfs = struct('X', {}, 'Y', {}, 'Z', {});
            for th = 1:p.nThorns
                idx     = round(tPos(th)*(p.nStemLen-1)) + 1;
                basePos = spine(idx,:);
                T_ = tang(idx,:);  N_ = norm_(idx,:);  B_ = binorm_(idx,:);
                outDir    = N_*cos(tAng(th)) + B_*sin(tAng(th));
                thornAxis = outDir*cos(pi/6) + (-T_)*sin(pi/6);
                thornAxis = thornAxis / norm(thornAxis);

                if abs(dot(thornAxis, [1,0,0])) < 0.9
                    perpRef = [1,0,0];
                else
                    perpRef = [0,1,0];
                end
                thornN = cross(thornAxis, perpRef);  thornN = thornN / norm(thornN);
                thornB = cross(thornAxis, thornN);   thornB = thornB / norm(thornB);

                Xt = zeros(size(X_cone));  Yt = Xt;  Zt = Xt;
                for ii = 1:numel(X_cone)
                    pt = X_cone(ii)*thornN + Y_cone(ii)*thornB + Z_cone(ii)*thornAxis;
                    w  = basePos + r_prof(idx)*outDir + pt;
                    Xt(ii) = w(1);  Yt(ii) = w(2);  Zt(ii) = w(3);
                end
                obj.ThornSurfs(th).X = Xt;
                obj.ThornSurfs(th).Y = Yt;
                obj.ThornSurfs(th).Z = Zt;
            end
        end

        %% ═════════════════════════════════════════════════════════════
        %  SCENE DRAWING
        %  ═════════════════════════════════════════════════════════════

        function drawScene(obj)
            hasView = ~isempty(obj.hRose) && all(isvalid(obj.hRose));
            if hasView
                [savedAz, savedEl] = view(obj.Ax);
            end

            cla(obj.Ax);

            p = obj.P;
            [roseLit, stemLit] = obj.resolveLighting();

            S = obj.StemSurfs;
            obj.hStem = surf(obj.Ax, S.X, S.Y, S.Z, ...
                'FaceColor', p.stemColor, 'EdgeColor', 'none', ...
                'FaceLighting', stemLit, 'AmbientStrength', 0.4, ...
                'DiffuseStrength', 0.7, 'SpecularStrength', 0.2);
            obj.hStemCap = patch(obj.Ax, ...
                'Vertices', [S.X(end,:)', S.Y(end,:)', S.Z(end,:)'], ...
                'Faces', 1:p.nStemCirc, ...
                'FaceColor', p.stemColor, 'EdgeColor', 'none', ...
                'FaceLighting', stemLit);

            obj.hSepals = gobjects(p.nSepals, 1);
            for s = 1:p.nSepals
                obj.hSepals(s) = surf(obj.Ax, ...
                    obj.SepalSurfs(s).X, obj.SepalSurfs(s).Y, obj.SepalSurfs(s).Z, ...
                    'FaceColor', p.sepalColor, 'EdgeColor', 'none', ...
                    'FaceLighting', stemLit, 'AmbientStrength', 0.4, ...
                    'DiffuseStrength', 0.7, 'BackFaceLighting', 'lit');
            end

            nTh = numel(obj.ThornSurfs);
            obj.hThorns = gobjects(max(nTh, 0), 1);
            for th = 1:nTh
                obj.hThorns(th) = surf(obj.Ax, ...
                    obj.ThornSurfs(th).X, obj.ThornSurfs(th).Y, obj.ThornSurfs(th).Z, ...
                    'FaceColor', p.thornColor, 'EdgeColor', 'none', ...
                    'FaceLighting', stemLit, 'AmbientStrength', 0.3);
            end

            k  = min(obj.CurrentFrame, p.nFrames);
            Xr = obj.XFrames(:,:,k);
            Yr = obj.YFrames(:,:,k);
            Zr = obj.ZFrames(:,:,k);

            if strcmp(p.colormapMode, 'static')
                obj.hRose = surf(obj.Ax, Xr, Yr, Zr, ...
                    'LineStyle', 'none', 'FaceLighting', roseLit);
            else
                C0 = hypot(hypot(Xr, Yr), Zr*0.9);
                obj.hRose = surf(obj.Ax, Xr, Yr, Zr, C0, ...
                    'LineStyle', 'none', 'FaceColor', 'interp', 'FaceLighting', roseLit);
            end

            obj.applyColormap(k);

            if hasView
                view(obj.Ax, savedAz, savedEl);
            else
                view(obj.Ax, [-40.5, 30]);
            end
            axis(obj.Ax, 'equal', 'off');
            obj.updateAxisLimits();

            if ~strcmp(p.lightingMode, 'none')
                camlight(obj.Ax, 'headlight');
                light(obj.Ax, 'Position', [0, 0, 5],    'Style', 'infinite');
                light(obj.Ax, 'Position', [2, 2, 3],    'Style', 'infinite');
                light(obj.Ax, 'Position', [-2, -1, -1], 'Style', 'infinite', 'Color', [0.3, 0.3, 0.3]);
            end

            obj.Ax.OuterPosition = [0, 0, 1, 1];
        end

        function updateRoseFrame(obj, k)
            if isempty(obj.hRose) || ~isvalid(obj.hRose), return; end
            p  = obj.P;
            Xr = obj.XFrames(:,:,k);
            Yr = obj.YFrames(:,:,k);
            Zr = obj.ZFrames(:,:,k);

            if strcmp(p.colormapMode, 'dynamic')
                C = hypot(hypot(Xr, Yr), Zr*0.9);
                set(obj.hRose, 'XData', Xr, 'YData', Yr, 'ZData', Zr, 'CData', C);
                darkness = (48 - obj.f_norm(k))/48;
                t = linspace(darkness, 1, 256).^2;
                colormap(obj.Ax, t' * p.roseColor);
            elseif strcmp(p.colormapMode, 'custom')
                C = hypot(hypot(Xr, Yr), Zr*0.9);
                set(obj.hRose, 'XData', Xr, 'YData', Yr, 'ZData', Zr, 'CData', C);
            else
                set(obj.hRose, 'XData', Xr, 'YData', Yr, 'ZData', Zr);
            end
            % No drawnow here — the animation loop or caller handles it
        end

        function applyColormap(obj, k)
            p = obj.P;
            if strcmp(p.colormapMode, 'dynamic')
                darkness = (48 - obj.f_norm(k))/48;
                t = linspace(darkness, 1, 256).^2;
                colormap(obj.Ax, t' * p.roseColor);
            elseif strcmp(p.colormapMode, 'custom')
                colormap(obj.Ax, BloomingRoseGUI.roseColormap(p.colormapName));
                if ~p.autoClim
                    caxis(obj.Ax, [p.climLo, p.climHi]); %#ok<CAXIS>
                end
            else
                t = linspace(1, 0.25, 10)';
                colormap(obj.Ax, t * p.roseColor);
            end
        end

        function updateAxisLimits(obj)
            p   = obj.P;
            pad = 0.15;
            S   = obj.StemSurfs;
            kE  = p.nFrames;
            obj.Ax.XLim = [min(min(obj.XFrames(:,:,kE), [], 'all'), min(S.X(:)))-pad, ...
                           max(max(obj.XFrames(:,:,kE), [], 'all'), max(S.X(:)))+pad];
            obj.Ax.YLim = [min(min(obj.YFrames(:,:,kE), [], 'all'), min(S.Y(:)))-pad, ...
                           max(max(obj.YFrames(:,:,kE), [], 'all'), max(S.Y(:)))+pad];
            obj.Ax.ZLim = [min(min(obj.ZFrames(:,:,kE), [], 'all'), min(S.Z(:)))-pad, ...
                           max(max(obj.ZFrames(:,:,kE), [], 'all'), max(S.Z(:)))+pad];
        end

        function [roseLit, stemLit] = resolveLighting(obj)
            switch obj.P.lightingMode
                case 'full',   roseLit = 'gouraud'; stemLit = 'gouraud';
                case 'hybrid', roseLit = 'none';    stemLit = 'gouraud';
                case 'none',   roseLit = 'none';    stemLit = 'none';
            end
        end

        %% ═════════════════════════════════════════════════════════════
        %  ANIMATION
        %  ═════════════════════════════════════════════════════════════

        function startAnimation(obj)
            if obj.IsPlaying, return; end
            obj.IsPlaying  = true;
            obj.FrameAccum = 0;
            obj.PlayButton.Text = [char(9208), ' Pause'];
            obj.PlayButton.BackgroundColor = [0.3, 0.5, 0.7];
            obj.updateStatus('Playing...');

            % Uncapped while-loop animation
            frameTimes = zeros(1, 30);
            ftIdx = 0;
            ftCount = 0;

            try
                while obj.IsPlaying && isvalid(obj.Fig)
                    tic;

                    % ── Render current frame ──
                    obj.updateRoseFrame(obj.CurrentFrame);
                    obj.updateTimeDisplay();
                    drawnow;
                    pause(0);  % yield for rotation interaction

                    % ── Capture (only on new frames) ──
                    if obj.IsRecording && isvalid(obj.Ax)
                        if obj.CurrentFrame ~= obj.LastCaptured
                            frame = obj.captureAxesPanel();
                            if obj.IsRecording  % re-check after getframe's drawnow
                                obj.RecordedFrames{end+1} = frame;
                                obj.RecordButton.Text = sprintf('%s Rec (%d)', char(9210), numel(obj.RecordedFrames));
                                obj.LastCaptured = obj.CurrentFrame;
                            end
                        end
                    end

                    % ── Advance frame ──
                    obj.FrameAccum = obj.FrameAccum + obj.AnimSpeed;
                    while obj.FrameAccum >= 1
                        obj.CurrentFrame = obj.CurrentFrame + 1;
                        obj.FrameAccum   = obj.FrameAccum - 1;
                    end

                    % ── Bounds check ──
                    if obj.CurrentFrame > obj.P.nFrames
                        if obj.IsRecording
                            obj.onRecordToggle(false);
                        end
                        if obj.IsLooping
                            obj.CurrentFrame = 1;
                        else
                            obj.CurrentFrame = obj.P.nFrames;
                            obj.IsPlaying = false;
                            break;
                        end
                    end

                    % FPS measurement
                    elapsed = toc;
                    ftIdx = mod(ftIdx, 30) + 1;
                    frameTimes(ftIdx) = elapsed;
                    ftCount = min(ftCount + 1, 30);

                    if ftCount > 2
                        obj.MeasuredFps = 1 / mean(frameTimes(1:ftCount));
                        if obj.IsRecording
                            obj.StatusLabel.Text = sprintf('Rec %d frames (%.0f fps)', numel(obj.RecordedFrames), obj.MeasuredFps);
                        else
                            obj.StatusLabel.Text = sprintf('Playing (%.0f fps)', obj.MeasuredFps);
                        end
                    end
                end
            catch ME
                if isvalid(obj.Fig)
                    warning(ME.identifier, '%s', ME.message);
                end
            end

            % Loop exited — update UI
            if isvalid(obj.Fig)
                obj.IsPlaying = false;
                obj.PlayButton.Text = [char(9654), ' Play'];
                obj.PlayButton.BackgroundColor = [0.2, 0.6, 0.2];
                obj.updateTimeDisplay();
                if ftCount > 2
                    obj.MeasuredFps = 1 / mean(frameTimes(1:ftCount));
                end

                % Auto-stop recording when playback ends
                if obj.IsRecording
                    obj.onRecordToggle(false);
                end

                obj.updateStatus('Paused');
            end
        end

        function stopAnimation(obj)
            obj.IsPlaying = false;
        end

        function deferStart(obj)
            % Cancel any pending deferred start
            if ~isempty(obj.DeferTimer) && isvalid(obj.DeferTimer)
                stop(obj.DeferTimer);
                delete(obj.DeferTimer);
            end
            obj.DeferTimer = timer('StartDelay', 0.02, 'TasksToExecute', 1, ...
                'TimerFcn', @(~, ~) obj.startAnimation(), ...
                'StopFcn', @(src, ~) delete(src));
            start(obj.DeferTimer);
        end

        function updateTimeDisplay(obj)
            if isempty(obj.TimeLabel) || ~isvalid(obj.TimeLabel), return; end
            obj.TimeLabel.Text = sprintf('Frame %d / %d', obj.CurrentFrame, obj.P.nFrames);
            % Skip slider update while user is dragging (prevents kickback)
            if ~obj.IsDraggingSlider
                if ~isempty(obj.TimeSlider) && isvalid(obj.TimeSlider)
                    obj.TimeSlider.Value = obj.CurrentFrame;
                end
            end
            if ~isempty(obj.BloomLabel) && isvalid(obj.BloomLabel)
                pct = round(100 * (obj.CurrentFrame - 1) / max(obj.P.nFrames - 1, 1));
                obj.BloomLabel.Text = sprintf('Bloom: %d%%', pct);
            end
        end

        %% ═════════════════════════════════════════════════════════════
        %  CALLBACKS
        %  ═════════════════════════════════════════════════════════════

        function onPlayPause(obj)
            if obj.IsPlaying
                obj.stopAnimation();
            else
                if obj.CurrentFrame >= obj.P.nFrames && ~obj.IsLooping
                    obj.CurrentFrame = 1;
                end
                obj.deferStart();
            end
            obj.shiftFocus();
        end

        function onLoopChanged(obj, val)
            obj.IsLooping = val;
            obj.shiftFocus();
        end

        function onSpeedChanging(obj, val)
            snapped = round(val * 2) / 2;   % nearest 0.5
            snapped = max(0.5, min(3.0, snapped));
            obj.AnimSpeed = snapped;
            obj.SpeedLabel.Text = sprintf('%.1fx', snapped);
        end

        function onSpeedChanged(obj, val)
            snapped = round(val * 2) / 2;
            snapped = max(0.5, min(3.0, snapped));
            obj.AnimSpeed = snapped;
            obj.SpeedSlider.Value = snapped;
            obj.SpeedLabel.Text = sprintf('%.1fx', snapped);
            obj.shiftFocus();
        end

        function onTimeSliderDragging(obj, val)
            obj.IsDraggingSlider = true;
            if obj.IsPlaying && ~obj.WasPlayingBeforeDrag
                obj.WasPlayingBeforeDrag = true;
                obj.stopAnimation();
            end
            obj.CurrentFrame = max(1, min(obj.P.nFrames, val));
            obj.updateRoseFrame(obj.CurrentFrame);
            obj.updateTimeDisplay();
            drawnow;
        end

        function onTimeSliderReleased(obj, val)
            obj.CurrentFrame = max(1, min(obj.P.nFrames, val));
            obj.updateRoseFrame(obj.CurrentFrame);
            obj.IsDraggingSlider = false;
            obj.updateTimeDisplay();
            drawnow;
            if obj.WasPlayingBeforeDrag
                obj.WasPlayingBeforeDrag = false;
                obj.deferStart();
            end
            obj.shiftFocus();
        end

        function onFrameStep(obj, delta)
            if obj.IsPlaying, obj.stopAnimation(); end
            newFrame = obj.CurrentFrame + delta;
            if newFrame < 1
                newFrame = obj.IsLooping * obj.P.nFrames + ~obj.IsLooping;
            elseif newFrame > obj.P.nFrames
                newFrame = obj.IsLooping + ~obj.IsLooping * obj.P.nFrames;
            end
            obj.CurrentFrame = newFrame;
            obj.updateRoseFrame(obj.CurrentFrame);
            obj.updateTimeDisplay();
            obj.shiftFocus();
        end

        function onKeyPress(obj, evt)
            switch evt.Key
                case 'space',        obj.onPlayPause();
                case 'escape'
                    obj.stopAnimation();
                    obj.CurrentFrame = 1;
                    obj.updateRoseFrame(1);
                    obj.updateTimeDisplay();
                    drawnow;
                    obj.updateStatus('Ready');
                case {'comma', 'leftarrow'},   obj.onFrameStep(-1);
                case {'period', 'rightarrow'}, obj.onFrameStep(1);
                case 'home'
                    if obj.IsPlaying, obj.stopAnimation(); end
                    obj.CurrentFrame = 1;
                    obj.updateRoseFrame(1);
                    obj.updateTimeDisplay();
                    drawnow;
                case 'end'
                    if obj.IsPlaying, obj.stopAnimation(); end
                    obj.CurrentFrame = obj.P.nFrames;
                    obj.updateRoseFrame(obj.CurrentFrame);
                    obj.updateTimeDisplay();
                    drawnow;
                case 'uparrow'
                    newSpeed = min(3.0, obj.AnimSpeed + 0.5);
                    obj.AnimSpeed = newSpeed;
                    obj.SpeedSlider.Value = newSpeed;
                    obj.SpeedLabel.Text = sprintf('%.1fx', newSpeed);
                case 'downarrow'
                    newSpeed = max(0.5, obj.AnimSpeed - 0.5);
                    obj.AnimSpeed = newSpeed;
                    obj.SpeedSlider.Value = newSpeed;
                    obj.SpeedLabel.Text = sprintf('%.1fx', newSpeed);
                case 'l'
                    obj.IsLooping = ~obj.IsLooping;
                    obj.LoopCheckbox.Value = obj.IsLooping;
                case 'r'
                    obj.onRecordToggle(~obj.IsRecording);
                case 'p'
                    obj.onScreenshot();
                case 'c'
                    obj.CropCheckbox.Value = ~obj.CropCheckbox.Value;
                case 'e'
                    obj.onExport();
                case {'q', 'x'}
                    obj.onFigureClose();
            end
        end

        function onFlowerChanged(obj, field, val)
            wasPlaying = obj.IsPlaying;
            if wasPlaying, obj.stopAnimation(); end

            obj.P.(field) = val;

            d = uiprogressdlg(obj.Fig, 'Title', 'Recomputing', ...
                'Message', 'Precomputing rose frames...', 'Indeterminate', 'on');
            obj.computeRoseFrames();
            close(d);

            obj.CurrentFrame = min(obj.CurrentFrame, obj.P.nFrames);
            obj.TimeSlider.Limits = [1, obj.P.nFrames];
            obj.TimeSlider.Value  = obj.CurrentFrame;

            obj.drawScene();
            obj.updateTimeDisplay();
            if wasPlaying, obj.deferStart(); end
        end

        function onRoseColorChanged(obj, color)
            obj.P.roseColor = color;
            obj.applyColormap(obj.CurrentFrame);
            obj.shiftFocus();
        end

        function onBgColorChanged(obj, color)
            obj.P.bgColor = color;
            obj.Fig.Color = color;
            obj.AxPanel.BackgroundColor = color;
            obj.MainGrid.BackgroundColor = color;
            obj.Ax.Color = color;
            obj.shiftFocus();
        end

        function onStemChanged(obj, field, val)
            wasPlaying = obj.IsPlaying;
            if wasPlaying, obj.stopAnimation(); end

            obj.P.(field) = val;

            d = uiprogressdlg(obj.Fig, 'Title', 'Recomputing', ...
                'Message', 'Rebuilding stem geometry...', 'Indeterminate', 'on');
            obj.computeStemSystem();
            close(d);

            obj.drawScene();
            if wasPlaying, obj.deferStart(); end
        end

        function onColorChanged(obj, field, color)
            obj.P.(field) = color;
            switch field
                case 'stemColor'
                    if isvalid(obj.hStem),    obj.hStem.FaceColor = color; end
                    if isvalid(obj.hStemCap), obj.hStemCap.FaceColor = color; end
                case 'sepalColor'
                    for s = 1:numel(obj.hSepals)
                        if isvalid(obj.hSepals(s)), obj.hSepals(s).FaceColor = color; end
                    end
                case 'thornColor'
                    for th = 1:numel(obj.hThorns)
                        if isvalid(obj.hThorns(th)), obj.hThorns(th).FaceColor = color; end
                    end
            end
        end

        function onPresetChanged(obj, val)
            obj.P.scenePreset = val;
            obj.applyPreset(val);

            wasPlaying = obj.IsPlaying;
            if wasPlaying, obj.stopAnimation(); end
            obj.drawScene();
            if wasPlaying, obj.deferStart(); end
            obj.shiftFocus();
        end

        function applyPreset(obj, name)
            isCustom = strcmp(name, 'custom');

            if ~isCustom
                [cMode, ~, cLim, lMode, rCol] = BloomingRoseGUI.rosePreset(name);
                obj.P.colormapMode = cMode;
                obj.P.lightingMode = lMode;
                obj.P.roseColor    = rCol;
                obj.P.colormapName = obj.reverseColormapName(name);
                if isnumeric(cLim)
                    obj.P.autoClim = false;
                    obj.P.climLo   = cLim(1);
                    obj.P.climHi   = cLim(2);
                else
                    obj.P.autoClim = true;
                    obj.P.climLo   = 0;
                    obj.P.climHi   = 1.6;
                end
            end

            enable = matlab.lang.OnOffSwitchState(isCustom);
            obj.wColormapMode.Value  = obj.P.colormapMode;
            obj.wColormapMode.Enable = enable;

            % Guard: only set dropdown value if it's a valid item
            if ismember(obj.P.colormapName, obj.ColormapItems)
                obj.wColormapName.Value = obj.P.colormapName;
            end

            obj.wLightingMode.Value  = obj.P.lightingMode;
            obj.wLightingMode.Enable = enable;
            obj.wAutoClim.Value      = obj.P.autoClim;
            obj.wAutoClim.Enable     = enable;
            obj.wRoseColor.Value     = obj.P.roseColor;

            obj.syncRow3Visibility();
            % Enable/disable the visible row 3 widget
            if isCustom
                if strcmp(obj.P.colormapMode, 'custom')
                    obj.wColormapName.Enable = 'on';
                else
                    obj.wRoseColor.Enable = 'on';
                end
            else
                obj.wRoseColor.Enable = 'off';
                obj.wColormapName.Enable = 'off';
            end

            climEnable = matlab.lang.OnOffSwitchState(isCustom && ~obj.P.autoClim);
            obj.wClimRange.Value  = [obj.P.climLo, obj.P.climHi];
            obj.wClimRange.Enable = climEnable;

            % Apply CLim to axes immediately
            if ~isempty(obj.Ax) && isvalid(obj.Ax)
                if obj.P.autoClim
                    obj.Ax.CLimMode = 'auto';
                else
                    caxis(obj.Ax, [obj.P.climLo, obj.P.climHi]); %#ok<CAXIS>
                end
            end
        end

        function name = reverseColormapName(~, presetName)
            map = struct( ...
                'dark_velvet',  'black baccara', ...
                'rose_gold',    'rose gold', ...
                'aurora',       'aurora borealis', ...
                'neon',         'cyberwave', ...
                'frozen',       'frozen', ...
                'solar',        'solar flare', ...
                'phantom',      'phantom orchid', ...
                'radioactive',  'radioactive', ...
                'winter',       'winter', ...
                'turbo',        'turbo');
            key = strrep(presetName, ' ', '_');
            if isfield(map, key)
                name = map.(key);
            else
                name = 'aobara';
            end
        end

        function onAppearanceChanged(obj, field, val)
            obj.P.(field) = val;

            wasPlaying = obj.IsPlaying;
            if wasPlaying, obj.stopAnimation(); end
            obj.drawScene();
            if wasPlaying, obj.deferStart(); end
        end

        function onMapModeChanged(obj, val)
            obj.P.colormapMode = val;
            obj.syncRow3Visibility();

            % Enable the visible row-3 widget if preset is custom
            if strcmp(obj.P.scenePreset, 'custom')
                if strcmp(val, 'custom')
                    obj.wColormapName.Enable = 'on';
                else
                    obj.wRoseColor.Enable = 'on';
                end
            end

            wasPlaying = obj.IsPlaying;
            if wasPlaying, obj.stopAnimation(); end
            obj.drawScene();
            if wasPlaying, obj.deferStart(); end
            obj.shiftFocus();
        end

        function syncRow3Visibility(obj)
            isCustom = strcmp(obj.P.colormapMode, 'custom');
            if isCustom
                obj.wRow3Label.Text = 'Colormap';
                obj.wColormapName.Visible = 'on';
                obj.wRoseColor.Visible = 'off';
            else
                obj.wRow3Label.Text = 'Color';
                obj.wColormapName.Visible = 'off';
                obj.wRoseColor.Visible = 'on';
            end
        end

        function onClimChanged(obj)
            obj.P.autoClim = obj.wAutoClim.Value;
            obj.wClimRange.Enable = matlab.lang.OnOffSwitchState(~obj.P.autoClim);

            if obj.P.autoClim
                obj.Ax.CLimMode = 'auto';
            else
                caxis(obj.Ax, [obj.P.climLo, obj.P.climHi]); %#ok<CAXIS>
            end
            obj.applyColormap(obj.CurrentFrame);
            obj.shiftFocus();
        end

        function onClimSliderChanging(obj, val)
            if val(2) - val(1) < 0.01
                if val(2) < 2
                    val(2) = val(1) + 0.01;
                else
                    val(1) = val(2) - 0.01;
                end
            end
            obj.P.climLo = val(1);
            obj.P.climHi = val(2);
            caxis(obj.Ax, val); %#ok<CAXIS>
        end

        function onClimSliderChanged(obj, val)
            if val(2) - val(1) < 0.01
                if val(2) < 2
                    val(2) = val(1) + 0.01;
                else
                    val(1) = val(2) - 0.01;
                end
                obj.wClimRange.Value = val;
            end
            obj.P.climLo = val(1);
            obj.P.climHi = val(2);
            caxis(obj.Ax, val); %#ok<CAXIS>
            obj.shiftFocus();
        end

        %% ═════════════════════════════════════════════════════════════
        %  RECORDING & EXPORTING
        %  ═════════════════════════════════════════════════════════════

        function onRecordToggle(obj, value)
            % Guard against re-entry (programmatic Value set may fire callback)
            if obj.RecordToggling, return; end
            obj.RecordToggling = true;

            obj.IsRecording = value;
            obj.RecordButton.Value = value;  % sync visual (guarded)

            if value
                obj.RecordedFrames = {};
                obj.RecordButton.Text = [char(9210), ' Rec (0)'];
                obj.RecordButton.BackgroundColor = [0.8, 0.1, 0.1];
                obj.ExportButton.Enable = 'off';
                obj.updateStatus('Recording...');
                % Restart animation from beginning
                obj.CurrentFrame = 1;
                obj.FrameAccum = 0;
                obj.LastCaptured = 0;
                if ~obj.IsPlaying
                    obj.deferStart();
                end
            else
                obj.RecordButton.Text = [char(9210), ' Record'];
                obj.RecordButton.BackgroundColor = [0.5, 0.2, 0.2];
                nRec = numel(obj.RecordedFrames);
                if nRec > 0
                    obj.ExportButton.Enable = 'on';
                    obj.ExportButton.Text = sprintf('Export (%d)', nRec);
                    obj.updateStatus(sprintf('Recorded %d frames', nRec));
                else
                    obj.updateStatus('Recording cancelled');
                end
            end

            obj.RecordToggling = false;
            obj.shiftFocus();
        end

        function img = captureAxesPanel(obj)
            % Capture the axes content directly
            frame = getframe(obj.Ax);
            img = frame.cdata;
        end

        function [r1, r2, c1, c2] = getCropRect(~, imgSize)
            %GETCROPRECT  Compute crop rectangle with fixed percentage margins.
            %   Removes dead space around the 3D plot area.
            imgH = imgSize(1);
            imgW = imgSize(2);
            margins = [0.15, 0.15, 0.10, 0.15];  % [Left Right Top Bottom]
            c1 = round(imgW * margins(1)) + 1;
            c2 = round(imgW * (1 - margins(2)));
            r1 = round(imgH * margins(3)) + 1;
            r2 = round(imgH * (1 - margins(4)));
        end

        function onScreenshot(obj)
            if isempty(obj.Ax) || ~isvalid(obj.Ax), return; end
            try
                img = obj.captureAxesPanel();

                if obj.CropCheckbox.Value
                    [r1, r2, c1, c2] = obj.getCropRect(size(img));
                    img = img(r1:r2, c1:c2, :);
                end

                defaultName = sprintf('BloomingRose_%s.png', datestr(now, 'yyyymmdd_HHMMSS')); %#ok<TNOW1,DATST>
                [file, path] = uiputfile('*.png', 'Save Screenshot', defaultName);
                if file ~= 0
                    imwrite(img, fullfile(path, file));
                    obj.updateStatus(sprintf('Saved: %s', file));
                end
            catch ME
                obj.updateStatus(['Screenshot failed: ', ME.message]);
            end
        end

        function onExport(obj)
            if isempty(obj.RecordedFrames), return; end

            frameData = obj.RecordedFrames;

            % Crop to axes content if enabled
            if obj.CropCheckbox.Value
                [r1, r2, c1, c2] = obj.getCropRect(size(frameData{1}));
                frameData = cellfun(@(im) im(r1:r2, c1:c2, :), frameData, 'UniformOutput', false);
            end

            [fmt, fps, dith] = obj.showExportDialog(numel(frameData));
            if isempty(fmt), return; end

            timestamp = datestr(now, 'yyyymmdd_HHMMSS'); %#ok<TNOW1,DATST>

            try
                switch fmt
                    case 'mp4'
                        defaultName = sprintf('BloomingRose_%s.mp4', timestamp);
                        [file, path] = uiputfile('*.mp4', 'Save Video', defaultName);
                        if file ~= 0
                            BloomingRoseGUI.exportToVideo(frameData, fullfile(path, file), fps);
                            obj.updateStatus(sprintf('Exported %s', file));
                        end
                    case 'avi'
                        defaultName = sprintf('BloomingRose_%s.avi', timestamp);
                        [file, path] = uiputfile('*.avi', 'Save Video', defaultName);
                        if file ~= 0
                            BloomingRoseGUI.exportToVideo(frameData, fullfile(path, file), fps);
                            obj.updateStatus(sprintf('Exported %s', file));
                        end
                    case 'gif'
                        defaultName = sprintf('BloomingRose_%s.gif', timestamp);
                        [file, path] = uiputfile('*.gif', 'Save GIF', defaultName);
                        if file ~= 0
                            BloomingRoseGUI.exportToGIF(frameData, fullfile(path, file), fps, dith);
                            obj.updateStatus(sprintf('Exported %s', file));
                        end
                    case 'png'
                        folder = uigetdir(pwd, 'Select Folder for PNG Sequence');
                        if folder ~= 0
                            BloomingRoseGUI.exportToPNG(frameData, folder);
                            obj.updateStatus(sprintf('Exported %d PNGs', numel(frameData)));
                        end
                end
            catch ME
                uialert(obj.Fig, ME.message, 'Export Error');
            end
        end

        function onResetToDefaults(obj)
            obj.stopAnimation();

            % Reset recording
            obj.RecordToggling = true;
            obj.IsRecording = false;
            obj.RecordedFrames = {};
            obj.RecordButton.Value = false;
            obj.RecordButton.Text = [char(9210), ' Record'];
            obj.RecordButton.BackgroundColor = [0.5, 0.2, 0.2];
            obj.ExportButton.Enable = 'off';
            obj.ExportButton.Text = 'Export';
            obj.RecordToggling = false;

            obj.initParams();
            obj.CurrentFrame = 1;
            obj.AnimSpeed    = 1.0;
            obj.IsLooping    = true;
            obj.FrameAccum   = 0;
            obj.MeasuredFps  = 0;

            % Sync playback widgets
            obj.wNFrames.Value      = obj.P.nFrames;
            obj.wN.Value            = obj.P.n;
            obj.SpeedSlider.Value   = 1.0;
            obj.SpeedLabel.Text     = '1.0x';
            obj.LoopCheckbox.Value  = true;
            obj.CropCheckbox.Value  = true;
            obj.TimeSlider.Limits   = [1, obj.P.nFrames];
            obj.TimeSlider.Value    = 1;

            % Sync flower widgets + value labels
            obj.syncSlider(obj.wA,        obj.P.A);
            obj.syncSlider(obj.wB,        obj.P.B);
            obj.syncSlider(obj.wPetalNum, obj.P.petalNum);

            % Sync stem widgets + value labels
            obj.syncSlider(obj.wStemLength, obj.P.stemLength);
            obj.syncSlider(obj.wStemRadTop, obj.P.stemRadiusTop);
            obj.syncSlider(obj.wStemRadBot, obj.P.stemRadiusBot);
            obj.syncSlider(obj.wStemCurveX, obj.P.stemCurveX);
            obj.syncSlider(obj.wStemCurveY, obj.P.stemCurveY);
            obj.wNStemLen.Value   = obj.P.nStemLen;
            obj.wNStemCirc.Value  = obj.P.nStemCirc;
            obj.wStemColor.Value  = obj.P.stemColor;

            % Sync sepal widgets + value labels
            obj.wNSepals.Value     = obj.P.nSepals;
            obj.syncSlider(obj.wSepalLength, obj.P.sepalLength);
            obj.syncSlider(obj.wSepalWidth,  obj.P.sepalWidth);
            obj.syncSlider(obj.wSepalDroop,  obj.P.sepalDroop);
            obj.wSepalColor.Value  = obj.P.sepalColor;

            % Sync thorn widgets + value labels
            obj.wNThorns.Value     = obj.P.nThorns;
            obj.syncSlider(obj.wThornHeight, obj.P.thornHeight);
            obj.syncSlider(obj.wThornRadius, obj.P.thornRadius);
            obj.wThornColor.Value  = obj.P.thornColor;

            % Recompute and redraw
            d = uiprogressdlg(obj.Fig, 'Title', 'Resetting', ...
                'Message', 'Recomputing geometry...', 'Indeterminate', 'on');
            obj.computeAll();
            close(d);

            obj.hRose = [];
            obj.drawScene();
            obj.updateTimeDisplay();

            % Sync appearance
            obj.wPreset.Value = obj.P.scenePreset;
            obj.applyPreset(obj.P.scenePreset);
            obj.wRoseColor.Value = obj.P.roseColor;
            obj.wBgColor.Value = obj.P.bgColor;
            obj.Fig.Color = obj.P.bgColor;
            obj.AxPanel.BackgroundColor = obj.P.bgColor;
            obj.MainGrid.BackgroundColor = obj.P.bgColor;
            obj.Ax.Color = obj.P.bgColor;

            obj.updateStatus('Reset to defaults');

            % Deferred autoplay restart
            obj.deferStart();
        end

        function syncSlider(obj, sl, val)
            %SYNCSSLIDER  Set slider value and update its value label.
            sl.Value = val;
            info = sl.UserData;
            info.valLabel.Text = obj.fmtSliderVal(val, info.limits);
        end

        function updateStatus(obj, msg)
            if ~isempty(obj.StatusLabel) && isvalid(obj.StatusLabel)
                obj.StatusLabel.Text = msg;
            end
        end

        function [fmt, fps, dith] = showExportDialog(obj, frameCount)
            %SHOWEXPORTDIALOG  Modal dialog to choose export format, FPS, and dithering.
            fmt  = [];
            fps  = 60;
            dith = true;

            baseW = 220;  expandedW = 330;  dlgH = 160;

            parentPos = obj.Fig.Position;
            dialogX = parentPos(1) + (parentPos(3) - expandedW) / 2;
            dialogY = parentPos(2) + (parentPos(4) - dlgH) / 2;

            dlg = uifigure('Name', 'Export Recording', ...
                'Position', [dialogX dialogY expandedW dlgH], ...
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
                'ButtonPushedFcn', @(~,~) doExport());

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

            function doExport()
                fmt  = fmtDrop.Value;
                fps  = fpsSpin.Value;
                dith = dithCheck.Value;
                close(dlg);
            end
        end

        function onFigureClose(obj)
            try
                obj.IsPlaying = false;
                obj.IsRecording = false;
                if ~isempty(obj.DeferTimer) && isvalid(obj.DeferTimer)
                    stop(obj.DeferTimer);
                    delete(obj.DeferTimer);
                end
            catch
            end
            try
                % Clear callbacks to prevent stale events during teardown
                obj.Fig.CloseRequestFcn = '';
                obj.Fig.KeyPressFcn = '';
                obj.Fig.WindowButtonDownFcn = '';
                if isvalid(obj.RecordButton)
                    obj.RecordButton.ValueChangedFcn = '';
                end
                if isvalid(obj.PlayButton)
                    obj.PlayButton.ButtonPushedFcn = '';
                end
                drawnow;
                pause(0.05);  % let animation loop exit
            catch
            end
            try
                delete(obj.Fig);
            catch
            end
        end
    end

    %% ═══════════════════════════════════════════════════════════════════
    %  STATIC HELPERS
    %  ═══════════════════════════════════════════════════════════════════

    methods (Static, Access = private)

        function exportToVideo(frameData, filepath, fps)
            nF = numel(frameData);
            wb = waitbar(0, 'Exporting video...');
            [~, ~, ext] = fileparts(filepath);
            if strcmpi(ext, '.avi')
                v = VideoWriter(filepath, 'Motion JPEG AVI');
            else
                v = VideoWriter(filepath, 'MPEG-4');
            end
            v.FrameRate = fps;  v.Quality = 95;
            open(v);
            for i = 1:nF
                writeVideo(v, frameData{i});
                if mod(i, 20) == 0 || i == nF, waitbar(i/nF, wb); end
            end
            close(v);  close(wb);
        end

        function exportToGIF(frameData, filepath, fps, useDither)
            nF = numel(frameData);
            dt = 1 / fps;
            if useDither, dm = 'dither'; else, dm = 'nodither'; end

            wb = waitbar(0, 'Building GIF colormap...');
            sIdx = unique(round(linspace(1, nF, min(10, nF))));
            pix  = [];
            for k = sIdx
                s   = frameData{k}(1:4:end, 1:4:end, :);
                pix = [pix; reshape(s, [], 3)]; %#ok<AGROW>
            end
            [~, gCmap] = rgb2ind(reshape(pix, [], 1, 3), 256, dm);

            waitbar(0, wb, 'Exporting GIF...');
            for i = 1:nF
                idx = rgb2ind(frameData{i}, gCmap, dm);
                if i == 1
                    imwrite(idx, gCmap, filepath, 'gif', 'LoopCount', Inf, 'DelayTime', dt);
                else
                    imwrite(idx, gCmap, filepath, 'gif', 'WriteMode', 'append', 'DelayTime', dt);
                end
                if mod(i, 20) == 0 || i == nF, waitbar(i/nF, wb); end
            end
            close(wb);
        end

        function exportToPNG(frameData, folderpath)
            nF = numel(frameData);
            wb = waitbar(0, 'Exporting PNGs...');
            nd = max(4, ceil(log10(nF + 1)));
            fs = sprintf('frame_%%0%dd.png', nd);
            for i = 1:nF
                imwrite(frameData{i}, fullfile(folderpath, sprintf(fs, i)));
                if mod(i, 20) == 0 || i == nF, waitbar(i/nF, wb); end
            end
            close(wb);
        end

        function [cMode, cMap, cLim, lMode, rCol] = rosePreset(name)
            switch lower(name)
                case 'classic',      cMode = 'dynamic'; cMap = [];                                             cLim = 'auto';    lMode = 'full';   rCol = [1.0, 0.0, 0.0];
                case 'matte red',    cMode = 'dynamic'; cMap = [];                                             cLim = 'auto';    lMode = 'none';   rCol = [1.0, 0.0, 0.0];
                case 'dark velvet',  cMode = 'custom';  cMap = BloomingRoseGUI.roseColormap('black baccara');   cLim = [0, 1.6];  lMode = 'full';   rCol = [1.0, 0.0, 0.0];
                case 'rose gold',    cMode = 'custom';  cMap = BloomingRoseGUI.roseColormap('rose gold');       cLim = 'auto';    lMode = 'full';   rCol = [1.0, 0.0, 0.0];
                case 'aurora',       cMode = 'custom';  cMap = BloomingRoseGUI.roseColormap('aurora borealis'); cLim = 'auto';    lMode = 'full';   rCol = [1.0, 0.0, 0.0];
                case 'neon',         cMode = 'custom';  cMap = BloomingRoseGUI.roseColormap('cyberwave');       cLim = 'auto';    lMode = 'none';   rCol = [1.0, 0.0, 0.0];
                case 'frozen',       cMode = 'custom';  cMap = BloomingRoseGUI.roseColormap('frozen');          cLim = [0, 1.6];  lMode = 'hybrid'; rCol = [1.0, 0.0, 0.0];
                case 'solar',        cMode = 'custom';  cMap = BloomingRoseGUI.roseColormap('solar flare');     cLim = [0, 1.6];  lMode = 'none';   rCol = [1.0, 0.0, 0.0];
                case 'phantom',      cMode = 'custom';  cMap = BloomingRoseGUI.roseColormap('phantom orchid');  cLim = [0, 1.6];  lMode = 'hybrid'; rCol = [1.0, 0.0, 0.0];
                case 'radioactive',  cMode = 'custom';  cMap = BloomingRoseGUI.roseColormap('radioactive');     cLim = [0, 1.6];  lMode = 'none';   rCol = [1.0, 0.0, 0.0];
                case 'winter',       cMode = 'custom';  cMap = BloomingRoseGUI.roseColormap('winter');          cLim = [0, 1.6];  lMode = 'full';   rCol = [1.0, 0.0, 0.0];
                case 'turbo',        cMode = 'custom';  cMap = BloomingRoseGUI.roseColormap('turbo');           cLim = 'auto';    lMode = 'full';   rCol = [1.0, 0.0, 0.0];
                otherwise, error('Unknown preset "%s".', name);
            end
        end

        function cmap = roseColormap(name)
            L = @BloomingRoseGUI.lerp;
            t = linspace(0, 1, 256)';
            switch lower(name)
                case 'aobara',          cmap = [L(0.12,0.72,t), L(0.05,0.45,t), L(0.28,0.82,t)];
                case 'true blue',       cmap = [L(0.02,0.18,t), L(0.04,0.38,t), L(0.18,0.78,t)];
                case 'mint green',      cmap = [L(0.1,0.85,t),  L(0.35,1,t),    L(0.25,0.75,t)];
                case 'black baccara',   cmap = [L(0.08,0.55,t), L(0.01,0.02,t), L(0.03,0.06,t)];
                case 'classic red',     cmap = [L(0.25,1.0,t),  L(0.0,0.08,t),  L(0.02,0.05,t)];
                case 'juliet',          cmap = [L(0.55,1.0,t),  L(0.22,0.72,t), L(0.10,0.50,t)];
                case 'amnesia',         cmap = [L(0.35,0.76,t), L(0.28,0.58,t), L(0.38,0.64,t)];
                case 'quicksand',       cmap = [L(0.45,0.90,t), L(0.32,0.72,t), L(0.28,0.62,t)];
                case 'sahara',          cmap = [L(0.50,0.95,t), L(0.38,0.82,t), L(0.18,0.55,t)];
                case 'coral reef',      cmap = [L(0.45,0.98,t), L(0.12,0.52,t), L(0.10,0.45,t)];
                case 'hot pink',        cmap = [L(0.35,1.0,t),  L(0.02,0.28,t), L(0.18,0.52,t)];
                case 'blush',           cmap = [L(0.55,0.96,t), L(0.35,0.75,t), L(0.38,0.76,t)];
                case 'ocean song',      cmap = [L(0.28,0.68,t), L(0.18,0.52,t), L(0.42,0.78,t)];
                case 'golden mustard',  cmap = [L(0.45,0.95,t), L(0.28,0.75,t), L(0.02,0.12,t)];
                case 'ivory',           cmap = [L(0.65,1.0,t),  L(0.58,0.96,t), L(0.45,0.88,t)];
                case 'free spirit',     cmap = [L(0.50,1.0,t),  L(0.15,0.55,t), L(0.02,0.12,t)];
                case 'burgundy',        cmap = [L(0.12,0.50,t), L(0.02,0.05,t), L(0.06,0.15,t)];
                case 'rose gold',       cmap = [L(0.42,0.92,t), L(0.22,0.58,t), L(0.18,0.48,t)];
                case 'white mondial',   cmap = [L(0.60,1.0,t),  L(0.68,1.0,t),  L(0.55,0.95,t)];
                case 'shocking blue',   cmap = [L(0.20,0.60,t), L(0.05,0.18,t), L(0.30,0.65,t)];
                case 'cafe latte',      cmap = [L(0.25,0.75,t), L(0.15,0.58,t), L(0.08,0.42,t)];
                case 'cyberwave',       cmap = [L(0.0,1.0,t),   L(0.85,0.10,t), L(0.90,0.80,t)];
                case 'solar flare',     cmap = [L(0.30,1.0,t).^0.7, L(0.0,0.95,t).^1.5, L(0.0,0.70,t).^2.5];
                case 'abyssal',         cmap = [L(0.0,0.10,t),  L(0.02,0.85,t), L(0.05,0.65,t)];
                case 'nebula',          cmap = [L(0.08,0.85,t), L(0.02,0.30,t), L(0.22,0.55,t)];
                case 'molten gold',     cmap = [L(0.05,1.0,t).^0.8, L(0.02,0.88,t).^1.2, L(0.0,0.40,t).^2.0];
                case 'frozen',          cmap = [L(0.10,0.88,t), L(0.15,0.92,t), L(0.30,1.0,t)];
                case 'radioactive',     cmap = [L(0.02,0.45,t), L(0.08,1.0,t),  L(0.0,0.15,t)];
                case 'obsidian flame',  cmap = [L(0.03,1.0,t).^1.8, L(0.0,0.25,t).^1.5, L(0.02,0.05,t)];
                case 'aurora borealis', cmap = [0.5*sin(2*pi*t+4)+0.5, 0.5*sin(2*pi*t*0.8)+0.5, 0.5*sin(2*pi*t*0.6+2)+0.5];
                case 'phantom orchid',  cmap = [L(0.85,0.30,t), L(0.85,0.08,t), L(0.88,0.55,t)];
                case 'turbo',           cmap = turbo(256);
                case 'winter',          cmap = winter(256);
                otherwise
                    try
                        fn   = str2func(name);
                        cmap = fn(256);
                    catch
                        error('Unknown colormap "%s".', name);
                    end
            end
        end

        function v = lerp(a, b, t)
            v = a + (b - a) * t;
        end
    end
end
