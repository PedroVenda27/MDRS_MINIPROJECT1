# Exercício 2.a — Alterações ao simulador

**Partimos de:** `WORK/EXERCICIO 1/Sim2FlowsMP.m` (o nosso simulador do exercício 1, FIFO com 3 fluxos)
**Chegámos a:** `WORK/EXERCICIO 2/Sim2FlowsPrioMP.m` (Priority Queuing com 3 fluxos)

Neste exercício tínhamos de fazer um simulador com 3 fluxos em que o **Fluxo 3** tem a prioridade mais alta e os **Fluxos 1 e 2** ficam com a segunda prioridade.

**Porque partimos do exercício 1:** o enunciado fala numa nova versão do `Sim2FlowsPrio` da Prática 2. Nós decidimos partir do `Sim2FlowsMP`, porque já tinha tudo o que era preciso para os 3 fluxos:
- o parâmetro `flows`;
- os contadores com uma posição por fluxo;
- a primeira chegada de cada fluxo;
- o `min` em vez do `sortrows`;
- a fila pré-alocada;
- o gerador de tamanhos.

Essas alterações estão explicadas no documento do exercício 1 ([Ex1_Alteracoes_Sim2FlowsMP.md](Ex1_Alteracoes_Sim2FlowsMP.md)). Aqui só descrevemos **o que mudámos para ter prioridades**.

Os números de linha são dos ficheiros como estão agora.

## Resumo

| # | O que alterámos | Linhas no Sim2FlowsMP | Linhas na nossa versão |
|---|---|---|---|
| 1 | Acrescentámos o parâmetro `prio` e passámos `f` a vetor | 1–7 | 1–8 |
| 2 | Calculamos o número de prioridades | — | 16 |
| 3 | Trocámos a fila única por uma fila por prioridade | 22–27 | 24–31 |
| 4 | Na chegada, o pacote vai para a fila da sua prioridade | 85–92 | 72–80 |
| 5 | Na partida, o próximo pacote sai da fila de prioridade mais alta que não esteja vazia | 101–114 | 89–103 |

**O que deixámos igual ao `Sim2FlowsMP`:**
- os eventos e a lista de eventos;
- os contadores estatísticos (linhas 34–39);
- a primeira chegada de cada fluxo (linhas 44–49);
- a escolha do próximo evento com `min` (linhas 53–60);
- a geração do tamanho do pacote (linha 66);
- a transmissão imediata quando a ligação está livre (linhas 68–70);
- a atualização dos contadores na partida (linhas 83–88);
- o critério de paragem (linha 52);
- o cálculo de PL, APD, MPD e TT (linhas 108–111);
- o `GenerateSize` (linhas 115–117).

---

## Detalhe de cada alteração

Clica numa alteração para a abrir.

<details>
<summary><b>1. Parâmetros de entrada — linhas 1–7 (Sim2FlowsMP) → linhas 1–8 (nossa versão)</b></summary>

**Antes:**
```matlab
function [PL , APD , MPD , TT] = Sim2FlowsMP(lambda,C,f,P,flows)
% ...
%  f      - queue size (Bytes)
```

**Depois:**
```matlab
function [PL , APD , MPD , TT] = Sim2FlowsPrioMP(lambda,C,f,P,flows,prio)
% ...
%  f      - tamanho de cada fila de prioridade (Bytes)
%  prio   - prioridade de cada fluxo (1 = alta)
```

**Porquê:**
- **`prio`:** criámos este vetor para dizer qual a prioridade de cada fluxo. No script usamos `prio = [2 2 1]`: o Fluxo 3 vai para a fila 1 (prioridade alta) e os Fluxos 1 e 2 vão para a fila 2. Se quisermos trocar as prioridades, basta mudar o vetor, sem mexer no simulador.
- **`f`:** passou de um valor único para um vetor com um tamanho para cada fila de prioridade. O enunciado pedia f₁ = f₂ = 1 000 000 Bytes, por isso no script passamos `f = [1e6 1e6]`.

</details>

<details>
<summary><b>2. Número de prioridades — linha nova 16</b></summary>

**Antes:** não existia. O `Sim2FlowsMP` só tinha `FLOW_NUM`, porque havia uma única fila.

**Depois:**
```matlab
PRIO_NUM = max(prio);
```

**Porquê:** assim o simulador percebe sozinho quantas filas de prioridade precisa de criar (2, porque as prioridades vão de 1 a 2).

</details>

<details>
<summary><b>3. Uma fila por prioridade — linhas 22–27 (Sim2FlowsMP) → linhas 24–31 (nossa versão)</b></summary>

**Antes:**
```matlab
QUEUEOCCUPATION= 0; % Occupation of the queue (in Bytes)
QUEUE = zeros(P,3);
queue_count = 0;     % Tracks current number of packets in queue
```

**Depois:**
```matlab
QUEUEOCCUPATION= zeros(1,PRIO_NUM);   % ocupação de cada fila (Bytes)
QUEUE = cell(1,PRIO_NUM);   % tamanho, instante de chegada e fluxo
queue_count = zeros(1,PRIO_NUM);   % nº de pacotes em cada fila
for q = 1:PRIO_NUM
    QUEUE{q} = zeros(P,3);
end
```

**Porquê:** o Priority Queuing funciona com uma fila por prioridade (Módulo 4, slide 6). Por isso trocámos a fila única por um cell array:
- `QUEUE{1}`: fila de prioridade alta (Fluxo 3);
- `QUEUE{2}`: fila de prioridade baixa (Fluxos 1 e 2).

A ocupação (`QUEUEOCCUPATION`) e o contador de pacotes (`queue_count`) passaram a vetores, com um valor por fila, para controlarmos cada fila em separado. Mantivemos a pré-alocação do exercício 1: cada fila é criada logo com P linhas.

</details>

<details>
<summary><b>4. Chegada com a ligação ocupada — linhas 85–92 (Sim2FlowsMP) → linhas 72–80 (nossa versão)</b></summary>

**Antes:**
```matlab
if QUEUEOCCUPATION + PacketSize <= f
    queue_count = queue_count + 1;
    QUEUE(queue_count, :) = [PacketSize , Clock, Flow];
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
- Com `q = prio(Flow)`, o pacote vai para a fila da **sua** prioridade, e não para a fila única onde estavam todos misturados.
- Só se perde o pacote se **essa** fila estiver cheia (`f(q)`). Assim, os Fluxos 1 e 2 nunca ocupam espaço na fila do Fluxo 3, nem o contrário.

</details>

<details>
<summary><b>5. Escolha do próximo pacote a transmitir — linhas 101–114 (Sim2FlowsMP) → linhas 89–103 (nossa versão)</b></summary>

**Antes:**
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
- Dentro de cada fila sai sempre o primeiro pacote (`QUEUE{q}(1,:)`), por isso, dentro da mesma prioridade, a ordem continua a ser FIFO, como no exercício 1.
- O algoritmo é **não preemptivo**: só escolhemos o próximo pacote quando a transmissão anterior acaba, e um pacote que já está a ser transmitido nunca é interrompido.
- Também é ***work conserving*** (Módulo 4, slide 4): a ligação só fica livre (`STATE= 0`) quando as duas filas estão vazias.

</details>
