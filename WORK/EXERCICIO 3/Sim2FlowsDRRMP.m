function [PL , APD , MPD , TT] = Sim2FlowsDRRMP(lambda,C,f,P,flows,Quantum)
% INPUT PARAMETERS:
%  lambda  - row vector with the packet rate of each flow (packets/sec)
%  C       - link bandwidth (Mbps)
%  f       - row vector with the queue size (Bytes) of each flow
%  P       - number of packets (stopping criterium)
%  flows   - cell array with the possible packet sizes (Bytes) of each flow
%  Quantum - row vector with the DRR quantum (Bytes) of each flow
% OUTPUT PARAMETERS:
%  PL   - row vector with the packet loss (%) of each flow
%  APD  - row vector with the average packet delay (milliseconds) of each flow
%  MPD  - maximum packet delay (milliseconds) of each flow
%  TT   - transmitted throughput (Mbps) of each flow

FLOW_NUM = length(flows);

%Events:
ARRIVAL= 0;       % Arrival of a packet
DEPARTURE= 1;     % Departure of a packet

%State variables:
STATE = 0;                          % 0 - connection is free; 1 - connection is occupied
% one queue per flow
QUEUEOCCUPATION= zeros(1,FLOW_NUM); % Occupation of each flow queue (in Bytes)
QUEUE = cell(1,FLOW_NUM);           % Size, arriving time instant and flowID of each queued packet
queue_count = zeros(1,FLOW_NUM);    % Tracks current number of packets in each queue
for q = 1:FLOW_NUM
    %allocate a maximum of P spaces in each queue
    QUEUE{q} = zeros(P,3);
end
FINALQUEUE = [];                    % packets selected in the current DRR round
CREDIT = zeros(1,FLOW_NUM);         % DRR credit (deficit counter) of each flow (in Bytes)

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
while sum(TRANSPACKETS)<P       
    [~, idx] = min(EventList(:,2));
    Event      = EventList(idx, 1);
    Clock      = EventList(idx, 2);
    PacketSize = EventList(idx, 3);
    Flow       = EventList(idx, 4);
    ArrInstant = EventList(idx, 5);
    EventList(idx, :) = [];

    switch Event
        case ARRIVAL
            TOTALPACKETS(Flow)= TOTALPACKETS(Flow)+1;
            tmp= Clock + exprnd(1/lambda(Flow));
            nextPacketSize= GenerateSize(flows{Flow});
            EventList = [EventList; ARRIVAL, tmp, nextPacketSize, Flow, tmp];
            if STATE==0
                STATE= 1;
                EventList = [EventList; DEPARTURE, Clock + 8*PacketSize/(C*1e6), PacketSize, Flow, Clock];
            else
                % the packet goes to its flow queue
                if QUEUEOCCUPATION(Flow) + PacketSize <= f(Flow)
                    queue_count(Flow) = queue_count(Flow) + 1;
                    QUEUE{Flow}(queue_count(Flow), :) = [PacketSize , Clock, Flow];
                    QUEUEOCCUPATION(Flow)= QUEUEOCCUPATION(Flow) + PacketSize;
                else
                    LOSTPACKETS(Flow)= LOSTPACKETS(Flow) + 1;
                end
            end
        case DEPARTURE
            TRANSBYTES(Flow)= TRANSBYTES(Flow) + PacketSize;
            TRANSPACKETS(Flow)= TRANSPACKETS(Flow) + 1;
            DELAYS(Flow)= DELAYS(Flow) + (Clock - ArrInstant);
            if Clock - ArrInstant > MAXDELAY(Flow)
                MAXDELAY(Flow)= Clock - ArrInstant;
            end
            % if the final queue is empty and there are waiting packets, a
            % new DRR round starts
            while isempty(FINALQUEUE) && any(queue_count > 0)
                for q = 1:FLOW_NUM
                    if queue_count(q) > 0
                        CREDIT(q) = CREDIT(q) + Quantum(q);
                        % moves packets which dont go over the credit
                        n = 0;
                        while n < queue_count(q) && QUEUE{q}(n+1,1) <= CREDIT(q)
                            n = n + 1;
                            CREDIT(q) = CREDIT(q) - QUEUE{q}(n,1);
                            QUEUEOCCUPATION(q) = QUEUEOCCUPATION(q) - QUEUE{q}(n,1);
                        end
                        if n > 0
                            FINALQUEUE = [FINALQUEUE; QUEUE{q}(1:n,:)];
                            QUEUE{q}(1:queue_count(q)-n, :) = QUEUE{q}(n+1:queue_count(q), :);
                            queue_count(q) = queue_count(q) - n;
                        end
                        % the empty queue loses the credit
                        if queue_count(q) == 0
                            CREDIT(q) = 0;
                        end
                    else
                        CREDIT(q) = 0;
                    end
                end
            end
            if ~isempty(FINALQUEUE)
                QSize= FINALQUEUE(1,1);
                QInstant= FINALQUEUE(1,2);
                QFlow= FINALQUEUE(1,3);
                EventList = [EventList; DEPARTURE, Clock + 8*QSize/(C*1e6), QSize, QFlow, QInstant];
                FINALQUEUE(1,:) = [];
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
