# POSCOMP — Exame Nacional para Ingresso na Pós-Graduação em Computação (Parâmetros para Geração de Simulados)

> **Banca / Promoção:** SBC (Sociedade Brasileira de Computação) — Execução Fundatec  
> **Base Analisada:** Cadernos e Gabaritos Oficiais do POSCOMP (2016–2025; sem edição em 2020/2021)  
> **Uso no Noesis:** Parâmetro para geração de questões técnicas de nível superior em Ciência da Computação (Matemática, Fundamentos e Tecnologia).

---

## 1. Requisitos e Estrutura Oficial da Prova

| Parâmetro | Especificação Oficial |
| :--- | :--- |
| **Total de Questões** | **70 questões objetivas** (execução em 4 horas) |
| **Divisão por Grandes Áreas** | 1. **Matemática (20 questões):** Matemática Discreta, Cálculo Diferencial e Integral, Álgebra Linear, Geometria Analítica, Probabilidade e Estatística, Lógica Matemática<br>2. **Fundamentos da Computação (30 questões):** Análise de Algoritmos, Estruturas de Dados, Linguagens Formais e Autômatos, Compiladores, Sistemas Operacionais, Arquitetura de Computadores, Sistemas Digitais, Teoria da Computação<br>3. **Tecnologia da Computação (20 questões):** Banco de Dados, Engenharia de Software, Redes de Computadores, Inteligência Artificial, Computação Gráfica, Processamento de Imagens |
| **Formato das Questões** | Múltipla escolha com **5 alternativas (`A` a `E`)**, 1 única correta |
| **Perfil Cognitivo** | Técnico, direto e formal — exige domínio de provas formais, rastreio de código em C/pseudocódigo, cálculo matricial/integral e circuitos lógicos |

---

## 2. Lógica de Elaboração e Arquitetura das Questões

1. **Zero Enrolação Narrativa:**
   - As questões vão direto ao problema técnico ou matemático (*"Utilizando o método de Gauss..."*, *"Considere a função $F(A,B,C)$..."*, *"Analise o código em Linguagem C..."*). Quando há contextualização (ex.: servidores em um rack, micro-operações de CPU), ela serve unicamente para parametrizar um modelo combinatório ou de sistemas operacionais.
2. **Arquétipos Recorrentes do POSCOMP:**
   - **Rastreio de Código C / Ponteiros / Bitwise / Threads:** apresenta um pequeno programa em C ANSI (ex.: deslocamento de bits `>>= 1` com ponteiros, ou `pthread_create`/`pthread_join` com condição de corrida!) e pergunta a saída ou relação matemática válida (`lbm <= 10`).
   - **Lógica Digital e Autômatos:** simplificação por Mapa de Karnaugh com *don't care*, forma dual, soma de mintermos $\sum m(\dots)$, classificação de FSM (Mealy vs. Moore).
   - **Assertivas `I, II, III`:** frequentemente em Sistemas Operacionais, Arquitetura e Engenharia de Software (*"Quais estão corretas? A) Apenas I ... E) I, II e III"*).
   - **Cálculo e Álgebra Linear Diretos:** autovalores/autovetores, projeção ortogonal, gradiente, multiplicadores de Lagrange, regra dos trapézios, limites e integrais.
3. **Distratores Técnicos Precisos:**
   - Em código com condição de corrida (`pthread`), o distrator óbvio é `lbm = 10`, enquanto a resposta correta exige notar a ausência de *mutex* (`lbm <= 10` pela perda de atualizações concorrentes!).
   - Em combinatória/grafos, distratores incluem fórmulas clássicas sem a restrição (*árvore* com $n-1$ arestas vs. grafo completo $n(n-1)/2$).

---

## 3. Exemplos Reais de Questões (POSCOMP 2024 e 2025 Oficiais)

### Exemplo 1 — Matemática: Combinatória / Programação Dinâmica em CPU (POSCOMP 2025, Q04)
**Enunciado:** Um processador executa tarefas compostas por uma sequência de micro-operações. Existem dois tipos: tipo A, que dura $1$ ciclo de clock, e tipo B, que dura $2$ ciclos de clock. Uma tarefa é definida pela sequência de micro-operações que a compõe. Quantas sequências distintas podem formar uma tarefa com duração total de exatamente $8$ ciclos de clock?  
- **A)** 21
- **B)** 26
- **C)** 34
- **D)** 42
- **E)** 55

**Resposta Correta:** **C** ($34$)  
**Lógica da Questão:** Recorrência de Fibonacci: $f(1)=1, f(2)=2, f(n)=f(n-1)+f(n-2) \Rightarrow f(8) = 34$. Distratores A (21 = $f(7)$) e E (55 = $f(9)$) capturam erro de indexação *off-by-one*.

---

### Exemplo 2 — Matemática: Lógica Proposicional / Equivalência (POSCOMP 2025, Q13)
**Enunciado:** Analise as proposições: $p$: "O sistema está ligado"; $q$: "O sensor foi ativado". A proposição composta $p \to q$ é logicamente equivalente a:  
- **A)** $\neg p \to \neg q$
- **B)** $\neg q \to \neg p$ *(e atenção: $\neg p \lor q$ também aparece como D — verificar gabarito oficial quando há contrapositiva vs. disjunção)*

