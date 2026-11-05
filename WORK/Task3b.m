%% Task 3.b - Simulação do caso C com DRR (Quantum = 1500 para cada fluxo)
clear; clc;

C       = 10;                        % capacidade da ligação (Mbps)
f       = [1000000 1000000 1000000]; % f1 = f2 = f3 = 1.000.000 Bytes
P       = 100000;                    % critério de paragem (pacotes transmitidos)
lambda  = [800 800 600];             % caso C (pps)
Quantum = [1500 1500 1500];          % quantum de cada fluxo (Bytes)
N       = 50;                        % número de corridas
alfa    = 0.1;                       % intervalo de confiança a 90%

PL  = zeros(N,3);
APD = zeros(N,3);
MPD = zeros(N,3);
TT  = zeros(N,3);
for it = 1:N
    [PL(it,:), APD(it,:), MPD(it,:), TT(it,:)] = Sim2FlowsDRR_newversion(lambda, C, f, P, Quantum);
end

% Média e intervalo de confiança de cada parâmetro (Módulo 3, slide 21)
media = @(X) mean(X);
termo = @(X) norminv(1-alfa/2) * sqrt(var(X)/N);

nomes = {'PL (%)', 'APD (ms)', 'MPD (ms)', 'TT (Mbps)'};
dados = {PL, APD, MPD, TT};
for k = 1:4
    m = media(dados{k});
    t = termo(dados{k});
    fprintf('%-10s  Fluxo 1 = %.4f +- %.4f | Fluxo 2 = %.4f +- %.4f | Fluxo 3 = %.4f +- %.4f\n', ...
        nomes{k}, m(1), t(1), m(2), t(2), m(3), t(3));
end

save('Task3b_resultados.mat', 'PL', 'APD', 'MPD', 'TT', 'N', 'alfa');

figure;
for k = 1:4
    subplot(2,2,k);
    m = media(dados{k});
    t = termo(dados{k});
    bar(1:3, m);
    hold on;
    errorbar(1:3, m, t, t, 'k.', 'LineWidth', 1.2);
    hold off;
    grid on;
    xticks(1:3);
    xticklabels({'Flow 1','Flow 2','Flow 3'});
    ylabel(nomes{k});
end
sgtitle('Task 3.b - DRR (Q = 1500/1500/1500), case C (90% confidence intervals)');
