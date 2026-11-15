# Exercício 1.a — Alterações ao simulador

**Partimos de:** `WORK/Sim2Flows_original.m` (o simulador que nos foi dado, FIFO com 2 fluxos)
**Chegámos a:** `WORK/EXERCICIO 1/Sim2FlowsMP.m` (FIFO com 3 fluxos)

Neste exercício tínhamos de fazer uma nova versão do `Sim2Flows` que suportasse os 3 fluxos do enunciado. O algoritmo continua a ser **FIFO**, com uma única fila para todos os fluxos.

Este simulador é a **base dos exercícios 2 e 3**: o `Sim2FlowsPrioMP` e o `Sim2FlowsDRRMP` foram feitos a partir dele. As alterações descritas aqui (3 fluxos, parâmetro `flows`, `min` em vez de `sortrows`, fila pré-alocada e gerador de tamanhos) já vêm "de fábrica" nesses dois e não se repetem nos documentos deles.

Os números de linha são dos ficheiros como estão agora. No original, a função aparece como `Sim2Flows_original` porque mudámos o nome ao ficheiro; na versão do professor chamava-se `Sim2Flows`.

## Resumo

| # | O que alterámos | Linhas no original | Linhas na nossa versão |
|---|---|---|---|
| 1 | Acrescentámos o parâmetro `flows` | 1 | 1, 7 |
| 2 | Calculamos o número de fluxos a partir dos argumentos | — | 14 |
| 3 | Pré-alocámos a fila | 19–20 | 22–27 |
| 4 | Pusemos os contadores com uma posição por fluxo | 23–28 | 30–35 |
| 5 | Criamos a primeira chegada de cada fluxo num ciclo | 40–44 | 47–54 |
| 6 | Trocámos o `sortrows` por um `min` | 48–54 | 66–73 |
| 7 | Geramos o tamanho do pacote a partir do seu fluxo | 59–63 | 79 |
| 8 | Na chegada, metemos o pacote na fila pré-alocada | 69–74 | 85–92 |
| 9 | Na partida, tiramos o pacote da fila pré-alocada | 83–92 | 101–114 |
| 10 | Simplificámos o gerador de tamanhos | 104–120 | 126–128 |

**O que deixámos como estava**, porque já funcionava para o que precisávamos:
- os eventos `ARRIVAL` e `DEPARTURE`;
- a fila FIFO única, partilhada por todos os fluxos;
- a transmissão imediata quando a ligação está livre (linhas 81–83);
- a atualização dos contadores na partida (linhas 95–100);
- o critério de paragem (linha 57);
- o cálculo de PL, APD, MPD e TT no fim (linhas 119–122).

---

## Detalhe de cada alteração

Clica numa alteração para a abrir.

<details>
<summary><b>1. Parâmetro de entrada flows — linha 1 (original) → linhas 1 e 7 (nossa versão)</b></summary>

**Antes:**
```matlab
function [PL , APD , MPD , TT] = Sim2Flows(lambda,C,f,P)
```

**Depois:**
```matlab
function [PL , APD , MPD , TT] = Sim2FlowsMP(lambda,C,f,P,flows)
% ...
%  flow   - array of bytes
```

**Porquê:** no original, os tamanhos dos pacotes estavam escritos dentro do simulador, em `GenerateSize1` e `GenerateSize2`, e só davam para 2 fluxos. Passámos a dar os tamanhos como argumento: no script fazemos `flows = {100:1500; 100:150; 500:1000}`. Assim o simulador funciona para quantos fluxos quisermos, com os tamanhos que quisermos.

</details>

<details>
<summary><b>2. Número de fluxos — linha nova 14</b></summary>

**Antes:** não havia. O número de fluxos (2) estava escrito diretamente no código.

**Depois:**
```matlab
FLOW_NUM = length(flows);
```

**Porquê:** assim o simulador percebe sozinho quantos fluxos tem (3) e usa esse valor para criar os contadores e as primeiras chegadas com o tamanho certo.

</details>

<details>
<summary><b>3. Fila pré-alocada — linhas 19–20 (original) → linhas 22–27 (nossa versão)</b></summary>

**Antes:**
```matlab
QUEUEOCCUPATION= 0; % Occupation of the queue (in Bytes)
QUEUE= [];          % Size, arriving time instant and flowID of each packet in the queue
```

**Depois:**
```matlab
QUEUEOCCUPATION= 0; % Occupation of the queue (in Bytes)
%for optimization purposes I will allocate a maximum of P spaces in the
%queue
QUEUE = zeros(P,3);
queue_count = 0;     % Tracks current number of packets in queue
```

