# SAT — Digital SAT Suite (Parâmetros para Geração de Simulados)

> **Banca:** College Board (EUA)  
> **Base Analisada:** Official Digital SAT Linear Practice Tests #4–#11, Answer Explanations & Scoring Guides (`satsuite.collegeboard.org`)  
> **Uso no Noesis:** Parâmetro para geração de simulados internacionais em inglês nos domínios *Reading and Writing* e *Math*.

---

## 1. Requisitos e Estrutura Oficial da Prova (Digital SAT)

| Parâmetro | Especificação Oficial |
| :--- | :--- |
| **Estrutura Geral** | 2 seções principais, cada uma dividida em **2 módulos adaptativos** (*Multistage Adaptive Testing*):<br>1. **Reading and Writing:** 2 módulos × 32 min (27 questões operacionais + 2 pré-teste por módulo no digital; **33 questões por módulo** nos simulados lineares em papel)<br>2. **Math:** 2 módulos × 35 min (22 questões por módulo no digital; **27 questões por módulo** nos simulados lineares) |
| **Duração Total** | 2h 14min (digital adaptativo) |
| **Formato das Questões** | • **Reading and Writing:** 100% múltipla escolha com **4 alternativas (`A` a `D`)**<br>• **Math:** ~75% múltipla escolha (`A` a `D`) e ~25% *Student-Produced Response* (resposta numérica direta, sem opções) |
| **Pontuação** | Escala **400–1600** (200–800 *Reading and Writing* + 200–800 *Math*); **sem penalidade por erro** (*no guessing penalty*) |
| **Calculadora** | Permitida em **toda** a seção de Matemática (Desmos integrada) |

---

## 2. Lógica de Elaboração e Arquitetura das Questões

### A. Seção *Reading and Writing*
- **Regra do Micro-Texto Único:** ao contrário de provas antigas com passagens longas de 800 palavras, **cada questão do Digital SAT traz seu próprio texto curto (25 a 150 palavras)** ou tabela/gráfico e exatamente **1 pergunta**.
- **4 Domínios Padronizados:**
  1. **Craft and Structure:** *Words in Context* (lacuna `_______` pedindo a palavra mais lógica e precisa), *Text Structure and Purpose*, *Cross-Text Connections* (Text 1 vs. Text 2).
  2. **Information and Ideas:** *Central Ideas and Details*, *Command of Evidence* (textual ou quantitativa com gráfico/tabela), *Inferences* (completar conclusão lógica com `_______`).
  3. **Standard English Conventions:** gramática/pontuação formal (concordância, pontuação de orações, tempos verbais, modificadores) com comando fixo: *"Which choice completes the text so that it conforms to the conventions of Standard English?"*
  4. **Expression of Ideas:** *Rhetorical Synthesis* (notas em bullet points *"While researching a topic, a student has taken the following notes:"* pedindo uma frase que atinja um objetivo específico) e *Transitions* (conector lógico entre frases).

### B. Seção *Math*
- **4 Domínios:** *Algebra* (~35%), *Advanced Math* (~35%), *Problem-Solving and Data Analysis* (~15%), *Geometry and Trigonometry* (~15%).
- **Estilo:** problemas concisos com interpretação de gráficos/equações lineares, modelagem de inequações, sistemas, funções quadráticas/exponenciais e análise estatística.

---

## 3. Exemplos Reais de Questões (College Board Practice Test #10 Oficial)

### Exemplo 1 — Reading and Writing: *Words in Context* (SAT Practice Test #10, M1, Q01)
**Passage:**  
> The general store was essential to daily life in the rural United States during the 1800s because it provided the supplies that the people living in nearby communities needed. Also, the store was a _______ of information. People socializing at the general store would share news and help spread it throughout their communities.

**Question:** Which choice completes the text with the most logical and precise word or phrase?  
- **A)** source
- **B)** rival
- **C)** condition
- **D)** waste

**Answer:** **A**  
**Lógica e Distratores:** A última frase define a pista contextual (*"share news and help spread it"* → lugar de origem/obtenção de informação = *source*). Os distratores são palavras da mesma classe gramatical (substantivos singulares) com relação semântica incompatível com o papel socializador descrito.

