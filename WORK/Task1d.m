%% Task 1.d - Atraso médio e máximo do Fluxo 3 nos casos A, B e C (FIFO)
clear; clc;

C    = 10;                   % capacidade da ligação (Mbps)
f    = 1000000;              % tamanho da fila (Bytes)
P    = 100000;               % critério de paragem
N    = 50;                   % número de corridas
alfa = 0.1;                  % intervalo de confiança a 90%

casos  = {'A','B','C'};
lambdas = [400 400 600;      % caso A
           600 600 600;      % caso B
           800 800 600];     % caso C

APD3 = zeros(N,3);           % linha = corrida, coluna = caso
MPD3 = zeros(N,3);
for c = 1:3
    for it = 1:N
        [~, APD, MPD, ~] = Sim2Flows_newversion(lambdas(c,:), C, f, P);
        APD3(it,c) = APD(3);     % só interessa o Fluxo 3
        MPD3(it,c) = MPD(3);
    end
end

z  = norminv(1-alfa/2);
mA = mean(APD3); tA = z*sqrt(var(APD3)/N);
mM = mean(MPD3); tM = z*sqrt(var(MPD3)/N);
for c = 1:3
    fprintf('Caso %s: APD Fluxo 3 = %.4f +- %.4f ms | MPD Fluxo 3 = %.4f +- %.4f ms\n', ...
        casos{c}, mA(c), tA(c), mM(c), tM(c));
end

save('Task1d_resultados.mat', 'APD3', 'MPD3', 'N', 'alfa');

figure;
subplot(1,2,1);
bar(1:3, mA); hold on;
errorbar(1:3, mA, tA, tA, 'k.', 'LineWidth', 1.2); hold off;
grid on; xticks(1:3); xticklabels({'Case A','Case B','Case C'});
ylabel('Average packet delay of Flow 3 (ms)');
subplot(1,2,2);
bar(1:3, mM); hold on;
errorbar(1:3, mM, tM, tM, 'k.', 'LineWidth', 1.2); hold off;
grid on; xticks(1:3); xticklabels({'Case A','Case B','Case C'});
ylabel('Maximum packet delay of Flow 3 (ms)');
sgtitle('Task 1.d - Flow 3 with FIFO (90% confidence intervals)');
