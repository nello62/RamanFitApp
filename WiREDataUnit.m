% WiREDataUnit  Enumeration used by WiRE to indicate units of measurement

% Copyright (c) 2012 - 2024 Renishaw plc.
%
% This file is part of the Renishaw WiRE WDF access package.
% See the accompanying README.md for licensing information; any use 
% of this file must be in compliance with the licensing of the 
% Renishaw WiRE WDF access package.

classdef WiREDataUnit < uint32
    enumeration
        Arbitrary          (0),
        RamanShift         (1),
        Wavenumber         (2),
        Nanometre          (3),
        ElectronVolt       (4),
        Micron             (5),
        Counts             (6),
        Electrons          (7),
        Millimetres        (8),
        Metres             (9),
        Kelvin            (10),
        Pascal            (11),
        Seconds           (12),
        Milliseconds      (13),
        Hours             (14),
        Days              (15),
        Pixels            (16),
        Intensity         (17),
        RelativeIntensity (18),
        Degrees           (19),
        Radians           (20),
        Celsius           (21),
        Fahrenheit        (22),
        KelvinPerMinute   (23),
        FileTime          (24),
        Microseconds      (25),
        Volts             (26),
        Amps              (27),
        MilliAmps         (28),
        Strain            (29),
        Ohms              (30),
        DegreesR          (31),
        Coulombs          (32),
        PicoCoulombs      (33)
    end;
end