function gen = generatorConnection
% Find a VISA-GPIB object.
gen = instrfind('Type', 'visa-gpib', 'RsrcName', 'GPIB0::10::0::INSTR', 'Tag', '');

% Create the VISA-GPIB object if it does not exist
% otherwise use the object that was found.
if isempty(gen)
    gen = visa('AGILENT', 'GPIB0::10::0::INSTR');
else
    fclose(gen);
    gen = gen(1);
end
gen.OutputBufferSize = 2e17;
set (gen,'timeout', 80);
% Connect to instrument object, obj1.
fopen(gen);
fprintf(gen,'*RST');