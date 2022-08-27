function closeOscilloscopeConnection(osc)
fclose(osc);
delete(osc);
clear osc
fprintf('Oscilloscope Connectione is closed\n\n')
end