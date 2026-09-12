function RamanFitApp(filename)
% RAMANFITAPP  Single-window app for fitting experimental Raman spectra.
%
%   RamanFitApp()
%   RamanFitApp(filename)
%
%   Loads a two-column (wavenumber, intensity) text/CSV spectrum, offers
%   baseline subtraction (BACKCOR) and Savitzky-Golay smoothing as
%   preprocessing steps, then fits a sum of Gauss-Lorentz peaks (GAUSSLOR)
%   to the result via LSQCURVEFIT. Each peak's shape (Gaussian, Lorentzian,
%   or Pseudo-Voigt) is chosen independently from a per-row dropdown, so a
%   fit can mix shapes -- the reason a custom multi-peak model is used here
%   instead of PEAKFIT.M, which only supports one shared shape per call.
%
%   Input:
%       filename - (optional) a two-column spectrum file to load
%                  immediately. If omitted, opens empty with a
%                  "Load spectrum..." button.
%
%   See also GAUSSLOR, AREAGL, BACKCOR, SGOLAYFILT, LSQCURVEFIT.
%
%   Author: Sebastiano Trusso
%   Developed with the assistance of an AI coding tool (Claude, Anthropic), under the author's supervision and review.

if nargin < 1
    filename = '';
end
filename = char(filename);

% GAUSSLOR/AREAGL/BACKCOR/READDPT/AIRPLS are all copied into this same
% folder (not left in their original sibling folders under prog/) so
% RamanFit is self-contained -- MATLAB always resolves a function call
% against its caller's own directory first, so no ADDPATH is needed.

% -------------------------------------------------------------------------
% Session state (nested-function closures share these -- same single-file,
% no-classdef pattern used by G_gaussian_viewer.m).
% -------------------------------------------------------------------------
rawX = []; rawY = [];
workingY = [];
currentBaseline = [];
currentBaselineMask = [];
currentSmoothed = [];
pickArmed = false;
xi = [];  % dense grid for smooth fit-curve/component plotting

% Snapshots of WORKINGY taken right after each preprocessing step commits
% (baseline subtraction / smoothing), kept purely so "Save data (.mat)"
% can export each pipeline stage separately -- WORKINGY itself is a
% single evolving array with no history once a later step overwrites it.
% Empty = that step was never applied this session.
backsubY = [];
smoothedY = [];

