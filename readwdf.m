function [x, y] = readwdf(filename)
%READWDF  Read a Raman spectrum from a Renishaw WiRE .wdf file.
%   [X,Y] = READWDF(FILENAME) reads a .wdf file via Renishaw's own
%   WdfReader class, returning the wavenumber axis in X and the
%   intensity in Y (both row vectors). If the file contains more than one
%   spectrum (e.g. a map or a time series), only the first is returned,
%   with a warning -- RamanFitApp works on one spectrum at a time.
%
%   Verified by a synthetic round-trip test during integration (write
%   with Renishaw's own WdfCreate, read back with this function): X and Y
%   matched to within single-precision rounding, the format's own storage
%   precision.
wdf = WdfReader(filename);
try
    x = wdf.GetXList();
    if wdf.Count > 1
        warning('readwdf:multiSpectrum', ...
            '%s contains %d spectra; only the first is returned.', ...
            filename, wdf.Count);
    end
    y = wdf.GetSpectra(1, 1);
catch ME
    wdf.Close();
    rethrow(ME);
end
wdf.Close();
x = double(x(:)');
y = double(y(:)');
end
