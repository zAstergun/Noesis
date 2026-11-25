# ANPEC — Exame Nacional de Seleção em Economia (Pós-Graduação)

> Guia de parâmetros para geração e correção de simulados pela IA — estruturado conforme o modelo oficial das provas de **Macroeconomia, Microeconomia, Matemática, Estatística e Economia Brasileira** da **ANPEC**.

---

## 1. Requisitos e Estrutura Oficial

O Exame Nacional da **ANPEC** seleciona candidatos para mestrados e doutorados em Economia no Brasil. Todas as questões objetivas seguem o formato rigoroso de **itens numerados de `0` a `4`** para julgamento **Verdadeiro (`V`) ou Falso (`F`)**, com **fator de penalização ao chute**.

| Prova | Estrutura | Regra de Pontuação |
| :--- | :--- | :--- |
| **Macroeconomia** | 15 questões (cada uma com 5 itens `0, 1, 2, 3, 4` -> 75 itens) · 2h | Item certo: **`+1,0`** · Item errado: **`-1,0`** (ou fração conforme edital; tradicionalmente 1 errado anula 1 certo) · Em branco: **`0`** |
| **Microeconomia** | 15 questões (itens `0–4`) · 2h | Idem (Nota padronizada por média e desvio-padrão do ano!) |
| **Matemática** | 15 questões (itens `0–4`) · 2h | Cálculo I/II/III, Álgebra Linear, Otimização com/sem restrições (Kuhn-Tucker), Equações Diferenciais e em Diferenças |
| **Estatística e Econometria** | 15 questões (itens `0–4`) · 2h | Probabilidade, Inferência, MQO (OLS), Gauss-Markov, Variáveis Instrumentais, Séries Temporais |
| **Economia Brasileira** | 15 questões (itens `0–4`) · 2h *(peso variável por centro)* | História econômica do Brasil (Café, Vargas, JK, PAEG, Milagre, Crise da Dívida, Plano Real, pós-1999) |

*(Algumas edições incluem também questões abertas/numéricas de 00 a 99 no bloco quantitativo; indique claramente ao gerar simulado quando usar V/F `0–4` ou cálculo aberto `00–99`.)*

---

## 2. Lógica de Elaboração e Arquitetura dos Itens (`0` a `4`)

1. **Formato misto por questão (`0–4`):** Dentro de uma mesma questão temática (ex.: *Modelo IS-LM em economia aberta*, *Teoria da Firma*, *MQO e Viés de Variável Omitida*), os 5 itens misturam **teoria formal, manipulação algébrica rápida e implicação econômica** — e cada item é avaliado de forma **independente** (V, F ou Branco).
2. **Sinalização de hipóteses matemáticas e sinais de derivadas:**
   - A ANPEC testa se o candidato checa rigorosamente **concavidade/convexidade**, **sinais de derivadas parciais** ($\frac{\partial h_i}{\partial p_i} \le 0$ vs. demanda marshalliana), **condições de primeira e segunda ordem** e **hipóteses de modelos** (ex.: mobilidade perfeita de capitais com câmbio fixo vs. flutuante no Mundell-Fleming).
3. **Armadilhas típicas dos itens Falsos (`F`):**
   - **Troca entre demanda Marshalliana e Hicksiana** (ou entre Bem Inferior comum e Bem de Giffen);
   - **Inversão de política fiscal/monetária no Mundell-Fleming:** Dizer que política monetária é eficaz com câmbio fixo e alta mobilidade de capitais (quando na verdade é ineficaz, sendo a *fiscal* a eficaz!);
   - **Violação sutil das hipóteses de Gauss-Markov:** Confundir *inexistência de viés* com *eficiência (variância mínima)* quando há **heterocedasticidade** (MQO continua não-viesado e consistente, mas deixa de ser BLUE e os erros-padrão ficam incorretos!).
   - **Economia Brasileira:** Trocar datas/ministros/mecanismos entre planos de estabilização (*PAEG* vs. *Cruzado* vs. *Collor* vs. *Real* — ex.: URV foi no Plano Real, congelamento de preços foi no Cruzado).

---

## 3. Exemplos Reais e Modelos Comentados (Padrão ANPEC)

