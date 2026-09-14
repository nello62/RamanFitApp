function gl=gausslor(x,I,Lor,FWHM,x0)
%GAUSSLOR  Gauss-Lorentz blend (pseudo-Voigt) peak lineshape.
%   GL = GAUSSLOR(X,I,LOR,FWHM,X0) evaluates a single symmetric peak at
%   the abscissa values X, as a linear blend of a Gaussian and a
%   Lorentzian of the same height and width. Used throughout RamanFitApp
%   as the underlying shape for the Gaussian, Lorentzian, and Pseudo-Voigt
%   peak types (LOR fixed at 0, fixed at 1, or left free in [0,1]
%   respectively -- see PEAKMODEL in RamanFitApp.m).
%
%   Inputs
%     X     abscissa (wavenumber) values at which to evaluate the peak
%     I     peak height (intensity) at the center, X0
%     LOR   Lorentzian fraction, in [0,1]: 0 = pure Gaussian, 1 = pure
%           Lorentzian, in between = pseudo-Voigt blend
%     FWHM  full width at half maximum
%     X0    peak center
%
%   Output
%     GL    the peak's intensity at each value of X, same size as X
r1=(x-x0)./FWHM;                                                      % Reduced abscissa
gl=I.*((1-Lor).*exp(-4.*log(2).*r1.*r1)+Lor./(1+4.*r1.*r1));          % Symmetric peak 1