% Full parameters of the most recently completed fit (peaksTable/
% resultsTable only show a display-friendly subset -- e.g. the
% shape-specific "extra" parameter, needed to reconstruct each peak's
% curve exactly, isn't shown anywhere in the UI), kept so "Save data
% (.mat)" can export the fit without re-running it. Empty = no fit yet.
lastFitPeaks = struct('Shape', {}, 'I', {}, 'I_err', {}, 'FWHM', {}, 'FWHM_err', {}, 'x0', {}, 'x0_err', {}, 'ExtraName', {}, 'ExtraValue', {});
lastFitBgDegree = -1;
lastFitBgCoeffs = [];
lastFitWorkingY = [];  % WORKINGY exactly as it was when this fit ran (may include normalization, not just baseline/smoothing)

% Analysis range (wavenumber window), set by dragging on the plot or
% typing into the Min/Max fields. Empty = no restriction (use the full
% spectrum) -- the default at load and after "Clear range".
rangeXMin = [];
rangeXMax = [];
rangeArmed = false;
isDragging = false;
dragStartX = [];

% -------------------------------------------------------------------------
% Find the active monitor, then build the window in one atomic call (same
% "throwaway invisible figure" trick as G_gaussian_viewer.m).
% -------------------------------------------------------------------------
winW = 1150;
winH = 890;
tmpFig = figure('Visible', 'off');
drawnow;
tmpPos = tmpFig.Position;
delete(tmpFig);

mp = get(groot, 'MonitorPositions');
monIdx = find(tmpPos(1) >= mp(:,1) & tmpPos(1) <= mp(:,1) + mp(:,3) & ...
              tmpPos(2) >= mp(:,2) & tmpPos(2) <= mp(:,2) + mp(:,4), 1);
if isempty(monIdx), monIdx = 1; end
scr = mp(monIdx, :);

winX = scr(1) + 20;
winY = max(scr(2) + 40, scr(2) + scr(4) - winH - 80);

fig = uifigure('Name', 'RamanFitApp', 'Position', [winX winY winW winH]);
% AX (below) gets a custom ButtonDownFcn for peak-picking/range-selection,
% which conflicts with the axes toolbar's own zoom/pan mode management --
% toggling zoom via the toolbar internally tries to manage ButtonDownFcn
% too, which MATLAB warns about (confirmed harmless: the custom callback
% value survives untouched across the mode transition). Suppressed only
% for this app's lifetime; restored to whatever it was before on close.
warnState = warning('off', 'MATLAB:modes:mode:InvalidPropertySet');
fig.CloseRequestFcn = @(src, evt) closeApp();

% -------------------------------------------------------------------------
% Window layout: bottom status strip, left sidebar, central spectrum view.
% -------------------------------------------------------------------------
sidebarW = 660;  % wide enough for the Peaks table's per-parameter Fix/Min/Max columns

statusLabel = uilabel(fig, 'Position', [10 8 winW-20 28], ...
    'Text', 'No spectrum loaded.', 'FontColor', [0.35 0.35 0.35]);

sidebar = uipanel(fig, 'Position', [0 40 sidebarW winH-40], 'BorderType', 'line');

% Main spectrum view on top, a shorter residuals strip below it, sharing
% the x-axis (linked so zooming/panning one moves the other) -- residuals
% are only populated after a Fit, empty otherwise.
residualsAx = uiaxes(fig, 'Position', [sidebarW+10 45 winW-sidebarW-20 150]);
xlabel(residualsAx, 'Raman shift (cm^{-1})');
ylabel(residualsAx, 'Residual');
grid(residualsAx, 'on');

ax = uiaxes(fig, 'Position', [sidebarW+10 210 winW-sidebarW-20 winH-260]);
ax.Toolbar.Visible = 'on';
xlabel(ax, 'Raman shift (cm^{-1})');
ylabel(ax, 'Intensity (a.u.)');
grid(ax, 'on');
linkaxes([ax, residualsAx], 'x');
% Clicking/dragging the axes places a peak (when "Add peak" is armed) or
% starts/extends a range selection (when "Select range" is armed). All
% plotted lines get PickableParts='none' so a click anywhere in the axes
% -- even on top of a line -- reaches this callback instead of being
% consumed by the line's own hit-testing.
ax.ButtonDownFcn = @(s,e) onAxesClicked(e);

uibutton(sidebar, 'push', 'Position', [10 810 sidebarW-20 30], ...
    'Text', 'Load spectrum...', 'FontWeight', 'bold', ...
    'ButtonPushedFcn', @(s,e) onLoadSpectrum());
lblFile     = uilabel(sidebar, 'Position', [10 786 sidebarW-20 18], 'Text', 'File: -');
lblNPoints  = uilabel(sidebar, 'Position', [10 768 sidebarW-20 18], 'Text', 'Points: -');

% ---- Analysis range (shared by baseline + fit) ---------------------------
uilabel(sidebar, 'Position', [10 740 sidebarW-20 18], 'Text', 'Analysis range (cm^{-1}):', 'FontWeight', 'bold');
uilabel(sidebar, 'Position', [10 712 34 18], 'Text', 'Min:');
rangeMinField = uieditfield(sidebar, 'numeric', 'Position', [46 710 120 22], ...
    'ValueChangedFcn', @(s,e) onRangeFieldChanged());
uilabel(sidebar, 'Position', [176 712 34 18], 'Text', 'Max:');
rangeMaxField = uieditfield(sidebar, 'numeric', 'Position', [212 710 120 22], ...
    'ValueChangedFcn', @(s,e) onRangeFieldChanged());
selectRangeBtn = uibutton(sidebar, 'push', 'Position', [10 676 (sidebarW-30)/2 28], ...
    'Text', 'Select range (drag on plot)', 'ButtonPushedFcn', @(s,e) onSelectRangeBtn());
uibutton(sidebar, 'push', 'Position', [20+(sidebarW-30)/2 676 (sidebarW-30)/2 28], ...
    'Text', 'Clear range', 'ButtonPushedFcn', @(s,e) onClearRange());
uibutton(sidebar, 'push', 'Position', [10 642 (sidebarW-30)/2 28], ...
    'Text', 'Zoom to range', 'ButtonPushedFcn', @(s,e) onZoomToRange());
uibutton(sidebar, 'push', 'Position', [20+(sidebarW-30)/2 642 (sidebarW-30)/2 28], ...
    'Text', 'Show full spectrum', 'ButtonPushedFcn', @(s,e) onShowFullSpectrum());
tg = uitabgroup(sidebar, 'Position', [5 10 sidebarW-10 584]);
tabPreprocess = uitab(tg, 'Title', 'Preprocess');
tabPeaks      = uitab(tg, 'Title', 'Peaks');
tabResults    = uitab(tg, 'Title', 'Results');

% Created after the tabgroup so it renders on top of the tab-strip in
% case its rendering encroaches above the tabgroup's declared Position.
uibutton(sidebar, 'push', 'Position', [10 608 sidebarW-20 28], ...
    'Text', 'Reset Y axis', 'ButtonPushedFcn', @(s,e) onResetYAxis());

% ---- Preprocess tab ------------------------------------------------------
uilabel(tabPreprocess, 'Position', [5 560 sidebarW-30 18], 'Text', 'Baseline', 'FontWeight', 'bold');
uilabel(tabPreprocess, 'Position', [5 534 60 18], 'Text', 'Method:');
baselineMethodDD = uidropdown(tabPreprocess, 'Position', [65 532 sidebarW-95 22], ...
    'Items', {'backcor','airPLS','SNIP'}, 'Value', 'backcor', ...
    'ValueChangedFcn', @(s,e) onBaselineMethodChanged());

% backcor parameters (visible when Method = backcor)
lblOrder = uilabel(tabPreprocess, 'Position', [5 506 110 18], 'Text', 'Order:');
baselineOrderField = uieditfield(tabPreprocess, 'numeric', 'Position', [140 504 sidebarW-170 22], ...
    'Value', 5, 'Limits', [0 Inf], 'RoundFractionalValues', 'on');
lblThreshold = uilabel(tabPreprocess, 'Position', [5 478 110 18], 'Text', 'Threshold:');
baselineThresholdField = uieditfield(tabPreprocess, 'numeric', 'Position', [140 476 sidebarW-170 22], 'Value', 0.1);
lblCostFn = uilabel(tabPreprocess, 'Position', [5 450 110 18], 'Text', 'Cost function:');
baselineFctDD = uidropdown(tabPreprocess, 'Position', [140 448 sidebarW-170 22], ...
    'Items', {'sh','ah','stq','atq'}, 'Value', 'atq');
backcorHandles = [lblOrder, baselineOrderField, lblThreshold, baselineThresholdField, lblCostFn, baselineFctDD];

% airPLS parameters (visible when Method = airPLS), packed two-per-row
% into the same vertical footprint as the backcor controls above.
lblLambda = uilabel(tabPreprocess, 'Position', [5 506 55 18], 'Text', 'Lambda:');
airplsLambdaField = uieditfield(tabPreprocess, 'numeric', 'Position', [62 504 110 22], 'Value', 1e7);
lblDiffOrder = uilabel(tabPreprocess, 'Position', [180 506 60 18], 'Text', 'Diff ord:');
airplsOrderField = uieditfield(tabPreprocess, 'numeric', 'Position', [237 504 sidebarW-30-232 22], ...
    'Value', 2, 'Limits', [1 Inf], 'RoundFractionalValues', 'on');
lblEdgeWt = uilabel(tabPreprocess, 'Position', [5 478 55 18], 'Text', 'Edge wt:');
airplsWepField = uieditfield(tabPreprocess, 'numeric', 'Position', [62 476 110 22], ...
    'Value', 0.1, 'Limits', [0 1]);
lblAsym = uilabel(tabPreprocess, 'Position', [180 478 60 18], 'Text', 'p (asym):');
airplsPField = uieditfield(tabPreprocess, 'numeric', 'Position', [237 476 sidebarW-30-232 22], ...
    'Value', 0.05, 'Limits', [0 1]);
lblMaxIter = uilabel(tabPreprocess, 'Position', [5 450 70 18], 'Text', 'Max iter:');
airplsIterField = uieditfield(tabPreprocess, 'numeric', 'Position', [80 448 100 22], ...
    'Value', 20, 'Limits', [1 Inf], 'RoundFractionalValues', 'on');
airplsHandles = [lblLambda, airplsLambdaField, lblDiffOrder, airplsOrderField, ...
    lblEdgeWt, airplsWepField, lblAsym, airplsPField, lblMaxIter, airplsIterField];
set(airplsHandles, 'Visible', 'off');

% SNIP parameters (visible when Method = SNIP), same footprint again.
lblSnipIter = uilabel(tabPreprocess, 'Position', [5 506 110 18], 'Text', 'Iterations (M):');
snipIterField = uieditfield(tabPreprocess, 'numeric', 'Position', [140 504 sidebarW-170 22], ...
    'Value', 40, 'Limits', [1 Inf], 'RoundFractionalValues', 'on');
snipLLSCheck = uicheckbox(tabPreprocess, 'Position', [5 478 sidebarW-30 22], ...
    'Text', 'Use LLS transform', 'Value', true);
snipHandles = [lblSnipIter, snipIterField, snipLLSCheck];
set(snipHandles, 'Visible', 'off');

uibutton(tabPreprocess, 'push', 'Position', [5 416 sidebarW-30 28], ...
    'Text', 'Preview baseline', 'ButtonPushedFcn', @(s,e) onPreviewBaseline());
uibutton(tabPreprocess, 'push', 'Position', [5 382 sidebarW-30 28], ...
    'Text', 'Subtract baseline', 'ButtonPushedFcn', @(s,e) onSubtractBaseline());

uilabel(tabPreprocess, 'Position', [5 342 sidebarW-30 18], 'Text', 'Smoothing (Savitzky-Golay)', 'FontWeight', 'bold');
uilabel(tabPreprocess, 'Position', [5 316 110 18], 'Text', 'Window length:');
smoothWinField = uieditfield(tabPreprocess, 'numeric', 'Position', [140 314 sidebarW-170 22], ...
    'Value', 11, 'Limits', [3 Inf], 'RoundFractionalValues', 'on');
uilabel(tabPreprocess, 'Position', [5 288 110 18], 'Text', 'Poly order:');
smoothOrderField = uieditfield(tabPreprocess, 'numeric', 'Position', [140 286 sidebarW-170 22], ...
    'Value', 3, 'Limits', [0 Inf], 'RoundFractionalValues', 'on');
uibutton(tabPreprocess, 'push', 'Position', [5 254 sidebarW-30 28], ...
    'Text', 'Preview smoothing', 'ButtonPushedFcn', @(s,e) onPreviewSmoothing());
uibutton(tabPreprocess, 'push', 'Position', [5 220 sidebarW-30 28], ...
    'Text', 'Apply smoothing', 'ButtonPushedFcn', @(s,e) onApplySmoothing());

uilabel(tabPreprocess, 'Position', [5 192 sidebarW-30 18], 'Text', 'Normalization', 'FontWeight', 'bold');
uilabel(tabPreprocess, 'Position', [5 166 60 18], 'Text', 'Method:');
normalizeDD = uidropdown(tabPreprocess, 'Position', [65 164 sidebarW-95 22], ...
    'Items', {'None','Max = 1','Area = 1'}, 'Value', 'None');
uibutton(tabPreprocess, 'push', 'Position', [5 130 sidebarW-30 28], ...
    'Text', 'Apply normalization', 'ButtonPushedFcn', @(s,e) onApplyNormalization());

uibutton(tabPreprocess, 'push', 'Position', [5 88 sidebarW-30 30], ...
    'Text', 'Reset to raw', 'ButtonPushedFcn', @(s,e) onResetToRaw());

% ---- Peaks tab -------------------------------------------------------------
uilabel(tabPeaks, 'Position', [5 560 sidebarW-30 24], 'WordWrap', 'on', ...
    'Text', 'Click "Add peak", then click on the plot to place it. Min/Max columns are optional per-parameter fit bounds (blank = default bounds); Fix pins a parameter to its current value, overriding Min/Max.');
addPeakBtn = uibutton(tabPeaks, 'push', 'Position', [5 528 sidebarW-30 28], ...
    'Text', 'Add peak', 'ButtonPushedFcn', @(s,e) onAddPeakBtn());
peaksTable = uitable(tabPeaks, 'Position', [5 200 sidebarW-30 320], ...
    'ColumnName', {'Shape','Center','Fix','C.Min','C.Max','FWHM','Fix','F.Min','F.Max','Height','Fix','H.Min','H.Max'}, ...
    'ColumnFormat', {{'Gaussian','Lorentzian','Pseudo-Voigt','Fano','Pearson VII','True Voigt'}, ...
        'numeric','logical','numeric','numeric','numeric','logical','numeric','numeric','numeric','logical','numeric','numeric'}, ...
    'ColumnWidth', {90, 55, 30, 45, 45, 55, 30, 45, 45, 55, 30, 45, 45}, ...
    'ColumnEditable', true(1,13), 'Data', cell(0,13));
uibutton(tabPeaks, 'push', 'Position', [5 166 sidebarW-30 28], ...
    'Text', 'Remove selected peak', 'ButtonPushedFcn', @(s,e) onRemovePeak());
uibutton(tabPeaks, 'push', 'Position', [5 132 sidebarW-30 28], ...
    'Text', 'Clear all peaks', 'ButtonPushedFcn', @(s,e) onClearPeaks());

uilabel(tabPeaks, 'Position', [5 94 100 18], 'Text', 'Background:');
backgroundDD = uidropdown(tabPeaks, 'Position', [110 92 sidebarW-140 22], ...
    'Items', {'None','Constant','Linear','Quadratic','Cubic'}, 'Value', 'None');

fitBtn = uibutton(tabPeaks, 'push', 'Position', [5 52 sidebarW-30 34], ...
    'Text', 'Fit', 'FontWeight', 'bold', 'ButtonPushedFcn', @(s,e) onFit());

% ---- Results tab -----------------------------------------------------------
resultsTable = uitable(tabResults, 'Position', [5 340 sidebarW-30 244], ...
    'ColumnName', {'Peak','Shape','Center','+/-','FWHM','+/-','Height','+/-','Area'}, ...
    'ColumnWidth', {40, 95, 60, 55, 60, 55, 60, 55, 65}, ...
    'ColumnEditable', false(1,9), 'Data', cell(0,9));
statsLabel = uilabel(tabResults, 'Position', [5 226 sidebarW-30 110], ...
    'Text', 'Fit statistics: -', 'VerticalAlignment', 'top');
uibutton(tabResults, 'push', 'Position', [5 194 sidebarW-30 28], ...
    'Text', 'Export results (CSV)...', 'ButtonPushedFcn', @(s,e) onExportResults());
uibutton(tabResults, 'push', 'Position', [5 160 sidebarW-30 28], ...
    'Text', 'Save fit figure...', 'ButtonPushedFcn', @(s,e) onSaveFigure());
uibutton(tabResults, 'push', 'Position', [5 126 sidebarW-30 28], ...
    'Text', 'Save data (.mat)...', 'ButtonPushedFcn', @(s,e) onSaveMatFile());

% -------------------------------------------------------------------------
if ~isempty(filename)
    loadFile(filename);
end

% =========================================================================
%  Nested callback/helper functions (share the outer function's workspace)
% =========================================================================

    function closeApp()
        warning(warnState);
        delete(fig);
    end

% -------------------------------------------------------------------------
    function [f, p] = pickOpenFile(filterSpec, dlgTitle)
    % Wraps UIGETFILE: on macOS, a uifigure's CEF-based window can end up
    % in front of the native file-picker dialog it just triggered, and
    % since the uifigure is blocked waiting for the (invisible, behind
    % it) dialog, there is then no way to move it out of the way either.
    % Minimising the main window for the duration of the dialog avoids
    % this entirely (fix carried over from G_gaussian_viewer.m, where it
    % was found and debugged).
        prevState = fig.WindowState;
        if strcmp(prevState, 'minimized')
            prevState = 'normal';
        end
        fig.WindowState = 'minimized';
        drawnow;
        try
            [f, p] = uigetfile(filterSpec, dlgTitle);
        catch ME
            fig.WindowState = prevState;
            drawnow;
            rethrow(ME);
        end
        fig.WindowState = prevState;
        drawnow;
    end

% -------------------------------------------------------------------------
    function [f, p] = pickSaveFile(filterSpec, dlgTitle, defaultName)
        prevState = fig.WindowState;
        if strcmp(prevState, 'minimized')
            prevState = 'normal';
        end
        fig.WindowState = 'minimized';
        drawnow;
        try
            [f, p] = uiputfile(filterSpec, dlgTitle, defaultName);
        catch ME
            fig.WindowState = prevState;
            drawnow;
            rethrow(ME);
        end
        fig.WindowState = prevState;
        drawnow;
    end

% -------------------------------------------------------------------------
    function clearTag(tagName)
        delete(findobj(ax, 'Tag', tagName));
    end

% -------------------------------------------------------------------------
    function clearResiduals()
    % CLA alone does not fully clear a uiaxes (same issue documented and
    % fixed in G_gaussian_viewer.m) -- FINDALL recurses into every
    % descendant, with the axes itself filtered back out before deleting.
        kids = findall(residualsAx);
        kids(kids == residualsAx) = [];
        delete(kids);
    end

% -------------------------------------------------------------------------
    function onLoadSpectrum()
        [f, p] = pickOpenFile({'*.txt;*.csv;*.dat;*.dpt','Text/CSV/DPT spectra (*.txt,*.csv,*.dat,*.dpt)'; '*.*','All files'}, ...
            'Select a Raman spectrum');
        if isequal(f, 0)
            return
        end
        try
            loadFile(fullfile(p, f));
        catch ME
            uialert(fig, ME.message, 'Load error');
        end
    end

% -------------------------------------------------------------------------
    function loadFile(f)
        [~, ~, ext] = fileparts(f);
        if strcmpi(ext, '.dpt')
            % READDPT (myfileutil/) parses OPUS-style .dpt files: plain
            % comma-separated wavenumber,intensity, one pair per line, no
            % header -- a different format from the whitespace-delimited
            % files READMATRIX handles below.
            [x, y] = readdpt(f);
            data = [x(:), y(:)];
        else
            data = readmatrix(f);
        end
        if size(data, 2) < 2
            error('RamanFitApp:badFile', 'Expected at least two columns (wavenumber, intensity) in %s.', f);
        end
        [rawX, ord] = sort(data(:,1));
        rawX = rawX(:);
        rawY = data(ord, 2);
        rawY = rawY(:);
        workingY = rawY;
        currentBaseline = [];
        currentBaselineMask = [];
        currentSmoothed = [];
        backsubY = [];
        smoothedY = [];
        lastFitPeaks = struct('Shape', {}, 'I', {}, 'I_err', {}, 'FWHM', {}, 'FWHM_err', {}, 'x0', {}, 'x0_err', {}, 'ExtraName', {}, 'ExtraValue', {});
        lastFitBgDegree = -1;
        lastFitBgCoeffs = [];
        lastFitWorkingY = [];
        rangeXMin = [];
        rangeXMax = [];
        rangeMinField.Value = min(rawX);
        rangeMaxField.Value = max(rawX);
        xi = linspace(min(rawX), max(rawX), 500)';

        kids = findall(ax);
        kids(kids == ax) = [];
        delete(kids);
        peaksTable.Data = cell(0,13);
        scroll(peaksTable, 'top');
        resultsTable.Data = cell(0,9);
        scroll(resultsTable, 'top');
        statsLabel.Text = 'Fit statistics: -';
        clearResiduals();

        plot(ax, rawX, rawY, 'Color', [0.75 0.75 0.75], 'LineWidth', 1, ...
            'PickableParts', 'none', 'Tag', 'rawLine');
        hold(ax, 'on');
        redrawWorking();
        hold(ax, 'off');
        % LINKAXES (set up once at startup, before any data exists) locks
        % XLimMode to 'manual' on both axes, so a freshly loaded spectrum
        % does NOT auto-scale into view -- the view stays at whatever the
        % empty default axes range was until the view is set explicitly.
        ax.XLim = [min(rawX), max(rawX)];

        [~, fname_] = fileparts(f);
        lblFile.Text = sprintf('File: %s', fname_);
        lblNPoints.Text = sprintf('Points: %d', numel(rawX));
        statusLabel.Text = sprintf('Loaded %s (%d points).', fname_, numel(rawX));
    end

% -------------------------------------------------------------------------
    function redrawWorking()
        clearTag('workingLine');
        plot(ax, rawX, workingY, 'b-', 'LineWidth', 1.2, ...
            'PickableParts', 'none', 'Tag', 'workingLine');
    end

% -------------------------------------------------------------------------
    function onBaselineMethodChanged()
        set(backcorHandles, 'Visible', 'off');
        set(airplsHandles, 'Visible', 'off');
        set(snipHandles, 'Visible', 'off');
        switch baselineMethodDD.Value
            case 'airPLS'
                set(airplsHandles, 'Visible', 'on');
            case 'SNIP'
                set(snipHandles, 'Visible', 'on');
            otherwise
                set(backcorHandles, 'Visible', 'on');
        end
    end

% -------------------------------------------------------------------------
    function onPreviewBaseline()
        if isempty(rawX)
            return
        end
        mask = rangeMask();
        try
            switch baselineMethodDD.Value
                case 'airPLS'
                    % airPLS takes a ROW vector (1 spectrum per row); our
                    % data is stored as columns throughout, so transpose
                    % in/out.
                    [~, z] = airPLS(workingY(mask)', airplsLambdaField.Value, ...
                        airplsOrderField.Value, airplsWepField.Value, ...
                        airplsPField.Value, airplsIterField.Value);
                    currentBaseline = z';
                case 'SNIP'
                    currentBaseline = snip(workingY(mask), snipIterField.Value, snipLLSCheck.Value);
                otherwise
                    currentBaseline = backcor(rawX(mask), workingY(mask), baselineOrderField.Value, ...
                        baselineThresholdField.Value, baselineFctDD.Value);
            end
        catch ME
            uialert(fig, ME.message, sprintf('%s error', baselineMethodDD.Value));
            return
        end
        currentBaselineMask = mask;
        clearTag('baselineLine');
        hold(ax, 'on');
        plot(ax, rawX(mask), currentBaseline, 'Color', [0.85 0.45 0.05], 'LineStyle', '--', ...
            'LineWidth', 1.2, 'PickableParts', 'none', 'Tag', 'baselineLine');
        hold(ax, 'off');
        statusLabel.Text = 'Baseline computed (preview only, not yet subtracted).';
    end

% -------------------------------------------------------------------------
    function onSubtractBaseline()
        if isempty(rawX)
            return
        end
        if isempty(currentBaseline)
            onPreviewBaseline();
            if isempty(currentBaseline)
                return
            end
        end
        workingY(currentBaselineMask) = workingY(currentBaselineMask) - currentBaseline;
        currentBaseline = [];
        currentBaselineMask = [];
        clearTag('baselineLine');
        % A pending (uncommitted) smoothing preview was computed against
        % the OLD workingY -- now stale, since workingY just changed.
        currentSmoothed = [];
        clearTag('smoothPreviewLine');
        backsubY = workingY;  % snapshot for "Save data (.mat)" -- see session-state comment above
        redrawWorking();
        statusLabel.Text = 'Baseline subtracted.';
    end

% -------------------------------------------------------------------------
    function onPreviewSmoothing()
        if isempty(rawX)
            return
        end
        winLen = round(smoothWinField.Value);
        if mod(winLen, 2) == 0
            winLen = winLen + 1;
            smoothWinField.Value = winLen;
        end
        try
            currentSmoothed = sgolayfilt(workingY, smoothOrderField.Value, winLen);
        catch ME
            uialert(fig, ME.message, 'sgolayfilt error');
            return
        end
        clearTag('smoothPreviewLine');
        hold(ax, 'on');
        plot(ax, rawX, currentSmoothed, 'Color', [0.55 0.25 0.65], 'LineStyle', '--', ...
            'LineWidth', 1.2, 'PickableParts', 'none', 'Tag', 'smoothPreviewLine');
        hold(ax, 'off');
        statusLabel.Text = 'Smoothing computed (preview only, not yet applied).';
    end

% -------------------------------------------------------------------------
    function onApplySmoothing()
        if isempty(rawX)
            return
        end
        if isempty(currentSmoothed)
            onPreviewSmoothing();
            if isempty(currentSmoothed)
                return
            end
        end
        workingY = currentSmoothed;
        currentSmoothed = [];
        clearTag('smoothPreviewLine');
        % A pending (uncommitted) baseline preview was computed against
        % the OLD workingY -- now stale, since workingY just changed.
        currentBaseline = [];
        currentBaselineMask = [];
        clearTag('baselineLine');
        smoothedY = workingY;  % snapshot for "Save data (.mat)" -- see session-state comment above
        redrawWorking();
        statusLabel.Text = 'Smoothing applied.';
    end

% -------------------------------------------------------------------------
    function onApplyNormalization()
        if isempty(rawX) || strcmp(normalizeDD.Value, 'None')
            return
        end
        % Normalizes against the CURRENT analysis range (RANGEMASK is
        % all-true when no range is set, i.e. the whole spectrum) --
        % "the region you want to fit", matching how baseline/fit already
        % respect that same range.
        mask = rangeMask();
        switch normalizeDD.Value
            case 'Max = 1'
                factor = max(workingY(mask));
            case 'Area = 1'
                factor = trapz(rawX(mask), workingY(mask));
        end
        if ~isfinite(factor) || factor <= 0
            uialert(fig, 'Cannot normalize: the selected region has a non-positive maximum/area.', 'Normalization error');
            return
        end
        workingY = workingY / factor;
        % A pending (uncommitted) baseline/smoothing preview was computed
        % against the OLD workingY -- now stale, since workingY changed.
        currentBaseline = [];
        currentBaselineMask = [];
        clearTag('baselineLine');
        currentSmoothed = [];
        clearTag('smoothPreviewLine');
        redrawWorking();
        statusLabel.Text = sprintf('Normalized by %s (factor = %.4g).', normalizeDD.Value, factor);
    end

% -------------------------------------------------------------------------
    function onResetToRaw()
        if isempty(rawX)
            return
        end
        workingY = rawY;
        currentBaseline = [];
        currentSmoothed = [];
        backsubY = [];
        smoothedY = [];
        lastFitPeaks = struct('Shape', {}, 'I', {}, 'I_err', {}, 'FWHM', {}, 'FWHM_err', {}, 'x0', {}, 'x0_err', {}, 'ExtraName', {}, 'ExtraValue', {});
        lastFitBgDegree = -1;
        lastFitBgCoeffs = [];
        lastFitWorkingY = [];
        clearTag('baselineLine');
        clearTag('smoothPreviewLine');
        clearTag('fitLine');
        clearTag('peakComponentLine');
        clearTag('backgroundFitLine');
        clearTag('peakMarker');
        redrawWorking();
        peaksTable.Data = cell(0,13);
        scroll(peaksTable, 'top');
        resultsTable.Data = cell(0,9);
        scroll(resultsTable, 'top');
        statsLabel.Text = 'Fit statistics: -';
        clearResiduals();
        statusLabel.Text = 'Reset to raw spectrum; peaks and fit cleared.';
    end

% -------------------------------------------------------------------------
    function onAddPeakBtn()
        pickArmed = ~pickArmed;
        if pickArmed
            addPeakBtn.Text = 'Click on plot to place... (click again to cancel)';
        else
            addPeakBtn.Text = 'Add peak';
        end
    end

% -------------------------------------------------------------------------
    function onAxesClicked(evt)
        if isempty(rawX)
            return
        end
        if rangeArmed
            dragStartX = evt.IntersectionPoint(1);
            isDragging = true;
            fig.WindowButtonMotionFcn = @(s,e) onRangeDragMotion();
            fig.WindowButtonUpFcn = @(s,e) onRangeDragUp();
            return
        end
        if ~pickArmed
            return
        end
        xClick = evt.IntersectionPoint(1);
        [~, nearIdx] = min(abs(rawX - xClick));
        heightGuess = workingY(nearIdx);
        fwhmGuess = range(rawX) * 0.01;

        d = peaksTable.Data;
        d(end+1, :) = {'Gaussian', xClick, false, [], [], fwhmGuess, false, [], [], heightGuess, false, [], []};
        peaksTable.Data = d;
        scroll(peaksTable, 'top');

        pickArmed = false;
        addPeakBtn.Text = 'Add peak';
        redrawPeakMarkers();
        statusLabel.Text = sprintf('Peak added at %.1f cm^{-1}.', xClick);
    end

% -------------------------------------------------------------------------
    function onSelectRangeBtn()
        rangeArmed = ~rangeArmed;
        if rangeArmed
            selectRangeBtn.Text = 'Drag on plot... (click to cancel)';
        else
            selectRangeBtn.Text = 'Select range (drag on plot)';
        end
    end

% -------------------------------------------------------------------------
    function onRangeDragMotion()
    % Fired continuously by the FIGURE while the mouse moves anywhere over
    % it (only wired during an active drag, see onAxesClicked). AX.CurrentPoint
    % is a live read-only property that tracks the pointer whenever it is
    % over that axes, in data units -- simpler and more reliable here than
    % converting the motion event's figure-pixel coordinates by hand.
        if ~isDragging
            return
        end
        xNow = ax.CurrentPoint(1,1);
        redrawRangeOverlay(min(dragStartX, xNow), max(dragStartX, xNow));
    end

% -------------------------------------------------------------------------
    function onRangeDragUp()
        if ~isDragging
            return
        end
        isDragging = false;
        fig.WindowButtonMotionFcn = '';
        fig.WindowButtonUpFcn = '';
        xEnd = ax.CurrentPoint(1,1);
        rangeArmed = false;
        selectRangeBtn.Text = 'Select range (drag on plot)';
        applyRangeSelection(min(dragStartX, xEnd), max(dragStartX, xEnd));
    end

% -------------------------------------------------------------------------
    function onRangeFieldChanged()
        if isempty(rawX)
            return
        end
        applyRangeSelection(rangeMinField.Value, rangeMaxField.Value);
    end

% -------------------------------------------------------------------------
    function onClearRange()
        rangeXMin = [];
        rangeXMax = [];
        rangeMinField.Value = min(rawX);
        rangeMaxField.Value = max(rawX);
        clearTag('rangeLine');
        statusLabel.Text = 'Analysis range cleared (using full spectrum).';
    end

% -------------------------------------------------------------------------
    function applyRangeSelection(x1, x2)
    % Single entry point for "a range has been chosen", regardless of
    % whether it came from a mouse drag (untestable headlessly -- AX.CurrentPoint
    % only updates for a real pointer over a rendered, visible axes) or
    % from typing into the Min/Max fields directly (fully scriptable, used
    % to verify this function end-to-end).
        if isempty(rawX)
            return
        end
        x1 = max(x1, min(rawX));
        x2 = min(x2, max(rawX));
        if x2 <= x1
            return
        end
        rangeXMin = x1;
        rangeXMax = x2;
        rangeMinField.Value = x1;
        rangeMaxField.Value = x2;
        redrawRangeOverlay(x1, x2);
        statusLabel.Text = sprintf('Analysis range set to %.1f - %.1f cm^{-1}.', x1, x2);
    end

% -------------------------------------------------------------------------
    function redrawRangeOverlay(x1, x2)
        clearTag('rangeLine');
        xline(ax, x1, '--', 'Color', [0.15 0.55 0.25], 'LineWidth', 1.2, ...
            'PickableParts', 'none', 'Tag', 'rangeLine');
        xline(ax, x2, '--', 'Color', [0.15 0.55 0.25], 'LineWidth', 1.2, ...
            'PickableParts', 'none', 'Tag', 'rangeLine');
    end

% -------------------------------------------------------------------------
    function mask = rangeMask()
    % True for data points inside the current analysis range, or all-true
    % when no range is set (the default -- operate on the full spectrum).
        if isempty(rangeXMin)
            mask = true(size(rawX));
        else
            mask = rawX >= rangeXMin & rawX <= rangeXMax;
        end
    end

% -------------------------------------------------------------------------
    function redrawPeakMarkers()
        clearTag('peakMarker');
        d = peaksTable.Data;
        if isempty(d)
            return
        end
        centers = cell2mat(d(:,2));
        heights = cell2mat(d(:,10));
        hold(ax, 'on');
        plot(ax, centers, heights, 'kv', 'MarkerFaceColor', [0.2 0.2 0.2], ...
            'MarkerSize', 6, 'PickableParts', 'none', 'Tag', 'peakMarker');
        hold(ax, 'off');
    end

% -------------------------------------------------------------------------
    function onRemovePeak()
        rows = peaksTable.Selection;
        if isempty(rows)
            return
        end
        d = peaksTable.Data;
        d(unique(rows(:,1)), :) = [];
        peaksTable.Data = d;
        scroll(peaksTable, 'top');
        redrawPeakMarkers();
    end

% -------------------------------------------------------------------------
    function onClearPeaks()
        peaksTable.Data = cell(0,13);
        scroll(peaksTable, 'top');
        clearTag('peakMarker');
        clearTag('fitLine');
        clearTag('peakComponentLine');
        clearTag('backgroundFitLine');
        clearResiduals();
        statsLabel.Text = 'Fit statistics: -';
    end

% -------------------------------------------------------------------------
    function onZoomToRange()
        if isempty(rangeXMin)
            uialert(fig, 'Select or type an analysis range first.', 'No range set');
            return
        end
        ax.XLim = [rangeXMin, rangeXMax];
    end

% -------------------------------------------------------------------------
    function onShowFullSpectrum()
        if isempty(rawX)
            return
        end
        ax.XLim = [min(rawX), max(rawX)];
    end

% -------------------------------------------------------------------------
    function onResetYAxis()
    % After subtracting a baseline, autoscale still accounts for the
    % (unsubtracted, greyed-out) raw reference line too, so the Y-axis
    % often ends up spanning far more than the working spectrum actually
    % needs, wasting vertical space. Fits the view to the working data
    % alone, with a 20% headroom margin above the peak -- computed as
    % 20% of the data's own range rather than a literal max*1.2, since
    % that would invert (shrink instead of grow) for all-negative data.
        if isempty(workingY)
            return
        end
        yMin = min(workingY);
        yMax = max(workingY);
        margin = 0.2 * (yMax - yMin);
        if margin <= 0
            margin = max(abs(yMax), 1) * 0.2;  % flat data: fall back to a margin based on its own magnitude
        end
        ax.YLim = [yMin, yMax + margin];
    end

% -------------------------------------------------------------------------
    function y = peakModel(x, shape, I, FWHM, x0, extra)
    % Evaluates one peak. EXTRA is the single free shape-specific
    % parameter for shapes that need one (meaning depends on SHAPE);
    % ignored by Gaussian/Lorentzian, which have no extra parameter.
        switch shape
            case 'Lorentzian'
                y = gausslor(x, I, 1, FWHM, x0);
            case 'Pseudo-Voigt'
                y = gausslor(x, I, extra, FWHM, x0);  % extra = Lorentzian fraction, in [0,1]
            case 'Fano'
                y = fanoLineshape(x, I, FWHM, x0, extra);  % extra = q (asymmetry)
            case 'Pearson VII'
                y = pearson7Lineshape(x, I, FWHM, x0, extra);  % extra = m (shape exponent)
            case 'True Voigt'
                y = trueVoigtLineshape(x, I, FWHM, extra, x0);  % extra = FWHM_L (FWHM is FWHM_G)
            otherwise % 'Gaussian'
                y = gausslor(x, I, 0, FWHM, x0);
        end
    end

% -------------------------------------------------------------------------
    function y = fanoLineshape(x, I, FWHM, x0, q)
    % Breit-Wigner-Fano lineshape. Same reduced-abscissa convention as
    % GAUSSLOR (r1 = (x-x0)/FWHM) so FWHM means the same thing across
    % every shape in this app. As q -> +-Inf this reduces to exactly the
    % same Lorentzian GAUSSLOR produces for Lor=1 (verified in testing).
        r1 = (x - x0) ./ FWHM;
        y = I .* (1 + 2*r1/q).^2 ./ (1 + 4*r1.^2);
    end

% -------------------------------------------------------------------------
    function y = pearson7Lineshape(x, I, FWHM, x0, m)
    % Pearson VII lineshape (normalized so FWHM has its usual meaning
    % regardless of m). m=1 reduces to exactly the same Lorentzian
    % GAUSSLOR produces for Lor=1; m -> Inf reduces to exactly the same
    % Gaussian GAUSSLOR produces for Lor=0 (both verified in testing).
        r1 = (x - x0) ./ FWHM;
        y = I ./ (1 + (2^(1/m) - 1) * 4*r1.^2).^m;
    end

% -------------------------------------------------------------------------
    function y = trueVoigtLineshape(x, I, FWHM_G, FWHM_L, x0)
    % True Voigt profile: the actual convolution of a Gaussian (width
    % FWHM_G) and a Lorentzian (width FWHM_L), computed by direct
    % numerical integration (MATLAB's ERFC does not accept complex
    % arguments in this release, ruling out the usual closed-form route
    % via the Faddeeva function -- confirmed by testing before writing
    % this). Normalized so the peak HEIGHT at x=x0 equals I, consistent
    % with how every other shape here is parameterized (by height, not
    % area) -- done by dividing by the same convolution evaluated at
    % x=x0, rather than by the analytic unit-area normalization those
    % kernels would otherwise carry.
        sigma = max(FWHM_G, eps) / (2*sqrt(2*log(2)));
        gamma = max(FWHM_L, eps) / 2;
        % When one width is much smaller than the other, its kernel acts
        % as a near-delta function -- convolving with it just returns the
        % OTHER pure shape. A fixed-resolution integration grid cannot
        % resolve a kernel that narrow relative to the other's span
        % (verified empirically: an under-resolved grid silently produces
        % wildly wrong values, not an error), so this regime is handled
        % as an explicit limit instead of by brute-force integration.
        if sigma >= 20 * gamma
            y = gausslor(x, I, 0, FWHM_G, x0);
            return
        elseif gamma >= 20 * sigma
            y = gausslor(x, I, 1, FWHM_L, x0);
            return
        end
        tMax = 10 * max(sigma, gamma);
        t = linspace(-tMax, tMax, 1600);  % converged to <0.2% up to a 20:1 width ratio (tested)
        G = exp(-(t.^2) / (2*sigma^2));
        xr = x(:) - x0;
        Lq = gamma ./ ((xr - t).^2 + gamma^2);
        L0 = gamma ./ (t.^2 + gamma^2);
        numer = trapz(t, G .* Lq, 2);
        denom = trapz(t, G .* L0, 2);
        y = I * numer ./ denom;
        y = reshape(y, size(x));
    end

% -------------------------------------------------------------------------
    function v = resolveBound(userVal, defaultVal)
    % A blank/uncleared Min or Max cell reads back as [] (never touched)
    % or NaN (cleared by the user) -- both mean "use the default bound".
        if isempty(userVal) || isnan(userVal)
            v = defaultVal;
        else
            v = userVal;
        end
    end

% -------------------------------------------------------------------------
    function tf = isFixedCell(v)
        tf = ~isempty(v) && logical(v);
    end

% -------------------------------------------------------------------------
    function onFit()
        d = peaksTable.Data;
        nPeaks = size(d, 1);
        if nPeaks < 1
            uialert(fig, 'Add at least one peak before fitting.', 'Nothing to fit');
            return
        end

        fitBtn.Enable = 'off';
        fitBtn.Text = 'Fitting...';
        statusLabel.Text = 'Fitting...';
        drawnow;

        shapes = d(:,1);
        theta0 = [];
        lb = [];
        ub = [];
        % Default FWHM floor: a peak narrower than the data's own point
        % spacing can't be resolved and just invites a degenerate fit --
        % confirmed by testing: with a floor of EPS, Pearson VII (whose
        % low-m tails can approximate a spike) slowly shrank FWHM toward
        % zero and grew height to needle-fit a single noisy data point,
        % improving resnorm a tiny bit further each repeated fit instead
        % of settling. Floored at twice the median point spacing instead.
        minFWHM = max(2 * median(diff(rawX)), eps);
        % Packing scheme: 3 params per peak (I, FWHM, x0), plus a 4th
        % ("extra") for shapes that need one extra free parameter beyond
        % those three -- Gaussian/Lorentzian don't, so they get no extra
        % slot in theta. extraSlot remembers where each peak's extra
        % parameter (if any) lives in theta so model/unpack agree.
        extraSlot = zeros(nPeaks, 1);
        for k = 1:nPeaks
            % Columns: Shape,Center,Fix,C.Min,C.Max,FWHM,Fix,F.Min,F.Max,Height,Fix,H.Min,H.Max
            fwhmGuess = d{k,6};
            heightGuess = d{k,10};
            centerGuess = d{k,2};
            % A Fix checkbox pins that parameter to its own current guess
            % by setting lb=ub=the guess directly, overriding Min/Max
            % entirely for it -- computed BEFORE the clamp below, not as a
            % later override, since clamping first would silently pull a
            % Fixed value in against a conflicting Min/Max and then "fix"
            % it at that wrong, already-clamped value instead.
            if isFixedCell(d{k,11})
                hLB = heightGuess; hUB = heightGuess;
            else
                hLB = resolveBound(d{k,12}, 0); hUB = resolveBound(d{k,13}, Inf);
            end
            if isFixedCell(d{k,7})
                fLB = fwhmGuess; fUB = fwhmGuess;
            else
                fLB = resolveBound(d{k,8}, minFWHM); fUB = resolveBound(d{k,9}, range(rawX));
            end
            if isFixedCell(d{k,3})
                cLB = centerGuess; cUB = centerGuess;
            else
                cLB = resolveBound(d{k,4}, min(rawX)); cUB = resolveBound(d{k,5}, max(rawX));
            end
            theta0 = [theta0, heightGuess, fwhmGuess, centerGuess]; %#ok<AGROW>
            lb = [lb, hLB, fLB, cLB]; %#ok<AGROW>
            ub = [ub, hUB, fUB, cUB]; %#ok<AGROW>
            % A user-typed bound can conflict with the current initial
            % guess (LSQCURVEFIT errors if theta0 falls outside [lb,ub]);
            % clamp the guess into range rather than surfacing that as a
            % confusing optimizer error -- a no-op for any Fixed parameter
            % above, since its lb/ub already equal its own guess exactly.
            theta0(end-2:end) = min(max(theta0(end-2:end), lb(end-2:end)), ub(end-2:end));
            switch shapes{k}
                case 'Pseudo-Voigt'
                    theta0(end+1) = 0.5; lb(end+1) = 0; ub(end+1) = 1; %#ok<AGROW>
                case 'Fano'
                    theta0(end+1) = 10; lb(end+1) = -1000; ub(end+1) = 1000; %#ok<AGROW>
                case 'Pearson VII'
                    theta0(end+1) = 1.5; lb(end+1) = 0.2; ub(end+1) = 50; %#ok<AGROW>
                case 'True Voigt'
                    % Extra parameter is FWHM_L; the 3rd packed parameter
                    % above (fwhmGuess) is FWHM_G. Start FWHM_L at a
                    % fraction of the peak's own initial FWHM guess.
                    theta0(end+1) = max(fwhmGuess * 0.3, eps); %#ok<AGROW>
                    lb(end+1) = eps; ub(end+1) = range(rawX); %#ok<AGROW>
            end
            if ~isequal(shapes{k}, 'Gaussian') && ~isequal(shapes{k}, 'Lorentzian')
                extraSlot(k) = numel(theta0);
            end
        end

        % Optional polynomial background, fitted JOINTLY with the peaks
        % (as opposed to the Preprocess tab's baseline subtraction, which
        % happens beforehand and is then fixed) -- useful when the
        % background and peaks are hard to separate cleanly beforehand.
        % Coefficients are appended after all peak parameters, in
        % POLYVAL's convention (highest power first); degree -1 means
        % "no background term" (no coefficients appended at all).
        bgDegree = find(strcmp(backgroundDD.Value, {'None','Constant','Linear','Quadratic','Cubic'})) - 2;
        nBgCoeffs = bgDegree + 1;
        if nBgCoeffs > 0
            theta0 = [theta0, zeros(1, nBgCoeffs)];
            lb = [lb, -Inf(1, nBgCoeffs)];
            ub = [ub, Inf(1, nBgCoeffs)];
        end

        mask = rangeMask();
        % Default tolerances/iteration caps can declare "convergence"
        % noticeably before the true minimum, especially for True Voigt
        % (its numerical-integration-based model gives LSQCURVEFIT's
        % finite-difference Jacobian a bit of noise) -- confirmed by
        % testing: repeatedly re-fitting from the "converged" result kept
        % creeping to a lower error instead of staying put. Raising the
        % caps and tightening the tolerances reaches that same lower
        % error in one Fit click instead of several.
        opts = optimoptions('lsqcurvefit', 'Display', 'off', ...
            'MaxIterations', 10000, 'MaxFunctionEvaluations', 100000, ...
            'FunctionTolerance', 1e-10, 'StepTolerance', 1e-10, 'OptimalityTolerance', 1e-10);
        try
            [thetaFit, resnorm, ~, ~, ~, ~, jacobian] = lsqcurvefit( ...
                @(th, x) totalModel(th, x, shapes, extraSlot, nPeaks, nBgCoeffs), ...
                theta0, rawX(mask), workingY(mask), lb, ub, opts);
        catch ME
            fitBtn.Enable = 'on';
            fitBtn.Text = 'Fit';
            uialert(fig, ME.message, 'Fit error');
            return
        end

        bgCoeffsFit = thetaFit(end-nBgCoeffs+1:end);
        peakThetaFit = thetaFit(1:end-nBgCoeffs);
        [I, FWHM, x0, Extra] = unpackTheta(peakThetaFit, shapes, extraSlot, nPeaks);
        N = nnz(mask);
        nParams = numel(thetaFit);
        % A Fixed parameter (lb==ub, via a Fix checkbox) isn't actually
        % being estimated, so it shouldn't consume a degree of freedom or
        % enter the parameter covariance below -- both use only the FREE
        % parameter count/subset.
        isFreeParam = (lb ~= ub);
        nFreeParams = nnz(isFreeParam);
        dof = N - nFreeParams;
        sse = resnorm;  % unweighted chi-square: sum of squared residuals
        rms = sqrt(sse / N);

        % Parameter standard errors from the linearized (Gaussian)
        % approximation standard for nonlinear least squares: Cov(theta)
        % = sigma^2 * (J'J)^-1, sigma^2 = SSE/dof, evaluated at the
        % solution's Jacobian, restricted to the FREE parameters -- a
        % Fixed parameter has exactly zero uncertainty by construction (it
        % was never varied), and including its column in J'J would make
        % the WHOLE matrix singular, wiping out the error estimate for
        % every OTHER (free) parameter too, not just the fixed one
        % (confirmed by testing: fixing just one parameter turned every
        % +/- column to NaN, not only the fixed parameter's own).
        %
        % J'J is additionally column-scaled (each column normalized to
        % unit norm, covariance un-scaled back afterwards) before
        % inverting -- confirmed necessary by testing: with several peaks
        % of different shapes plus a fitted background, parameters as
        % different in scale as a Fano q (~10) and a background constant
        % (Jacobian column norm ~1e4) made J'J's raw condition number
        % ~1e22 (RCOND below any reasonable threshold, so every error
        % came back NaN even with nothing fixed), while the SAME matrix
        % after per-column scaling had a perfectly invertible RCOND
        % ~1e-7. This is the standard equilibration trick for this
        % problem, not an approximation of a different quantity: scaling
        % a column of J is exactly equivalent to a linear change of that
        % one parameter's units, so undoing the scale on the resulting
        % covariance recovers the exact same answer a well-conditioned
        % J'J would have given directly.
        %
        % RCOND still guards the remaining case where even the scaled
        % J'J is too ill-conditioned to invert meaningfully (genuinely
        % near-degenerate/strongly correlated parameters, e.g. Fano/
        % Pearson VII pinned near a bound). LSQCURVEFIT can also return a
        % 0x0 JACOBIAN outright (confirmed by testing: happens when a
        % parameter's bounds are inconsistent, lb > ub -- it doesn't
        % error in that case, it just reports back the starting point).
        Jfull = full(jacobian);
        paramErrors = zeros(1, nParams);  % Fixed parameters: exactly 0 uncertainty
        if any(isFreeParam)
            if dof > 0 && isequal(size(Jfull), [N, nParams])
                Jfree = Jfull(:, isFreeParam);
                colNormsRaw = sqrt(sum(Jfree.^2, 1));
                % A free parameter can still have an (almost) all-zero
                % Jacobian column at the solution -- not from being Fixed,
                % but because the model is locally insensitive to it there.
                % Confirmed case: True Voigt's FWHM_L/FWHM_G, when one width
                % fits much smaller than the other, trueVoigtLineshape
                % returns a shape that depends only on the DOMINANT width
                % (an explicit limit, see trueVoigtLineshape) -- so the
                % other width's column is exactly zero. Including it in J'J
                % makes the WHOLE matrix singular, wiping out every OTHER
                % parameter's error too (same failure mode as an unguarded
                % Fixed parameter), so it's excluded from the inversion here
                % and reported as NaN for itself only.
                isEstimable = colNormsRaw > 1e-10 * max(colNormsRaw);
                freeIdx = find(isFreeParam);
                paramErrors(freeIdx(~isEstimable)) = NaN;
                if any(isEstimable)
                    Jest = Jfree(:, isEstimable);
                    colNorms = colNormsRaw(isEstimable);
                    Jscaled = Jest ./ colNorms;
                    JTJscaled = Jscaled' * Jscaled;
                    if rcond(JTJscaled) > 1e-12
                        covarScaled = (sse / dof) * (JTJscaled \ eye(size(JTJscaled)));
                        covarEst = covarScaled ./ (colNorms(:) * colNorms(:)');
                        paramErrors(freeIdx(isEstimable)) = sqrt(max(diag(covarEst), 0))';
                    else
                        paramErrors(freeIdx(isEstimable)) = NaN;
                    end
                end
            else
                paramErrors(isFreeParam) = NaN;
            end
        end
        peakParamErrors = paramErrors(1:end-nBgCoeffs);
        [I_err, FWHM_err, x0_err, ~] = unpackTheta(peakParamErrors, shapes, extraSlot, nPeaks);

        clearTag('fitLine');
        clearTag('peakComponentLine');
        clearTag('backgroundFitLine');
        resData = cell(nPeaks, 9);
        newPeaksData = d;  % preserve each peak's Min/Max bound overrides; only the fitted columns below are overwritten
        hold(ax, 'on');
        if nBgCoeffs > 0
            totalCurve = polyval(bgCoeffsFit, xi);
            plot(ax, xi, totalCurve, ':', 'Color', [0.55 0.35 0.1], 'LineWidth', 1.2, ...
                'PickableParts', 'none', 'Tag', 'backgroundFitLine');
        else
            totalCurve = zeros(size(xi));
        end
        for k = 1:nPeaks
            comp = peakModel(xi, shapes{k}, I(k), FWHM(k), x0(k), Extra(k));
            totalCurve = totalCurve + comp;
            plot(ax, xi, comp, '--', 'Color', [0.4 0.4 0.4], 'LineWidth', 0.8, ...
                'PickableParts', 'none', 'Tag', 'peakComponentLine');
            % Numerical integration over the same dense XI grid used for
            % the component curve above -- shape-agnostic (unlike AREAGL,
            % which is an analytic formula specific to the Gauss-Lorentz
            % blend and doesn't apply to Fano/Pearson VII/True Voigt).
            area_ = trapz(xi, comp);
            resData(k,:) = {k, shapes{k}, x0(k), x0_err(k), FWHM(k), FWHM_err(k), I(k), I_err(k), area_};
            newPeaksData(k,[1 2 6 10]) = {shapes{k}, x0(k), FWHM(k), I(k)};
        end
        plot(ax, xi, totalCurve, 'r-', 'LineWidth', 1.5, 'PickableParts', 'none', 'Tag', 'fitLine');
        hold(ax, 'off');

        % Residuals + goodness-of-fit, evaluated AT the actual data points
        % used by the fit (rawX(mask)), not the dense XI grid used above
        % only for smooth component/total curves.
        yFitAtData = totalModel(thetaFit, rawX(mask), shapes, extraSlot, nPeaks, nBgCoeffs);
        resid = workingY(mask) - yFitAtData;
        sst = sum((workingY(mask) - mean(workingY(mask))).^2);
        r2 = 1 - sse / sst;
        if dof > 0
            redChi2 = sse / dof;
            dofStr = sprintf('%d', dof);
            redChi2Str = sprintf('%.4g', redChi2);
        else
            dofStr = sprintf('%d (underdetermined)', dof);
            redChi2Str = 'n/a';
        end

        clearResiduals();
        hold(residualsAx, 'on');
        plot(residualsAx, rawX(mask), resid, 'o-', 'MarkerSize', 3, 'LineWidth', 0.75, ...
            'Color', [0.2 0.4 0.75], 'Tag', 'residLine');
        yline(residualsAx, 0, 'k-', 'Tag', 'residZero');
        hold(residualsAx, 'off');

        peaksTable.Data = newPeaksData;
        scroll(peaksTable, 'top');
        resultsTable.Data = resData;
        scroll(resultsTable, 'top');
        rmsLine = sprintf('RMS error = %.4g', rms);
        if nBgCoeffs > 0
            rmsLine = sprintf('%s   |   Background (%s): %s', rmsLine, backgroundDD.Value, mat2str(bgCoeffsFit, 4));
        end
        statsLabel.Text = { ...
            sprintf('N = %d, parameters = %d (%d free), dof = %s', N, nParams, nFreeParams, dofStr), ...
            sprintf('Chi-square (SSE) = %.4g', sse), ...
            sprintf('Reduced chi-square = %s', redChi2Str), ...
            sprintf('R^2 = %.4f', r2), ...
            rmsLine};
        redrawPeakMarkers();
        statusLabel.Text = sprintf('Fit complete: %d peak(s), RMS error %.4g.', nPeaks, rms);

        % Full parameters of this fit, kept for "Save data (.mat)" -- see
        % session-state comment above for why (the UI tables alone don't
        % carry enough to reconstruct each peak's curve exactly).
        lastFitPeaks = struct('Shape', {}, 'I', {}, 'I_err', {}, 'FWHM', {}, 'FWHM_err', {}, ...
            'x0', {}, 'x0_err', {}, 'ExtraName', {}, 'ExtraValue', {});
        for k = 1:nPeaks
            lastFitPeaks(k).Shape = shapes{k};
            lastFitPeaks(k).I = I(k);
            lastFitPeaks(k).I_err = I_err(k);
            lastFitPeaks(k).FWHM = FWHM(k);
            lastFitPeaks(k).FWHM_err = FWHM_err(k);
            lastFitPeaks(k).x0 = x0(k);
            lastFitPeaks(k).x0_err = x0_err(k);
            lastFitPeaks(k).ExtraName = extraParamName(shapes{k});
            lastFitPeaks(k).ExtraValue = Extra(k);
        end
        lastFitBgDegree = nBgCoeffs - 1;
        lastFitBgCoeffs = bgCoeffsFit;
        lastFitWorkingY = workingY;

        fitBtn.Enable = 'on';
        fitBtn.Text = 'Fit';
    end

% -------------------------------------------------------------------------
    function name = extraParamName(shape)
    % Name of the shape-specific extra parameter, matching PEAKMODEL's
    % own dispatch -- empty for shapes that don't have one.
        switch shape
            case 'Pseudo-Voigt'
                name = 'Lor';
            case 'Fano'
                name = 'q';
            case 'Pearson VII'
                name = 'm';
            case 'True Voigt'
                name = 'FWHM_L';
            otherwise
                name = '';
        end
    end

% -------------------------------------------------------------------------
    function y = totalModel(theta, x, shapes, extraSlot, nPeaks, nBgCoeffs)
        bgCoeffs = theta(end-nBgCoeffs+1:end);
        peakTheta = theta(1:end-nBgCoeffs);
        [I, FWHM, x0, Extra] = unpackTheta(peakTheta, shapes, extraSlot, nPeaks);
        if nBgCoeffs > 0
            y = polyval(bgCoeffs, x);
        else
            y = zeros(size(x));
        end
        for k = 1:nPeaks
            y = y + peakModel(x, shapes{k}, I(k), FWHM(k), x0(k), Extra(k));
        end
    end

% -------------------------------------------------------------------------
    function [I, FWHM, x0, Extra] = unpackTheta(theta, shapes, extraSlot, nPeaks)
    % Extra(k) is meaningless (left 0) for Gaussian/Lorentzian peaks --
    % PEAKMODEL hardcodes their lineshape parameter internally and never
    % reads it for those two shapes.
        I = zeros(nPeaks,1); FWHM = zeros(nPeaks,1); x0 = zeros(nPeaks,1); Extra = zeros(nPeaks,1);
        base = 0;
        for k = 1:nPeaks
            I(k)    = theta(base+1);
            FWHM(k) = theta(base+2);
            x0(k)   = theta(base+3);
            base = base + 3;
            if extraSlot(k) > 0
                Extra(k) = theta(extraSlot(k));
                base = base + 1;
            end
        end
    end

% -------------------------------------------------------------------------
    function onExportResults()
        if isempty(resultsTable.Data)
            uialert(fig, 'No fit results to export yet.', 'Nothing to export');
            return
        end
        [f, p] = pickSaveFile({'*.csv','CSV file'}, 'Export fit results', 'raman_fit_results.csv');
        if isequal(f, 0)
            return
        end
        varNames = {'Peak','Shape','Center','Center_err','FWHM','FWHM_err','Height','Height_err','Area'};
        T = cell2table(resultsTable.Data, 'VariableNames', varNames);
        try
            writetable(T, fullfile(p, f));
            statusLabel.Text = sprintf('Results exported to %s.', f);
        catch ME
            uialert(fig, ME.message, 'Export error');
        end
    end

% -------------------------------------------------------------------------
    function onSaveFigure()
        [f, p] = pickSaveFile({'*.pdf','PDF'; '*.png','PNG'}, 'Save fit figure', 'raman_fit.pdf');
        if isequal(f, 0)
            return
        end
        try
            exportgraphics(ax, fullfile(p, f));
            statusLabel.Text = sprintf('Figure saved to %s.', f);
        catch ME
            uialert(fig, ME.message, 'Save error');
        end
    end

% -------------------------------------------------------------------------
    function onSaveMatFile()
    % Exports every pipeline stage as its own (x,y) curve under DATA, plus
    % one parameter struct per fitted peak (p1, p2, ...) -- fit info is
    % only included if a fit has actually been run (LASTFITPEAKS is empty
    % otherwise). Curves are evaluated on RAWX throughout, so every field
    % lines up point-for-point for direct comparison/plotting outside the
    % app.
        if isempty(rawX)
            uialert(fig, 'Load a spectrum first.', 'Nothing to save');
            return
        end
        [f, p] = pickSaveFile({'*.mat','MAT-file'}, 'Save data', 'raman_fit_data.mat');
        if isequal(f, 0)
            return
        end

        S = struct();
        S.data.raw = struct('x', rawX, 'y', rawY);
        if ~isempty(backsubY)
            S.data.backsub = struct('x', rawX, 'y', backsubY);
        end
        if ~isempty(smoothedY)
            S.data.smoothed = struct('x', rawX, 'y', smoothedY);
        end

        nPeaksSaved = numel(lastFitPeaks);
        if nPeaksSaved > 0
            S.data.fitted = struct('x', rawX, 'y', lastFitWorkingY);
            totalFit = zeros(size(rawX));
            if lastFitBgDegree >= 0
                bgCurve = polyval(lastFitBgCoeffs, rawX);
                S.data.background = struct('x', rawX, 'y', bgCurve);
                totalFit = totalFit + bgCurve;
            end
            for k = 1:nPeaksSaved
                pk = lastFitPeaks(k);
                curve = peakModel(rawX, pk.Shape, pk.I, pk.FWHM, pk.x0, pk.ExtraValue);
                totalFit = totalFit + curve;
                S.data.(sprintf('peak%d', k)) = struct('x', rawX, 'y', curve);

                pStruct = struct('I', pk.I, 'I_err', pk.I_err, 'w', pk.x0, 'w_err', pk.x0_err, ...
                    'FWHM', pk.FWHM, 'FWHM_err', pk.FWHM_err, 'Shape', pk.Shape, 'Area', trapz(rawX, curve));
                if ~isempty(pk.ExtraName)
                    pStruct.(pk.ExtraName) = pk.ExtraValue;
                end
                S.(sprintf('p%d', k)) = pStruct;
            end
            S.data.fit = struct('x', rawX, 'y', totalFit);
        end

        try
            save(fullfile(p, f), '-struct', 'S');
            statusLabel.Text = sprintf('Data saved to %s.', f);
        catch ME
            uialert(fig, ME.message, 'Save error');
        end
    end

end
