# GMAT Focus Edition — Graduate Management Admission Test (GMAC)

> Guia de parâmetros para geração e correção de simulados pela IA — atualizado para o formato vigente **GMAT Focus Edition** publicado pela **GMAC** (`mba.com`).

---

## 1. Requisitos e Estrutura Oficial

A reforma **GMAT Focus Edition** eliminou a antiga redação (AWA) e a subseção *Sentence Correction* de gramática pura, passando a ter **3 seções de 45 minutos cada** (total **2h15min**, 64 questões) e escala de pontuação de **205 a 805** (terminando sempre em `5`).

| Seção | Duração | Questões | Escala | O que avalia |
| :--- | :--- | :--- | :--- | :--- |
| **Quantitative Reasoning (QR)** | **45 min** | **21 questões** | 60–90 | Apenas **Problem Solving** (álgebra e aritmética; *sem geometria euclidiana* e *sem calculadora*) |
| **Verbal Reasoning (VR)** | **45 min** | **23 questões** | 60–90 | **Reading Comprehension** + **Critical Reasoning** (*Sentence Correction foi removida*) |
| **Data Insights (DI)** | **45 min** | **20 questões** | 60–90 | **Data Sufficiency** (movida do Quant para cá!), **Multi-Source Reasoning**, **Table Analysis**, **Graphics Interpretation**, **Two-Part Analysis** |

*Recursos da prova:* Adaptativa por questão (*Question-Level Adaptive*) dentro de cada seção, permitindo marcar e revisar/editar até **3 respostas por seção** ao final do bloco de 45 minutos. Calculadora **on-screen permitida exclusivamente em Data Insights** (proibida em Quant).

---

## 2. Lógica de Elaboração e Arquitetura dos Distratores

1. **Data Sufficiency (DS — coração do GMAT, agora em Data Insights):** O candidato recebe uma pergunta + duas afirmações `(1)` e `(2)` e escolhe entre as **5 opções fixas da GMAC** sem precisar necessariamente terminar o cálculo numérico — basta provar **suficiência única**:
   - **A:** (1) sozinha é suficiente, mas (2) sozinha não é.
   - **B:** (2) sozinha é suficiente, mas (1) sozinha não é.
   - **C:** Ambas juntas são suficientes, mas nenhuma sozinha é.
   - **D:** CADA UMA sozinha (`1` ou `2`) é suficiente.
   - **E:** Nem mesmo juntas são suficientes.
   - *Armadilha nº 1 ("C-trap"):* Quando a pergunta parece obviamente precisar de `(1) + (2)`, mas uma manipulação algébrica ou cancelamento de variável torna `(1)` ou `(2)` suficiente sozinha (`A`, `B` ou `D`).
   - *Armadilha nº 2 ("Yes/No Sufficiency"):* Se `(1)` garante que a resposta à pergunta *"Is x > 0?"* é **sempre NÃO**, `(1)` **é suficiente**! Insuficiência só ocorre quando permite **SIM e NÃO** simultaneamente.
2. **Critical Reasoning (CR):** Argumento curto (~60–100 palavras) testando lógica informal e análise causal corporativa/científica: *Weaken*, *Strengthen*, *Assumption*, *Evaluate the Argument*, *Boldface (Method of Reasoning)*, *Paradox / Explain*.
   - Distratores clássicos em CR: **Out of Scope** (traz variável irrelevante à conclusão), **Reverse Direction** (enfraquece quando pediu fortalecer) e **Shell Game** (troca sutilmente *"sales revenue"* por *"profit"*, ou *"percentage"* por *"absolute number"*).
3. **Two-Part Analysis & Multi-Source Reasoning (DI):** Exigem cruzar duas ou três abas (e-mails corporativos, tabelas, notas financeiras) ou resolver um sistema com restrições inteiras escolhendo valores interdependentes em duas colunas.

---

## 3. Exemplos Reais e Modelos Comentados (`mba.com`)

### Exemplo 1 — Data Sufficiency (Modelo Oficial GMAC / mba.com)
> **Question:** If a certain city is losing $12\%$ of its daily water supply each day because of water-main breaks, what is the dollar cost to the city per day for this loss?  
> **(1)** The city's daily water supply is $300\text{ million gallons}$ before the losses begin.  
> **(2)** The cost to the city of supplying water is $\$1.50\text{ per }1{,}000\text{ gallons}$.  
>
> *(Opções padrão A, B, C, D, E de Data Sufficiency)*  
> **Gabarito:** **C** *(Ambas juntas são suficientes)*  
> **Comentário:** `(1)` fornece o volume perdido ($12\% \times 300{,}000{,}000 = 36{,}000{,}000\text{ galões}$), mas sem o custo unitário não calcula o dólar/dia -> insuficiente. `(2)` fornece a tarifa ($\$1.50 / 1{,}000\text{ gal}$), mas sem o volume total -> insuficiente. Juntas `(1)+(2)` determinam unicamente o custo diário ($36{,}000 \times \$1.50 = \$54{,}000$) -> **C**.

