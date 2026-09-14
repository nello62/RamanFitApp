function Exception = WdfError(Msg, varargin)

% WdfError  Initialise an MException with "WdfError" message-ID
%
% WE = WdfError(ERRMSG, V1, V2, ... VN) captures information about a
% specific error and stores it in WdfError object WE, which has the
% message-ID "Renishaw:SPD:WiRE:WdfError".
%
% See also: MException

% Copyright (c) 2012 - 2024 Renishaw plc.
%
% This file is part of the Renishaw WiRE WDF access package.
% See the accompanying README.md for licensing information; any use 
% of this file must be in compliance with the licensing of the 
% Renishaw WiRE WDF access package.

Exception = MException('Renishaw:SPD:WiRE:WdfError', Msg, varargin{:});