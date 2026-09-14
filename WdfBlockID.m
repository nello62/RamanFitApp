% WdfBlockID Enumeration of WDF Block IDs. Copied from wdf.h

% Important Block IDs:
%   FILE            File header block id.
%   DATA            Spectral data block id.
%   ORIGIN          Data origin block id (additional values per spectrum,
%                   ie: spatial coordinates, timestamp and so on)
%   COMMENT         Free-form file comment block id.
%   WIREDATA        Global file properties block id.
%   DATASETDATA     Per-spectrum extended property information block id.
%   MEASUREMENT     WiRE measurement definition block id.

% Copyright (c) 2012 - 2024 Renishaw plc.
%
% This file is part of the Renishaw WiRE WDF access package.
% See the accompanying README.md for licensing information; any use 
% of this file must be in compliance with the licensing of the 
% Renishaw WiRE WDF access package.

classdef WdfBlockID < uint32
    enumeration
        FILE            (826688599),      % 0x31464457  'W' 'D' 'F' '1'
        DATA            (1096040772),     % 0x41544144  'D' 'A' 'T' 'A'
        YLIST           (1414745177),     % 0x54534C59  'Y' 'L' 'S' 'T'
        XLIST           (1414745176),     % 0x54534C58  'X' 'L' 'S' 'T'
        ORIGIN          (1313296975),     % 0x4E47524F  'O' 'R' 'G' 'N'
        COMMENT         (1415071060),     % 0x54584554  'T' 'E' 'X' 'T'
        WIREDATA        (1094998103),     % 0x41445857  'W' 'X' 'D' 'A'
        DATASETDATA     (1111775319),     % 0x42445857  'W' 'X' 'D' 'B'
        MEASUREMENT     (1296324695),     % 0x4D445857  'W' 'X' 'D' 'M'
        CALIBRATION     (1396922455),     % 0x53435857  'W' 'X' 'C' 'S'
        INSTRUMENT      (1397315671),     % 0x53495857  'W' 'X' 'I' 'S'
        MAPAREA         (1346456919),     % 0x50414D57  'W' 'M' 'A' 'P'
        WHITELIGHT      (1280591959),     % 0x4C544857  'W' 'H' 'T' 'L'
        THUMBNAIL       (1279869262),     % 0x4C49414E  'N' 'A' 'I' 'L'
        MAP             (542130509),      % 0x2050414D  'M' 'A' 'P' ' '
        CURVEFIT        (1380009539),     % 0x52414643  'C' 'F' 'A' 'R'
        COMPONENT       (1397506884),     % 0x534C4344  'D' 'C' 'L' 'S'
        PCA             (1380008784),     % 0x52414350  'P' 'C' 'A' 'R'
        EM              (1163019085),     % 0x4552434D  'M' 'C' 'R' 'E'
        ZELDAC          (1128549466),     % 0x43444C5A  'Z' 'L' 'D' 'C'
        RESPONSECAL     (1279345490),     % 0x4C414352  'R' 'C' 'A' 'L'
        CAP             (542130499),      % 0x20504143  'C' 'A' 'P' ' '
        PROCESSING      (1347567959),     % 0x50524157  'W' 'A' 'R' 'P'
        ANALYSIS        (1095909719),     % 0x41524157  'W' 'A' 'R' 'A'
        SPECTRUMLABELS  (1279413335),     % 0x4C424C57  'W' 'L' 'B' 'L'
        CHECKSUM        (1263027031),     % 0x4B484357  'W' 'C' 'H' 'K'
        RXCALDATA       (1145264210),     % 0x44435852  'R' 'X' 'C' 'D'
        RXCALFIT        (1178818642),     % 0x46435852  'R' 'X' 'C' 'F'
        XCAL            (1279345496),     % 0x4C414358  'X' 'C' 'A' 'L'
        SPECSEARCH      (1212371539),     % 0x48435253  'S' 'R' 'C' 'H'
        TEMPPROFILE     (1347241300),     % 0x504D4554  'T' 'E' 'M' 'P'
        UNITCONVERT     (1447251541),     % 0x56434E55  'U' 'N' 'C' 'V'
        ARPLATE         (1380995649),     % 0x52505241  'A' 'R' 'P' 'R'
        ELECSIGN        (1128614981),     % 0x43454C45  'E' 'L' 'E' 'C'
        BKXLIST         (1280854850),     % 0x4C584B42  'B' 'K' 'X' 'L'
        AUXILARYDATA    (542659905),      % 0x20585541  'A' 'U' 'X' ' '
        CHANGELOG       (1196181571),     % 0x474C4843  'C' 'H' 'L' 'G'
        SURFACE         (1179800915),     % 0x46525553  'S' 'U' 'R' 'F'
        ARCALPLATE      (1346589249),     % 0x50435241  'A' 'R' 'C' 'P'
        PMC             (541281616),      % 0x20434D50  'P' 'M' 'C' ' '
        CAMERAFIXEDFREQDATA (1145456195), % 0x44464643  'C' 'F' 'F' 'D'
        CLUSTER         (1398099011),     % 0x53554C43  'C' 'L' 'U' 'S'
        HIERARCHICALCLUSTER (541147976),  % 0x20414348  'H' 'C' 'A' ' '
        TEMPPTR         (1381257300),     % 0x52545054  'T' 'P' 'T' 'R'
        UNKNOWN         (1061899861),     % 0x3F4B4E55  'U' 'N' 'K' '?'
        WMSK            (1263750487),     % 0x4B534D57  'W' 'M' 'S' 'K'
        STDV            (1447318611),     % 0x56445453  'S' 'T' 'D' 'V'
        EDIT            (1414087749),     % 0x54494445  'E' 'D' 'I' 'T'
        WSLS            (1397510999),     % 0x534C5357  'W' 'S' 'L' 'S'
        WPAC            (1128353879),     % 0x43415057  'W' 'P' 'A' 'C'
        ANY             (-1),             % 0xffffffff reserved value
    end;
end