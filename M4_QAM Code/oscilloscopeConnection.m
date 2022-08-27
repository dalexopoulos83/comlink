function osc = oscilloscopeConnection
% Find a VISA-USB object.
osc = instrfind('Type', 'visa-usb', 'RsrcName', 'USB0::2391::1416::cn50097489::0::INSTR', 'Tag', '');

% Create the VISA-USB object if it does not exist
% otherwise use the object that was found.
if isempty(osc)
    osc = visa('AGILENT', 'USB0::2391::1416::cn50097489::0::INSTR');
else
    fclose(osc);
    osc = osc(1)
end

% Set the buffer size
osc.InputBufferSize = 1000000;
%set (osc,'timeout', 120);
% Connect to instrument object, obj1.
fopen(osc);
fprintf('Oscilloscope Connection is Open\n');