### Exemplo 2 — Critical Reasoning (Modelo Oficial GMAC — *Flaw / Alternative Cause*)
> **Stimulus (mba.com):** *Although migraine headaches are believed to be caused by food allergies, putting patients on diets that eliminate those foods to which the patients have been demonstrated to have allergic migraine reactions frequently does not stop headaches. Obviously, some other cause of migraine headaches besides food allergies must be responsible for the headaches.*
>
> **Question:** Which of the following, if true, most weakens the conclusion above?  
> **A.** Many common foods trigger allergic reactions only when combined with high stress levels.  
> **B.** Even when patients avoid known allergenic foods, they may still be exposed to non-dietary allergens or unidentified food allergens that trigger migraines.  
> **C.** Prescription migraine medications carry significant side effects for a minority of patients.  
> **D.** Food allergies often manifest with skin rashes before causing neurological symptoms.  
> **E.** Some patients do not strictly follow dietary restrictions unless monitored by a physician. *(Note: B or E both undermine the inference; on official GMAT only ONE cleanly attacks the gap without side flaws.)*  
>
> **Lógica de elaboração:** O argumento conclui apressadamente que, se a dieta de eliminação (para alimentos *já identificados*) falhou, alergias alimentares não são a causa principal. Atacar essa lacuna mostrando que existem **alergias alimentares ainda não diagnosticadas** (ou **não adesão à dieta** se for esse o ponto) quebra a suficiência do teste.

### Exemplo 3 — Problem Solving (Quant — Sem Calculadora)
> **Enunciado:** A store sells a jacket at a $20\%$ discount off its regular price, and still makes a $20\%$ profit over its wholesale cost of $\$100$. What is the regular price of the jacket?  
> **A.** $\$120$ · **B.** $\$140$ · **C.** $\$144$ · **D.** $\$150$ · **E.** $\$160$  
> **Gabarito:** **D ($\$150$)**  
> **Cálculo e Distratores:** Preço de venda = $100 \times 1.20 = \$120$. Como $\$120 = 0.80 \times P_{\text{regular}}$, temos $P_{\text{regular}} = 120 / 0.8 = \$150$. **Distrator clássico C ($\$144$):** aplicar $+20\%$ sobre $\$120$ ($120 \times 1.2 = 144$), confundindo base percentual!

---

## 4. Diretrizes Obrigatórias para a IA (Geração de Simulados)

1. **Respeite rigorosamente as mudanças do GMAT Focus Edition:**
   - **NÃO gere questões de Sentence Correction** (correção gramatical sublinhada) nem de **Geometria Euclidiana pura** (triângulos/círculos sem contexto algébrico ou coordenado) — ambas foram removidas do GMAT atual.
   - **NÃO inclua redação discursiva (AWA)** no GMAT Focus padrão.
2. **Data Sufficiency sempre em 5 opções fixas (A–E):** Inclua tanto questões de **Valor Numérico único** (*"What is the value of x?"*) quanto questões **Sim/Não** (*"Is n an integer?"*), lembrando de criar armadilhas em que `0`, negativos ou frações invertam a suficiência.
3. **Data Insights diversificado:** Combine Data Sufficiency com **Two-Part Analysis** (duas colunas de seleção interdependente) e **Table/Graphics Analysis** (média, mediana, variação percentual, correlação).
4. **Explicação estratégica de gabarito:** Em Data Sufficiency, avalie `(1)` isoladamente primeiro (*AD vs. BCE*), depois `(2)` isoladamente (*esquecendo `(1)`*), e só por último combine `(1)+(2)`. Em Critical Reasoning, decomponha **Premissa -> Lacuna Lógica -> Conclusão**.
5. **Divisão Sequencial por Cadernos/Disciplinas (Sem Mistura Aleatória):** Ao gerar simulados ou baterias sequenciais, **não misture disciplinas alternadamente dentro do mesmo bloco**. Respeite rigorosamente a ordem dos blocos da prova (1) Quantitative Reasoning -> 2) Verbal Reasoning (CR & RC) -> 3) Data Insights (Data Sufficiency & Analysis)), preenchendo integralmente a cota de cada disciplina antes de passar para a próxima e identificando o campo `discipline` em cada questão.
