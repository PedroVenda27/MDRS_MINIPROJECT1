function [PL , APD , MPD , TT] = Sim2Flows_newversion(lambda,C,f,P)
% INPUT PARAMETERS:
%  lambda - row vector with the packet rate of each flow (packets/sec)
%  C      - link bandwidth (Mbps)
%  f      - queue size (Bytes)
%  P      - number of packets (stopping criterium)
% OUTPUT PARAMETERS:
%  PL   - row vector with the packet loss (%) of each flow
%  APD  - row vector with the average packet delay (milliseconds) of each flow
%  MPD  - maximum packet delay (milliseconds) of each flow
%  TT   - transmitted throughput (Mbps) of each flow

%Events:
ARRIVAL= 0;       % Arrival of a packet
DEPARTURE= 1;     % Departure of a packet

%State variables:
STATE = 0;          % 0 - connection is free; 1 - connection is occupied
QUEUEOCCUPATION= 0; % Occupation of the queue (in Bytes)
QUEUE= [];          % Size, arriving time instant and flowID of each packet in the queue

% Initializing the required Statistical Counters:
% ALTERAÇÃO 1: vetores com 3 posições (uma por fluxo) em vez de 2
TOTALPACKETS= zeros(1,3);     % No. of packets of each flow arrived to the system
LOSTPACKETS= zeros(1,3);      % No. of packets of each flow lost due to buffer fulness
TRANSPACKETS= zeros(1,3);     % No. of transmitted packets of each flow
TRANSBYTES= zeros(1,3);       % Sum of the Bytes of all transmitted packets of each flow
DELAYS= zeros(1,3);           % Sum of the delays of all transmitted packets of each flow
MAXDELAY= zeros(1,3);         % Maximum delay among all transmitted packets of each flow

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
% ALTERAÇÃO 2: primeira chegada também para o fluxo 3
tmp= Clock + exprnd(1/lambda(1));
EventList = [ARRIVAL, tmp, GenerateSize(1), 1, tmp];
tmp= Clock + exprnd(1/lambda(2));
EventList = [EventList; ARRIVAL, tmp, GenerateSize(2), 2, tmp];
tmp= Clock + exprnd(1/lambda(3));
EventList = [EventList; ARRIVAL, tmp, GenerateSize(3), 3, tmp];

% Simulation loop:
while sum(TRANSPACKETS)<P       % Simulation stopping criterion
    EventList= sortrows(EventList,2); % Order EventList by 2nd column (the time instant)
    Event= EventList(1,1);            % Get event
    Clock= EventList(1,2);            % Get the time instant of the event
    PacketSize= EventList(1,3);       % Get the packet size of the event
    Flow= EventList(1,4);             % Get the flow ID of the packet
    ArrInstant= EventList(1,5);       % Get the arriving instant of the packet
    EventList(1,:)= [];               % Eliminate first event from the EventList
    switch Event
        case ARRIVAL         % If event is an ARRIVAL
            TOTALPACKETS(Flow)= TOTALPACKETS(Flow)+1;
            tmp= Clock + exprnd(1/lambda(Flow));
            % ALTERAÇÃO 3: o tamanho do próximo pacote depende do fluxo (1, 2 ou 3)
            nextPacketSize= GenerateSize(Flow);
            EventList = [EventList; ARRIVAL, tmp, nextPacketSize, Flow, tmp];
            if STATE==0
                STATE= 1;
                EventList = [EventList; DEPARTURE, Clock + 8*PacketSize/(C*1e6), PacketSize, Flow, Clock];
            else
                if QUEUEOCCUPATION + PacketSize <= f
                    QUEUE= [QUEUE; PacketSize , Clock, Flow];
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
                QUEUE(1,:)= [];
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

% ALTERAÇÃO 4: um único gerador de tamanhos com os 3 fluxos do enunciado
% (todos os valores com igual probabilidade)
function out= GenerateSize(Flow)
    switch Flow
        case 1
            out= randi([100 1500]);   % Flow 1: 100 a 1500 Bytes
        case 2
            out= randi([100 150]);    % Flow 2: 100 a 150 Bytes
        case 3
            out= randi([500 1000]);   % Flow 3: 500 a 1000 Bytes
    end
end
