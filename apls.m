function z = apls(y, gamma, order, itermax)
%APLS  Adaptive-weight Penalized Least Squares baseline.
%   Z = APLS(Y, GAMMA, ORDER, ITERMAX) estimates a smooth baseline for the
%   vector Y with a penalized-least-squares (Whittaker) smoother whose
%   weights are updated each iteration from the probability that the
%   observed value at each point could have arisen, by chance, from
%   Poisson-distributed background noise alone, given the current
%   baseline estimate -- points well above the current baseline (likely
%   genuine Raman peaks) end up with a low weight, points at or below it
%   with a weight near 1. Unlike backcor/airPLS's hard/asymmetric
%   reweighting, this is a single, continuously-varying, statistically
%   motivated weight.
%
%   GAMMA   roughness penalty (larger = smoother baseline). Typical
%           values differ by orders of magnitude between ORDER=1 and
%           ORDER=2 (the source paper reports order-2 gamma ~25000 being
%           comparable to order-1 gamma ~10).
%   ORDER   difference-penalty order, 1 or 2 (default 2 -- the paper's
%           own recommended, best-performing "O2W1" variant).
%   ITERMAX maximum number of reweighting iterations (default 10).
%
%   Reference: P. J. Cadusch, M. M. Hlaing, S. A. Wade, S. L. McArthur,
%   P. R. Stoddart, "Improved methods for fluorescence background
%   subtraction from Raman spectra", J. Raman Spectrosc. 44 (2013)
%   1587-1595.

if nargin < 4
    itermax = 10;
end
if nargin < 3 || isempty(order)
    order = 2;
end

origSize = size(y);
y = y(:);
n = numel(y);

D = diff(speye(n), order);
DD = gamma * (D' * D);

% Initial background estimate: the paper notes this isn't critical and
% suggests the mean of the observed signal.
b = mean(y) * ones(n, 1);

for it = 1:itermax
    % Pr(Poisson(mean = b_n) >= y_n), via the regularized incomplete
    % gamma function (GAMMAINC) rather than POISSCDF -- gives the exact
    % same value (verified against the textbook Poisson CDF/survival
    % function) without requiring the Statistics and Machine Learning
    % Toolbox. B is floored at EPS (a baseline estimate can dip slightly
    % negative for a low/noisy spectrum, which GAMMAINC does not accept)
    % and Y at 0 (GAMMAINC's shape parameter must be non-negative).
    w = gammainc(max(b, eps), max(y, 0), 'lower');
    W = spdiags(w, 0, n, n);
    C = chol(W + DD);
    z = C \ (C' \ (w .* y));
    if norm(z - b) < 1e-6 * max(norm(b), eps)
        b = z;
        break
    end
    b = z;
end

z = reshape(b, origSize);
end
