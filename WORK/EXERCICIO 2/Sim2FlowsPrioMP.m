function [PL , APD , MPD , TT] = Sim2FlowsPrioMP(lambda,C,f,P,flows,prio)
% INPUT PARAMETERS:
%  lambda - row vector with the packet rate of each flow (packets/sec)
%  C      - link bandwidth (Mbps)
%  f      - row vector with the size (Bytes) of each priority queue
%  P      - number of packets (stopping criterium)
%  flows  - cell array with the possible packet sizes (Bytes) of each flow
%  prio   - row vector with the priority of each flow (1 - highest)
% OUTPUT PARAMETERS:
%  PL   - row vector with the packet loss (%) of each flow
%  APD  - row vector with the average packet delay (milliseconds) of each flow
%  MPD  - maximum packet delay (milliseconds) of each flow
%  TT   - transmitted throughput (Mbps) of each flow

FLOW_NUM = length(flows);
PRIO_NUM = max(prio);

%Events:
ARRIVAL= 0;       % Arrival of a packet
DEPARTURE= 1;     % Departure of a packet

%State variables:
STATE = 0;                          % 0 - connection is free; 1 - connection is occupied
% uma fila por prioridade (alterado em relacao ao Sim2FlowsMP)
QUEUEOCCUPATION= zeros(1,PRIO_NUM); % Occupation of each queue (in Bytes)
QUEUE = cell(1,PRIO_NUM);           % Size, arriving time instant and flowID of each queued packet
queue_count = zeros(1,PRIO_NUM);    % Tracks current number of packets in each queue
for q = 1:PRIO_NUM
    %for optimization purposes I will allocate a maximum of P spaces in each queue
    QUEUE{q} = zeros(P,3);
end

% Initializing the required Statistical Counters:
TOTALPACKETS= zeros(1,FLOW_NUM);     % No. of packets of each flow arrived to the system
LOSTPACKETS= zeros(1,FLOW_NUM);      % No. of packets of each flow lost due to buffer fulness
TRANSPACKETS= zeros(1,FLOW_NUM);     % No. of transmitted packets of each flow
TRANSBYTES= zeros(1,FLOW_NUM);       % Sum of the Bytes of all transmitted packets of each flow
DELAYS= zeros(1,FLOW_NUM);           % Sum of the delays of all transmitted packets of each flow
MAXDELAY= zeros(1,FLOW_NUM);         % Maximum delay among all transmitted packets of each flow

% Initializing the Simulation Clock:
Clock= 0;

% Initializing the List of Events with the first ARRIVAL of each flow:
EventList = zeros(FLOW_NUM, 5);
for k = 1:FLOW_NUM
    tmp = Clock + exprnd(1/lambda(k));
    EventList(k,:) = [ARRIVAL, tmp, GenerateSize(flows{k}), k, tmp];
end

% Simulation loop:
while sum(TRANSPACKETS)<P       % Simulation stopping criterion
    % proximo evento = o de menor instante (mais rapido que o sortrows)
    [~, idx] = min(EventList(:,2));
    Event      = EventList(idx, 1);
    Clock      = EventList(idx, 2);
    PacketSize = EventList(idx, 3);
    Flow       = EventList(idx, 4);
    ArrInstant = EventList(idx, 5);
    EventList(idx, :) = [];

    switch Event
        case ARRIVAL         % If event is an ARRIVAL
            TOTALPACKETS(Flow)= TOTALPACKETS(Flow)+1;
            tmp= Clock + exprnd(1/lambda(Flow));
            nextPacketSize= GenerateSize(flows{Flow});
            EventList = [EventList; ARRIVAL, tmp, nextPacketSize, Flow, tmp];
            if STATE==0
                STATE= 1;
                EventList = [EventList; DEPARTURE, Clock + 8*PacketSize/(C*1e6), PacketSize, Flow, Clock];
            else
                % o pacote vai para a fila da sua prioridade
                q = prio(Flow);
                if QUEUEOCCUPATION(q) + PacketSize <= f(q)
                    queue_count(q) = queue_count(q) + 1;
                    QUEUE{q}(queue_count(q), :) = [PacketSize , Clock, Flow];
                    QUEUEOCCUPATION(q)= QUEUEOCCUPATION(q) + PacketSize;
                else
                    LOSTPACKETS(Flow)= LOSTPACKETS(Flow) + 1;
                end
            end
        case DEPARTURE          % If event is a DEPARTURE
            TRANSBYTES(Flow)= TRANSBYTES(Flow) + PacketSize;
            TRANSPACKETS(Flow)= TRANSPACKETS(Flow) + 1;
            DELAYS(Flow)= DELAYS(Flow) + (Clock - ArrInstant);
            if Clock - ArrInstant > MAXDELAY(Flow)
                MAXDELAY(Flow)= Clock - ArrInstant;
            end
            % o proximo pacote sai da fila de prioridade mais alta nao vazia
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

% Performance parameters determination:
PL= 100*LOSTPACKETS./TOTALPACKETS;  % in percentage
APD= 1000*DELAYS./TRANSPACKETS;     % in milliseconds
MPD= 1000*MAXDELAY;                % in milliseconds
TT= 1e-6*TRANSBYTES*8/Clock;       % in Mbps

end

function out= GenerateSize(flow)
    out= randi([flow(1) flow(length(flow))]);
end
