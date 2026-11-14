flow1 = 100:1500;   %BYTES
flow2 = 100:150;    %BYTES
flow3 = 500:1000;   %BYTES
flows = {flow1;flow2;flow3};

p_flow1 = zeros(1,numel(flow1)) + 1/numel(flow1);
p_flow2 = zeros(1,numel(flow2)) + 1/numel(flow2);
p_flow3 = zeros(1,numel(flow3)) + 1/numel(flow3);
p_flows = {p_flow1;p_flow2;p_flow3};

C = 10;               %Mbps
f = [1e6 1e6 1e6];    %B  (f1 = f2 = f3, uma fila por fluxo)
P = 100000;
N = 50;               % numero de simulacoes
alfa = 0.1;           % intervalo de confianca a 90%

lambda1 = [400 600 800 1000];       %pps
lambda2 = [400 600 800 1000];       %pps
lambda3 = [600 600 600 1000];       %pps
v_lambda_A = [lambda1(1), lambda2(1), lambda3(1)];
v_lambda_B = [lambda1(2), lambda2(2), lambda3(2)];
v_lambda_C = [lambda1(3), lambda2(3), lambda3(3)];
v_lambda_D = [lambda1(4), lambda2(4), lambda3(4)];
v_lambda = [v_lambda_A;v_lambda_B;v_lambda_C;v_lambda_D];

cases = ["A" "B" "C" "D"];
names = ["Packet loss (%)" "Avg. packet delay (ms)" "Max. packet delay (ms)" "Throughput (Mbps)"];

%  PL   - row vector with the packet loss (%) of each flow
%  APD  - row vector with the average packet delay (milliseconds) of each flow
%  MPD  - maximum packet delay (milliseconds) of each flow
%  TT   - transmitted throughput (Mbps) of each flow


%% 3.a
% O simulador DRR esta no ficheiro Sim2FlowsDRRMP.m (na mesma pasta).
% Foi feito a partir do Sim2FlowsMP do exercicio 1:
%  - uma fila por fluxo, uma fila final e um credito (deficit) por fluxo
%  - cada pacote vai para a fila do seu fluxo
%  - quando a fila final fica vazia comeca uma nova ronda DRR: para cada
%    fluxo (pela ordem do ID) soma-se o quantum ao credito e passam para a
%    fila final os primeiros pacotes cujo tamanho total nao excede o credito
%  - uma fila vazia fica com credito zero


%% 3.b
% caso C, Quantum = 1500 para cada fluxo
Quantum = [1500 1500 1500];

% alocação de recursos
packet_loss = zeros(N, 3);
packet_delay = zeros(N, 3);
max_packet_delay= zeros(N, 3);
throughput = zeros(N, 3);

for i = 1:N
    [PL, APD, MPD, TT] = Sim2FlowsDRRMP(v_lambda_C,C,f,P,flows,Quantum);
    packet_loss(i, :) = PL;
    packet_delay(i, :) = APD;
    max_packet_delay(i, :)= MPD;
    throughput(i, :) = TT;
    fprintf("%d\n", i);
end

% media e intervalo de confianca a 90% (Modulo 3, slide 21)
avgs = {mean(packet_loss), mean(packet_delay), mean(max_packet_delay), mean(throughput)};
terms = {norminv(1-alfa/2)*sqrt(var(packet_loss)/N), norminv(1-alfa/2)*sqrt(var(packet_delay)/N), ...
         norminv(1-alfa/2)*sqrt(var(max_packet_delay)/N), norminv(1-alfa/2)*sqrt(var(throughput)/N)};

for i = 1:3
    fprintf("Flow %d:\n Avg. Packet loss (%%) = %.3e +- %.3e\n Avg. Packet Delay (ms) = %.3e +- %.3e\n Max. Packet Delay (ms) = %.3e +- %.3e\n Troughput (Mbps) = %.3e +- %.3e\n", ...
        i, avgs{1}(i), terms{1}(i), avgs{2}(i), terms{2}(i), avgs{3}(i), terms{3}(i), avgs{4}(i), terms{4}(i));
end

figure;
for k = 1:4
    subplot(2,2,k);
    bar(1:3, avgs{k});
    hold on
    errorbar(1:3, avgs{k}, terms{k}, terms{k}, 'k.', 'LineWidth', 1.2);
    hold off
    grid on
    xticks(1:3)
    xticklabels(["Flow 1" "Flow 2" "Flow 3"])
    ylabel(names(k))
end
sgtitle('3.b - DRR (Q = 1500/1500/1500), case C');


%% 3.c
% caso D (congestionado), Quantum = 1500 para cada fluxo
Quantum = [1500 1500 1500];

% alocação de recursos
packet_loss = zeros(N, 3);
packet_delay = zeros(N, 3);
max_packet_delay= zeros(N, 3);
throughput = zeros(N, 3);

for i = 1:N
    [PL, APD, MPD, TT] = Sim2FlowsDRRMP(v_lambda_D,C,f,P,flows,Quantum);
    packet_loss(i, :) = PL;
    packet_delay(i, :) = APD;
    max_packet_delay(i, :)= MPD;
    throughput(i, :) = TT;
    fprintf("%d\n", i);
end

avgs = {mean(packet_loss), mean(packet_delay), mean(max_packet_delay), mean(throughput)};
terms = {norminv(1-alfa/2)*sqrt(var(packet_loss)/N), norminv(1-alfa/2)*sqrt(var(packet_delay)/N), ...
         norminv(1-alfa/2)*sqrt(var(max_packet_delay)/N), norminv(1-alfa/2)*sqrt(var(throughput)/N)};

