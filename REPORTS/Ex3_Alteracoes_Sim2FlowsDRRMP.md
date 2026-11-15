# Exercício 3.a — Alterações ao simulador

**Partimos de:** `WORK/EXERCICIO 1/Sim2FlowsMP.m` (o nosso simulador do exercício 1, FIFO com 3 fluxos)
**Chegámos a:** `WORK/EXERCICIO 3/Sim2FlowsDRRMP.m` (Deficit Round Robin com 3 fluxos)

Neste exercício tínhamos de fazer um simulador com 3 fluxos a usar **Deficit Round Robin (DRR)**. Em cada ronda, os fluxos são servidos **pela ordem do ID** (1, 2, 3).

**Porque partimos do exercício 1:** o enunciado fala numa nova versão do `Sim2FlowsDRR` da Prática 2. Nós decidimos partir do `Sim2FlowsMP`, porque já tinha tudo o que era preciso para os 3 fluxos:
- o parâmetro `flows`;
- os contadores com uma posição por fluxo;
- a primeira chegada de cada fluxo;
- o `min` em vez do `sortrows`;
- a fila pré-alocada;
- o gerador de tamanhos.

Essas alterações estão explicadas no documento do exercício 1 ([Ex1_Alteracoes_Sim2FlowsMP.md](Ex1_Alteracoes_Sim2FlowsMP.md)). Aqui só descrevemos **o que mudámos para ter DRR**.

Os números de linha são dos ficheiros como estão agora.

## Resumo

| # | O que alterámos | Linhas no Sim2FlowsMP | Linhas na nossa versão |
|---|---|---|---|
| 1 | Acrescentámos o parâmetro `Quantum` e passámos `f` a vetor | 1–7 | 1–8 |
| 2 | Trocámos a fila única por uma fila por fluxo | 22–27 | 23–30 |
| 3 | Criámos a fila final e o crédito de cada fluxo | — | 31–32 |
| 4 | Na chegada, o pacote vai para a fila do seu fluxo | 85–92 | 73–80 |
| 5 | Na partida, fazemos uma ronda DRR quando a fila final está vazia | — | 89–115 |
| 6 | O próximo pacote a transmitir sai da fila final | 101–114 | 116–125 |

**O que deixámos igual ao `Sim2FlowsMP`:**
- os eventos e a lista de eventos;
- o `FLOW_NUM` (linha 15);
- os contadores estatísticos (linhas 35–40);
- a primeira chegada de cada fluxo (linhas 45–50);
- a escolha do próximo evento com `min` (linhas 54–61);
- a geração do tamanho do pacote (linha 67);
- a transmissão imediata quando a ligação está livre (linhas 69–71);
- a atualização dos contadores na partida (linhas 83–88);
- o critério de paragem (linha 53);
- o cálculo de PL, APD, MPD e TT (linhas 130–133);
- o `GenerateSize` (linhas 137–139).

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
function [PL , APD , MPD , TT] = Sim2FlowsDRRMP(lambda,C,f,P,flows,Quantum)
% ...
%  f       - row vector with the queue size (Bytes) of each flow
%  Quantum - row vector with the DRR quantum (Bytes) of each flow
```

**Porquê:**
- **`Quantum`:** no DRR, cada fluxo tem um quantum, que é o número de bytes que pode enviar em cada ronda. Passámo-lo como argumento porque o enunciado pede experiências com quanta diferentes:
  - na 3.b e na 3.c usamos `[1500 1500 1500]`;
  - na 3.d usamos `[1500 1500 4500]`.

  Assim só mudamos o vetor no script, sem mexer no simulador.
- **`f`:** passou de um valor único para um vetor com o tamanho da fila de cada fluxo. O enunciado pedia f₁ = f₂ = f₃ = 1 000 000 Bytes, por isso no script passamos `f = [1e6 1e6 1e6]`.

</details>

<details>
<summary><b>2. Uma fila por fluxo — linhas 22–27 (Sim2FlowsMP) → linhas 23–30 (nossa versão)</b></summary>

**Antes:**
```matlab
QUEUEOCCUPATION= 0; % Occupation of the queue (in Bytes)
QUEUE = zeros(P,3);
queue_count = 0;     % Tracks current number of packets in queue
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

**Porquê:** os algoritmos do tipo round robin funcionam com uma fila para cada fluxo (Módulo 4, slide 18). Por isso trocámos a fila única por um cell array: `QUEUE{1}`, `QUEUE{2}` e `QUEUE{3}` são as filas dos Fluxos 1, 2 e 3. A ocupação e o contador de pacotes passaram a vetores, com um valor por fila. Mantivemos a pré-alocação do exercício 1.

</details>

<details>
<summary><b>3. Fila final e crédito de cada fluxo — linhas novas 31–32</b></summary>

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
<summary><b>4. Chegada com a ligação ocupada — linhas 85–92 (Sim2FlowsMP) → linhas 73–80 (nossa versão)</b></summary>

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
if QUEUEOCCUPATION(Flow) + PacketSize <= f(Flow)
    queue_count(Flow) = queue_count(Flow) + 1;
    QUEUE{Flow}(queue_count(Flow), :) = [PacketSize , Clock, Flow];
    QUEUEOCCUPATION(Flow)= QUEUEOCCUPATION(Flow) + PacketSize;
else
    LOSTPACKETS(Flow)= LOSTPACKETS(Flow) + 1;
end
```

**Porquê:**
- O pacote vai para a fila do **seu** fluxo (`QUEUE{Flow}`), e não para a fila única onde estavam todos misturados.
- Só se perde o pacote se **a fila do seu fluxo** estiver cheia (`f(Flow)`). Isto é importante no caso D (congestionado): os fluxos que mandam demasiado tráfego enchem a sua própria fila, mas não tiram espaço aos outros. Por exemplo, o Fluxo 2 não perde pacotes mesmo com as filas dos Fluxos 1 e 3 cheias.

</details>

<details>
<summary><b>5. Ronda DRR — linhas novas 89–115</b></summary>

**Antes:** não existia. No `Sim2FlowsMP`, quando acabava uma transmissão, passava logo o primeiro pacote da fila única.

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
<summary><b>6. Próximo pacote a transmitir — linhas 101–114 (Sim2FlowsMP) → linhas 116–125 (nossa versão)</b></summary>

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
- Aqui já não mexemos em `QUEUEOCCUPATION` nem em `queue_count`, porque isso já foi feito quando o pacote passou para a fila final (alteração 5).
- O algoritmo continua a ser ***work conserving***: a ligação só fica livre (`STATE= 0`) quando a fila final e todas as filas dos fluxos estão vazias, porque a ronda da alteração 5 só deixa a fila final vazia se não houver pacotes em lado nenhum.

</details>
