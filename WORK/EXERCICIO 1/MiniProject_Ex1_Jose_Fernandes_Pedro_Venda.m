flow1 = 100:1500;   %BYTES
flow2 = 100:150;    %BYTES
flow3 = 500:1000;   %BYTES
flows = {flow1;flow2;flow3};        %cel array

p_flow1 = zeros(1,numel(flow1)) + 1/numel(flow1);
p_flow2 = zeros(1,numel(flow2)) + 1/numel(flow2);
p_flow3 = zeros(1,numel(flow3)) + 1/numel(flow3);

C = 10;           %Mbps
f = 1e6;          %B
P = 100000;

lambda1 = [400 600 800 1000];       %pps
lambda2 = [400 600 800 1000];       %pps
lambda3 = [600 600 600 1000];       %pps
v_lambda_A = [lambda1(1), lambda2(1), lambda3(1)];
v_lambda_B = [lambda1(2), lambda2(2), lambda3(2)];
v_lambda_C = [lambda1(3), lambda2(3), lambda3(3)];
v_lambda_D = [lambda1(4), lambda2(4), lambda3(4)];
v_lambda = [v_lambda_A;v_lambda_B;v_lambda_C;v_lambda_D];
lambda_A = lambda1(1)+lambda2(1)+lambda3(1);
lambda_B = lambda1(2)+lambda2(2)+lambda3(2);
lambda_C = lambda1(3)+lambda2(3)+lambda3(3);
lambda_D = lambda1(4)+lambda2(4)+lambda3(4);
lambda = [lambda_A lambda_B lambda_C lambda_D];

cases = ["A" "B" "C" "D"];

% Calculo dos termos de erro para o intervalo de confiança a 90%
alfa = 0.1;
z = norminv(1 - alfa/2);

%  PL   - row vector with the packet loss (%) of each flow
%  APD  - row vector with the average packet delay (milliseconds) of each flow
%  MPD  - maximum packet delay (milliseconds) of each flow
%  TT   - transmitted throughput (Mbps) of each flow

% para executar cada alínea basta fazer um bloco em comentário das
% restantes. A alinea 1.c deve ser corrida em conjunto com a 1.b

%{
%1.a feito apenas para testar o sim2flowsMP na sua totalidade, mas demora
muito tempo
% normalmente faria [] para ser o mais genérico possivel mas como o programa é muito lento, vou fazer
% alocação de recursos
packet_loss = zeros(50, 3);
packet_delay = zeros(50, 3);
max_packet_delay= zeros(50, 3);
throughput = zeros(50, 3);
% throughput = []       se for genérico

for k = 1:length(lambda1)
    for i = 1:50
        [PL, APD, MPD, TT] = Sim2FlowsMP(v_lambda(k,:),C,f,P,flows);
        packet_loss(i, :) = PL;
        packet_delay(i, :) = APD;
        max_packet_delay(i, :)= MPD;
        throughput(i, :) = TT;
        % throughput = [throughput; TT];      se for genérico
        fprintf("%d\n", i);
    end
end
%}

%-------------------------------------------------------------------------

%1.b
% alocação de recursos
packet_loss = zeros(50, 3);
packet_delay = zeros(50, 3);
max_packet_delay= zeros(50, 3);
throughput = zeros(50, 3);
avg_packet_loss = zeros(1,3);
avg_packet_delay = zeros(1,3);
avg_max_packet_delay = zeros(1,3);
avg_throughput = zeros(1,3);


for i = 1:50
    [PL, APD, MPD, TT] = Sim2FlowsMP(v_lambda_C,C,f,P,flows);
    packet_loss(i, :) = PL;
    packet_delay(i, :) = APD;
    max_packet_delay(i, :)= MPD;
    throughput(i, :) = TT;
    fprintf("%d\n", i);
end

for k = 1:3
    avg_packet_loss(k) = sum(packet_loss(:,k))/length(packet_loss(:,k));
    avg_packet_delay(k) = sum(packet_delay(:,k))/length(packet_delay(:,k));
    avg_max_packet_delay(k) = sum(max_packet_delay(:,k))/length(max_packet_delay(:,k));
    avg_throughput(k) = sum(throughput(:,k))/length(throughput(:,k));
end

