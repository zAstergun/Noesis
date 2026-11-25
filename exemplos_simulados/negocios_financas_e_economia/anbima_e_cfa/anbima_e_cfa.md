# Certificações Financeiras — ANBIMA (CPA, C-Pro R, C-Pro I / Legado CPA-10, CPA-20, CEA) & CFA Level I

> Guia de parâmetros para geração e correção de simulados pela IA — cobre o mercado financeiro brasileiro (**ANBIMA**) e a certificação global de investimentos (**CFA Institute Level I**).

---

## 1. Requisitos e Estrutura Oficial

### A. ANBIMA — Novo Modelo de Certificações (Transição CPA-10 / CPA-20 / CEA -> CPA / C-Pro R / C-Pro I)
A ANBIMA reestruturou seu sistema em certificações cumulativas orientadas à jornada prática de atendimento (mantendo compatibilidade de conteúdo nuclear com CPA-10, CPA-20 e CEA):

| Certificação | Escopo Principal | Estrutura e Corte Típico |
| :--- | :--- | :--- |
| **CPA** *(Certificação Profissional ANBIMA — base para atendimento/prospecção; sucede CPA-10/20)* | Sistema Financeiro Nacional (SFN), ética/compliance/PLDFT, economia/finanças, renda fixa, renda variável, fundos (Res. CVM 175) e previdência | ~50–60 questões · 4 alternativas (`A–D`) · **70% de acerto** |
| **C-Pro R** *(Especialista em Relacionamento / Varejo Alta Renda)* | Planejamento financeiro, tributação avançada, alocação por perfil API (*Suitability*), produtos estruturados e derivativos | Questões situacionais e casos práticos · 4 alternativas · **70%** |
| **C-Pro I** *(Especialista em Investimento — equivale ao núcleo técnico do CEA)* | Gestão de portfólios (CAPM, Sharpe, VaR, fronteira eficiente), macroeconomia aplicada, matemática financeira (HP-12C) e tributação internacional | ~70 questões com casos práticos e cálculos · 4 alternativas · **70%** |

### B. CFA Program — Level I (Chartered Financial Analyst — CFA Institute)
- **Formato:** Exame computadorizado de **4h30min** (2 sessões de 2h15min, **180 questões** de múltipla escolha com **3 alternativas `A, B, C`**).
- **10 Tópicos Oficiais e Pesos (CFA Level I):** Ethical and Professional Standards (**15–20%**), Quantitative Methods (**6–9%**), Economics (**6–9%**), Financial Statement Analysis / FSA (**11–14%**), Corporate Issuers (**6–9%**), Equity Investments (**11–14%**), Fixed Income (**11–14%**), Derivatives (**5–8%**), Alternative Investments (**7–10%**), Portfolio Management (**8–12%**).

---

## 2. Lógica de Elaboração e Arquitetura dos Distratores

### ANBIMA (Compliance, Tributação e Cálculos de Renda Fixa/Fundos)
1. **Regulação e Ética (Suitability, PLDFT, Marcação a Mercado):**
   - **API / Suitability:** O profissional **não** pode aplicar recursos em produto incompatível sem **alerta formal prévio e declaração expressa de ciência de desenquadramento** assinada pelo cliente (nunca alterar o perfil manualmente para "Arrojado" sem reavaliação real).
   - **PLDFT (Lavagem de Dinheiro):** 3 fases (**Colocação -> Ocultação -> Integração**); comunicação obrigatória ao **COAF** em até 24h (em sigilo absoluto, proibido avisar o cliente!).
2. **Tributação Brasileira (Pegadinha nº 1):**
   - **Come-Cotas** (maio e novembro): **15% em Fundos de Longo Prazo**, **20% em Curto Prazo**, e **isento em Fundos de Ações (FIA)** e FIIs!
   - **IOF Regressivo:** Incide apenas até o **29º dia** (zera no 30º dia; **não incide sobre Ações/FIA**).
   - **Isenção de IR Pessoa Física:** LCI, LCA, CRI, CRA, Debêntures Incentivadas (Lei 12.431) e Poupança; além de vendas de Ações à vista ≤ **R$ 20.000/mês** (não vale para Day Trade nem FIIs/ETFs!).
3. **Resolução CVM 175 (Marco dos Fundos):** Novo padrão exige citar **Classes e Subclasses**, responsabilidade limitada dos cotistas e separação de patrimônio por classe.

### CFA Level I (3 Opções `A/B/C` + Ethics Adjustment)
1. **3 Alternativas de Altíssima Precisão (`A, B, C`):** Não existem opções obviamente absurdas. Em cálculos financeiros, os dois distratores representam **exatamente os erros de fórmula mais comuns** (ex.: esquecer de subtrair dividendo preferencial no EPS, usar $N$ em vez de $N-1$ no desvio-padrão amostral, errar convenção de contagem de dias em *accrued interest*).
2. **Ethics Adjustment (Peso decisivo):** O **Code of Ethics and Standards of Professional Conduct** é o critério de desempate próximo à nota de corte (*MPS*). Questões nunca perguntam *"O que diz o Standard IV(B)?"* — apresentam um dilema narrativo sutil sobre *Material Nonpublic Information*, *Mosaic Theory*, *Soft Dollars*, *Referral Fees* ou *Gifts from Clients*.

