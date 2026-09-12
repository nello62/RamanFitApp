function baseline = snip(y, M, useLLS)
%SNIP  Statistics-sensitive Non-linear Iterative Peak-clipping baseline.
%   baseline = SNIP(y, M) estimates the baseline of spectrum Y by
%   iteratively clipping each point down to the average of its two
%   neighbors M points away, for M = 1..M -- any feature narrower than
%   about M points gets clipped away as a peak, leaving slower variation
%   as the estimated baseline.
%
%   baseline = SNIP(y, M, useLLS) additionally applies the log-log-sqrt
%   (LLS) transform before clipping and inverts it afterward (the
%   "improved SNIP" of Ryan et al.), which compresses the dynamic range so
%   that both very strong and very weak peaks get clipped correctly in
%   the same pass. Default true.
%
%   Reference: C.G. Ryan et al., "SNIP, a statistics-sensitive background
%   treatment for the quantitative analysis of PIXE spectra in geoscience
%   applications", Nucl. Instr. Meth. B 34 (1988) 396-402.
if nargin < 3
    useLLS = true;
end
origSize = size(y);
y = y(:);
n = numel(y);
if useLLS
    v = log(log(sqrt(y + 1) + 1) + 1);
else
    v = y;
end
for m = 1:M
    vPrev = v;
    idx = (m+1):(n-m);
    v(idx) = min(vPrev(idx), (vPrev(idx-m) + vPrev(idx+m)) / 2);
end
if useLLS
    baseline = (exp(exp(v) - 1) - 1).^2 - 1;
else
    baseline = v;
end
baseline = reshape(baseline, origSize);
end
