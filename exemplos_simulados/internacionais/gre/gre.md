# GRE General Test — Graduate Record Examinations (ETS)

> Guia de parâmetros para geração e correção de simulados pela IA — atualizado para o **Shorter GRE (1h58min)** da **ETS** (`ets.org`).

---

## 1. Requisitos e Estrutura Oficial

O GRE é o exame padrão de admissão para mestrados, doutorados (PhD) e MBAs internacionais. É **adaptativo por seção (*Section-Level Adaptive*)**: o desempenho na Seção 1 de *Verbal* ou *Quant* define o nível de dificuldade da Seção 2 (*Easy, Medium, Hard*).

| Seção | Tempo | Estrutura e Itens | Escala de Pontuação |
| :--- | :--- | :--- | :--- |
| **Analytical Writing (AWA)** | **30 min** | **1 redação:** *Analyze an Issue* (Argument essay foi removido na reforma de 2023) | **0.0 – 6.0** (incrementos de 0.5) |
| **Verbal Reasoning** | **41 min total** | **27 questões** (Sec 1: 12 Qs em 18 min · Sec 2: 15 Qs em 23 min) | **130 – 170** (incrementos de 1 ponto) |
| **Quantitative Reasoning** | **47 min total** | **27 questões** (Sec 1: 12 Qs em 21 min · Sec 2: 15 Qs em 26 min) | **130 – 170** (incrementos de 1 ponto) |

### Tipologias Únicas de Questões do GRE
- **Verbal Reasoning:**
  1. **Text Completion (TC):** Textos curtos com 1, 2 ou 3 lacunas. Em 2 ou 3 lacunas, há 3 opções por lacuna e **não existe crédito parcial** (precisa acertar todas as lacunas da questão).
  2. **Sentence Equivalence (SE):** 1 frase com 1 lacuna e **6 alternativas (`A–F`)**; o candidato deve marcar **exatamente 2 respostas** que produzam frases equivalentes em sentido. Sem crédito parcial.
  3. **Reading Comprehension (RC):** Múltipla escolha simples (5 opções `A–E`), **Múltipla escolha múltipla** (*"Consider each of the choices separately and select all that apply"* — 3 opções, sem crédito parcial) e **Select-in-Passage** (clicar na frase exata do texto).
- **Quantitative Reasoning:**
  1. **Quantitative Comparison (QC):** Comparar **Quantity A** vs. **Quantity B** com **4 opções fixas** (`A` = A maior; `B` = B maior; `C` = iguais; `D` = impossível determinar).
  2. **Multiple Choice (5 opções)**, **Select One or More** e **Numeric Entry** (digitar o número ou fração sem alternativas).

---

## 2. Lógica de Elaboração e Arquitetura dos Distratores

1. **Quantitative Comparison (QC) — Armadilha da Opção `D`:** A maior armadilha criada pela ETS em QC é testar apenas inteiros positivos (`x = 2, 3`). Candidatos esquecem de testar **frações entre 0 e 1 (`1/2`)**, **zero (`0`)**, **números negativos (`-2`)** e desigualdades não estritas. Se um caso dá A > B e outro dá B > A ou A = B, a resposta é obrigatoriamente **D**.
2. **Sentence Equivalence (SE) — O "Par Falso" vs. Par Sinônimo + Ajuste Contextual:** Entre as 6 opções, a ETS costuma colocar **dois pares sinônimos** (um par semanticamente alinhado à frase e outro par com sentido oposto ou fora do tom) + 2 palavras isoladas sem par (muitas vezes tentadoras individualmente, mas impossíveis de marcar em dupla equivalente).
3. **Text Completion (TC) — Polaridade e Conectivos Lógicos:** Frases são construídas em torno de marcadores explícitos de contraste (*yet, notwithstanding, paradoxically, belied by*) ou continuidade (*indeed, moreover, consequently*). O vocabulário é de nível acadêmico sofisticado (*ephemeral, iconoclastic, equivocal, corroborate, pedestrian*).
4. **Quantitative — Matemática de Ensino Médio com Raciocínio Sofisticado:** Não cobra cálculo diferencial, mas exige maestria em teoria dos números (resto, divisibilidade, primos), combinatória/probabilidade, desvios-padrão e propriedades algébricas.

---

## 3. Exemplos Reais e Modelos Comentados (`ets.org`)