---

### Exemplo 2 — Reading and Writing: *Words in Context* (SAT Practice Test #10, M1, Q03)
**Passage:**  
> Former astronaut Ellen Ochoa says that although she doesn’t have a definite idea of when it might happen, she _______ that humans will someday need to be able to live in other environments than those found on Earth. This conjecture informs her interest in future research missions to the moon.

**Question:** Which choice completes the text with the most logical and precise word or phrase?  
- **A)** demands
- **B)** speculates
- **C)** doubts
- **D)** establishes

**Answer:** **B**  
**Lógica e Distratores:** A pista lexical explícita é *"doesn't have a definite idea"* + *"This conjecture"* → hipótese sem evidência definitiva = *speculates*. *Demands* (exige), *doubts* (nega a hipótese) e *establishes* (comprova com certeza) contradizem o grau de incerteza do texto.

---

### Exemplo 3 — Reading and Writing: *Text Structure and Purpose* (SAT Practice Test #10, M1, Q06)
**Passage:** Texto curto (100 palavras) explicando como o *jazz tap* nasceu em comunidades afro-americanas nos anos 1920, foi moldado pelos ritmos rápidos e improvisações do jazz e evoluiu nos anos 1930–1940 tornando-se distinto de formas anteriores de sapateado.

**Question:** Which choice best states the main purpose of the text?  
- **A)** It explains why audiences prefer some kinds of music over others.
- **B)** It discusses the development of a dance form.
- **C)** It describes how to play a musical instrument.
- **D)** It emphasizes the popularity of a famous dancer.

**Answer:** **B**  
**Lógica da Questão:** Avalia o propósito retórico global sem se perder em detalhes. Note o paralelismo perfeito (*"It + verb in present simple..."*).

---

### Exemplo 4 — Math: *Algebra / Linear Inequality Modeling* (SAT Practice Test #10, M1, Q03)
**Problem:**  
> The total cost, in dollars, to rent a surfboard consists of a $\$25$ service fee and a $\$10$ per hour rental fee. A person rents a surfboard for $t$ hours and intends to spend a maximum of $\$75$ to rent the surfboard.

**Question:** Which inequality represents this situation?  
- **A)** $10t \le 75$
- **B)** $10t + 25 \le 75$
- **C)** $25t \le 75$
- **D)** $25t + 10 \le 75$

**Answer:** **B**  
**Lógica e Distratores:** A = omite a taxa fixa ($25$); C = multiplica a taxa fixa por $t$ e omite a variável; D = inverte coeficiente angular e intercepto ($25t+10$). Distratores clássicos de modelagem linear.

---

## 4. Diretrizes Obrigatórias para a IA (Motor de Simulados Noesis)

1. **Idioma:** gerar questões **100% em inglês americano padrão** (exceto se o usuário pedir tradução comentada nas explicações).
2. **Reading and Writing:** **1 micro-texto (25–150 palavras) por questão** + **exatamente 4 opções (`A`–`D`)**; usar comandos canônicos do College Board (*"Which choice completes the text with the most logical and precise word or phrase?"*, *"Which choice best states the main purpose of the text?"*, *"Which choice completes the text so that it conforms to the conventions of Standard English?"*).
3. **Math:** incluir tanto múltipla escolha (`A`–`D`) quanto problemas abertos (*Student-Produced Response*), construindo distratores com erros algébricos típicos (trocar coeficiente e constante, errar sinal na translação, inverter inclinação).
4. **Explicações:** justificar não só a alternativa correta, mas também por que cada um dos 3 distratores está errado.
5. **Divisão Sequencial por Cadernos/Disciplinas (Sem Mistura Aleatória):** Ao gerar simulados ou baterias sequenciais, **não misture disciplinas alternadamente dentro do mesmo bloco**. Respeite rigorosamente a ordem dos blocos da prova (1) Reading and Writing -> 2) Math), preenchendo integralmente a cota de cada disciplina antes de passar para a próxima e identificando o campo `discipline` em cada questão.
