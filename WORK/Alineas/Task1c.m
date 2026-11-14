%% Task 1.c - Valores teóricos do caso C com o modelo M/G/1
clear; clc;

C      = 10e6;               % capacidade da ligação (bps)
lambda = [800 800 600];      % caso C (pps)

% Tamanhos de cada fluxo (todos os valores com igual probabilidade)
B1 = 100:1500;
B2 = 100:150;
B3 = 500:1000;

% Média e 2.º momento do tempo de transmissão de cada fluxo: S = 8*B/C
% (média simples porque todos os tamanhos têm a mesma probabilidade)
ES  = [mean(8*B1/C)     mean(8*B2/C)     mean(8*B3/C)];        % E[S_i]   (seg)
ES2 = [mean((8*B1/C).^2) mean((8*B2/C).^2) mean((8*B3/C).^2)]; % E[S_i^2] (seg^2)
EB  = [mean(B1) mean(B2) mean(B3)];                            % tamanho médio (Bytes)

% Agregado dos 3 fluxos (Módulo 2, slides 36 e 37)
% lambda = soma dos lambda_i (soma de processos de Poisson)
% E[S]   = soma( lambda_i/lambda * E[S_i] )
% E[S^2] = soma( lambda_i/lambda * E[S_i^2] )
lambdaT = sum(lambda);
ESagr   = sum(lambda/lambdaT .* ES);
ES2agr  = sum(lambda/lambdaT .* ES2);
rho     = lambdaT * ESagr;                                     % ocupação da ligação

% Pollaczek-Khintchine: atraso na fila é igual para todos os fluxos (fila FIFO única)
WQ = lambdaT * ES2agr / (2 * (1 - rho));

% Atraso médio de cada fluxo = fila + transmissão do próprio fluxo
% (o simulador não tem atraso de propagação)
APDteo = (WQ + ES) * 1e3;                                      % ms

% Throughput: fila muito grande -> sem perdas -> TT_i = lambda_i * 8 * E[B_i]
TTteo = lambda * 8 .* EB / 1e6;                                % Mbps

fprintf('rho = %.3f | WQ = %.4f ms\n', rho, WQ*1e3);
fprintf('Teoria   APD: Fluxo 1 = %.4f ms | Fluxo 2 = %.4f ms | Fluxo 3 = %.4f ms\n', APDteo);
fprintf('Teoria   TT : Fluxo 1 = %.4f Mbps | Fluxo 2 = %.4f Mbps | Fluxo 3 = %.4f Mbps\n', TTteo);

% Comparação com a simulação da 1.b
if isfile('Task1b_resultados.mat')
    S = load('Task1b_resultados.mat');
    z = norminv(1 - S.alfa/2);
    mA = mean(S.APD); tA = z*sqrt(var(S.APD)/S.N);
    mT = mean(S.TT);  tT = z*sqrt(var(S.TT)/S.N);
    fprintf('Simulacao APD: Fluxo 1 = %.4f +- %.4f | Fluxo 2 = %.4f +- %.4f | Fluxo 3 = %.4f +- %.4f\n', ...
        mA(1), tA(1), mA(2), tA(2), mA(3), tA(3));
    fprintf('Simulacao TT : Fluxo 1 = %.4f +- %.4f | Fluxo 2 = %.4f +- %.4f | Fluxo 3 = %.4f +- %.4f\n', ...
        mT(1), tT(1), mT(2), tT(2), mT(3), tT(3));

    % Gráfico: simulação (barras + intervalo de confiança) vs teoria
    figure;
    subplot(1,2,1);
    bar(1:3, mA); hold on;
    errorbar(1:3, mA, tA, tA, 'k.', 'LineWidth', 1.2);
    plot(1:3, APDteo, 'rx', 'MarkerSize', 12, 'LineWidth', 2); hold off;
    grid on; xticks(1:3); xticklabels({'Flow 1','Flow 2','Flow 3'});
    ylabel('Average packet delay (ms)');
    legend('Simulation', '90% CI', 'M/G/1', 'Location', 'south');
    subplot(1,2,2);
    bar(1:3, mT); hold on;
    errorbar(1:3, mT, tT, tT, 'k.', 'LineWidth', 1.2);
    plot(1:3, TTteo, 'rx', 'MarkerSize', 12, 'LineWidth', 2); hold off;
    grid on; xticks(1:3); xticklabels({'Flow 1','Flow 2','Flow 3'});
    ylabel('Throughput (Mbps)');
    legend('Simulation', '90% CI', 'M/G/1', 'Location', 'north');
    sgtitle('Task 1.c - Simulation vs M/G/1 (case C)');
end
