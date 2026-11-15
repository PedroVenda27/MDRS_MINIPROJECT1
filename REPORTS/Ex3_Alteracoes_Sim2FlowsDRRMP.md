# Exercício 3.a — Alterações ao simulador

**Partimos de:** `WORK/Sim2Flows_original.m` (o simulador que nos foi dado, FIFO com 2 fluxos)
**Chegámos a:** `WORK/EXERCICIO 3/Sim2FlowsDRRMP.m` (Deficit Round Robin com 3 fluxos)

Neste exercício tínhamos de fazer uma nova versão do simulador com 3 fluxos a usar **Deficit Round Robin (DRR)**. Em cada ronda, os fluxos são servidos **pela ordem do ID** (1, 2, 3).

Os números de linha são dos ficheiros como estão agora. No original, a função aparece como `Sim2Flows_original` porque mudámos o nome ao ficheiro; na versão do professor chamava-se `Sim2Flows`.

## Resumo

| # | O que alterámos | Linhas no original | Linhas na nossa versão |
|---|---|---|---|
| 1 | Acrescentámos os parâmetros `flows` e `Quantum` e passámos `f` a vetor | 1 | 1–8 |
| 2 | Calculamos o número de fluxos a partir dos argumentos | — | 15 |
| 3 | Pusemos uma fila por fluxo, pré-alocada | 19–20 | 23–30 |
| 4 | Criámos a fila final e o crédito de cada fluxo | — | 31–32 |
| 5 | Pusemos os contadores com uma posição por fluxo | 23–28 | 35–40 |
| 6 | Criamos a primeira chegada de cada fluxo num ciclo | 40–44 | 45–50 |
| 7 | Trocámos o `sortrows` por um `min` | 48–54 | 54–61 |
| 8 | Geramos o tamanho do pacote a partir do seu fluxo | 59–63 | 67 |
| 9 | Na chegada, o pacote vai para a fila do seu fluxo | 69–74 | 73–80 |
| 10 | Na partida, fazemos uma ronda DRR quando a fila final está vazia | — | 89–115 |
| 11 | O próximo pacote a transmitir sai da fila final | 83–92 | 116–125 |
| 12 | Simplificámos o gerador de tamanhos | 104–120 | 137–139 |

**O que deixámos como estava**, porque já funcionava para o que precisávamos:
- os eventos `ARRIVAL` e `DEPARTURE` (linhas 18–19);
- a transmissão imediata quando a ligação está livre (linhas 69–71);
- a atualização dos contadores na partida (linhas 83–88);
- o critério de paragem (linha 53);
- o cálculo de PL, APD, MPD e TT no fim (linhas 130–133).

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
function [PL , APD , MPD , TT] = Sim2FlowsDRRMP(lambda,C,f,P,flows,Quantum)
% ...
%  f       - row vector with the queue size (Bytes) of each flow
%  flows   - cell array with the possible packet sizes (Bytes) of each flow
%  Quantum - row vector with the DRR quantum (Bytes) of each flow
```

**Porquê:**
- **`flows`:** tal como no exercício 2, não queríamos ter os tamanhos dos pacotes escritos dentro do simulador, por isso passamo-los como argumento. No script fazemos `flows = {100:1500; 100:150; 500:1000}`.
- **`Quantum`:** no DRR, cada fluxo tem um quantum, que é o número de bytes que pode enviar em cada ronda. Passámo-lo como argumento porque o enunciado pede experiências com quanta diferentes:
  - na 3.b e na 3.c usamos `[1500 1500 1500]`;
  - na 3.d usamos `[1500 1500 4500]`.

  Assim só mudamos o vetor no script, sem mexer no simulador.
- **`f`:** passou de um valor único para um vetor com o tamanho da fila de cada fluxo. O enunciado pedia f₁ = f₂ = f₃ = 1 000 000 Bytes, por isso no script passamos `f = [1e6 1e6 1e6]`.

</details>

<details>
<summary><b>2. Número de fluxos — linha nova 15</b></summary>

**Antes:** não havia. O número de fluxos (2) estava escrito diretamente no código.

**Depois:**
```matlab
FLOW_NUM = length(flows);
```

**Porquê:** assim o simulador percebe sozinho quantos fluxos tem (3). No DRR há uma fila por fluxo, por isso este valor também nos diz quantas filas temos de criar.

</details>

<details>
<summary><b>3. Uma fila por fluxo — linhas 19–20 (original) → linhas 23–30 (nossa versão)</b></summary>

**Antes:**
```matlab
QUEUEOCCUPATION= 0; % Occupation of the queue (in Bytes)
QUEUE= [];          % Size, arriving time instant and flowID of each packet in the queue
```

**Depois:**
```matlab
QUEUEOCCUPATION= zeros(1,FLOW_NUM); % Occupation of each flow queue (in Bytes)
QUEUE = cell(1,FLOW_NUM);           % Size, arriving time instant and flowID of each queued packet
queue_count = zeros(1,FLOW_NUM);    % Tracks current number of packets in each queue
for q = 1:FLOW_NUM
    QUEUE{q} = zeros(P,3);
