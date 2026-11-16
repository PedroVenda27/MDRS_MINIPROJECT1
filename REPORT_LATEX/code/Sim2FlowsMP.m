function [PL , APD , MPD , TT] = Sim2FlowsMP(lambda,C,f,P,flows)
% INPUT PARAMETERS:
%  lambda - row vector with the packet rate of each flow (packets/sec)
%  C      - link bandwidth (Mbps)
%  f      - queue size (Bytes)
%  P      - number of packets (stopping criterium)
%  flow   - array of bytes
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
STATE = 0;          % 0 - connection is free; 1 - connection is occupied
QUEUEOCCUPATION= 0; % Occupation of the queue (in Bytes)
%for optimization purposes I will allocate a maximum of P spaces in the
%queue
QUEUE = zeros(P,3);
queue_count = 0;     % Tracks current number of packets in queue
%QUEUE= [];          % Size, arriving time instant and flowID of each packet in the queue

% Initializing the required Statistical Counters:
TOTALPACKETS= zeros(1,FLOW_NUM);     % No. of packets of each flow arrived to the system
LOSTPACKETS= zeros(1,FLOW_NUM);      % No. of packets of each flow lost due to buffer fulness
TRANSPACKETS= zeros(1,FLOW_NUM);     % No. of transmitted packets of each flow
TRANSBYTES= zeros(1,FLOW_NUM);       % Sum of the Bytes of all transmitted packets of each flow
DELAYS= zeros(1,FLOW_NUM);           % Sum of the delays of all transmitted packets of each flow
MAXDELAY= zeros(1,FLOW_NUM);         % Maximum delay among all transmitted packets of each flow

% Initializing the Simulation Clock:
Clock= 0;

% Each row of Event List:
% Row 1: Event Type
% Row 2: Time instant of event occurrence
% Row 3: Packet size
% Row 4: Flow ID of the packet
% Row 5: Time instant of the packet arrival to the system
%
% Initializing the List of Events with the first ARRIVAL of each flow:
%EventList = [];
EventList = zeros(FLOW_NUM, 5);
for k = 1:FLOW_NUM
    tmp = Clock + exprnd(1/lambda(k));
    %EventList = [EventList; ARRIVAL, tmp, GenerateSize(flows{k}), k, tmp];
    EventList(k,:) = [ARRIVAL, tmp, GenerateSize(flows{k}), k, tmp];
end

% Simulation loop:
while sum(TRANSPACKETS)<P       % Simulation stopping criterion
    %EventList= sortrows(EventList,2); % Order EventList by 2nd column (the time instant)
    %Event= EventList(1,1);            % Get event 
    %Clock= EventList(1,2);            % Get the time instant of the event 
    %PacketSize= EventList(1,3);       % Get the packet size of the event
    %Flow= EventList(1,4);             % Get the flow ID of the packet
    %ArrInstant= EventList(1,5);       % Get the arriving instant of the packet
    %EventList(1,:)= [];               % Eliminate first event from the EventList

    % more optimization processes the sortrows takes a looong time
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
                if QUEUEOCCUPATION + PacketSize <= f
                    queue_count = queue_count + 1;
                    QUEUE(queue_count, :) = [PacketSize , Clock, Flow];
                    %QUEUE = [QUEUE; PacketSize , Clock, Flow];
                    QUEUEOCCUPATION= QUEUEOCCUPATION + PacketSize;
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
            if QUEUEOCCUPATION > 0
                QSize= QUEUE(1,1);
                QInstant= QUEUE(1,2);
                QFlow= QUEUE(1,3);
                EventList = [EventList; DEPARTURE, Clock + 8*QSize/(C*1e6), QSize, QFlow, QInstant];
                QUEUEOCCUPATION= QUEUEOCCUPATION - QSize;
                %QUEUE(1,:)= [];
                if queue_count > 1
                    QUEUE(1:queue_count-1, :) = QUEUE(2:queue_count, :);
                end
                queue_count = queue_count - 1;
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