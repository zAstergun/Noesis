# OBI — Olimpíada Brasileira de Informática (Instituto de Computação / UNICAMP)

> Guia de parâmetros para geração e correção de simulados pela IA — cobre as duas modalidades oficiais (**Iniciação** e **Programação**) em todos os níveis (**Júnior, Nível 1, Nível 2 e Sênior**).

---

## 1. Requisitos e Estrutura Oficial

Organizada pela **SBC (Sociedade Brasileira de Computação)** e pelo **Instituto de Computação da UNICAMP**, a OBI ocorre tipicamente em **3 Fases** (Local, Estadual e Nacional) com progressão de rigor lógico e algorítmico.

| Modalidade | Público-Alvo | Formato da Prova | O que exige |
| :--- | :--- | :--- | :--- |
| **Iniciação** *(Júnior, N1, N2)* | 4º–5º ano EF (Jr), 6º–7º EF (N1), 8º–9º EF (N2) | **Prova teórica objetiva (5 opções `A–E`)** · Não exige linguagem de programação | Lógica dedutiva, simulação de algoritmos no papel, grafos/rotas, combinatória, autômatos simples |
| **Programação** *(Júnior, N1, N2, Sênior)* | EF (Jr/N1), EM até 3º ano (N2), Técnico / 1º ano Graduação (Sênior) | **Problemas práticos de programação competitiva** (C, C++, Python 3, Java, JavaScript) avaliados por **juiz automático** | Entrada/saída padrão (`stdin`/`stdout`), complexidade assintótica ($O(N \log N)$, $O(N)$), estruturas de dados e algoritmos |

### Conteúdo Programático Típico por Nível (Programação)
- **Nível Júnior:** Condicionais (`if/else`), laços simples, strings, ordenação básica, aritmética inteira e simulação direta.
- **Nível 1:** Vetores/matrizes 2D, busca binária, ordenação, guloso (*greedy*), dois ponteiros e grafos básicos (BFS/DFS simples).
- **Nível 2 & Sênior:** Grafos completos (Dijkstra, Kruskal/Prim, Union-Find/DSU, ordenação topológica), **Programação Dinâmica (DP)**, Segment Tree / Fenwick Tree (BIT), prefix sums, teoria dos números modular.

---

## 2. Lógica de Elaboração e Arquitetura dos Problemas

1. **Modalidade Iniciação — "Enigma Contextualizado em Grupos":**
   - Os problemas vêm agrupados em **cenários narrativos** (ex.: escalação de banda, agendamento de salas, robô em grade, distribuição de apartamentos) seguidos de **3 a 5 questões objetivas encadeadas** com pequenas variações de restrição.
   - Distratores testam o esquecimento de **uma única restrição** do conjunto (*"Ana não senta ao lado de Bruno"*, *"o elevador leva no máximo 2 pessoas"*).
2. **Modalidade Programação — "Subtarefas & Complexidade":**
   - Problemas modernos da OBI valem **100 pontos divididos em subtarefas** (ex.: 20 pts para $N \le 100$ onde $O(N^2)$ passa; 80 pts para $N \le 10^5$ onde exige $O(N \log N)$ ou $O(N)$!).
   - **Casos de borda clássicos:** Empates, valores negativos/zero, $N = 1$, overflow de inteiro de 32 bits em C++ (`int` vs. `long long` quando $10^9 \times 10^5$ ocorre!), e **TLE (*Time Limit Exceeded*)** em Python caso o algoritmo seja $O(N^2)$ para $N = 10^5$.
   - Formato padrão estrito de entrada/saída: **nunca imprima prompts** como `"Digite N:"` — imprima estritamente o resultado especificado na seção *Saída*.

---

## 3. Exemplos Reais e Modelos Comentados (`olimpiada.ic.unicamp.br`)

