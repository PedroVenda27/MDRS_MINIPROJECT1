# Exercício 2.a — Alterações ao simulador

**De:** `WORK/Sim2Flows_original.m` (simulador fornecido, FIFO, 2 fluxos)
**Para:** `WORK/EXERCICIO 2/Sim2FlowsPrioMP.m` (Priority Queuing, 3 fluxos)

O enunciado pede uma nova versão do simulador com 3 fluxos. O **Fluxo 3** tem a prioridade mais alta e os **Fluxos 1 e 2** têm a segunda prioridade mais alta.

Os números de linha referem-se aos ficheiros atuais. No original, a função chama-se `Sim2Flows_original` porque o ficheiro foi renomeado; no professor chamava-se `Sim2Flows`.

## Resumo

| # | Alteração | Linhas no original | Linhas no novo |
|---|---|---|---|
| 1 | Novos parâmetros de entrada `flows` e `prio`; `f` passa a vetor | 1 | 1–8 |
| 2 | Número de fluxos e de prioridades calculado a partir dos argumentos | — | 15–16 |
| 3 | Uma fila por prioridade, pré-alocada | 19–20 | 24–31 |
| 4 | Contadores estatísticos com uma posição por fluxo | 23–28 | 34–39 |
| 5 | Primeira chegada de cada fluxo criada num ciclo | 40–44 | 44–49 |
| 6 | Próximo evento escolhido com `min` em vez de `sortrows` | 48–54 | 53–60 |
| 7 | Tamanho do próximo pacote gerado a partir do seu fluxo | 59–63 | 66 |
| 8 | Chegada: o pacote vai para a fila da sua prioridade | 69–74 | 72–80 |
| 9 | Partida: o próximo pacote sai da fila de prioridade mais alta não vazia | 83–92 | 89–103 |
| 10 | Gerador de tamanhos genérico | 104–120 | 115–117 |

**O que não mudou:**
- os eventos `ARRIVAL` e `DEPARTURE` (linhas 19–20);
- a transmissão imediata quando a ligação está livre (linhas 68–70);
- a atualização dos contadores na partida (linhas 83–88);
- o critério de paragem (linha 52);
- o cálculo de PL, APD, MPD e TT (linhas 108–111).

---

## 1. Parâmetros de entrada — linha 1 (original) → linhas 1–8 (novo)

**Antes:**
```matlab
function [PL , APD , MPD , TT] = Sim2Flows(lambda,C,f,P)
```

**Depois:**
```matlab
function [PL , APD , MPD , TT] = Sim2FlowsPrioMP(lambda,C,f,P,flows,prio)
% ...
%  f      - row vector with the size (Bytes) of each priority queue
%  flows  - cell array with the possible packet sizes (Bytes) of each flow
%  prio   - row vector with the priority of each flow (1 - highest)
```

**Propósito:**
- **`flows`:** os tamanhos dos pacotes de cada fluxo deixam de estar fixos dentro do simulador. O script passa `flows = {100:1500; 100:150; 500:1000}`, e o simulador funciona para qualquer número de fluxos.
- **`prio`:** indica a prioridade de cada fluxo. O script passa `prio = [2 2 1]`: o Fluxo 3 fica na fila 1 (prioridade alta) e os Fluxos 1 e 2 na fila 2. As prioridades podem mudar sem alterar o simulador.
- **`f`:** passa de um único valor para um vetor, com um tamanho por fila. O enunciado pede f₁ = f₂ = 1 000 000 Bytes, e o script passa `f = [1e6 1e6]`.

---

## 2. Número de fluxos e de prioridades — novas linhas 15–16

**Antes:** não existia. O número de fluxos (2) estava escrito diretamente no código.

**Depois:**
```matlab
FLOW_NUM = length(flows);
PRIO_NUM = max(prio);
```

**Propósito:** o simulador descobre quantos fluxos (3) e quantas filas de prioridade (2) tem a partir dos argumentos. Estes valores são usados para dimensionar as filas e os contadores.

---

## 3. Uma fila por prioridade — linhas 19–20 (original) → linhas 24–31 (novo)

**Antes:**
```matlab
QUEUEOCCUPATION= 0; % Occupation of the queue (in Bytes)
QUEUE= [];          % Size, arriving time instant and flowID of each packet in the queue
```

