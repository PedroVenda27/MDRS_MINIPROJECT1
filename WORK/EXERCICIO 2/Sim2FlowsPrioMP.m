function [PL , APD , MPD , TT] = Sim2FlowsPrioMP(lambda,C,f,P,flows,prio)
% ENTRADAS:
%  lambda - taxa de chegada de cada fluxo (pps)
%  C      - capacidade da ligação (Mbps)
%  f      - tamanho de cada fila de prioridade (Bytes)
%  P      - nº de pacotes transmitidos (critério de paragem)
%  flows  - tamanhos de cada fluxo (Bytes)
%  prio   - prioridade de cada fluxo (1 = alta)
% SAÍDAS:
%  PL   - perda de pacotes (%)
%  APD  - atraso médio (ms)
%  MPD  - atraso máximo (ms)
%  TT   - throughput (Mbps)

FLOW_NUM = length(flows);
PRIO_NUM = max(prio);

% Eventos:
ARRIVAL= 0;   % chegada de um pacote
DEPARTURE= 1;   % fim da transmissão de um pacote

% Variáveis de estado:
STATE = 0;   % 0 - ligação livre; 1 - ligação ocupada
% uma fila por prioridade em vez de fila única
QUEUEOCCUPATION= zeros(1,PRIO_NUM);   % ocupação de cada fila (Bytes)
QUEUE = cell(1,PRIO_NUM);   % tamanho, instante de chegada e fluxo
queue_count = zeros(1,PRIO_NUM);   % nº de pacotes em cada fila
for q = 1:PRIO_NUM
    % pré-alocação de P posições (mais rápido)
    QUEUE{q} = zeros(P,3);
end

% Contadores estatísticos:
TOTALPACKETS= zeros(1,FLOW_NUM);   % pacotes que chegaram
LOSTPACKETS= zeros(1,FLOW_NUM);   % pacotes perdidos (fila cheia)
TRANSPACKETS= zeros(1,FLOW_NUM);   % pacotes transmitidos
TRANSBYTES= zeros(1,FLOW_NUM);   % Bytes transmitidos
DELAYS= zeros(1,FLOW_NUM);   % soma dos atrasos
MAXDELAY= zeros(1,FLOW_NUM);   % atraso máximo

% Relógio da simulação:
Clock= 0;

% Primeira chegada de cada fluxo:
EventList = zeros(FLOW_NUM, 5);
for k = 1:FLOW_NUM
    tmp = Clock + exprnd(1/lambda(k));
    EventList(k,:) = [ARRIVAL, tmp, GenerateSize(flows{k}), k, tmp];
end

% Ciclo da simulação:
while sum(TRANSPACKETS)<P       % critério de paragem
    % próximo evento (min em vez de sortrows)
    [~, idx] = min(EventList(:,2));
    Event      = EventList(idx, 1);
    Clock      = EventList(idx, 2);
    PacketSize = EventList(idx, 3);
    Flow       = EventList(idx, 4);
    ArrInstant = EventList(idx, 5);
    EventList(idx, :) = [];

    switch Event
        case ARRIVAL         % chegada
            TOTALPACKETS(Flow)= TOTALPACKETS(Flow)+1;
            tmp= Clock + exprnd(1/lambda(Flow));
            nextPacketSize= GenerateSize(flows{Flow});
            EventList = [EventList; ARRIVAL, tmp, nextPacketSize, Flow, tmp];
            if STATE==0
                STATE= 1;
                EventList = [EventList; DEPARTURE, Clock + 8*PacketSize/(C*1e6), PacketSize, Flow, Clock];
            else
                % fila da prioridade do pacote
                q = prio(Flow);
                if QUEUEOCCUPATION(q) + PacketSize <= f(q)
                    queue_count(q) = queue_count(q) + 1;
                    QUEUE{q}(queue_count(q), :) = [PacketSize , Clock, Flow];
                    QUEUEOCCUPATION(q)= QUEUEOCCUPATION(q) + PacketSize;
                else
                    LOSTPACKETS(Flow)= LOSTPACKETS(Flow) + 1;
                end
            end
        case DEPARTURE          % partida
            TRANSBYTES(Flow)= TRANSBYTES(Flow) + PacketSize;
            TRANSPACKETS(Flow)= TRANSPACKETS(Flow) + 1;
            DELAYS(Flow)= DELAYS(Flow) + (Clock - ArrInstant);
            if Clock - ArrInstant > MAXDELAY(Flow)
                MAXDELAY(Flow)= Clock - ArrInstant;
            end
            % fila de prioridade mais alta não vazia
            q = find(queue_count > 0, 1);
            if ~isempty(q)
                QSize= QUEUE{q}(1,1);
                QInstant= QUEUE{q}(1,2);
                QFlow= QUEUE{q}(1,3);
                EventList = [EventList; DEPARTURE, Clock + 8*QSize/(C*1e6), QSize, QFlow, QInstant];
                QUEUEOCCUPATION(q)= QUEUEOCCUPATION(q) - QSize;
                if queue_count(q) > 1
                    QUEUE{q}(1:queue_count(q)-1, :) = QUEUE{q}(2:queue_count(q), :);
                end
                queue_count(q) = queue_count(q) - 1;
            else
                STATE= 0;
            end
    end
end

% Cálculo dos parâmetros de desempenho:
PL= 100*LOSTPACKETS./TOTALPACKETS;   % em percentagem
APD= 1000*DELAYS./TRANSPACKETS;   % em milissegundos
MPD= 1000*MAXDELAY;   % em milissegundos
TT= 1e-6*TRANSBYTES*8/Clock;   % em Mbps

end

function out= GenerateSize(flow)
    out= randi([flow(1) flow(length(flow))]);
end