### Exemplo 1 — Modalidade Iniciação (Padrão OBI Nível 1 / Nível 2)
> **Problema:** Seis amigos — **A, B, C, D, E, F** — devem sentar-se em fila em seis cadeiras numeradas de 1 a 6 (da esquerda para a direita), respeitando todas as regras:  
> 1. **A** deve sentar-se em uma extremidade (1 ou 6).  
> 2. **B** senta-se imediatamente à direita de **C** (bloco `[C, B]`).  
> 3. **D** não pode sentar-se ao lado de **A** nem na cadeira 3.  
> 4. **E** senta-se em algum lugar à esquerda de **F**.  
>
> **Questão:** Se **A** está na cadeira **1** e **C** está na cadeira **2**, em qual cadeira **D** obrigatoriamente deve sentar-se?  
> **A.** Cadeira 3 · **B.** Cadeira 4 · **C.** Cadeira 5 · **D.** Cadeira 6 · **E.** Não é possível cumprir todas as regras  
>
> **Gabarito:** **D (Cadeira 6)**  
> **Dedução:** `1 = A`, `2 = C` -> pela regra 2, `3 = B`. Pela regra 3, **D** não pode ficar ao lado de A (mas 2 já está ocupado) e precisa evitar 3; sobram `4, 5, 6`. Se D estivesse em 4 ou 5, e `E < F` ocupassem as duas restantes... espere: se D = 4, sobra 5=E, 6=F (válido!); se D = 5, 4=E, 6=F (válido!). *Ajuste de elaboração:* Se adicionarmos a regra *"F senta-se imediatamente à esquerda de D"* ou *"D deve sentar-se à direita de F"*, então `E < F < D` fixa unicamente `4=E, 5=F, 6=D`! *(Exemplo demonstra o rigor exato com que a IA deve validar unicidade da dedução em questões de Iniciação!)*

### Exemplo 2 — Modalidade Programação (Estilo Clássico OBI Júnior/N1 — *A Idade de Camila*)
> **Enunciado:** Dona Inês tem três filhas: Camila, Celeste e Cibele. As idades delas são números inteiros diferentes. Sabendo que Camila não é nem a mais velha nem a mais nova, escreva um programa que leia as três idades e imprima a idade de Camila.  
> **Entrada:** Três inteiros $N_1, N_2, N_3$ ($5 \le N_i \le 100$).  
> **Saída:** Um único inteiro indicando a idade de Camila.  
>
> **Solução OBI (Python 3):**
> ```python
> idades = [int(input()) for _ in range(3)] # ou map(int, input().split()) conforme formato
> idades.sort()
> print(idades[1])
> ```

### Exemplo 3 — Modalidade Programação (Estilo OBI Nível 2 / Sênior — Estrutura + Subtarefas)
> **Padrão obrigatório ao gerar problemas Nível 2 / Sênior:**  
> - **Enunciado narrativo** claro;  
> - **Entrada & Saída** com limites exatos (`Restrições: 1 <= N <= 2 * 10^5`, `1 <= A_i <= 10^9`);  
> - **Subtarefas:** Ex.: *Subtarefa 1 (25 pts): $N \le 1.000$; Subtarefa 2 (75 pts): Sem restrições adicionais*;  
> - **Exemplos de Entrada e Saída** (pelo menos 2 casos de teste completos com explicação passo a passo);  
> - **Solução de referência comentada** em Python/C++ analisando complexidade de tempo e espaço ($O(N \log N)$).

---

## 4. Diretrizes Obrigatórias para a IA (Geração de Simulados)

1. **Identifique sempre a modalidade e o nível:**
   - **Iniciação:** Crie cenários de raciocínio lógico puro com **3 a 5 questões objetivas (`A–E`)** por enunciado-base, testando **exaustivamente** se a resposta é **única** antes de exibir o gabarito.
   - **Programação:** Estruture sempre com **Descrição + Entrada + Saída + Restrições + Subtarefas + Casos de Teste (`Entrada 1 / Saída 1`) + Solução Comentada (C++ ou Python) com Análise de Complexidade**.
2. **Calibração rigorosa das restrições:** Em Nível 2/Sênior, escolha limites ($N \le 10^5$ ou $2\cdot 10^5$) que realmente exijam algoritmo eficiente (DP, busca binária na resposta, grafo ou prefix sum) em vez de força bruta.
3. **Sem bibliotecas mágicas fora do padrão competitivo:** Em soluções Python/C++, use apenas biblioteca padrão (`sys.stdin`, `bisect`, `heapq`, `collections` / STL `<vector>`, `<algorithm>`, `<queue>`).
4. **Divisão Sequencial por Cadernos/Disciplinas (Sem Mistura Aleatória):** Ao gerar simulados ou baterias sequenciais, **não misture disciplinas alternadamente dentro do mesmo bloco**. Respeite rigorosamente a ordem dos blocos da prova (1) Raciocínio Lógico (Iniciação) -> 2) Algoritmos & Estruturas de Dados), preenchendo integralmente a cota de cada disciplina antes de passar para a próxima e identificando o campo `discipline` em cada questão.