**Depois:**
```matlab
QUEUEOCCUPATION= zeros(1,PRIO_NUM); % Occupation of each queue (in Bytes)
QUEUE = cell(1,PRIO_NUM);           % Size, arriving time instant and flowID of each queued packet
queue_count = zeros(1,PRIO_NUM);    % Tracks current number of packets in each queue
for q = 1:PRIO_NUM
    QUEUE{q} = zeros(P,3);
end
```

**Propósito:**
- **Uma fila por prioridade:** o Priority Queuing tem uma fila por prioridade (Módulo 4, slide 6). `QUEUE{1}` é a fila de prioridade alta (Fluxo 3) e `QUEUE{2}` a de prioridade baixa (Fluxos 1 e 2). Cada fila tem a sua ocupação, em `QUEUEOCCUPATION(q)`, para controlar o seu limite de tamanho.
- **Pré-alocação:** cada fila é criada logo com P linhas, e `queue_count(q)` diz quantas estão ocupadas. Isto evita aumentar a matriz linha a linha, como fazia `QUEUE= [QUEUE; ...]` no original, o que torna a simulação mais rápida.

---

## 4. Contadores estatísticos — linhas 23–28 (original) → linhas 34–39 (novo)

**Antes:**
```matlab
TOTALPACKETS= zeros(1,2);
LOSTPACKETS= zeros(1,2);
TRANSPACKETS= zeros(1,2);
TRANSBYTES= zeros(1,2);
DELAYS= zeros(1,2);
MAXDELAY= zeros(1,2);
```

**Depois:**
```matlab
TOTALPACKETS= zeros(1,FLOW_NUM);
LOSTPACKETS= zeros(1,FLOW_NUM);
TRANSPACKETS= zeros(1,FLOW_NUM);
TRANSBYTES= zeros(1,FLOW_NUM);
DELAYS= zeros(1,FLOW_NUM);
MAXDELAY= zeros(1,FLOW_NUM);
```

**Propósito:** cada posição guarda os valores de um fluxo. Com 3 fluxos são precisas 3 posições. Com `FLOW_NUM`, o tamanho ajusta-se sozinho ao número de fluxos.

---

## 5. Primeira chegada de cada fluxo — linhas 40–44 (original) → linhas 44–49 (novo)

**Antes:**
```matlab
tmp= Clock + exprnd(1/lambda(1));
EventList = [ARRIVAL, tmp, GenerateSize1(), 1, tmp];
tmp= Clock + exprnd(1/lambda(2));
EventList = [EventList; ARRIVAL, tmp, GenerateSize2(), 2, tmp];
```

**Depois:**
```matlab
EventList = zeros(FLOW_NUM, 5);
for k = 1:FLOW_NUM
    tmp = Clock + exprnd(1/lambda(k));
    EventList(k,:) = [ARRIVAL, tmp, GenerateSize(flows{k}), k, tmp];
end
```

**Propósito:** a simulação começa com uma chegada de cada fluxo. O original só criava as chegadas dos fluxos 1 e 2; sem esta alteração, o Fluxo 3 nunca teria pacotes. O ciclo cria a primeira chegada de todos os fluxos.

---

## 6. Escolha do próximo evento — linhas 48–54 (original) → linhas 53–60 (novo)

**Antes:**
```matlab
EventList= sortrows(EventList,2);
Event= EventList(1,1);
Clock= EventList(1,2);
PacketSize= EventList(1,3);
Flow= EventList(1,4);
ArrInstant= EventList(1,5);
EventList(1,:)= [];
```

**Depois:**
```matlab
[~, idx] = min(EventList(:,2));
Event      = EventList(idx, 1);
Clock      = EventList(idx, 2);
PacketSize = EventList(idx, 3);
Flow       = EventList(idx, 4);
ArrInstant = EventList(idx, 5);
EventList(idx, :) = [];
```

**Propósito:** é uma otimização. O resultado é o mesmo (o próximo evento é sempre o de menor instante), mas não é preciso ordenar a lista toda em cada iteração; basta encontrar o mínimo. Cada corrida passa de cerca de 3,5 s para cerca de 1,3 s, o que conta quando cada experiência tem 50 corridas de 100 000 pacotes.

---

## 7. Tamanho do próximo pacote — linhas 59–63 (original) → linha 66 (novo)