for i = 1:3
    fprintf("Flow %d:\n Avg. Packet loss (%%) = %.3e +- %.3e\n Avg. Packet Delay (ms) = %.3e +- %.3e\n Max. Packet Delay (ms) = %.3e +- %.3e\n Troughput (Mbps) = %.3e +- %.3e\n", ...
        i, avgs{1}(i), terms{1}(i), avgs{2}(i), terms{2}(i), avgs{3}(i), terms{3}(i), avgs{4}(i), terms{4}(i));
end

figure;
for k = 1:4
    subplot(2,2,k);
    bar(1:3, avgs{k});
    hold on
    errorbar(1:3, avgs{k}, terms{k}, terms{k}, 'k.', 'LineWidth', 1.2);
    hold off
    grid on
    xticks(1:3)
    xticklabels(["Flow 1" "Flow 2" "Flow 3"])
    ylabel(names(k))
end
sgtitle('3.c - DRR (Q = 1500/1500/1500), case D');

% guardar o throughput para comparar com o ideal na 3.e
sim_throughput_c = avgs{4};
sim_term_throughput_c = terms{4};


%% 3.d
% caso D (congestionado), Quantum = 1500 / 1500 / 4500
Quantum = [1500 1500 4500];

% alocação de recursos
packet_loss = zeros(N, 3);
packet_delay = zeros(N, 3);
max_packet_delay= zeros(N, 3);
throughput = zeros(N, 3);

for i = 1:N
    [PL, APD, MPD, TT] = Sim2FlowsDRRMP(v_lambda_D,C,f,P,flows,Quantum);
    packet_loss(i, :) = PL;
    packet_delay(i, :) = APD;
    max_packet_delay(i, :)= MPD;
    throughput(i, :) = TT;
    fprintf("%d\n", i);
end

avgs = {mean(packet_loss), mean(packet_delay), mean(max_packet_delay), mean(throughput)};
terms = {norminv(1-alfa/2)*sqrt(var(packet_loss)/N), norminv(1-alfa/2)*sqrt(var(packet_delay)/N), ...
         norminv(1-alfa/2)*sqrt(var(max_packet_delay)/N), norminv(1-alfa/2)*sqrt(var(throughput)/N)};

for i = 1:3
    fprintf("Flow %d:\n Avg. Packet loss (%%) = %.3e +- %.3e\n Avg. Packet Delay (ms) = %.3e +- %.3e\n Max. Packet Delay (ms) = %.3e +- %.3e\n Troughput (Mbps) = %.3e +- %.3e\n", ...
        i, avgs{1}(i), terms{1}(i), avgs{2}(i), terms{2}(i), avgs{3}(i), terms{3}(i), avgs{4}(i), terms{4}(i));
end

figure;
for k = 1:4
    subplot(2,2,k);
    bar(1:3, avgs{k});
    hold on
    errorbar(1:3, avgs{k}, terms{k}, terms{k}, 'k.', 'LineWidth', 1.2);
    hold off
    grid on
    xticks(1:3)
    xticklabels(["Flow 1" "Flow 2" "Flow 3"])
    ylabel(names(k))
end
sgtitle('3.d - DRR (Q = 1500/1500/4500), case D');

% guardar o throughput para comparar com o ideal na 3.e
sim_throughput_d = avgs{4};
sim_term_throughput_d = terms{4};


%% 3.e
% throughput ideal pelo max-min fairness ponderado (Modulo 4, slides 12-15)
% debito pedido por cada fluxo no caso D: lambda * 8 * tamanho medio
avg_size = zeros(1,3);
for k = 1:3
    avg_size(k) = sum(flows{k}.*p_flows{k});      % tamanho medio (Bytes)
end
x = v_lambda_D*8.*avg_size/1e6;                   % Mbps -> [6.4 1.0 6.0]

% no DRR os pesos sao os valores de quantum
weights = [1500 1500 1500; 1500 1500 4500];

for w = 1:2
    % algoritmo do max-min fairness ponderado
    ideal = zeros(1,3);
    active = true(1,3);       % fluxos ainda nao satisfeitos
    left = C;                 % capacidade ainda por atribuir
    while any(active)
        share = left*weights(w,active)/sum(weights(w,active));
        idx = find(active);
        satisfied = x(idx) <= ideal(idx) + share;
        if ~any(satisfied)
            % nenhum fluxo fica satisfeito: todos recebem a sua parte
            ideal(idx) = ideal(idx) + share;
            break;
        end
        % os satisfeitos recebem so o que pedem; o que sobra e dividido de novo
        for j = idx(satisfied)
            left = left - (x(j) - ideal(j));
            ideal(j) = x(j);
            active(j) = false;
        end
    end

    fprintf("Quantum = [%d %d %d]:\n", weights(w,:));
    fprintf(" Required throughput (Mbps) = %.3f  %.3f  %.3f\n", x);
    fprintf(" Ideal throughput (Mbps)    = %.3f  %.3f  %.3f\n", ideal);
    if w == 1 && exist('sim_throughput_c', 'var')
        fprintf(" Simulated throughput (Mbps) = %.3f +- %.3f  %.3f +- %.3f  %.3f +- %.3f\n", ...
            [sim_throughput_c; sim_term_throughput_c]);
    elseif w == 2 && exist('sim_throughput_d', 'var')
        fprintf(" Simulated throughput (Mbps) = %.3f +- %.3f  %.3f +- %.3f  %.3f +- %.3f\n", ...
            [sim_throughput_d; sim_term_throughput_d]);
    end
    fprintf("\n");
end
