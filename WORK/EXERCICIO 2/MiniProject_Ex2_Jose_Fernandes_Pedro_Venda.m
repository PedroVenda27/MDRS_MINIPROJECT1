flow1 = 100:1500;   % tamanhos fluxo 1 (Bytes)
flow2 = 100:150;    % tamanhos fluxo 2 (Bytes)
flow3 = 500:1000;   % tamanhos fluxo 3 (Bytes)
flows = {flow1;flow2;flow3};

% probabilidade de cada tamanho (uniforme)
p_flow1 = zeros(1,numel(flow1)) + 1/numel(flow1);
p_flow2 = zeros(1,numel(flow2)) + 1/numel(flow2);
p_flow3 = zeros(1,numel(flow3)) + 1/numel(flow3);
p_flows = {p_flow1;p_flow2;p_flow3};

C = 10;           % capacidade (Mbps)
f = [1e6 1e6];    % filas (Bytes): f1 prioridade alta, f2 prioridade baixa
P = 100000;       % parar simulação: 100 000 pacotes transmitidos
N = 50;           % nº de simulações
alfa = 0.1;       % intervalo de confiança 90%

% prioridades: fluxo 3 = 1 (alta), fluxos 1 e 2 = 2
prio = [2 2 1];

lambda1 = [400 600 800 1000];       % fluxo 1, casos A-D (pps)
lambda2 = [400 600 800 1000];       % fluxo 2, casos A-D (pps)
lambda3 = [600 600 600 1000];       % fluxo 3, casos A-D (pps)
v_lambda_A = [lambda1(1), lambda2(1), lambda3(1)];
v_lambda_B = [lambda1(2), lambda2(2), lambda3(2)];
v_lambda_C = [lambda1(3), lambda2(3), lambda3(3)];
v_lambda_D = [lambda1(4), lambda2(4), lambda3(4)];
v_lambda = [v_lambda_A;v_lambda_B;v_lambda_C;v_lambda_D];

cases = ["A" "B" "C" "D"];

%  PL   - perda de pacotes (%)
%  APD  - atraso médio (ms)
%  MPD  - atraso máximo (ms)
%  TT   - throughput (Mbps)


%% 2.a
% Simulador: Sim2FlowsPrioMP.m (a partir do Sim2FlowsMP do ex. 1)
%  - uma fila por prioridade (QUEUE{1} alta, QUEUE{2} baixa)
%  - pacote vai para a fila da sua prioridade (prio)
%  - transmite primeiro a fila de prioridade mais alta não vazia


%% 2.b
% alocação de resultados
packet_loss = zeros(N, 3);
packet_delay = zeros(N, 3);
max_packet_delay= zeros(N, 3);
throughput = zeros(N, 3);

for i = 1:N
    [PL, APD, MPD, TT] = Sim2FlowsPrioMP(v_lambda_C,C,f,P,flows,prio);
    packet_loss(i, :) = PL;
    packet_delay(i, :) = APD;
    max_packet_delay(i, :)= MPD;
    throughput(i, :) = TT;
    fprintf("%d\n", i);   % progresso
end

% média e intervalo de confiança 90%
avg_packet_loss = mean(packet_loss);
avg_packet_delay = mean(packet_delay);
avg_max_packet_delay = mean(max_packet_delay);
avg_throughput = mean(throughput);
term_packet_loss = norminv(1-alfa/2)*sqrt(var(packet_loss)/N);
term_packet_delay = norminv(1-alfa/2)*sqrt(var(packet_delay)/N);
term_max_packet_delay = norminv(1-alfa/2)*sqrt(var(max_packet_delay)/N);
term_throughput = norminv(1-alfa/2)*sqrt(var(throughput)/N);

for i = 1:3
    fprintf("Flow %d:\n Avg. Packet loss (%%) = %.3e +- %.3e\n Avg. Packet Delay (ms) = %.3e +- %.3e\n Max. Packet Delay (ms) = %.3e +- %.3e\n Troughput (Mbps) = %.3e +- %.3e\n", ...
        i, avg_packet_loss(i), term_packet_loss(i), avg_packet_delay(i), term_packet_delay(i), ...
        avg_max_packet_delay(i), term_max_packet_delay(i), avg_throughput(i), term_throughput(i));
end

% gráficos: média + intervalo de confiança
figure;
names = ["Packet loss (%)" "Avg. packet delay (ms)" "Max. packet delay (ms)" "Throughput (Mbps)"];
avgs = {avg_packet_loss, avg_packet_delay, avg_max_packet_delay, avg_throughput};
terms = {term_packet_loss, term_packet_delay, term_max_packet_delay, term_throughput};
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
sgtitle('2.b - Priority Queuing, case C');

% atraso da 2.b para a 2.c
sim_packet_delay = avg_packet_delay;
sim_term_packet_delay = term_packet_delay;