for i = 1:3
    fprintf("Flow %d:\n Avg. Packet loss (%%) = %.3e\n Avg. Packet Delay (ms) = %.3e\n Max. Packet Delay (ms) = %.3e\n Troughput (Mbps) = %.3e\n", i, avg_packet_loss(i), avg_packet_delay(i), avg_max_packet_delay(i), avg_throughput(i));
end

termo_packet_loss      = z * std(packet_loss) / sqrt(50);
termo_packet_delay     = z * std(packet_delay) / sqrt(50);
termo_max_packet_delay = z * std(max_packet_delay) / sqrt(50);
termo_throughput       = z * std(throughput) / sqrt(50);

figure;

% Gráfico 1: Packet Loss
subplot(2,2,1);
bar(1:3, avg_packet_loss);
hold on;
errorbar(1:3, avg_packet_loss, termo_packet_loss, termo_packet_loss, 'k.', 'LineWidth', 1.2);
hold off;
grid on;
xticks(1:3);
xticklabels({'Flow 1','Flow 2','Flow 3'});
ylabel('PL (%)');

% Gráfico 2: Average Packet Delay
subplot(2,2,2);
bar(1:3, avg_packet_delay);
hold on;
errorbar(1:3, avg_packet_delay, termo_packet_delay, termo_packet_delay, 'k.', 'LineWidth', 1.2);
hold off;
grid on;
xticks(1:3);
xticklabels({'Flow 1','Flow 2','Flow 3'});
ylabel('APD (ms)');

% Gráfico 3: Max Packet Delay
subplot(2,2,3);
bar(1:3, avg_max_packet_delay);
hold on;
errorbar(1:3, avg_max_packet_delay, termo_max_packet_delay, termo_max_packet_delay, 'k.', 'LineWidth', 1.2);
hold off;
grid on;
xticks(1:3);
xticklabels({'Flow 1','Flow 2','Flow 3'});
ylabel('MPD (ms)');

% Gráfico 4: Throughput
subplot(2,2,4);
bar(1:3, avg_throughput);
hold on;
errorbar(1:3, avg_throughput, termo_throughput, termo_throughput, 'k.', 'LineWidth', 1.2);
hold off;
grid on;
xticks(1:3);
xticklabels({'Flow 1','Flow 2','Flow 3'});
ylabel('TT (Mbps)');

sgtitle('Task 1.b - case C performance');


%------------------------------------------------------------------------

%1.c
C_bps = C * 1e6;

Es_f1  = sum(p_flow1.*(8*flow1/C_bps));
Es2_f1 = sum(p_flow1.*(8*flow1/C_bps).^2);
Es_f2  = sum(p_flow2.*(8*flow2/C_bps));
Es2_f2 = sum(p_flow2.*(8*flow2/C_bps).^2);
Es_f3  = sum(p_flow3.*(8*flow3/C_bps));
Es2_f3 = sum(p_flow3.*(8*flow3/C_bps).^2);

rho1 = lambda1(3) * Es_f1;
rho2 = lambda2(3) * Es_f2;
rho3 = lambda3(3) * Es_f3;
rho_total = rho1 + rho2 + rho3;

Wq = (lambda1(3)*Es2_f1 + lambda2(3)*Es2_f2 + lambda3(3)*Es2_f3)/(2 * (1 - rho_total));

W1 = Wq + Es_f1;
W2 = Wq + Es_f2;
W3 = Wq + Es_f3;

avg_B_f1 = sum(flow1)/numel(flow1);
avg_B_f2 = sum(flow2)/numel(flow2);
avg_B_f3 = sum(flow3)/numel(flow3);
throughput_f1 = lambda1(3)*(8*avg_B_f1);
throughput_f2 = lambda2(3)*(8*avg_B_f2);
throughput_f3 = lambda3(3)*(8*avg_B_f3);

APD_teo = [W1, W2, W3] * 1000;      %ms
TT_teo  = [throughput_f1, throughput_f2, throughput_f3] / 1e6;

figure;

% Gráfico 1: Average Packet Delay
subplot(1,2,1);
bar(1:3, avg_packet_delay); 
hold on;
errorbar(1:3, avg_packet_delay, termo_packet_delay, termo_packet_delay, 'k.', 'LineWidth', 1.2);
plot(1:3, APD_teo, 'rx', 'MarkerSize', 12, 'LineWidth', 2); 
hold off;
grid on; 
xticks(1:3); 
xticklabels({'Flow 1','Flow 2','Flow 3'});
ylabel('Average packet delay (ms)');
legend('Simulation', '90% CI', 'M/G/1', 'Location', 'south');