*(Nota do arquivo `caderno_2025.pdf`: na Q13 constavam ambas $\neg q \to \neg p$ e $\neg p \lor q$; na edição 2024, Q13 cobrou $\neg p \to \neg q \equiv q \to p$, gabarito oficial **D**.)*

---

### Exemplo 3 — Fundamentos: Programação em C com Ponteiros e Bitwise (POSCOMP 2024, Q33)
**Enunciado:** Analise o código em Linguagem C (Compilador Ansi C) abaixo:
```c
int main() {
    int valor1 = 12;
    int *valor2;
    int cont = 0;
    valor2 = &valor1;
    do {
        valor1 >>= 1;
        cont++;
    } while (*valor2 > 0);
    printf("%d", cont);
}
```
A saída do programa na tela é o número:  
- **A)** 2.
- **B)** 3.
- **C)** 4.
- **D)** 5.
- **E)** 6.

**Gabarito Oficial 2024:** **C** ($4$)  
**Lógica da Questão:** `valor1 = 12` (binário `1100`): iteração 1 → `6`, iteração 2 → `3`, iteração 3 → `1`, iteração 4 → `0` (sai do `do-while`), imprimindo `cont = 4`. Combina aritmética binária, ponteiro apontando para `valor1` e semântica de `do-while`.

---

### Exemplo 4 — Fundamentos: Concorrência com `pthreads` (POSCOMP 2024, Q43)
**Enunciado:** Analise a execução considerando cabeçalhos inclusos:
```c
int lbm = 0;
void *func(void *i) { lbm = lbm + 1; }
int main(void) {
    int i;
    pthread_t t[10];
    for (i = 0; i < 10; i++) pthread_create(&t[i], NULL, func, NULL);
    for (i = 0; i < 10; i++) pthread_join(t[i], NULL);
    printf("%d", lbm);
}
```
Assinale a alternativa que melhor representa o resultado da execução do programa acima.  
- **A)** `lbm = 1`
- **B)** `lbm = 9`
- **C)** `lbm <= 10`
- **D)** `lbm = 10`
- **E)** `lbm >= 10`

**Gabarito Oficial 2024:** **C**  
**Lógica da Questão:** Como `lbm = lbm + 1` não é atômico e não há `pthread_mutex_lock`, há **condição de corrida** (*lost update* entre leitura, incremento e escrita nos registradores de cada thread). Assim, o valor final é no máximo 10 (`lbm <= 10`).

---

### Exemplo 5 — Fundamentos: Sistemas Operacionais / Escalonamento Round-Robin (POSCOMP 2025, Q42)
**Enunciado:** A execução de um processo alterna ciclos de CPU (`exec_t`) e E/S (`es_t`) sob escalonamento *round-robin* (RR) preemptivo, com tempo de troca de contexto `switch_t`. Assinale a alternativa que melhor minimiza o tempo médio de *turnaround*:  
- **A)** `(exec_t > switch_t) e (exec_t > quantum)`
- **B)** `(exec_t < switch_t) e (exec_t < quantum)`
- **C)** `(exec_t > switch_t) e (exec_t < quantum)`
- **D)** `(exec_t < switch_t) e (exec_t > quantum)`
- **E)** `(exec_t + switch_t) > quantum`

**Lógica da Questão:** Para bom desempenho em RR sem *overhead* excessivo, o `quantum` deve ser maior que o surto típico de CPU (`exec_t < quantum`, permitindo terminar o surto antes da preempção) e o tempo útil de CPU deve superar o custo da troca de contexto (`exec_t > switch_t`).

---

## 4. Diretrizes Obrigatórias para a IA (Motor de Simulados Noesis)

1. **Rigor formal de pós-graduação em Computação:** usar notação matemática/algorítmica precisa ($\Theta, O, \Omega$, $\sum m$, C/C++, SQL, grafos, autômatos).
2. **Incluir blocos de código reais e rastreio:** gerar trechos curtos de código em C, pseudocódigo ou SQL que exijam execução mental passo a passo (ponteiros, recursão, concorrência, complexidade assintótica).
3. **5 alternativas (`A` a `E`)** com distratores que reflitam **erros técnicos clássicos** (*off-by-one*, ignorar condição de corrida, confundir Mealy e Moore, usar $n-1$ vs. $n(n-1)/2$).
4. **Cuidar da unicidade de resposta:** garantir que não haja duas expressões logicamente equivalentes entre as opções.
5. **Divisão Sequencial por Cadernos/Disciplinas (Sem Mistura Aleatória):** Ao gerar simulados ou baterias sequenciais, **não misture disciplinas alternadamente dentro do mesmo bloco**. Respeite rigorosamente a ordem dos blocos da prova (1) Matemática da Computação -> 2) Fundamentos da Computação -> 3) Tecnologia da Computação), preenchendo integralmente a cota de cada disciplina antes de passar para a próxima e identificando o campo `discipline` em cada questão.