**Porquê:** é para a simulação correr mais depressa. No original, a fila começava vazia (`[]`) e crescia uma linha de cada vez que chegava um pacote, o que obriga o MATLAB a copiar a matriz toda a cada passo. Criamos logo a fila com P linhas e usamos `queue_count` para saber quantas estão ocupadas.

</details>

<details>
<summary><b>4. Contadores estatísticos — linhas 23–28 (original) → linhas 30–35 (nossa versão)</b></summary>

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

**Porquê:** cada posição destes vetores guarda os valores de um fluxo, e como passámos a ter 3 fluxos precisávamos de 3 posições. Com `FLOW_NUM`, o tamanho acerta-se sozinho.

</details>

<details>
<summary><b>5. Primeira chegada de cada fluxo — linhas 40–44 (original) → linhas 47–54 (nossa versão)</b></summary>

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

**Porquê:** a simulação tem de começar com uma chegada de cada fluxo. O original só criava as dos fluxos 1 e 2, por isso, se não mudássemos isto, o Fluxo 3 nunca chegava a ter pacotes. Com o ciclo, criamos a primeira chegada de todos os fluxos de uma vez.

</details>

<details>
<summary><b>6. Escolha do próximo evento — linhas 48–54 (original) → linhas 66–73 (nossa versão)</b></summary>

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

**Porquê:** também é para a simulação correr mais depressa. O resultado é igual, porque o próximo evento continua a ser o de menor instante, mas assim não ordenamos a lista toda em cada iteração; basta encontrar o mínimo. Juntando com a fila pré-alocada, cada corrida passou de cerca de 3,5 s para cerca de 1,3 s. Faz muita diferença quando cada experiência tem 50 corridas de 100 000 pacotes.

</details>

<details>
<summary><b>7. Tamanho do próximo pacote — linhas 59–63 (original) → linha 79 (nossa versão)</b></summary>

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

**Porquê:** o `if/else` só separava 2 fluxos. Com 3 fluxos, o Fluxo 3 ia cair no `else` e ser tratado como se fosse o Fluxo 2. Agora geramos o tamanho a partir dos tamanhos do próprio fluxo (`flows{Flow}`).

</details>

<details>
<summary><b>8. Chegada com a ligação ocupada — linhas 69–74 (original) → linhas 85–92 (nossa versão)</b></summary>

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
if QUEUEOCCUPATION + PacketSize <= f
    queue_count = queue_count + 1;
    QUEUE(queue_count, :) = [PacketSize , Clock, Flow];
    QUEUEOCCUPATION= QUEUEOCCUPATION + PacketSize;
else
    LOSTPACKETS(Flow)= LOSTPACKETS(Flow) + 1;
end
```

**Porquê:** a lógica é igual (o pacote entra na fila se houver espaço, senão perde-se), mas como a fila agora está pré-alocada, metemos o pacote na primeira posição livre (`queue_count`) em vez de acrescentar uma linha nova.

</details>

<details>
<summary><b>9. Partida: tirar o pacote da fila — linhas 83–92 (original) → linhas 101–114 (nossa versão)</b></summary>

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
if QUEUEOCCUPATION > 0
    QSize= QUEUE(1,1);
    QInstant= QUEUE(1,2);
    QFlow= QUEUE(1,3);
    EventList = [EventList; DEPARTURE, Clock + 8*QSize/(C*1e6), QSize, QFlow, QInstant];
    QUEUEOCCUPATION= QUEUEOCCUPATION - QSize;
    if queue_count > 1
        QUEUE(1:queue_count-1, :) = QUEUE(2:queue_count, :);
    end
    queue_count = queue_count - 1;
else
    STATE= 0;
end
```

**Porquê:** continua a sair sempre o primeiro pacote da fila (FIFO). Como a fila está pré-alocada, em vez de apagar a primeira linha (`QUEUE(1,:)= []`), subimos as linhas seguintes uma posição e diminuímos `queue_count`.

</details>

<details>
<summary><b>10. Gerador de tamanhos — linhas 104–120 (original) → linhas 126–128 (nossa versão)</b></summary>

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

**Porquê:** as duas funções do original tinham as distribuições do exemplo das aulas, que não são as que o enunciado pede. No Mini-Projeto, os 3 fluxos têm todos os tamanhos com a mesma probabilidade:
- Fluxo 1: 100–1500 B;
- Fluxo 2: 100–150 B;
- Fluxo 3: 500–1000 B.

Por isso chegou-nos uma só função, que faz um `randi` entre o tamanho mínimo e o máximo de cada fluxo (Módulo 3, slide 13).

</details>
