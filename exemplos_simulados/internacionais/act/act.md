# ACT — American College Testing (Enhanced ACT Format)

> Guia de parâmetros para geração e correção de simulados pela IA — atualizado para o formato **Enhanced ACT (2025/2026)** publicado pela **ACT, Inc.** (`act.org`).

---

## 1. Requisitos e Estrutura Oficial

O ACT mede prontidão acadêmica para ingresso universitário nos EUA em uma escala de **1 a 36 pontos** por seção e no **Composite Score** (média das seções obrigatórias: no formato Enhanced ACT, **English, Math e Reading**, com **Science** e **Writing** opcionais — embora o Composite tradicional de 4 seções ainda possa ser simulado quando solicitado).

| Seção | Duração (Enhanced) | Nº de Questões | Alternativas | Foco Principal |
| :--- | :--- | :--- | :--- | :--- |
| **English** | 35 min | 50 questões | 4 (`A/B/C/D` ou `F/G/H/J`) | Uso retórico, organização, concisão e convenções gramaticais |
| **Mathematics** | 50 min | 45 questões | **4** (reduzido de 5 no novo ACT) | Álgebra, funções, geometria, trigonometria, estatística/probabilidade |
| **Reading** | 40 min | 36 questões | 4 | Ficção literária, ciências sociais, humanidades, ciências naturais |
| **Science** *(opcional)* | 40 min | 40 questões | 4 | Interpretação de dados, resumos de pesquisa e pontos de vista conflitantes |
| **Writing** *(opcional)* | 40 min | 1 redação | Dissertativa | Análise de 3 perspectivas sobre tema contemporâneo |

*Convenção visual histórica do ACT:* Questões ímpares usam alternativas `A, B, C, D` e questões pares alternam para `F, G, H, J` no formato impresso (para evitar erros de marcação no cartão-resposta). Na prova digital/IA, `A/B/C/D` é aceito de forma contínua, mantendo obrigatoriamente **4 opções** em todas as seções (inclusive Matemática no novo formato).

---

## 2. Lógica de Elaboração e Arquitetura dos Distratores

1. **English — Concisão e Economia Retórica (*"Shortest non-redundant answer"*):** Cerca de 25–30% das questões de *Production of Writing / Knowledge of Language* testam redundância (*"annual event held every year"*, *"returned back"*). Se duas alternativas estão gramaticalmente corretas, a mais concisa e livre de pleonasmo costuma ser a correta — exceto quando a pergunta pede especificamente *"which choice best emphasizes..."* ou *"most specific detail"*.
2. **Reading — Literalidade rápida sob pressão de tempo:** Diferente do SAT (que cobra inferências profundas em parágrafos curtos), o ACT traz **4 passagens longas** (~750 palavras cada) com questões que exigem localização veloz de evidências explícitas. Distratores comuns:
   - Verdades de outra parte do texto que não respondem ao comando da linha citada;
   - Distorção de intensidade (*"always"*, *"never"*, *"primarily"*);
   - Inversão causal entre dois fenômenos do texto.
3. **Mathematics — Progressão linear de dificuldade + calculadora permitida em toda a prova:** Diferente do SAT antigo, calculadora gráfica/científica sempre foi permitida em 100% da prova de Matemática do ACT. Enunciados são diretos (*word problems*, geometria coordenada, matrizes básicas, logaritmos, identidades trigonométricas `sen²θ + cos²θ = 1`). Distratores representam erros algébricos comuns (esquecer de distribuir o sinal negativo, errar área vs. perímetro, usar raio em vez de diâmetro).
4. **Science — Não é prova de memorização científica:** 90%+ das questões são resolvidas lendo **tabelas, gráficos de dispersão/linhas e desenhos experimentais** (*Data Representation*, *Research Summaries*, *Conflicting Viewpoints* — debate entre Cientista 1 e Cientista 2).

---

## 3. Exemplos Reais e Modelos Comentados (`act.org`)

