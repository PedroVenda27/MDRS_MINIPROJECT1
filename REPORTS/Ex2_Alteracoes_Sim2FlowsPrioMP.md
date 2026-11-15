# Exercício 2.a — Alterações ao simulador

**Partimos de:** `WORK/Sim2Flows_original.m` (o simulador que nos foi dado, FIFO com 2 fluxos)
**Chegámos a:** `WORK/EXERCICIO 2/Sim2FlowsPrioMP.m` (Priority Queuing com 3 fluxos)

Neste exercício tínhamos de fazer uma nova versão do simulador com 3 fluxos. O **Fluxo 3** tem a prioridade mais alta e os **Fluxos 1 e 2** ficam com a segunda prioridade.

Os números de linha são dos ficheiros como estão agora. No original, a função aparece como `Sim2Flows_original` porque mudámos o nome ao ficheiro; na versão do professor chamava-se `Sim2Flows`.

## Resumo

| # | O que alterámos | Linhas no original | Linhas na nossa versão |
|---|---|---|---|
| 1 | Acrescentámos os parâmetros `flows` e `prio` e passámos `f` a vetor | 1 | 1–8 |
| 2 | Calculamos o número de fluxos e de prioridades a partir dos argumentos | — | 15–16 |
| 3 | Pusemos uma fila por prioridade, pré-alocada | 19–20 | 24–31 |
| 4 | Pusemos os contadores com uma posição por fluxo | 23–28 | 34–39 |
| 5 | Criamos a primeira chegada de cada fluxo num ciclo | 40–44 | 44–49 |
| 6 | Trocámos o `sortrows` por um `min` | 48–54 | 53–60 |
| 7 | Geramos o tamanho do pacote a partir do seu fluxo | 59–63 | 66 |
| 8 | Na chegada, o pacote vai para a fila da sua prioridade | 69–74 | 72–80 |
| 9 | Na partida, o próximo pacote sai da fila de prioridade mais alta que não esteja vazia | 83–92 | 89–103 |
| 10 | Simplificámos o gerador de tamanhos | 104–120 | 115–117 |

**O que deixámos como estava**, porque já funcionava para o que precisávamos:
- os eventos `ARRIVAL` e `DEPARTURE` (linhas 19–20);
- a transmissão imediata quando a ligação está livre (linhas 68–70);
- a atualização dos contadores na partida (linhas 83–88);
- o critério de paragem (linha 52);
- o cálculo de PL, APD, MPD e TT no fim (linhas 108–111).

---

## Detalhe de cada alteração

Clica numa alteração para a abrir.

<details>
<summary><b>1. Parâmetros de entrada — linha 1 (original) → linhas 1–8 (nossa versão)</b></summary>

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

**Porquê:**
- **`flows`:** não queríamos ter os tamanhos dos pacotes escritos dentro do simulador, por isso passamo-los como argumento. No script fazemos `flows = {100:1500; 100:150; 500:1000}`. Assim, o simulador funciona para quantos fluxos quisermos.
- **`prio`:** criámos este vetor para dizer qual a prioridade de cada fluxo. No script usamos `prio = [2 2 1]`: o Fluxo 3 vai para a fila 1 (prioridade alta) e os Fluxos 1 e 2 vão para a fila 2. Se quisermos trocar as prioridades, basta mudar o vetor, sem mexer no simulador.
- **`f`:** passou de um valor único para um vetor com um tamanho para cada fila. O enunciado pedia f₁ = f₂ = 1 000 000 Bytes, por isso no script passamos `f = [1e6 1e6]`.

</details>

<details>
<summary><b>2. Número de fluxos e de prioridades — linhas novas 15–16</b></summary>

**Antes:** não havia nada disto. O número de fluxos (2) estava escrito diretamente no código.

**Depois:**
```matlab
FLOW_NUM = length(flows);
PRIO_NUM = max(prio);
```

**Porquê:** assim o simulador percebe sozinho quantos fluxos tem (3) e quantas filas de prioridade são precisas (2). Usamos estes valores mais à frente para criar as filas e os contadores com o tamanho certo.

</details>

<details>
<summary><b>3. Uma fila por prioridade — linhas 19–20 (original) → linhas 24–31 (nossa versão)</b></summary>

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