% Gráfico 2: Throughput
subplot(1,2,2);
bar(1:3, avg_throughput); 
hold on;
errorbar(1:3, avg_throughput, termo_throughput, termo_throughput, 'k.', 'LineWidth', 1.2);
plot(1:3, TT_teo, 'rx', 'MarkerSize', 12, 'LineWidth', 2); 
hold off;
grid on; 
xticks(1:3); 
xticklabels({'Flow 1','Flow 2','Flow 3'});
ylabel('Throughput (Mbps)');
legend('Simulation', '90% CI', 'M/G/1', 'Location', 'north');

sgtitle('Task 1.c - Simulation vs M/G/1 (case C)');

%-----------------------------------------------------------------------------

%1.d
% alocação de recursos
packet_loss = zeros(150, 3);
packet_delay = zeros(150, 3);
max_packet_delay= zeros(150, 3);
throughput = zeros(150, 3);
avg_packet_loss = zeros(1,3);
avg_packet_delay = zeros(1,3);
avg_max_packet_delay = zeros(1,3);
avg_throughput = zeros(1,3);

for i = 1:150
    if (i<=50)
        [PL, APD, MPD, TT] = Sim2FlowsMP(v_lambda_A,C,f,P,flows);
    elseif (i>50) && (i<=100)
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

avg_packet_delay_f3     = zeros(1,3);
avg_max_packet_delay_f3 = zeros(1,3);
termo_packet_delay_f3     = zeros(1,3);
termo_max_packet_delay_f3 = zeros(1,3);

for c = 1:3
    fprintf("Case %s:\n", cases(c))
    start = 50*(c-1) + 1;
    fim   = 50*c;
    avg_packet_delay_f3(c)     = sum(packet_delay(start:fim, 3)) / 50;
    avg_max_packet_delay_f3(c) = sum(max_packet_delay(start:fim, 3)) / 50;
    termo_packet_delay_f3(c)     = z * std(packet_delay(start:fim, 3)) / sqrt(50);
    termo_max_packet_delay_f3(c) = z * std(max_packet_delay(start:fim, 3)) / sqrt(50);
    
    fprintf("Flow %d:\n Avg. Packet Delay (ms) = %.3e\n Max. Packet Delay (ms) = %.3e\n\n\n", 3, avg_packet_delay_f3(c), avg_max_packet_delay_f3(c));
end

figure;

% Gráfico 1: Average Packet Delay
subplot(1,2,1);
bar(1:3, avg_packet_delay_f3); 
hold on;
errorbar(1:3, avg_packet_delay_f3, termo_packet_delay_f3, termo_packet_delay_f3, 'k.', 'LineWidth', 1.2); 
hold off;
grid on; 
xticks(1:3); 
xticklabels({'Case A','Case B','Case C'});
ylabel('Average packet delay of Flow 3 (ms)');

% Gráfico 2: Maximum Packet Delay
subplot(1,2,2);
bar(1:3, avg_max_packet_delay_f3); 
hold on;
errorbar(1:3, avg_max_packet_delay_f3, termo_max_packet_delay_f3, termo_max_packet_delay_f3, 'k.', 'LineWidth', 1.2); 
hold off;
grid on; 
xticks(1:3); 
xticklabels({'Case A','Case B','Case C'});
ylabel('Maximum packet delay of Flow 3 (ms)');

sgtitle('Task 1.d - Flow 3');

%{      
%para ver todos os casos e flows
for c = 1:3
    fprintf("Case %s:\n", cases(c))
    for k = 1:3
        start = 50*(c-1) + 1;
        avg_packet_loss(k) = sum(packet_loss(start:50*c,k))/length(packet_loss(start:50*c,k));
        avg_packet_delay(k) = sum(packet_delay(start:50*c,k))/length(packet_delay(start:50*c,k));
        avg_max_packet_delay(k) = sum(max_packet_delay(start:50*c,k))/length(max_packet_delay(start:50*c,k));
        avg_throughput(k) = sum(throughput(start:50*c,k))/length(throughput(start:50*c,k));
        fprintf("Flow %d:\n Avg. Packet Delay (ms) = %.3e\n Max. Packet Delay (ms) = %.3e\n\n", k, avg_packet_delay(k), avg_max_packet_delay(k));
    end
    fprintf("\n\n")
end
%}