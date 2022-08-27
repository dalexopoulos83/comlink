function closeGeneratorConnection(gen)
fclose(gen);
delete(gen);
clear gen
fprintf('Generator Connectione is closed\n\n')
end