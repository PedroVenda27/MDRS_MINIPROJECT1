%% Gera todas as imagens do relatório (corre as simulações e guarda os PNG)
% Demora cerca de 35 minutos. As imagens ficam na pasta deste ficheiro.

% Muda o MATLAB para a pasta onde está este ficheiro (onde estão os Task*.m)
cd(fileparts(mfilename('fullpath')));

Task1b;  exportgraphics(gcf, 'Task1b.png', 'Resolution', 200);
Task1c;  exportgraphics(gcf, 'Task1c.png', 'Resolution', 200);
Task1d;  exportgraphics(gcf, 'Task1d.png', 'Resolution', 200);
Task2b;  exportgraphics(gcf, 'Task2b.png', 'Resolution', 200);
Task2c;  exportgraphics(gcf, 'Task2c.png', 'Resolution', 200);
Task2d;  exportgraphics(gcf, 'Task2d.png', 'Resolution', 200);
Task3b;  exportgraphics(gcf, 'Task3b.png', 'Resolution', 200);
Task3c;  exportgraphics(gcf, 'Task3c.png', 'Resolution', 200);
Task3d;  exportgraphics(gcf, 'Task3d.png', 'Resolution', 200);
Task3e;
disp('Imagens geradas.');