### Exemplo 1 — ACT Mathematics (Estilo Oficial 4 Alternativas)
> **Enunciado oficial de referência:**  
> When $x = 3$ and $y = 5$, by how much does the value of $3x^2 - 2y$ exceed the value of $2x^2 - 3y$?  
> **A.** $4$  
> **B.** $14$  
> **C.** $16$  
> **D.** $20$  
>
> **Gabarito:** **B ($14$)**  
> **Resolução e Distratores:**  
> $3(3)^2 - 2(5) = 27 - 10 = 17$; $2(3)^2 - 3(5) = 18 - 15 = 3$. Diferença: $17 - 3 = 14$.  
> - **Distrator A ($4$):** erro ao calcular $(27 - 10) - (18 - 5)$ ou trocar sinais ao subtrair $-3y$.  
> - **Distrator C ($16$) / D ($20$):** confusão comum ao fazer $(3\cdot 3)^2$ ou somar termos em vez de subtrair $17 - (-3) = 20$.

### Exemplo 2 — ACT Reading (Compreensão Literal e Nuance)
> **Passage Excerpt:**  
> *"The old house had stood at the edge of the cliff for over a century, enduring the salt-laden winds that stripped its paint and warped its timber. To the townsfolk, it was an eyesore—a looming reminder of a shipping magnate whose fortunes had vanished as quickly as they were made. But to Clara, the peeling clapboards and groaning floorboards possessed a stubborn character. While her parents saw only structural liabilities, Clara saw a monument to resilience."*
>
> **Question:** Based on the passage, how do the townsfolk primarily view the old house?  
> **A.** As a historical landmark worth preserving for future generations  
> **B.** As an ugly reminder of a failed businessman's vanished wealth  
> **C.** As a structurally dangerous hazard that should be torn down immediately  
> **D.** As a peaceful retreat hidden away from the rest of the town  
>
> **Gabarito:** **B**  
> **Comentário:** "eyesore" = *ugly reminder*; "shipping magnate whose fortunes had vanished" = *failed businessman's vanished wealth*. **C** mistura a visão dos *pais* ("structural liabilities") com uma extrapolação ("torn down immediately").

### Exemplo 3 — ACT English (Pontuação, Modificadores e Opção `NO CHANGE`)
> **Modelo obrigatório do ACT English:** Frase sublinhada no texto onde a alternativa **A** (ou **F**) é sempre **`NO CHANGE`**, e uma alternativa frequente em questões retóricas é **`DELETE the underlined portion`**.  
> **Exemplo:** *"Because the observatory sits at an elevation of 14,000 feet, **therefore, astronomers** can capture clearer images of distant nebulae."*  
> **A.** `NO CHANGE`  
> **B.** `astronomers, therefore,`  
> **C.** `astronomers`  
> **D.** `consequently astronomers`  
> **Gabarito:** **C** (*Because* já introduz subordinação causal; usar *therefore* ou *consequently* na oração principal cria dupla conjunção agramatical).

---

## 4. Diretrizes Obrigatórias para a IA (Geração de Simulados)

1. **Sempre use 4 alternativas (`A–D`):** Mesmo em Matemática e Ciências, use exatamente **4 opções** alinhadas ao Enhanced ACT atual.
2. **Em simulados de `ACT English`:** Inclua passagens contínuas com trechos numerados sublinhados; faça **A = `NO CHANGE`** nas questões de gramática/pontuação e cobre explicitamente vírgulas em aposto/orações não restritivas, ponto-e-vírgula (`;`), paralelismo, concordância sujeito-verbo distante e concisão.
3. **Em simulados de `ACT Science`:** Sempre construa **tabelas de dados ou descrições textuais de gráficos/experimentos** (Experimento 1, Experimento 2, ou Hipótese 1 vs. Hipótese 2), com foco em interpolação, extrapolação e identificação de variável dependente vs. independente.
4. **Calibragem de tempo:** Lembre o usuário da alta densidade por minuto (~42s/questão em English, ~66s em Math e Reading), diferenciando o ACT do SAT pela menor carga de abstração por questão e maior volume de leitura rápida.
5. **Divisão Sequencial por Cadernos/Disciplinas (Sem Mistura Aleatória):** Ao gerar simulados ou baterias sequenciais, **não misture disciplinas alternadamente dentro do mesmo bloco**. Respeite rigorosamente a ordem dos blocos da prova (1) ACT English -> 2) ACT Mathematics -> 3) ACT Reading), preenchendo integralmente a cota de cada disciplina antes de passar para a próxima e identificando o campo `discipline` em cada questão.
