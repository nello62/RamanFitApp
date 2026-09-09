function [x,y]=readdpt(filename);

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






