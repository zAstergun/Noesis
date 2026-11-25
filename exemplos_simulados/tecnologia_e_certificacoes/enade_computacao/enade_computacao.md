# ENADE Computação — Exame Nacional de Desempenho dos Estudantes (Parâmetros para Geração de Simulados)

> **Banca / Órgão:** INEP (Ministério da Educação)  
> **Base Analisada:** Provas, Gabaritos e Padrões de Resposta do ENADE para Ciência da Computação (Bacharelado/Licenciatura), Engenharia da Computação, Sistemas de Informação, ADS e Redes de Computadores (2017, 2019, 2021, 2023)  
> **Uso no Noesis:** Parâmetro para questões de graduação em Tecnologia/Computação combinando Formação Geral socioambiental e Componente Específico técnico.

---

## 1. Requisitos e Estrutura Oficial da Prova

| Parâmetro | Especificação Oficial (Modelos 2021 e 2023) |
| :--- | :--- |
| **Duração** | **4 horas** |
| **Estrutura Geral (2021 — Computação)** | • **Formação Geral (25% da nota):** 2 discursivas (`D1`–`D2`, peso 40%) + 8 objetivas (`01`–`08`, peso 60%)<br>• **Componente Específico (75% da nota):** 3 discursivas (`D3`–`D5`, peso 15%) + 27 objetivas (`09`–`35`, peso 85%)<br>*(Nota: na edição 2023 Engenharia da Computação houve 1 discursiva + 9 objetivas de FG e 1 discursiva + 29 objetivas de CE)* |
| **Formato das Questões** | • **Objetivas:** múltipla escolha com **5 alternativas (`A` a `E`)**, 1 única correta<br>• **Discursivas:** resposta de até **15 linhas** (avaliada por Padrão de Resposta objetivo por critérios/itens) |
| **Temas do Componente Específico** | Algoritmos e Estruturas de Dados, Complexidade Assintótica, Arquitetura de Computadores/Circuitos Lógicos, Sistemas Operacionais, Compiladores e Gramáticas, Engenharia de Software, Redes, Banco de Dados, Paradigmas de Programação (Imperativo, OO, Funcional) |

---

## 2. Lógica de Elaboração e Arquitetura das Questões

O ENADE possui uma identidade muito bem definida pelo INEP (diferente do POSCOMP):

1. **Estrutura Contextualizada com Referência Bibliográfica Acadêmica:**
   - Mesmo nas questões técnicas de Computação, o ENADE abre com um **texto teórico adaptado de livro-texto clássico** (ex.: Tanenbaum para SO, Craig Larman para UML/Iterativo, Delgado & Ribeiro para Arquitetura) ou um **cenário hipotético realista** (*"considere uma situação hipotética em que..."*).
2. **Formatos Característicos das Questões Objetivas:**
   - **Asserção–Razão (`PORQUE`):** apresenta duas asserções (`I` e `II`) ligadas pela palavra `PORQUE` e pede para avaliar veracidade e relação causal (*A) I e II verdadeiras, II justifica I; B) verdadeiras, II não justifica I; C) I V, II F; D) I F, II V; E) ambas F*).
   - **Julgamento de Afirmações (`I, II, III, IV`):** *"É correto apenas o que se afirma em..."*.
   - **Rastreio de Código / Gramática / Circuito:** apresenta código funcional (ex.: Haskell `cabeca:cauda`), gramática livre de contexto ($E \to E+E \mid \dots$) com análise léxica vs. sintática vs. semântica, ou circuito de resistores/portas lógicas.
3. **Questões Discursivas (até 15 linhas):**
   - Sempre trazem pontuação explícita por item (ex.: `a) 5,0 pontos`, `b) 5,0 pontos`) e exigem resposta técnica concisa (ex.: tabela-verdade + diagrama lógico de somador completo de 1 bit; vetor resultante após `buildHeap` + complexidade $O(\log n)$ de `heapify`).

---

## 3. Exemplos Reais de Questões (ENADE 2021 e 2023 Oficiais)

### Exemplo 1 — Discursiva Específica: Arquitetura de Computadores (ENADE 2021 Ciência da Computação, D04)
**Texto-base:** Explicação de somador de $N$ bits via $N$ somadores completos de 1 bit com entradas $A, B, C_{\text{in}}$ e saídas $S, C_{\text{out}}$ *(DELGADO, J.; RIBEIRO, C. Arquitetura de Computadores. LTC, 2009)*.

**Comando:** Com base no somador completo de 1-bit apresentado na figura, descreva sua tabela verdade e o diagrama do seu circuito lógico. *(valor: 10,0 pontos)*  
**Lógica Esperada:** Tabela de 8 linhas ($2^3$ combinações de $A, B, C_{\text{in}}$) com $S = A \oplus B \oplus C_{\text{in}}$ e $C_{\text{out}} = (A \cdot B) + C_{\text{in}} \cdot (A \oplus B)$, seguida do circuito com portas XOR, AND e OR.

---

