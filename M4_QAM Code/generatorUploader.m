function generatorUploader(datastrm)

gen = generatorConnection;
   
%combine string of data with scpi command
datas = '';
for i=1:1:length(datastrm)
    tmp = datastrm(i);
    datas = [datas ',' num2str(tmp)];
end
arbstring = sprintf('DATA VOLATILE%s', datas);
%Send Command to set the desired configuration
fprintf('Downloading Waveform...\n\n')
fprintf(gen, arbstring);
%make instrument wait for data to download before moving on to next
%command set
fprintf(gen, '*WAI');
fprintf('Downloading Completed\n\n')
fprintf(gen, 'BURST:MODE TRIG');
fprintf(gen, 'BURST:NCYC 1');
fprintf(gen, 'TRIG:SOUR BUS');
fprintf(gen, 'TRIG:SLOP POS');
fprintf(gen, 'BURST:STAT ON');
fprintf(gen, 'FUNC USER');
fprintf(gen, 'OUTPUT:TRIG ON');
fprintf(gen, 'OUTPUT ON');
fprintf(gen,'func:user volatile');
%the default is 1 kHz, 100 mVpp
fprintf(gen,'apply:user 0.75e3, .4 VPP, 0');
fprintf('Acquisition completed \n');
% Read Error
fprintf(gen, 'SYST:ERR?');
errorstr = fscanf (gen);
% error checking
if strncmp (errorstr, '+0,"No error"',13)
   errorcheck = 'Arbitrary waveform generated without any error \n';
   fprintf (errorcheck)
else
   errorcheck = ['Error reported: ', errorstr];
   fprintf (errorcheck)
end

closeGeneratorConnection(gen);

end