end
```

**Porquê:**
- **Uma fila por fluxo:** os algoritmos do tipo round robin funcionam com uma fila para cada fluxo (Módulo 4, slide 18). Por isso trocámos a fila única por um cell array: `QUEUE{1}`, `QUEUE{2}` e `QUEUE{3}` são as filas dos Fluxos 1, 2 e 3. Cada uma tem a sua ocupação em `QUEUEOCCUPATION(q)`, para controlarmos o limite de cada fila em separado.
- **Pré-alocação:** criamos cada fila logo com P linhas e usamos `queue_count(q)` para saber quantas estão ocupadas. No original, a fila crescia uma linha de cada vez, o que torna a simulação muito mais lenta.

</details>

<details>
<summary><b>4. Fila final e crédito de cada fluxo — linhas novas 31–32</b></summary>

**Antes:** não existiam.

**Depois:**
```matlab
FINALQUEUE = [];                    % packets selected in the current DRR round
CREDIT = zeros(1,FLOW_NUM);         % DRR credit (deficit counter) of each flow (in Bytes)
```

**Porquê:** são as duas variáveis de que o DRR precisa (Módulo 4, slides 18 e 23):
- **`FINALQUEUE`:** a fila final, onde pomos os pacotes escolhidos em cada ronda. A ligação transmite sempre a partir daqui.
- **`CREDIT`:** o crédito (*deficit counter*) de cada fluxo, em bytes. Em cada ronda, um fluxo recebe o seu quantum de crédito e gasta-o nos pacotes que manda para a fila final. O que sobra fica guardado para a ronda seguinte.

</details>

<details>
<summary><b>5. Contadores estatísticos — linhas 23–28 (original) → linhas 35–40 (nossa versão)</b></summary>

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
<summary><b>6. Primeira chegada de cada fluxo — linhas 40–44 (original) → linhas 45–50 (nossa versão)</b></summary>

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
<summary><b>7. Escolha do próximo evento — linhas 48–54 (original) → linhas 54–61 (nossa versão)</b></summary>

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

**Porquê:** isto é só para a simulação correr mais depressa. O resultado é igual, porque o próximo evento continua a ser o de menor instante, mas assim não ordenamos a lista toda em cada iteração; basta encontrar o mínimo. Com 50 corridas de 100 000 pacotes por experiência, isto poupa bastante tempo (cada corrida demora cerca de 2 s).

</details>

<details>
<summary><b>8. Tamanho do próximo pacote — linhas 59–63 (original) → linha 67 (nossa versão)</b></summary>

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
<summary><b>9. Chegada com a ligação ocupada — linhas 69–74 (original) → linhas 73–80 (nossa versão)</b></summary>

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
if QUEUEOCCUPATION(Flow) + PacketSize <= f(Flow)
    queue_count(Flow) = queue_count(Flow) + 1;
    QUEUE{Flow}(queue_count(Flow), :) = [PacketSize , Clock, Flow];
    QUEUEOCCUPATION(Flow)= QUEUEOCCUPATION(Flow) + PacketSize;
else
    LOSTPACKETS(Flow)= LOSTPACKETS(Flow) + 1;
end
```

**Porquê:**
- O pacote vai para a fila do **seu** fluxo (`QUEUE{Flow}`), e não para uma fila onde estão todos misturados.
- Só se perde o pacote se **a fila do seu fluxo** estiver cheia (`f(Flow)`). Isto é importante no caso D (congestionado): os fluxos que mandam demasiado tráfego enchem a sua própria fila, mas não tiram espaço aos outros. Por exemplo, o Fluxo 2 não perde pacotes mesmo com as filas dos Fluxos 1 e 3 cheias.
- Como a fila está pré-alocada, metemos o pacote na primeira posição livre (`queue_count(Flow)`).