**Porquê:**
- **Uma fila por prioridade:** o Priority Queuing funciona com uma fila por prioridade (Módulo 4, slide 6). Por isso trocámos a fila única por um cell array:
  - `QUEUE{1}`: fila de prioridade alta (Fluxo 3);
  - `QUEUE{2}`: fila de prioridade baixa (Fluxos 1 e 2).

  Cada fila tem a sua ocupação em `QUEUEOCCUPATION(q)`, para controlarmos o limite de cada uma em separado.
- **Pré-alocação:** criamos cada fila logo com P linhas e usamos `queue_count(q)` para saber quantas estão ocupadas. No original, a fila crescia uma linha de cada vez (`QUEUE= [QUEUE; ...]`), o que torna a simulação bem mais lenta.

</details>

<details>
<summary><b>4. Contadores estatísticos — linhas 23–28 (original) → linhas 34–39 (nossa versão)</b></summary>

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

**Porquê:** cada posição destes vetores guarda os valores de um fluxo, e como passámos a ter 3 fluxos precisávamos de 3 posições. Com `FLOW_NUM`, o tamanho acerta-se sozinho e não temos de mudar nada se o número de fluxos mudar.

</details>

<details>
<summary><b>5. Primeira chegada de cada fluxo — linhas 40–44 (original) → linhas 44–49 (nossa versão)</b></summary>

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
<summary><b>6. Escolha do próximo evento — linhas 48–54 (original) → linhas 53–60 (nossa versão)</b></summary>

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

**Porquê:** isto é só para a simulação correr mais depressa. O resultado é igual, porque o próximo evento continua a ser o de menor instante, mas assim não ordenamos a lista toda em cada iteração; basta encontrar o mínimo. Cada corrida passou de cerca de 3,5 s para cerca de 1,3 s, e isso nota-se bastante quando temos de fazer 50 corridas de 100 000 pacotes por experiência.

</details>

<details>
<summary><b>7. Tamanho do próximo pacote — linhas 59–63 (original) → linha 66 (nossa versão)</b></summary>

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

**Porquê:** o `if/else` só separava 2 fluxos. Com 3 fluxos, o Fluxo 3 ia cair no `else` e ser tratado como se fosse o Fluxo 2. Agora geramos o tamanho a partir dos tamanhos do próprio fluxo (`flows{Flow}`), por isso funciona com qualquer número de fluxos.

</details>

<details>
<summary><b>8. Chegada com a ligação ocupada — linhas 69–74 (original) → linhas 72–80 (nossa versão)</b></summary>

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

**Porquê:**
- Com `q = prio(Flow)`, o pacote vai para a fila da **sua** prioridade, e não para uma fila onde estão todos misturados.
- Só se perde o pacote se **essa** fila estiver cheia (`f(q)`). Assim, os Fluxos 1 e 2 nunca ocupam espaço na fila do Fluxo 3, nem o contrário.
- Como a fila está pré-alocada, metemos o pacote na primeira posição livre (`queue_count(q)`).

</details>

<details>
<summary><b>9. Escolha do próximo pacote a transmitir — linhas 83–92 (original) → linhas 89–103 (nossa versão)</b></summary>

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

**Porquê:** esta é **a alteração mais importante**, porque é aqui que o Priority Queuing acontece de facto.
- `find(queue_count > 0, 1)` dá-nos a **primeira fila que não está vazia**: se a fila 1 (prioridade alta) tiver pacotes, sai dela; se não, sai da fila 2. Ou seja, um pacote dos Fluxos 1 ou 2 só é transmitido quando não há pacotes do Fluxo 3 à espera.
- Dentro de cada fila sai sempre o primeiro pacote (`QUEUE{q}(1,:)`), por isso, dentro da mesma prioridade, a ordem continua a ser FIFO.
- O algoritmo é **não preemptivo**: só escolhemos o próximo pacote quando a transmissão anterior acaba, e um pacote que já está a ser transmitido nunca é interrompido.
- Também é ***work conserving*** (Módulo 4, slide 4): a ligação só fica livre (`STATE= 0`) quando as duas filas estão vazias.
- Como a fila está pré-alocada, para tirar o primeiro pacote subimos as linhas de baixo uma posição e diminuímos `queue_count(q)`, em vez de apagar a linha com `QUEUE(1,:)= []`, como estava no original.

</details>

<details>
<summary><b>10. Gerador de tamanhos — linhas 104–120 (original) → linhas 115–117 (nossa versão)</b></summary>

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
