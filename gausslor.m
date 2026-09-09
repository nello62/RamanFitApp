function gl=gausslor(x,I,Lor,FWHM,x0)
% Gauss Lorentzian lineshape
% x abscissa 
% I Intensity
% Lor Lorentz content (0 = Gaussian 1= Lorentzian)
% FHHM Full Width Half Maximum
% x0 center
r1=(x-x0)./FWHM;                                                      % Reduced abscissa 
gl=I.*((1-Lor).*exp(-4.*log(2).*r1.*r1)+Lor./(1+4.*r1.*r1));          % Symmetric peak 1