</details>

<details>
<summary><b>10. Ronda DRR — linhas novas 89–115</b></summary>

**Antes:** não existia. No original, quando acabava uma transmissão, passava logo o primeiro pacote da fila única.

**Depois:**
```matlab
while isempty(FINALQUEUE) && any(queue_count > 0)
    for q = 1:FLOW_NUM
        if queue_count(q) > 0
            CREDIT(q) = CREDIT(q) + Quantum(q);
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
            if queue_count(q) == 0
                CREDIT(q) = 0;
            end
        else
            CREDIT(q) = 0;
        end
    end
end
```

**Porquê:** esta é **a alteração mais importante**, porque é aqui que o DRR acontece de facto (Módulo 4, slides 23–24). Quando acaba uma transmissão e a fila final está vazia, começa uma nova ronda. Percorremos os fluxos **pela ordem do ID** (`for q = 1:FLOW_NUM`), como pede o enunciado, e para cada um:
1. **Se a fila tem pacotes,** somamos o quantum ao crédito (`CREDIT(q) + Quantum(q)`).
2. **Escolhemos os pacotes:** enquanto o pacote da cabeça couber no crédito que resta, gastamos o crédito no tamanho desse pacote e passamos para o seguinte. No fim, os `n` pacotes escolhidos vão todos de uma vez para a fila final.
3. **Guardamos o crédito que sobra** para a ronda seguinte. É isto que torna o algoritmo justo em bytes: se um fluxo não conseguiu usar o crédito todo porque o próximo pacote era grande, numa próxima ronda já tem crédito suficiente.
4. **Se a fila ficar vazia** (ou já estiver vazia), o crédito volta a zero. Assim, um fluxo que esteve parado não acumula crédito para depois "atropelar" os outros.

**Outros pormenores:**
- O `while` de fora repete a ronda até haver pelo menos um pacote na fila final. Como usamos quanta de 1500 B ou mais, que é o tamanho máximo dos pacotes, basta sempre uma ronda (Módulo 4, slide 23).
- **Uma decisão nossa:** o espaço de um pacote na fila do fluxo é libertado quando ele passa para a fila final (`QUEUEOCCUPATION(q) - QUEUE{q}(n,1)`). Ou seja, o limite `f` conta só os pacotes que ainda não foram escolhidos por nenhuma ronda.
- Com quanta iguais, cada fluxo pode mandar o mesmo número de bytes por ronda. Com o quantum do Fluxo 3 três vezes maior (3.d), o Fluxo 3 fica com o triplo do peso. É assim que o DRR implementa o max-min fairness ponderado (Módulo 4, slide 23).

</details>

<details>
<summary><b>11. Próximo pacote a transmitir — linhas 83–92 (original) → linhas 116–125 (nossa versão)</b></summary>

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
if ~isempty(FINALQUEUE)
    QSize= FINALQUEUE(1,1);
    QInstant= FINALQUEUE(1,2);
    QFlow= FINALQUEUE(1,3);
    EventList = [EventList; DEPARTURE, Clock + 8*QSize/(C*1e6), QSize, QFlow, QInstant];
    FINALQUEUE(1,:) = [];
else
    STATE= 0;
end
```

**Porquê:**
- No DRR, os pacotes são sempre transmitidos **a partir da fila final**, pela ordem em que lá foram postos na ronda: primeiro os do Fluxo 1, depois os do 2, depois os do 3. Por isso o próximo pacote é sempre o primeiro da `FINALQUEUE`.
- Aqui já não mexemos em `QUEUEOCCUPATION`, porque o espaço na fila do fluxo foi libertado quando o pacote passou para a fila final (alteração 10).
- O algoritmo continua a ser ***work conserving***: a ligação só fica livre (`STATE= 0`) quando a fila final e todas as filas dos fluxos estão vazias, porque a ronda da alteração 10 só deixa a fila final vazia se não houver pacotes em lado nenhum.

</details>

<details>
<summary><b>12. Gerador de tamanhos — linhas 104–120 (original) → linhas 137–139 (nossa versão)</b></summary>

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
