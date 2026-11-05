%% Task 2.c - Valores teóricos do caso C com o modelo M/G/1 com prioridades
clear; clc;

C      = 10e6;               % capacidade da ligação (bps)
lambda = [800 800 600];      % caso C (pps)

% Tamanhos de cada fluxo (todos os valores com igual probabilidade)
B1 = 100:1500;
B2 = 100:150;
B3 = 500:1000;

% Média e 2.º momento do tempo de transmissão de cada fluxo: S = 8*B/C
ES  = [mean(8*B1/C)      mean(8*B2/C)      mean(8*B3/C)];       % E[S_i]   (seg)
ES2 = [mean((8*B1/C).^2) mean((8*B2/C).^2) mean((8*B3/C).^2)];  % E[S_i^2] (seg^2)
rho = lambda .* ES;                                             % ocupação de cada fluxo

% M/G/1 com prioridades (Módulo 4, slide 7)
% Numerador comum: soma de lambda_i * E[S_i^2] de TODOS os fluxos
num = sum(lambda .* ES2);

% Prioridade 1 (mais alta): Flow 3
rhoA = rho(3);
WQ_alta = num / (2 * (1 - rhoA));

% Prioridade 2: Flows 1 e 2 (partilham a mesma fila, logo o mesmo atraso na fila)
rhoB = rho(1) + rho(2);
WQ_baixa = num / (2 * (1 - rhoA) * (1 - rhoA - rhoB));

% Atraso médio de cada fluxo = atraso na fila da sua prioridade + transmissão
APDteo = ([WQ_baixa WQ_baixa WQ_alta] + ES) * 1e3;             % ms

fprintf('rho(Flow 3) = %.3f | rho(Flows 1+2) = %.3f | rho total = %.3f\n', rhoA, rhoB, rhoA+rhoB);
fprintf('WQ prioridade alta = %.4f ms | WQ prioridade baixa = %.4f ms\n', WQ_alta*1e3, WQ_baixa*1e3);
fprintf('Teoria    APD: Fluxo 1 = %.4f ms | Fluxo 2 = %.4f ms | Fluxo 3 = %.4f ms\n', APDteo);

% Comparação com a simulação da 2.b
if isfile('Task2b_resultados.mat')
    S = load('Task2b_resultados.mat');
    z = norminv(1 - S.alfa/2);
    mA = mean(S.APD); tA = z*sqrt(var(S.APD)/S.N);
    fprintf('Simulacao APD: Fluxo 1 = %.4f +- %.4f | Fluxo 2 = %.4f +- %.4f | Fluxo 3 = %.4f +- %.4f\n', ...
        mA(1), tA(1), mA(2), tA(2), mA(3), tA(3));

    figure;
    bar(1:3, mA); hold on;
    errorbar(1:3, mA, tA, tA, 'k.', 'LineWidth', 1.2);
    plot(1:3, APDteo, 'rx', 'MarkerSize', 12, 'LineWidth', 2); hold off;
    grid on; xticks(1:3); xticklabels({'Flow 1','Flow 2','Flow 3'});
    ylabel('Average packet delay (ms)');
    legend('Simulation', '90% CI', 'M/G/1 with priorities', 'Location', 'north');
    title('Task 2.c - Simulation vs M/G/1 with priorities (case C)');
end
