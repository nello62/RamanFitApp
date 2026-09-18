function [yOut, spikeMask] = despike(y, threshold, window)
%DESPIKE  Remove cosmic-ray spikes from a spectrum (Whitaker-Hayes method).
%   [yOut, spikeMask] = DESPIKE(y, threshold, window) flags cosmic-ray
%   spikes via a modified Z-score on the first derivative of Y, then
%   replaces each flagged sample with the median of its non-spike
%   neighbors within +/- WINDOW points.
%
%   A cosmic-ray spike shows up as one (or a few) point(s) that jump away
%   from their neighbors and back again, i.e. as a large spike in
%   diff(y). Ordinary Raman peaks are much wider than one sample, so they
%   barely register in the derivative by comparison -- this is what lets
%   the method tell spikes apart from real peaks.
%
%   THRESHOLD is the modified-Z-score cutoff (default 7, a commonly used
%   value for this method); WINDOW is the half-width, in samples, of the
%   neighborhood used both to flag adjacent points around a detected
%   spike and to compute the replacement median (default 5).
%
%   Reference: D. Whitaker & K. Hayes, "A simple algorithm for despiking
%   Raman spectra", Chemometrics and Intelligent Laboratory Systems 179
%   (2018) 82-84.
if nargin < 2 || isempty(threshold)
    threshold = 7;
end
if nargin < 3 || isempty(window)
    window = 5;
end
origSize = size(y);
y = y(:);
n = numel(y);

dy = diff(y);
medDy = median(dy);
absDev = abs(dy - medDy);
madDy = median(absDev);
if madDy == 0
    % Degenerate case: the derivative is flat everywhere except at a few
    % isolated points (e.g. noise-free data with injected spikes), so the
    % usual ratio would divide by zero. Any nonzero deviation from the
    % (zero-spread) baseline is then unambiguously an outlier.
    Z = Inf(size(dy));
    Z(absDev == 0) = 0;
else
    Z = 0.6745 * (dy - medDy) / madDy;
end

% A spike at sample i shows up as a large jump both into it and out of
% it, i.e. in dy(i-1) (jump in) and dy(i) (jump out) -- flag i if either
% neighboring derivative sample exceeds the threshold.
spikeMask = false(n, 1);
spikeMask(1:end-1) = spikeMask(1:end-1) | (abs(Z) > threshold);
spikeMask(2:end)   = spikeMask(2:end)   | (abs(Z) > threshold);

yOut = y;
flagged = find(spikeMask);
for k = 1:numel(flagged)
    i = flagged(k);
    lo = max(1, i - window);
    hi = min(n, i + window);
    localIdx = lo:hi;
    goodIdx = localIdx(~spikeMask(localIdx));
    if isempty(goodIdx)
        continue  % entire neighborhood flagged -- leave the sample as-is
    end
    yOut(i) = median(y(goodIdx));
end
yOut = reshape(yOut, origSize);
spikeMask = reshape(spikeMask, origSize);
end
