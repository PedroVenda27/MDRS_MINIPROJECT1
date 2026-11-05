%% Task 3.e - Throughput ideal (max-min fairness ponderado) nos casos de 3.c e 3.d
clear; clc;

C      = 10;                         % capacidade da ligação (Mbps)
lambda = [1000 1000 1000];           % caso D (pps)
EB     = [800 125 750];              % tamanho médio de cada fluxo (Bytes)

% Débito pedido por cada fluxo (Mbps) = lambda * 8 * E[B]
x = lambda * 8 .* EB / 1e6;          % [6.4 1.0 6.0]

% No DRR os pesos são os valores de quantum (Módulo 4, slide 23)
pesos = {[1500 1500 1500], [1500 1500 4500]};
nomes = {'3.c (Q = 1500/1500/1500)', '3.d (Q = 1500/1500/4500)'};
ficheiros = {'Task3c_resultados.mat', 'Task3d_resultados.mat'};

for k = 1:2
    ideal = MaxMinPonderado(x, pesos{k}, C);
    fprintf('%s\n', nomes{k});
    fprintf('  Debito pedido : Fluxo 1 = %.3f | Fluxo 2 = %.3f | Fluxo 3 = %.3f Mbps\n', x);
    fprintf('  Ideal (max-min): Fluxo 1 = %.3f | Fluxo 2 = %.3f | Fluxo 3 = %.3f Mbps\n', ideal);
    if isfile(ficheiros{k})
        S = load(ficheiros{k});
        z = norminv(1 - S.alfa/2);
        m = mean(S.TT); t = z*sqrt(var(S.TT)/S.N);
        fprintf('  Simulacao     : Fluxo 1 = %.3f +- %.3f | Fluxo 2 = %.3f +- %.3f | Fluxo 3 = %.3f +- %.3f Mbps\n', ...
            m(1), t(1), m(2), t(2), m(3), t(3));
    end
end

function a = MaxMinPonderado(x, w, C)
% Max-min fairness ponderado (Módulo 4, slides 14 e 15)
%  x - débito pedido por cada fluxo
%  w - peso de cada fluxo
%  C - capacidade a distribuir
    a = zeros(size(x));
    ativos = true(size(x));          % fluxos ainda não satisfeitos
    resto = C;                       % capacidade ainda por atribuir
    while any(ativos)
        % divide o que resta pelos fluxos ativos, proporcionalmente ao peso
        parte = resto * w(ativos) / sum(w(ativos));
        idx = find(ativos);
        satisfeitos = x(idx) <= a(idx) + parte;
        if ~any(satisfeitos)
            % nenhum fluxo fica satisfeito: todos recebem a sua parte
            a(idx) = a(idx) + parte;
            break;
        end
        % os fluxos satisfeitos recebem só o que pedem; o que sobra volta a ser dividido
        for j = idx(satisfeitos)
            resto = resto - (x(j) - a(j));
            a(j) = x(j);
            ativos(j) = false;
        end
    end
end