### Exemplo 1 — Microeconomia (Teoria do Consumidor — Formato Oficial `0` a `4`)
> **Questão:** Com base na Teoria do Consumidor e nas propriedades das funções de demanda e utilidade, julgue os itens a seguir como **V (Verdadeiro)** ou **F (Falso)**:  
> **(0)** Se as preferências do consumidor são estritamente convexas, a taxa marginal de substituição é decrescente ao longo de uma curva de indiferença.  
> **(1)** A função de demanda hicksiana (compensada) de um bem normal pode ser positivamente inclinada em relação ao próprio preço se o efeito-renda superar o efeito-substituição.  
> **(2)** Em uma economia com apenas dois bens e preferências localmente não saciadas, ambos os bens não podem ser inferiores simultaneamente.  
> **(3)** Se a função de utilidade é homotética, as curvas de Engel para todos os bens são semirretas lineares que partem da origem.  
> **(4)** Pela Identidade de Roy, a função de demanda marshalliana pode ser obtida diretamente derivando a função dispêndio em relação ao preço do bem.  
>
> **Gabarito Comentado:**  
> - **(0) V:** Convexidade estrita implica TMS estritamente decrescente ao longo da curva de indiferença.  
> - **(1) F:** Pela negatividade da matriz de Slutsky e pelo **Lema de Shephard**, $\frac{\partial h_i(p,u)}{\partial p_i} \le 0$ **sempre** (mesmo para bens de Giffen — que envolvem demanda *marshalliana*, não hicksiana!).  
> - **(2) V:** Pela agregação de Engel ($\sum s_i \varepsilon_{i,m} = 1$), a média ponderada das elasticidades-renda é 1; logo, ao menos um bem precisa ter $\varepsilon_{i,m} > 0$ (ser normal).  
> - **(3) V:** Preferências homotéticas implicam expansão radial do consumo proporcional à renda.  
> - **(4) F:** Derivar a **função dispêndio** dá a demanda **hicksiana** (**Lema de Shephard**); a **Identidade de Roy** deriva a **função utilidade indireta** ($x_i = -\frac{\partial V/\partial p_i}{\partial V/\partial m}$).

### Exemplo 2 — Macroeconomia (Mundell-Fleming / Curva de Phillips)
> **Questão:** Em um modelo Mundell-Fleming tradicional com preços rígidos, mobilidade perfeita de capitais e taxa de câmbio **flutuante**, julgue:  
> **(0)** Uma expansão monetária provoca depreciação cambial, estimula as exportações líquidas e eleva o produto de equilíbrio. -> **V**  
> **(1)** Uma expansão fiscal eleva a taxa de juros doméstica, provoca entrada de capitais, aprecia a moeda local e gera *crowding out* total sobre o produto (no caso de economia pequena com $i = i^*$). -> **V**  
> *(Na ANPEC, inverter "flutuante" por "fixo" em um único item cria imediatamente um item `F` preciso.)*

---

## 4. Diretrizes Obrigatórias para a IA (Geração de Simulados)

1. **Use estritamente a estrutura `0, 1, 2, 3, 4` com julgamento `V / F`:** Toda questão gerada no estilo ANPEC (exceto se o usuário pedir questão aberta numérica `00–99`) deve conter exatamente **5 afirmativas independentes numeradas de `(0)` a `(4)`**.
2. **Aplique o sistema de correção com penalidade na avaliação:** Ao corrigir respostas enviadas pelo usuário, instrua que ele pode responder `V`, `F` ou `Branco`, e calcule **Pontos Líquidos = Acertos − Erros** (itens em branco = 0), simulando a gestão estratégica de risco da prova real!
3. **Rigor matemático e econômico formal:** Utilize notação matemática precisa ($\LaTeX$: matrizes hessianas, lagrangeanos, multiplicadores de Lagrange $\lambda$, elasticidades, esperança condicional $E[u_i \mid X_i] = 0$) em Micro, Macro, Matemática e Estatística.
4. **Cobertura equilibrada de Economia Brasileira:** Quando gerar itens de Economia Brasileira, baseie-se na historiografia consagrada da prova (Furtado, Prado Jr., Tavares, Giambiagi/Villela — *Economia Brasileira Contemporânea*).
5. **Divisão Sequencial por Cadernos/Disciplinas (Sem Mistura Aleatória):** Ao gerar simulados ou baterias sequenciais, **não misture disciplinas alternadamente dentro do mesmo bloco**. Respeite rigorosamente a ordem dos blocos da prova (1) Microeconomia -> 2) Macroeconomia -> 3) Matemática -> 4) Estatística e Econometria -> 5) Economia Brasileira), preenchendo integralmente a cota de cada disciplina antes de passar para a próxima e identificando o campo `discipline` em cada questão.
