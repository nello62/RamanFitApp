# RamanFitApp

MATLAB app (App Designer, single window) for fitting experimental Raman
spectra with sums of peak lineshapes — baseline subtraction, smoothing,
and normalization as optional preprocessing steps.

Works on **experimental** data (real measurements), not quantum-chemistry
results.

## Requirements

- MATLAB with **Optimization Toolbox** (`lsqcurvefit`, the fit engine)
- **Signal Processing Toolbox** (`sgolayfilt`, Savitzky-Golay smoothing)
- No dependencies outside MATLAB: every helper function
  (`gausslor.m`, `backcor.m`, `airPLS.m`, `snip.m`, `apls.m`, `readdpt.m`,
  `readspc.m`, `readwdf.m`) ships in this same folder.

## Quick start

```matlab
RamanFitApp()              % empty window, then "Load spectrum..."
RamanFitApp('spectrum.txt') % load a file immediately
```

## Features

- Reads `.txt`/`.csv`/`.dat` (plain columns), `.dpt` (OPUS/Bruker),
  `.spc` (Galactic/GRAMS binary, also used by Jobin-Yvon/Horiba systems),
  and `.wdf` (Renishaw WiRE binary).
- Cosmic-ray spike removal (Whitaker-Hayes modified Z-score method).
- Baseline subtraction: **backcor**, **airPLS**, **SNIP**, or **APLS**.
- Savitzky-Golay smoothing and normalization (max=1 / area=1).
- Peak shapes: Gaussian, Lorentzian, Pseudo-Voigt, Fano, Pearson VII,
  True Voigt — mixable per fit, each with optional per-parameter Fix and
  Min/Max bounds.
- Peak markers on the plot are draggable (position + height, and FWHM),
  with a live curve preview and numeric labels.
- Per-parameter error estimates (linearized covariance from the fit's
  Jacobian), live chi-square during the fit, and a Stop-fit button.
- Multiple spectra can be loaded at once and switched between via the
  "Spectra:" selector, each keeping its own peaks/results/fit state.
- Export: CSV results table, PDF/PNG figure, and a `.mat` file with the
  raw/processed data and every fitted peak's parameters (+ errors).

See [`MANUAL.md`](MANUAL.md) for the full user manual.

## License

See [`LICENSE`](LICENSE) if present; otherwise all rights reserved by the
author pending an explicit license choice.
