% WiREScanType  Represents a WiRE scan type value and associated flags
%
% The scan-type is the method used to acquire a single spectrum / dataset.
% The basic scan type (see WiREScanBasicType) can be combined with the
% following additional flags (which are exposed as read-only properties of
% a WiREScanType object):
%   IsMultitrackStitched  If TRUE, multiple tracks of data were acquired,
%                         but are 'stitched' together to produce a single
%                         spectrum / dataset per scan.
%   IsMultitrackDiscrete  If TRUE, multiple tracks of data were acquired
%                         and are stored separately using the multi-track
%                         file format (not currently supported in Matlab).
%   IsLineFocusMapping    If TRUE, line-focus mapping mode was used to
%                         acquire the data; certain adjacent map points
%                         were collected simultaneously.
%
% See also: WiREScanBasicType

% Copyright (c) 2012 - 2024 Renishaw plc.
%
% This file is part of the Renishaw WiRE WDF access package.
% See the accompanying README.md for licensing information; any use 
% of this file must be in compliance with the licensing of the 
% Renishaw WiRE WDF access package.

classdef (Sealed = true) WiREScanType 
    properties (Constant, GetAccess = private)
        MultitrackStitched = uint32(256);
        MultitrackDiscrete = uint32(512);
        LineFocusMapping   = uint32(1024);
    end;
    
    properties (SetAccess = private)
        BasicType = WiREScanBasicType.Unspecified;
        IsMultitrackStitched = false;
        IsMultitrackDiscrete = false;
        IsLineFocusMapping = false;
    end;
    
    methods
        function v = WiREScanType(bitFlags)
            bitFlags = uint32(bitFlags);
            v.BasicType = WiREScanBasicType(bitand(uint32(255), bitFlags));
            v.IsMultitrackStitched = bitand(WiREScanType.MultitrackStitched, bitFlags) ~= 0;
            v.IsMultitrackDiscrete = bitand(WiREScanType.MultitrackDiscrete, bitFlags) ~= 0;
            v.IsLineFocusMapping = bitand(WiREScanType.LineFocusMapping, bitFlags) ~= 0;
        end;
    end;
end