### Exemplo 1 — Quantitative Comparison (Padrão Oficial ETS)
> **Condição dada:** $x > 4$  
>
> | Quantity A | Quantity B |
> | :--- | :--- |
> | $\dfrac{3x + 2}{5}$ | $x$ |
>
> **Alternativas fixas da ETS:**  
> **A.** Quantity A is greater.  
> **B.** Quantity B is greater.  
> **C.** The two quantities are equal.  
> **D.** The relationship cannot be determined from the information given.  
>
> **Gabarito:** **B**  
> **Análise:** Comparando $\frac{3x+2}{5}$ com $x$ (multiplicando ambos os lados por $+5$): $3x + 2$ vs. $5x \Rightarrow 2$ vs. $2x \Rightarrow 1$ vs. $x$. Como o enunciado garante $x > 4$, sempre vale $x > 1$, logo **Quantity B é estritamente maior** para qualquer valor admissível de $x$. *(Se a restrição $x > 4$ não existisse, $x = 1$ daria C e $x = 0$ daria A, tornando D correto!)*

### Exemplo 2 — Sentence Equivalence (6 opções, escolha exata de 2)
> **Enunciado:** *Although the critic praised the novel's ambitious scope, she found its prose unnecessarily ______, bogged down by redundant adjectives and convoluted clauses.*  
> **A.** `lucid` · **B.** `turgid` · **C.** `terse` · **D.** `florid` · **E.** `mundane` · **F.** `concise`  
>
> **Gabarito:** **B (`turgid`) e D (`florid`)**  
> **Comentário:** "bogged down by redundant adjectives and convoluted clauses" define o estilo rebuscado/prolixo (**B** e **D**). **C** (`terse`) e **F** (`concise`) formam um **par sinônimo armadilha** de sentido exatamente oposto ao contexto.

### Exemplo 3 — Text Completion com 2 Lacunas
> **Enunciado:** *Far from being a (i) ______ observer of nineteenth-century politics, the historian wrote pamphlets that (ii) ______ the prevailing policies of the crown.*  
> **Blank (i):** `A. detached` · `B. partisan` · `C. perceptive`  
> **Blank (ii):** `D. corroborated` · `E. lambasted` · `F. ignored`  
>
> **Gabarito:** **(i) A (`detached`)** e **(ii) E (`lambasted`)**  
> **Comentário:** "Far from being..." estabelece contraste entre imparcialidade (`detached`) e ataque ativo às políticas da coroa (`lambasted`).

---

## 4. Diretrizes Obrigatórias para a IA (Geração de Simulados)

1. **Implemente todas as tipologias nativas do GRE:**
   - **Quant:** Inclua obrigatoriamente questões de **Quantitative Comparison** (com as 4 opções fixas A/B/C/D da ETS), **Numeric Entry** (sem alternativas) e **Data Interpretation** (lendo gráficos/tabelas percentuais).
   - **Verbal:** Inclua **Sentence Equivalence** (com **6 alternativas** exigindo **2 respostas** e par sinônimo distrator), **Text Completion** (1, 2 e 3 lacunas) e **Reading Comprehension** com opções *"Select all that apply"* (3 itens).
2. **Vocabulário GRE autêntico:** Empregue léxico acadêmico avançado (nível C1/C2) com pistas lógicas internas claras na própria frase — nunca dependa de definição isolada sem contexto sintático.
3. **Analytical Writing (AWA):** Caso o usuário peça treino de redação, gere apenas o prompt **`Analyze an Issue`** (com instrução de resposta em 30 minutos avaliando complexidade, concessões e exemplos históricos/acadêmicos).
4. **No gabarito de QC:** Demonstre sempre **duas abordagens**: (a) manipulação algébrica das duas quantidades e (b) teste de casos extremos (*plugging in*: negativos, `0`, frações `1/2`, inteiros grandes).
5. **Divisão Sequencial por Cadernos/Disciplinas (Sem Mistura Aleatória):** Ao gerar simulados ou baterias sequenciais, **não misture disciplinas alternadamente dentro do mesmo bloco**. Respeite rigorosamente a ordem dos blocos da prova (1) Verbal Reasoning (TC / SE / RC) -> 2) Quantitative Reasoning (QC & Problem Solving)), preenchendo integralmente a cota de cada disciplina antes de passar para a próxima e identificando o campo `discipline` em cada questão.
