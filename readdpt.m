function [x,y]=readdpt(filename);
%READDPT  Read a two-column, comma-separated .dpt Raman spectrum file.
%   [X,Y] = READDPT(FILENAME) reads a .dpt file with one "wavenumber,
%   intensity" pair per line and no header, returning the wavenumber
%   values in X and the corresponding intensities in Y (both row
%   vectors, in file order -- RamanFitApp itself sorts by increasing X
%   after loading).
%
%   The .dpt format is the plain-text spectrum export produced by the
%   Hamamatsu C15471 Raman spectroscopic module:
%   https://www.hamamatsu.com/eu/en/product/optical-sensors/spectrometers/raman-spectroscopic-module/C15471.html
%   (the same two-column, comma-separated layout is also used by other
%   OPUS/Bruker-style instruments).

fid=fopen(filename,'r');
lines=0;        
while 1
    tline = fgetl(fid);
    lines=lines+1;
    if ~ischar(tline), break, end
    index=findstr(',',tline);
    x(lines)=str2num(tline(1:index-1));
    y(lines)=str2num(tline(index+1:end));
end
fclose (fid);