**Antes:**
```matlab
if Flow==1
    nextPacketSize= GenerateSize1();
else
    nextPacketSize= GenerateSize2();
end
```

**Depois:**
```matlab
nextPacketSize= GenerateSize(flows{Flow});
```

**Propósito:** o `if/else` só distinguia 2 fluxos. Com 3 fluxos, o Fluxo 3 seria tratado como o Fluxo 2. Agora o tamanho é gerado a partir dos tamanhos do próprio fluxo (`flows{Flow}`), seja qual for o número de fluxos.

---

## 8. Chegada com a ligação ocupada — linhas 69–74 (original) → linhas 72–80 (novo)

**Antes:**
```matlab
if QUEUEOCCUPATION + PacketSize <= f
    QUEUE= [QUEUE; PacketSize , Clock, Flow];
    QUEUEOCCUPATION= QUEUEOCCUPATION + PacketSize;
else
    LOSTPACKETS(Flow)= LOSTPACKETS(Flow) + 1;
end
```

**Depois:**
```matlab
q = prio(Flow);
if QUEUEOCCUPATION(q) + PacketSize <= f(q)
    queue_count(q) = queue_count(q) + 1;
    QUEUE{q}(queue_count(q), :) = [PacketSize , Clock, Flow];
    QUEUEOCCUPATION(q)= QUEUEOCCUPATION(q) + PacketSize;
else
    LOSTPACKETS(Flow)= LOSTPACKETS(Flow) + 1;
end
```

**Propósito:**
- O pacote vai para a fila da **sua** prioridade (`q = prio(Flow)`), e não para uma fila partilhada por todos.
- Só é perdido se **essa** fila não tiver espaço (`f(q)`). Os Fluxos 1 e 2 nunca ocupam espaço na fila do Fluxo 3, e vice-versa.
- O pacote é colocado na primeira posição livre da fila pré-alocada (`queue_count(q)`).

---

## 9. Escolha do próximo pacote a transmitir — linhas 83–92 (original) → linhas 89–103 (novo)

**Antes:**
```matlab
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
```

**Depois:**
```matlab
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
```

**Propósito:** é **a alteração principal**, a que implementa o Priority Queuing.
- `find(queue_count > 0, 1)` devolve a **primeira fila não vazia**: a fila 1 (prioridade alta) se tiver pacotes; senão, a fila 2. Assim, um pacote dos Fluxos 1 e 2 só é transmitido quando não há pacotes do Fluxo 3 à espera.
- Dentro de cada fila, sai sempre o primeiro pacote (`QUEUE{q}(1,:)`), por isso a ordem dentro de cada prioridade continua a ser FIFO.
- O algoritmo é **não preemptivo**: a escolha só é feita no fim de cada transmissão, e um pacote que já está a ser transmitido nunca é interrompido.
- O algoritmo é ***work conserving*** (Módulo 4, slide 4): a ligação só fica livre (`STATE= 0`) quando as duas filas estão vazias.
- Com a fila pré-alocada, retirar o primeiro pacote faz-se a subir as linhas seguintes e a decrementar `queue_count(q)`, em vez de apagar a linha com `QUEUE(1,:)= []`.

---

## 10. Gerador de tamanhos — linhas 104–120 (original) → linhas 115–117 (novo)

**Antes:**
```matlab
function out= GenerateSize1()
    aux= rand();
    aux2= [65:109 111:1517];
    if aux <= 0.19
        out= 64;
    elseif aux <= 0.19 + 0.23
        out= 110;
    elseif aux <= 0.19 + 0.23 + 0.17
        out= 1518;
    else
        out = aux2(randi(length(aux2)));
    end
end

function out= GenerateSize2()
    out= randi([110 130]);
end
```

**Depois:**
```matlab
function out= GenerateSize(flow)
    out= randi([flow(1) flow(length(flow))]);
end
```

**Propósito:** as duas funções do original tinham as distribuições do exemplo das aulas, que não são as do enunciado. No Mini-Projeto, os 3 fluxos têm todos os tamanhos com igual probabilidade:
- Fluxo 1: 100–1500 B;
- Fluxo 2: 100–150 B;
- Fluxo 3: 500–1000 B.

Por isso basta uma única função: um `randi` entre o tamanho mínimo e o máximo do vetor de tamanhos do fluxo (Módulo 3, slide 13).
