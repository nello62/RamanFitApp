% WiREMeasurementType  Enumeration indicating WiRE measurement type
%
% There are three types of WiRE measurement:
%   Single    The file contains a single spectrum / dataset.
%   Series    The file contains a series of spectra / datasets, but these
%             spectra are related via something other than spatial position
%             (for example: time, temperature, pressure, etc).
%   Map       The file contains multiple spectra / datasets that relate to
%             different spatial positions in the sample.

% Copyright (c) 2012 - 2024 Renishaw plc.
%
% This file is part of the Renishaw WiRE WDF access package.
% See the accompanying README.md for licensing information; any use 
% of this file must be in compliance with the licensing of the 
% Renishaw WiRE WDF access package.

classdef WiREMeasurementType < uint32
    enumeration
        Unspecified        (0),
        Single             (1),
        Series             (2),
        Map                (3)
    end;
end