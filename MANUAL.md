# RamanFit — User Manual

`RamanFitApp.m` is a MATLAB application (App Designer, single window) for
fitting experimental Raman spectra with sums of peak lineshapes, with
baseline subtraction, smoothing, and normalization as optional
preprocessing steps.

It works on **experimental** data (real measurements), not on
quantum-chemistry calculation results.

## Requirements

- MATLAB with **Optimization Toolbox** (for `lsqcurvefit`, the fit engine)
- **Signal Processing Toolbox** (for `sgolayfilt`, Savitzky-Golay
  smoothing)
- No external dependencies beyond MATLAB itself: every helper function
  (`gausslor.m`, `backcor.m`, `airPLS.m`, `readdpt.m`) is included in the
  `RamanFit/` folder itself.

## Starting the app

```matlab
RamanFitApp()              % empty window, then "Load spectrum..."
RamanFitApp('spectrum.txt') % load the given file immediately
```

## Supported file formats

| Extension | Format | Notes |
|---|---|---|
| `.txt`, `.csv`, `.dat` | Two columns, space/tab/comma delimited, with or without a header | Read with `readmatrix` |
| `.dpt` | Two comma-separated columns, no header (typical OPUS/Bruker export) | Read with `readdpt.m` |
| `.spc` | Binary Galactic/GRAMS spectrum format (also produced/supported by many instruments, including Jobin-Yvon/Horiba systems) | Read with `readspc.m` |
| `.wdf` | Renishaw WiRE binary spectrum format | Read with `readwdf.m` |

For `.txt`/`.csv`/`.dat`/`.dpt` files, the first column is the wavenumber
(X axis), the second the intensity (Y axis); for `.spc`/`.wdf` files the
axis and intensity are read directly from the file's own binary header/
data blocks. Data is automatically sorted by increasing X on load. If a
`.spc`/`.wdf` file contains more than one spectrum (e.g. a map or a time
series), only the first is loaded, with a warning.

