% WiREDataType  Enumeration used by WiRE to indicate data type (meaning). Copied from wdf.h

% Copyright (c) 2012 - 2024 Renishaw plc.
%
% This file is part of the Renishaw WiRE WDF access package.
% See the accompanying README.md for licensing information; any use 
% of this file must be in compliance with the licensing of the 
% Renishaw WiRE WDF access package.

classdef WiREDataType < uint32
    enumeration
        Arbitrary     (0),
        Spectral      (1), % deprecated: use Frequency instead (spectral data type)
        Intensity     (2),
        SpatialX      (3), % X axis position
        SpatialY      (4), % Y axis position
        SpatialZ      (5), % Z axis (vertical) position
        SpatialR      (6), % rotary stage R axis position
        SpatialTheta  (7), % rotary stage theta angle
        SpatialPhi    (8), % rotary stage phi angle
        Temperature   (9),
        Pressure     (10),
        Time         (11),
        Derived      (12), % derivative type
        Polarization (13),
        FocusTrack   (14), % focus track Z position
        RampRate     (15), % temperature ramp rate
        Checksum     (16),
        Flags        (17), % bit flags
        ElapsedTime  (18), % elapsed time interval
        Frequency    (19), % Frequency (such as wavelength or wavenumber).
        Mp_Well_Spatial_X (20), % Microplate mapping origin X
        Mp_Well_Spatial_Y (21), % Microplate mapping origin Y
        Mp_LocationIndex  (22),% Microplate mapping location index
        Mp_WellReference  (23), % Microplate mapping well reference
        PAFZActual        (24), % PAF focus distance from focus
        PAFZError         (25), % PAF distance between current and last positions,
        PAFSignalUsed     (26), % PAF signal used (0 = None, 1 = Top, 2 = Bottom, 3 = Correlation)
        ExposureTime      (27), % Measured exposure time per dataset
        ExternalSignal    (28), % Intensity data from external data source
        Custom            (99), % Custom data type: bit 31 is set
    end;
    % NOTE: custom data types are supported by having bit 31 set.
    %
    %       When a data type is read from an origin list in the file,
    %       bit 32 should be masked as this is a flag bit to indicate
    %       that the data origin is alternate when clear or primary when set.
end