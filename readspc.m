function [x, y] = readspc(filename)
%READSPC  Read a Raman spectrum from a Galactic/GRAMS .spc file.
%   [X,Y] = READSPC(FILENAME) reads a .spc file (the widely-used Galactic
%   Industries/Thermo GRAMS binary spectrum format, also produced or
%   supported by many other instruments, including Jobin-Yvon/Horiba
%   systems) via GSSpcRead, returning the wavenumber axis in X and the
%   intensity in Y (both row vectors). If the file contains more than one
%   spectrum, only the first is returned, with a warning.
%
%   Known limitation: some files written in the older ("version 77") SPC
%   sub-format can come back with implausible axis/intensity values --
%   confirmed against real test files during integration. If a loaded
%   .spc spectrum looks wrong, try re-exporting it in the newer SPC
%   format, or as .txt/.dpt instead.

% Only 3 args passed to GSSpcRead deliberately: its own YScaling-override
% mechanism only activates when its NARGIN>=4, but treats an explicitly
% passed empty value as if an override had actually been chosen, which
% then crashes ("SWITCH expression must be a scalar...") -- confirmed by
% testing against real .spc files. Omitting the argument entirely lets
% GSSpcRead default it correctly instead.
Specdata = GSSpcRead(filename, -1, false);
if ~isempty(Specdata.data)
    x = Specdata.xaxis(:)';
    y = Specdata.data(:)';
elseif isfield(Specdata, 'spectra') && ~isempty(Specdata.spectra)
    if numel(Specdata.spectra) > 1
        warning('readspc:multiSpectrum', ...
            '%s contains %d spectra; only the first is returned.', ...
            filename, numel(Specdata.spectra));
    end
    x = Specdata.spectra(1).xaxis(:)';
    y = Specdata.spectra(1).data(:)';
else
    error('readspc:empty', 'No spectrum data found in %s.', filename);
end
end