Note on `.spc`: some files written in the older ("version 77") SPC
sub-format have been observed to come back with implausible axis/
intensity values (see `readspc.m`'s help). If a loaded `.spc` spectrum
looks wrong, try re-exporting it in the newer SPC format, or as
`.txt`/`.dpt` instead.

## Multiple spectra at once

**Load spectrum...** adds a new spectrum instead of replacing the current
one. The **Spectra:** dropdown in the sidebar lists every spectrum loaded
in the session: selecting one switches to it, restoring exactly the state
it was left in — raw/working data, analysis range, peaks, results table,
statistics, and, if a fit had been run, the total fit curve (and any
fitted background) on the plot.

**Copy peaks to other spectra** (Peaks tab, enabled once 2+ spectra are
loaded) copies the active spectrum's current peaks and Background setting
into every other loaded spectrum, ready to be fitted with the same model
— useful when the same set of bands is expected across a series of
related spectra. Any fit a target spectrum previously had is cleared
(it belonged to a different set of peaks), so it's ready for a clean
Fit. Note that absolute Center/FWHM/Height values are copied as-is: if
spectra have a slight calibration shift between them, the copied peak
positions may need a small manual adjustment (e.g. by dragging their
markers) before fitting.

## Window layout

- **Main plot** (top right): raw spectrum (grey), "working" spectrum after
  processing (blue), baseline overlay (dashed orange), total fit curve
  (red), individual peak components (dashed, a different color per peak —
  see [Peak markers on the plot](#peak-markers-on-the-plot)).
- **Residuals plot** (below, smaller): `data - fit` after each fit, with
  its X axis linked to the main plot (zoom/pan stay in sync).
- **Sidebar**: load button, analysis-range selector, **Reset Y axis**
  button (rescales the Y axis to just the data within the selected
  analysis range — or the whole spectrum if none is set — removing wasted
  space left by, e.g., a baseline not yet subtracted), and three
  highlighted tabs (Preprocess / Peaks / Results).

## Analysis range

The **analysis range** (cm⁻¹) restricts both the baseline calculation and
the fit to the selected window only (if not set, the whole spectrum is
used).

- **Select range (drag on plot)**: press the button, then drag on the
  plot from one end of the desired window to the other.
- The **Min/Max** fields can also be typed directly.
- **Zoom to range** / **Show full spectrum**: view-only zoom, does not
  change which data enters the fit.
- **Clear range**: goes back to using the whole spectrum.

## Preprocess tab

### Baseline (background subtraction)

Four methods selectable from the **Method** menu:

- **backcor** — iterative background estimation with a polynomial and
  asymmetric weights. Parameters: `Order` (polynomial degree, default 5),
  `Threshold` (default 0.1), `Cost function` (`sh`/`ah`/`stq`/`atq`,
  default `atq`).
- **airPLS** — *Adaptive Iteratively Reweighted Penalized Least Squares*.
  Parameters: `Lambda` (curve stiffness, default 1e7 — higher = smoother
  baseline), `Diff ord` (penalized-difference order, default 2), `Edge wt`
  (edge weight, default 0.1), `p (asym)` (asymmetry, default 0.05),
  `Max iter` (default 20).
- **SNIP** (*Statistics-sensitive Non-linear Iterative Peak-clipping*) —
  conceptually different from the other methods: it does not fit a
  polynomial or use iterative weights, it "shaves" each point down to the
  average of its neighbors at growing distance, leaving only slow
  variation. Parameters: `Iterations (M)` (default 40 — how many
  iterations/maximum distance: any feature narrower than ~M points is
  treated as a peak, not background), `Use LLS transform` (default on —
  compresses the signal's dynamic range before clipping, useful when
  peaks of very different heights are present in the same spectrum).
- **APLS** (*Adaptive-weight Penalized Least Squares*, Cadusch et al.
  2013) — like `airPLS`, a penalized-spline (Whittaker) fit, but with a
  simpler, statistically motivated weight: at each iteration, the weight
  of each point is the probability that the observed value could have
  arisen by chance from the background alone (Poisson noise), given the
  background estimate from the previous step — points well above the
  background (likely Raman peaks) get a low weight, points at background
  level get a weight near 1. In the original paper this is the most
  accurate method on complex (structured fluorescence) backgrounds.
  Parameters: `Gamma` (curve stiffness, default 1e5 — scales heavily with
  the data, typically needs tuning case by case, like `Lambda` for
  `airPLS`), `Diff ord` (1 or 2, default 2 — the variant recommended by
  the authors), `Max iter` (default 10).

Workflow: **Preview baseline** draws the estimated background as an
overlay without modifying the data; **Subtract baseline** actually
subtracts it from the working spectrum. The calculation respects the
current analysis range.

### Smoothing (Savitzky-Golay)

Parameters: `Window length` (window length, odd, default 11), `Poly
order` (local polynomial degree, default 3). Same Preview/Apply workflow
as the baseline: **Preview smoothing** shows the result without applying
it, **Apply smoothing** confirms it.

Note: confirming the baseline or the smoothing automatically invalidates
any unconfirmed preview of the other (avoids overlays that are no longer
consistent with the updated data).

### Normalization

**Method** menu: `None` / `Max = 1` (divides by the maximum within the
current analysis window) / `Area = 1` (divides by the integrated area in
the same window). Useful for comparing different spectra on a common
scale.

### Reset to raw

Returns the working spectrum to the original raw data, clearing baseline,
smoothing, normalization, peaks, and fit results.

## Peaks tab

### Adding peaks

Press **Add peak**, then click on the plot at the desired point: a
Gaussian peak is created centered at the clicked point, with height equal
to the data value there, and an initial estimated width.

### Peak markers on the plot

Each peak in the table is shown on the plot with two colored markers
(same color as the peak's curve, cycling through MATLAB's default
palette), both draggable with the mouse to visually correct the initial
guess before fitting:

- **Position marker** (triangle, with a numeric label of the Center value
  above it): dragging it updates both **Center** (horizontal) and
  **Height** (vertical) in the table.
- **FWHM marker** (circle, with a label below it), placed at the peak's
  half-maximum point (Center + FWHM/2, Height/2): dragging it
  **horizontally only** updates FWHM = 2 x (distance from the center).

On mouse release, that peak's dashed curve is redrawn immediately with
the new values (for shapes with an extra parameter — Fano, Pearson VII,
True Voigt — it reuses the last fitted value if still applicable,
otherwise a reasonable default guess), so the effect of the change is
visible immediately without having to rerun Fit.

### Peaks table

| Column | Meaning |
|---|---|
| Shape | Peak shape (per-row dropdown, see below) |
| Center, FWHM, Height | Base parameters, directly editable (or by dragging the markers on the plot, see above) |
| Fix (next to Center/FWHM/Height) | If checked, pins that parameter to its current value during the fit (overrides any Min/Max) |
| C.Min/C.Max, F.Min/F.Max, H.Min/H.Max | Optional fit bounds — leave blank to use the default bounds |

The default bounds are: Height >= 0, FWHM between twice the data's own
point spacing and the whole spectrum width (prevents a peak from
collapsing onto a single noisy point), Center within the data range (or
the analysis range, if set).

If a peak's initial height guess comes out non-positive (e.g. clicked in
a spot where baseline subtraction left slightly negative noise), it is
nudged to a small positive value instead of being clamped exactly to the
Height >= 0 bound: starting exactly at Height = 0 leaves every other
parameter's sensitivity to the fit at zero too (every shape here is a
plain height-times-lineshape), so the optimizer would otherwise get stuck
and return the initial guess unchanged.

### Available peak shapes

| Shape | Parameters | Notes |
|---|---|---|
| Gaussian | I, FWHM, x0 | |
| Lorentzian | I, FWHM, x0 | |
| Pseudo-Voigt | I, FWHM, x0, `Lor` (0-1) | Gauss-Lorentz blend; `Lor`=0 pure Gaussian, `Lor`=1 pure Lorentzian |
| Fano | I, FWHM, x0, `q` | Breit-Wigner-Fano lineshape, for asymmetric bands (e.g. carbon materials); large `q` -> Lorentzian |
| Pearson VII | I, FWHM, x0, `m` | `m`=1 -> exact Lorentzian, large `m` -> exact Gaussian |
| True Voigt | I, FWHM (=Gaussian FWHM), x0, `FWHM_L` (Lorentzian) | True Gauss(x)Lorentz convolution, computed by numerical integration (not the pseudo-Voigt approximation) |

Each row of the table can use a different shape: the fit can therefore
mix different shapes in the same spectrum.

### Background (fitted jointly with the peaks)

**Background** menu: `None` / `Constant` / `Linear` / `Quadratic` /
`Cubic`. Unlike the baseline subtraction in Preprocess (done *beforehand*
and then fixed), here the polynomial coefficients are estimated
**together** with the peaks in the same optimization — useful when the
background and the peaks are hard to separate beforehand. The estimated
background appears as a dotted curve on the plot.

### Fit

The **Fit** button disables itself and shows "Fitting..." while running.
When done it shows "Fit" again, whether it succeeded or errored.

While fitting, the status bar at the bottom shows the current iteration
and chi-square value (`chi^2 = SSE`) live, useful for gauging how the
convergence is going. Next to **Fit**, a **Stop fit** button also
appears: it stops the optimization while keeping the best result found so
far, without raising an error — equivalent to a fit that stopped
naturally at that iteration.

The engine is `lsqcurvefit` (unweighted sum of squared residuals), with
tight tolerances and generous iteration limits to help convergence happen
in a single click.

## Results tab

### Results table

Columns: `Peak`, `Shape`, `Center` (+/- error), `FWHM` (+/- error),
`Height` (+/- error), `Area` (computed by numerical integration, valid
for any shape).

The **errors** ("+/-" columns) are standard estimates for nonlinear least
squares: `Cov(theta) = sigma^2*(J^T J)^-1` with `sigma^2 = SSE/dof`, from
`lsqcurvefit`'s Jacobian at the minimum. A parameter with **Fix** enabled
has an error of exactly `0` (it is not estimated, and does not consume a
degree of freedom). If the matrix is too ill-conditioned (parameters
strongly correlated, at the edge of a bound, or — for a single parameter
— locally insensitive to the model at that point, e.g. a True Voigt whose
fit has drifted almost entirely onto one of its two widths) the error is
reported as `NaN` for just the parameter(s) involved, instead of a
misleading number, without affecting the other parameters' errors.

### Statistics panel

After each fit: number of points, number of parameters, degrees of
freedom, chi-square (SSE), reduced chi-square, R-squared, RMS error, and
— if a background was fitted — its coefficients.

### Export

- **Export results (CSV)...** — the results table as CSV.
- **Save fit figure...** — the main plot as PDF/PNG.
- **Save data (.mat)...** — see the dedicated section below.

## Saving data (.mat)

The saved `.mat` file contains:

- **`data`** (a struct of curves, each with `x`/`y` fields):
  - `data.raw` — always present, the original spectrum
  - `data.backsub` — present if a baseline was subtracted in Preprocess
  - `data.smoothed` — present if smoothing was applied
  - `data.fitted` — present after a fit: the data exactly as used by the
    fit (includes any normalization)
  - `data.background` — present if a polynomial background was fitted
  - `data.peak1`, `data.peak2`, ... — each individual peak's curve
  - `data.fit` — the total curve (sum of everything)
- **`p1`, `p2`, ...** (one variable per fitted peak): `I` (height),
  `I_err`, `w` (position), `w_err`, `FWHM`, `FWHM_err`, `Shape`, `Area`,
  and the shape-specific extra parameter when present (`Lor` for
  pseudo-Voigt, `q` for Fano, `m` for Pearson VII, `FWHM_L` for true
  Voigt).

If no fit has been run yet, only `data.raw` is saved (and, if applicable,
`data.backsub`/`data.smoothed`) — fitting first is not required in order
to save.

## Included dependencies

| File | Origin | Use |
|---|---|---|
| `gausslor.m` | personal library (`mymatfunctions/`) | Gauss-Lorentz lineshape, the basis for Gaussian/Lorentzian/Pseudo-Voigt |
| `backcor.m` (+ `backcor_license.txt`) | V. Mazet | `backcor` baseline-subtraction method |
| `airPLS.m` | Zhang et al. (public domain) | `airPLS` baseline-subtraction method |
| `snip.m` | C.G. Ryan et al. 1988 (public algorithm, original implementation) | `SNIP` baseline-subtraction method |
| `apls.m` | P.J. Cadusch et al. 2013 (public algorithm, original implementation) | `APLS` baseline-subtraction method |
| `readdpt.m` | personal library (`myfileutil/`) | Reading `.dpt` files |
| `readspc.m` (wraps `GSSpcRead.m` + `GSSpcReadStructure.m`, `GetSPCAxisTypes.m`, `GetTechniques.m`, `GSToolsAbout.m`, `LocateItem.m`, `trimstr.m`, `trimleft.m`, `trimright.m`) | K. De Gussem, GSTools (GPLv3/BSD dual license, from `prog/GSTools/`) | Reading `.spc` files |
| `readwdf.m` (wraps `WdfReader.m` + `WdfError.m`, `WdfBlockID.m`, `WiREDataType.m`, `WiREDataUnit.m`, `WiREKeys.m`, `WiREMeasurementType.m`, `WiREScanType.m`, `WiREScanBasicType.m`, `WiREFocusMode.m`) | Renishaw plc (Apache-2.0/BSD-3-Clause dual license, from `prog/RamanFit/Renishaw_wdf_access/`) | Reading `.wdf` files |

Full bibliographic references for the baseline-subtraction methods are in
[`REFERENCES.txt`](REFERENCES.txt).

## Known limitations

- Fits are unweighted least squares: every point has the same weight,
  there is no per-point measurement-uncertainty propagation.
- Fano and Pearson VII, having very heavy tails at extreme `q`/`m`, can in
  theory converge to degenerate solutions if the bounds are too wide —
  the minimum FWHM bound (tied to the data spacing) mitigates the most
  common case, but a visual check of the result is still recommended.
- If you set a Min > Max bound for a parameter, the fit does not report
  an error but returns the initial value unchanged, with the errors
  reported as `NaN`.