%% 2.c
% M/G/1 com prioridades
% E[S] e E[S^2] de cada fluxo
ES = zeros(1,3);
ES2 = zeros(1,3);
for k = 1:3
    S = 8*flows{k}/(C*1e6);                  % tempo de transmissão (s)
    ES(k) = sum(S.*p_flows{k});              % E[S]
    ES2(k) = sum(S.^2.*p_flows{k});          % E[S^2]
end

rho = v_lambda_C.*ES;                        % ocupação de cada fluxo
num = sum(v_lambda_C.*ES2);                  % soma de todos os fluxos

rho_alta = sum(rho(prio==1));                % prioridade 1: fluxo 3
rho_baixa = sum(rho(prio==2));               % prioridade 2: fluxos 1 e 2

WQ_alta = num/(2*(1-rho_alta));                          % fila prioridade alta
WQ_baixa = num/(2*(1-rho_alta)*(1-rho_alta-rho_baixa));  % fila prioridade baixa

WQ = zeros(1,3);
WQ(prio==1) = WQ_alta;
WQ(prio==2) = WQ_baixa;
theory_packet_delay = (WQ + ES)*1000;        % fila + transmissão (ms)

for i = 1:3
    fprintf("Flow %d:\n Theoretical Avg. Packet Delay (ms) = %.3e\n", i, theory_packet_delay(i));
end

% comparação com a simulação da 2.b (Tem de Já Estar Corrida)
if exist('sim_packet_delay', 'var')
    figure;
    bar(1:3, sim_packet_delay);
    hold on
    errorbar(1:3, sim_packet_delay, sim_term_packet_delay, sim_term_packet_delay, 'k.', 'LineWidth', 1.2);
    plot(1:3, theory_packet_delay, 'rx', 'MarkerSize', 12, 'LineWidth', 2);   % teoria
    hold off
    grid on
    xticks(1:3)
    xticklabels(["Flow 1" "Flow 2" "Flow 3"])
    ylabel('Avg. packet delay (ms)')
    legend('Simulation', '90% CI', 'M/G/1 with priorities', 'Location', 'north');
    title('2.c - Simulation vs M/G/1 with priorities (case C)');
end


%% 2.d
% alocação dos resultados (N por caso)
packet_loss = zeros(3*N, 3);
packet_delay = zeros(3*N, 3);
max_packet_delay= zeros(3*N, 3);
throughput = zeros(3*N, 3);
avg_packet_delay = zeros(1,3);
avg_max_packet_delay = zeros(1,3);
term_packet_delay = zeros(1,3);
term_max_packet_delay = zeros(1,3);

% casos A, B e C
for i = 1:3*N
    if (i<=N)
        [PL, APD, MPD, TT] = Sim2FlowsPrioMP(v_lambda_A,C,f,P,flows,prio);
    elseif (i>N) && (i<=2*N)
        [PL, APD, MPD, TT] = Sim2FlowsPrioMP(v_lambda_B,C,f,P,flows,prio);
    else
        [PL, APD, MPD, TT] = Sim2FlowsPrioMP(v_lambda_C,C,f,P,flows,prio);
    end
    packet_loss(i, :) = PL;
    packet_delay(i, :) = APD;
    max_packet_delay(i, :)= MPD;
    throughput(i, :) = TT;
    fprintf("%d\n", i);
end

% fluxo 3 (coluna 3), um valor por caso
for c = 1:3
    start = N*(c-1) + 1;
    avg_packet_delay(c) = mean(packet_delay(start:N*c,3));
    avg_max_packet_delay(c) = mean(max_packet_delay(start:N*c,3));
    term_packet_delay(c) = norminv(1-alfa/2)*sqrt(var(packet_delay(start:N*c,3))/N);
    term_max_packet_delay(c) = norminv(1-alfa/2)*sqrt(var(max_packet_delay(start:N*c,3))/N);
    fprintf("Case %s:\n", cases(c))
    fprintf("Flow 3:\n Avg. Packet Delay (ms) = %.3e +- %.3e\n Max. Packet Delay (ms) = %.3e +- %.3e\n\n", ...
        avg_packet_delay(c), term_packet_delay(c), avg_max_packet_delay(c), term_max_packet_delay(c));
end

% gráficos fluxo 3
figure;
subplot(1,2,1);
bar(1:3, avg_packet_delay);
hold on
errorbar(1:3, avg_packet_delay, term_packet_delay, term_packet_delay, 'k.', 'LineWidth', 1.2);
hold off
grid on
xticks(1:3)
xticklabels(["Case A" "Case B" "Case C"])
ylabel('Avg. packet delay of Flow 3 (ms)')
subplot(1,2,2);
bar(1:3, avg_max_packet_delay);
hold on
errorbar(1:3, avg_max_packet_delay, term_max_packet_delay, term_max_packet_delay, 'k.', 'LineWidth', 1.2);
hold off
grid on
xticks(1:3)
xticklabels(["Case A" "Case B" "Case C"])
ylabel('Max. packet delay of Flow 3 (ms)')
sgtitle('2.d - Flow 3 with Priority Queuing');
