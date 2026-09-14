% WiREFocusMode  Enumeration used by WiRE to indicate focus mode

% Copyright (c) 2024 Renishaw plc.
%
% This file is part of the Renishaw WiRE WDF access package.
% See the accompanying README.md for licensing information; any use 
% of this file must be in compliance with the licensing of the 
% Renishaw WiRE WDF access package.

classdef WiREFocusMode < uint32
    enumeration
        Uninitialised       (0),
        Regular             (1),
        Confocal            (2),
        Linefocus           (3),
        Streamline          (4)
    end
end