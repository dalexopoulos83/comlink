function [output] = led_oscilloscopeDataReader
clearvars osc inputdat inputdata output
osc = oscilloscopeConnection;
fprintf(osc,':RST; :AUTOSCALE');
fprintf(osc,':CHANnel1:PROBe 10X');
fprintf(osc, ':TIMebase:SCALe 50.00e-06');
fprintf(osc, ':TIMebase:OFFSet 6.00e-04');
fprintf(osc, ':TRIGger:MODE EDGE');
fprintf(osc, ':TRIGger:EDGE:SOURce CHANnel1');
fprintf(osc,':TRIGger:EDGE:LEVel -1.00e+00'); %at -8 for 26cm, -16 for 20cm -5.7 for 30cm
fprintf(osc,':SINGLE');                       %at -2.4 for 35cm, -1.8 for 60cm for 0.3Vpp 
fprintf(osc,':WAVeform:POINts:MODE RAW');     %at -0.85 for 1m 
fprintf(osc,':WAVeform:POINts 10240');
fprintf(osc,':WAVeform:SOURce CHANnel1');
fprintf(osc,':WAVeform:FORMat ASCII');
pause(1);
fprintf(osc,':WAV:DATA?');
inputdat = fscanf(osc,'%s');
inputdata = inputdat(11:end);
output = str2num(inputdata);

fprintf('Acquisition completed \n');

closeOscilloscopeConnection(osc);