---

## 3. Exemplos Reais e Modelos Comentados

### Exemplo 1 — ANBIMA Suitability / Compliance (Padrão CPA / C-Pro)
> **Enunciado:** Um cliente classificado na Análise do Perfil do Investidor (API) como **Moderado** solicita ao gerente a aplicação integral de sua reserva em um fundo de ações *small caps*, visando alto retorno no curto prazo. Diante das regras de *Suitability* da ANBIMA e CVM, o profissional certificado deve:  
> **A.** Realizar a aplicação imediatamente sem alertas, pois a decisão é soberana do cliente.  
> **B.** Recusar o atendimento e encerrar a conta por incompatibilidade legal de perfil.  
> **C.** Alertar o cliente sobre a incompatibilidade entre o produto e seu perfil API, orientá-lo sobre os riscos envolvidos e exigir declaração expressa de ciência/desenquadramento caso o cliente mantenha a ordem.  
> **D.** Alterar o perfil do cliente no sistema para "Arrojado" para viabilizar a operação sem restrições.  
>
> **Gabarito:** **C**  
> **Comentário:** Regras de *Suitability* exigem transparência, alerta formal de desenquadramento e registro da declaração expressa do investidor antes de executar ordem incompatível.

### Exemplo 2 — CFA Level I Ethics (Standard IV(B) — Cenário Oficial Modelo)
> **Scenario:** *Sarah Jenkins, CFA, is a senior portfolio manager at an investment advisory firm. Recently, one of her affluent clients offered her an all-expenses-paid weekend getaway at a luxury resort as a token of appreciation for generating superior portfolio returns over the past year. Jenkins accepted the trip without notifying her employer in writing, reasoning that the gift was given retrospectively for past performance and did not create a conflict of interest regarding future investment decisions.*  
>
> **Question:** According to the CFA Institute Code of Ethics and Standards of Professional Conduct, did Jenkins violate any standard?  
> **A.** No, because the gift was a retrospective token of appreciation and did not influence her future investment advice.  
> **B.** Yes, because she accepted a gift from a client without obtaining written consent from her employer.  
> **C.** Yes, because accepting any form of luxury gift from a client is strictly prohibited under all circumstances.  
>
> **Gabarito:** **B**  
> **Comentário:** Pelo **Standard IV(B) Additional Compensation Arrangements** (e **Standard I(B) Independence and Objectivity** quanto a presentes vultosos), aceitar presentes/compensações de clientes relacionadas ao desempenho exige **consentimento prévio por escrito do empregador** — mesmo sendo retrospectivo! **C** erra por absolutismo ("prohibited under all circumstances"), armadilha clássica em Ética do CFA.

---

## 4. Diretrizes Obrigatórias para a IA (Geração de Simulados)

1. **Respeite o número exato de alternativas de cada exame:**
   - **ANBIMA:** **4 alternativas (`A–D`)** em português com contexto regulatório brasileiro atual (Resolução **CVM 175**, **Selic/CDI/IPCA**, tabelas de IR/IOF, regras de API e COAF/PLDFT).
   - **CFA Level I:** **3 alternativas (`A–C`)** em inglês financeiro padrão (ou português se o usuário pedir traduzido, mantendo termos técnicos como *Duration, WACC, CAPM, Standard I–VII*).
2. **Matemática financeira executável (C-Pro I / CEA / CFA):** Sempre que gerar questão quantitativa (TIR/IRR, Duration modificada, Sharpe Ratio, Preço Unitário de NTN-B/LTN, VPL/NPV, Imposto de Renda líquido), apresente todos os parâmetros numéricos sem ambiguidade e faça os **2 ou 3 distratores corresponderem a erros aritméticos reais**.
3. **Sem confusão entre regulamentos:** Em ANBIMA, observe prazos vigentes de IOF (até 29 dias), come-cotas (maio/novembro), FGC (limite R$ 250 mil por CPF/instituição e teto global R$ 1 milhão a cada 4 anos) e atualização da **Resolução CVM 175**.
4. **Divisão Sequencial por Cadernos/Disciplinas (Sem Mistura Aleatória):** Ao gerar simulados ou baterias sequenciais, **não misture disciplinas alternadamente dentro do mesmo bloco**. Respeite rigorosamente a ordem dos blocos da prova (1) Ética, Compliance, Suitability & PLDFT -> 2) Economia, SFN & Métodos Quantitativos -> 3) Renda Fixa, Variável, Fundos (CVM 175) & Derivativos -> 4) Tributação & Gestão de Portfólios), preenchendo integralmente a cota de cada disciplina antes de passar para a próxima e identificando o campo `discipline` em cada questão.
