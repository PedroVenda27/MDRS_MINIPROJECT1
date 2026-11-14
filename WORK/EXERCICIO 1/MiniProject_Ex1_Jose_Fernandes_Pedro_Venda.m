flow1 = 100:1500;   %BYTES
flow2 = 100:150;    %BYTES
flow3 = 500:1000;   %BYTES
flows = {flow1;flow2;flow3};

p_flow1 = zeros(1,numel(flow1)) + 1/numel(flow1);
p_flow2 = zeros(1,numel(flow2)) + 1/numel(flow2);
p_flow3 = zeros(1,numel(flow3)) + 1/numel(flow3);
p_flows = {p_flow1;p_flow2;p_flow3};

C = 10;           %Mbps
f = 1e6;          %B
P = 100000;
N = 50;           % numero de simulacoes
alfa = 0.1;       % intervalo de confianca a 90%

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


%% 1.a
% O simulador esta no ficheiro Sim2FlowsMP.m (na mesma pasta). Foi feito a
% partir do Sim2Flows fornecido:
%  - o numero de fluxos passa a ser dado pelo cell array flows (3 fluxos),
%    e os contadores estatisticos tem uma posicao por fluxo
%  - a primeira chegada de cada fluxo e criada num ciclo
%  - o tamanho de cada pacote e gerado a partir dos tamanhos do seu fluxo
%    (todos com igual probabilidade)
%  - otimizacoes: o proximo evento e escolhido com min (em vez de sortrows)
%    e a fila e pre-alocada com P posicoes


%% 1.b
% alocação de recursos
packet_loss = zeros(N, 3);
packet_delay = zeros(N, 3);
max_packet_delay= zeros(N, 3);
throughput = zeros(N, 3);

for i = 1:N
    [PL, APD, MPD, TT] = Sim2FlowsMP(v_lambda_C,C,f,P,flows);
    packet_loss(i, :) = PL;
    packet_delay(i, :) = APD;
    max_packet_delay(i, :)= MPD;
    throughput(i, :) = TT;
    fprintf("%d\n", i);
end

% media e intervalo de confianca a 90% (Modulo 3, slide 21)
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

% graficos: barras com a media e barras de erro com o intervalo de confianca
figure;
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
sgtitle('1.b - FIFO, case C');

% guardar o atraso e o throughput para comparar com a teoria na 1.c
sim_packet_delay = avg_packet_delay;
sim_term_packet_delay = term_packet_delay;
sim_throughput = avg_throughput;
sim_term_throughput = term_throughput;


%% 1.c
% M/G/1 (Modulo 2, slides 36-37)
% media e 2o momento do tempo de transmissao de cada fluxo
ES = zeros(1,3);
ES2 = zeros(1,3);
avg_size = zeros(1,3);
for k = 1:3
    S = 8*flows{k}/(C*1e6);                  % tempo de transmissao de cada tamanho (s)
    ES(k) = sum(S.*p_flows{k});              % E[S]
    ES2(k) = sum(S.^2.*p_flows{k});          % E[S^2]
    avg_size(k) = sum(flows{k}.*p_flows{k}); % tamanho medio (Bytes)
end

% agregado dos 3 fluxos: lambda = soma dos lambdas, momentos pesados pelos lambdas
lambda_C = sum(v_lambda_C);
ES_agr = sum(v_lambda_C/lambda_C.*ES);
ES2_agr = sum(v_lambda_C/lambda_C.*ES2);
rho = lambda_C*ES_agr;

% Pollaczek-Khintchine: o atraso na fila e igual para todos os fluxos (fila FIFO unica)
WQ = lambda_C*ES2_agr/(2*(1-rho));

% atraso medio de cada fluxo = fila + transmissao do proprio fluxo
theory_packet_delay = (WQ + ES)*1000;                % ms
% throughput: fila muito grande -> sem perdas -> lambda * 8 * tamanho medio
theory_throughput = v_lambda_C*8.*avg_size/1e6;      % Mbps

fprintf("rho = %.3f | WQ = %.3e ms\n", rho, WQ*1000);
for i = 1:3
    fprintf("Flow %d:\n Theoretical Avg. Packet Delay (ms) = %.3e\n Theoretical Throughput (Mbps) = %.3e\n", ...
        i, theory_packet_delay(i), theory_throughput(i));
end

% comparacao com a simulacao da 1.b (se ja tiver sido corrida)
if exist('sim_packet_delay', 'var')
    figure;
    subplot(1,2,1);
    bar(1:3, sim_packet_delay);
    hold on
    errorbar(1:3, sim_packet_delay, sim_term_packet_delay, sim_term_packet_delay, 'k.', 'LineWidth', 1.2);
    plot(1:3, theory_packet_delay, 'rx', 'MarkerSize', 12, 'LineWidth', 2);
    hold off
    grid on
    xticks(1:3)
    xticklabels(["Flow 1" "Flow 2" "Flow 3"])
    ylabel('Avg. packet delay (ms)')
    legend('Simulation', '90% CI', 'M/G/1', 'Location', 'southoutside');
    subplot(1,2,2);
    bar(1:3, sim_throughput);
    hold on
    errorbar(1:3, sim_throughput, sim_term_throughput, sim_term_throughput, 'k.', 'LineWidth', 1.2);
    plot(1:3, theory_throughput, 'rx', 'MarkerSize', 12, 'LineWidth', 2);
    hold off
    grid on
    xticks(1:3)
    xticklabels(["Flow 1" "Flow 2" "Flow 3"])
    ylabel('Throughput (Mbps)')
    legend('Simulation', '90% CI', 'M/G/1', 'Location', 'southoutside');
    sgtitle('1.c - Simulation vs M/G/1 (case C)');
end


%% 1.d
% alocação de recursos
packet_loss = zeros(3*N, 3);
packet_delay = zeros(3*N, 3);
max_packet_delay= zeros(3*N, 3);
throughput = zeros(3*N, 3);
avg_packet_delay = zeros(1,3);
avg_max_packet_delay = zeros(1,3);
term_packet_delay = zeros(1,3);
term_max_packet_delay = zeros(1,3);

for i = 1:3*N
    if (i<=N)
        [PL, APD, MPD, TT] = Sim2FlowsMP(v_lambda_A,C,f,P,flows);
    elseif (i>N) && (i<=2*N)
        [PL, APD, MPD, TT] = Sim2FlowsMP(v_lambda_B,C,f,P,flows);
    else
        [PL, APD, MPD, TT] = Sim2FlowsMP(v_lambda_C,C,f,P,flows);
    end
    packet_loss(i, :) = PL;
    packet_delay(i, :) = APD;
    max_packet_delay(i, :)= MPD;
    throughput(i, :) = TT;
    fprintf("%d\n", i);
end

% so interessa o Flow 3 (coluna 3), um valor por caso
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
sgtitle('1.d - Flow 3 with FIFO');