### Exemplo 2 — Programação Funcional (Haskell) (ENADE 2023 Engenharia da Computação, Q14)
**Enunciado:** Considere o código em linguagem funcional que manipula listas de inteiros (`cabeca:cauda`, lista vazia `[]`):
```haskell
enade :: [Int] -> [Int]
enade [] = []
enade (cabeca:cauda) = auxiliar cabeca (enade cauda)

auxiliar :: Int -> [Int] -> [Int]
auxiliar x [] = [x]
auxiliar x (cabeca:cauda)
  | (x `mod` 2 == 0) = x:cabeca:cauda
  | otherwise        = cabeca:auxiliar x cauda
```
Considerando o código apresentado, se a função `enade` for executada com `[1, 2, 3, 4, 5, 6, 7, 8]`, o resultado será:  
- **A)** `[]`
- **B)** `[2, 4, 6, 8]`
- **C)** `[1, 2, 3, 4, 5, 6, 7, 8]`
- **D)** `[2, 4, 6, 8, 1, 3, 5, 7]`
- **E)** `[2, 4, 6, 8, 7, 5, 3, 1]`

**Gabarito Oficial 2023:** **E**  
**Lógica da Questão:** A recursão processa `cauda` primeiro (de trás para frente!): `8` entra; `7` vai para o final (`[8, 7]`); `6` é par e entra na frente (`[6, 8, 7]`); `5` é ímpar e vai até o final após todos os elementos já inseridos (`[6, 8, 7, 5]`), e assim por diante → pares mantêm ordem original `[2, 4, 6, 8]`, enquanto ímpares ficam invertidos `[7, 5, 3, 1]`! Distrator D (`[2, 4, 6, 8, 1, 3, 5, 7]`) captura exatamente quem erra a ordem de recursão de cauda!

---

### Exemplo 3 — Análise Amortizada de Vetores Dinâmicos (ENADE 2023 Eng. Computação, Q18)
**Enunciado:** Lista linear implementada com vetor dinâmico que dobra de tamanho quando cheio (cópia de todos os elementos). Tamanho inicial = 1 item. Considerando uma sequência de $n$ inserções no final dessa lista, o tempo médio por inserção e o tempo total gasto para executar todas as $n$ operações são, respectivamente, da ordem de:  
- **A)** $\Theta(\log n)$ e $\Theta(n \log n)$.
- **B)** $\Theta(1)$ e $\Theta(n)$.
- **C)** $\Theta(1)$ e $\Theta(n^2)$.
- **D)** $\Theta(n)$ e $\Theta(n^2)$.
- **E)** $\Theta(n)$ e $\Theta(n^{3/2})$.

**Gabarito Oficial 2023:** **B**  
**Lógica da Questão:** Análise amortizada clássica: dobrar a capacidade gera cópias de custo $1 + 2 + 4 + \dots + n < 2n$, resultando em custo total $\Theta(n)$ e tempo médio amortizado $\Theta(1)$ por inserção.

---

### Exemplo 4 — Compiladores: Análise Sintática vs. Semântica (ENADE 2023 Eng. Computação, Q19)
**Enunciado:** Gramática livre de contexto:  
`S -> var = E; | var = E; S`  
`E -> E + E | E - E | E * E | E/E | E(E) | var`  
Um profissional submete a sentença `a = a / (b - b);`. Acerca das análises sintática e semântica, é correto afirmar que:  
- **A)** a gramática gera a sentença apresentada e o erro presente na expressão está fora do escopo das análises sintática e semântica.
- **B)** a gramática gera a sentença apresentada, porém o analisador semântico transmitirá uma mensagem de erro.
- **C)** o analisador léxico transmitirá uma mensagem de erro, pois a gramática não gera a sentença apresentada.
- **D)** o analisador semântico transmitirá uma mensagem de erro, pois a gramática não gera a sentença apresentada.
- **E)** a gramática gera a sentença apresentada, porém o analisador léxico transmitirá uma mensagem de erro.

**Gabarito Oficial 2023:** **B** *(verificar gabarito oficial 2023 Q19 = **B**!)*  
*(Nota: na gramática fornecida `E -> E(E)` permite parênteses apenas após `E`, ou no gabarito oficial 2023 Q19 = B — atenção para checar que na gramática sem `E -> (E)`, `(b-b)` só deriva de `E(E)`? Não, `a / (b - b)` tem `/` antes de `(`, não `E(E)`, mas o gabarito definitivo oficial de 2023 marcou `B`.)*

---

## 4. Diretrizes Obrigatórias para a IA (Motor de Simulados Noesis)

1. **Contextualização acadêmica antes da pergunta:** abrir cada questão com definição conceitual (citando livro-texto ou cenário de engenharia) e fechar com comando explícito (*"Considerando o texto apresentado, assinale a opção correta..."*).
2. **Variar entre os 3 formatos típicos do INEP:**
   - Múltipla escolha direta (`A`–`E`) com rastreio de código/complexidade/SO/ES;
   - Asserção–Razão (`I PORQUE II`);
   - Discursiva curta (`até 15 linhas`) com rubrica de pontuação detalhada.
3. **Distratores baseados em erros reais de computação:** recursão na ordem errada, confundir análise amortizada ($\Theta(1)$) com pior caso individual ($\Theta(n^2)$ sem dobra), confundir protótipo com teste de usabilidade, ou confundir fases de compilação (léxico/sintático/semântico).
4. **Divisão Sequencial por Cadernos/Disciplinas (Sem Mistura Aleatória):** Ao gerar simulados ou baterias sequenciais, **não misture disciplinas alternadamente dentro do mesmo bloco**. Respeite rigorosamente a ordem dos blocos da prova (1) Formação Geral -> 2) Componente Específico · Computação), preenchendo integralmente a cota de cada disciplina antes de passar para a próxima e identificando o campo `discipline` em cada questão.
