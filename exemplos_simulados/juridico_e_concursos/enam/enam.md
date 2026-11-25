# ENAM — Exame Nacional da Magistratura (ENFAM / FGV)

> Guia de parâmetros para geração e correção de simulados pela IA — alinhado às resoluções do **CNJ / ENFAM** e às provas oficiais aplicadas pela **FGV** (`enfam.jus.br` / `fgv.br`).

---

## 1. Requisitos e Estrutura Oficial

O **ENAM** é o exame nacional unificado de caráter **habilitatório** (requisito prévio para inscrição em concursos da Magistratura estadual, federal, trabalhista e militar em todo o Brasil). **Não é classificatório**, funcionando por aprovação via **nota de corte fixa**.

| Parâmetro | Regra Oficial ENAM (ENFAM / FGV) |
| :--- | :--- |
| **Duração** | **5 horas** |
| **Total de Questões** | **80 questões objetivas** · **5 alternativas (`A, B, C, D, E`)** |
| **Nota de Corte (Ampla Concorrência)** | **70% de acertos** (**56 de 80 questões**) |
| **Nota de Corte (Cotas — Negros, Indígenas, PCD)** | **50% de acertos** (**40 de 80 questões**) |

### Distribuição Exata das Disciplinas (80 Questões)
1. **Direito Constitucional** — **16 questões** *(maior peso — controle de constitucionalidade, federalismo, direitos fundamentais, jurisprudência STF)*
2. **Direito Administrativo** — **10 questões** *(Lei 14.133/2021, improbidade Lei 14.230/2021, intervenção estatal, servidores, atos)*
3. **Noções Gerais de Direito e Formação Humanística** — **6 questões** *(sociologia do direito, psicologia judiciária, filosofia do direito, ética e estatuto da magistratura, teoria da decisão/argumentação)*
4. **Direitos Humanos** — **6 questões** *(Sistema Interamericano CADH, controle de convencionalidade, tratados e grupos vulneráveis)*
5. **Direito Processual Civil** — **12 questões** *(CPC/2015, precedentes vinculantes, tutelas provisórias, recursos, execução)*
6. **Direito Civil** — **12 questões** *(LINDB, obrigações, responsabilidade civil, contratos, família/sucessões, reais)*
7. **Direito Empresarial** — **6 questões** *(sociedades, recuperação judicial/falência Lei 11.101/2005 reformada, títulos)*
8. **Direito Penal** — **12 questões** *(teoria do crime, dosimetria, crimes em espécie, Pacote Anticrime e súmulas STJ/STF)*

*(Atenção: Direito Tributário e Direito Eleitoral/Previdenciário/Ambiental não integram o núcleo isolado das 80 questões do ENAM, salvo interdisciplinaridade com Constitucional/Administrativo.)*

---

## 2. Lógica de Elaboração e Arquitetura dos Distratores (FGV Magistratura)

1. **Casos Hipotéticos Complexos de Aplicação Jurisdicional:** Quase todas as questões colocam o candidato na posição de **Juiz ou Desembargador** decidindo um incidente processual, conflito federativo ou caso de responsabilização (*"O magistrado deverá..."*).
2. **Predominância de Jurisprudência Recente do STF e STJ + Controle de Convencionalidade:** A FGV cobra diretamente **Teses de Repercussão Geral (STF)**, **Recursos Repetitivos (STJ)** e **Jurisprudência da Corte Interamericana de Direitos Humanos (Corte IDH)** aplicada pelo CNJ (ex.: Protocolo para Julgamento com Perspectiva de Gênero / Antidiscriminatório).
3. **Formação Humanística Aplicada (Não Decoreba):** Exige distinguir autores clássicos e contemporâneos aplicados à função judicial (**Hart vs. Dworkin vs. Alexy** — regras vs. princípios, ponderação, *hard cases*; **Weber** — tipos de dominação; vieses cognitivos na decisão judicial — heurísticas de Kahneman).
4. **Arquitetura dos Distratores FGV no ENAM:**
   - **Tese superada (Overruling):** Alternativa traz entendimento antigo do STJ/STF que foi modificado recentemente (ex.: mudança em improbidade culposa após Lei 14.230/21, ou alteração de competência/prescrição).
   - **Confusão entre Controle de Constitucionalidade e Controle de Convencionalidade**, ou entre **efeito vinculante** vs. **eficácia erga omnes** em ADI/ADC/ADPF/Rcl.
   - **Redação longa com inversão sutil no final:** Metade da alternativa reproduz o artigo de lei corretamente e o trecho final troca uma exceção (*"independentemente de autorização judicial"* quando a súmula exige reserva de jurisdição).

---

## 3. Exemplos Reais e Modelos Comentados (Padrão ENAM / FGV)

### Exemplo 1 — Direito Constitucional (Baseado em prova oficial ENAM / FGV)
> **Enunciado:** A intervenção é um mecanismo constitucional que permite à União ou aos Estados intervir temporariamente nos Estados, no Distrito Federal ou nos Municípios, restringindo de forma excepcional a sua autonomia para preservar a integridade da Federação e assegurar a observância de princípios constitucionais.  
> Considerando o sistema de intervenções previsto na Constituição Federal de 1988, assinale a afirmativa correta quanto aos requisitos formais e materiais de decretação:
>
> **A.** O decreto de intervenção federal dependará de provimento, pelo Supremo Tribunal Federal, de representação do Procurador-Geral da República, no caso de recusa à execução de lei federal. *(Atenção: Art. 36, III exige provimento do STF em representação do PGR para recusa à execução de lei federal OU ofensa aos princípios constitucionais sensíveis! Verifique a redação exata do item oficial abaixo)*  
> **B.** O decreto de intervenção dependerá sempre de prévia autorização do Congresso Nacional, mesmo em casos de urgência durante o recesso parlamentar.  
> **C.** O controle político do ato interventivo pelo Poder Legislativo é dispensável se a medida decretada pelo Presidente da República abranger apenas o âmbito municipal. *(Nota: União não intervém em Município de Estado — art. 35!)*  
> **D.** A decretação de intervenção nos Estados para garantir o livre exercício de qualquer dos Poderes nas unidades da federação depende de solicitação do Poder coato ou impedido *(ou requisição do STF, se a coação for contra o Judiciário — art. 36, I)*.  
> **E.** Os atos de intervenção federal decretados pelo Presidente da República prescindem de apreciação pelo Congresso Nacional se o prazo estipulado for inferior a 48 horas.  
>
> **Comentário de gabarito (Padrão FGV):** A questão testa leitura combinada rigorosa dos **arts. 34, 35 e 36 da CF/88**: controle político em 24h (descasa **B** e **E**), impossibilidade de intervenção federal direta em município localizado em Estado (descasa **C**), e distinção exata entre *solicitação* (Executivo/Legislativo) vs. *requisição* (STF) no art. 36, I (**D**). *(Nota: Em A, se o texto oficial dissesse "STJ" em vez de "STF", estaria errado; na CF art. 36, III com EC 45/04, realmente é STF + PGR — na elaboração da IA, mantenha sempre apenas UM gabarito estritamente correto conforme o art. 36!)*

### Exemplo 2 — Formação Humanística / Teoria da Decisão (Padrão ENAM)
> **Enunciado modelo:** Ao analisar um caso difícil (*hard case*) em que duas normas colidem aparentemente, o magistrado recorre à distinção teórica formulada por Robert Alexy entre regras e princípios. Segundo esse referencial jusfilosófico:  
> **A.** A colisão entre dois princípios resolve-se mediante declaração de invalidade de um deles no ordenamento jurídico.  
> **B.** Regras operam como mandados de otimização que devem ser realizados na maior medida possível fática e juridicamente.  
> **C.** Princípios constituem mandados de otimização cuja colisão se resolve na dimensão do peso por meio da técnica da ponderação, sem invalidação abstrata do princípio cedente.  
> **D.** O juiz, diante de lacuna legal, decide exclusivamente por discricionariedade pura segundo Ronald Dworkin.  
> **E.** A subsunção silogística estrita é o único método válido para aplicar princípios constitucionais segundo Alexy.  
>
> **Gabarito:** **C** — **Regras** aplicam-se por subsunção (tudo ou nada; conflito = invalidade/exceção); **Princípios** são *mandados de otimização* solucionados por **ponderação** na colisão concreta (**C**).

---

## 4. Diretrizes Obrigatórias para a IA (Geração de Simulados)

1. **Respeite exatamente a proporção de 8 disciplinas do ENAM:** Se gerar simulado completo ou proporcional (ex.: 40 questões), mantenha o peso oficial (**20% Constitucional, 15% Civil, 15% CPC, 15% Penal, 12,5% Adm, 7,5% Empresarial, 7,5% Humanos, 7,5% Formação Humanística**).
2. **Estilo jurisdicional + FGV:** Enunciados devem apresentar **litígios reais, decisões interlocutórias, recursos ou conflitos normativos**, exigindo que o candidato decida com base em **lei atualizada + jurisprudência vinculante (STF/STJ/Corte IDH)**.
3. **Inclua Formação Humanística e Direitos Humanos com rigor conceitual:** Não reduza a senso comum ético; cite teorias filosóficas/sociológicas do direito, vieses decisórios e protocolos do CNJ.
4. **Sinalize a nota de corte ENAM ao final:** Avalie o desempenho do usuário informando se atingiu **≥ 70%** (ampla concorrência) ou **≥ 50%** (cotas), discriminando acertos por ramo do Direito.
5. **Divisão Sequencial por Cadernos/Disciplinas (Sem Mistura Aleatória):** Ao gerar simulados ou baterias sequenciais, **não misture disciplinas alternadamente dentro do mesmo bloco**. Respeite rigorosamente a ordem dos blocos da prova (1) Direito Constitucional -> 2) Direito Administrativo -> 3) Noções Gerais e Formação Humanística -> 4) Direitos Humanos -> 5) Direito Processual Civil -> 6) Direito Civil -> 7) Direito Empresarial -> 8) Direito Penal), preenchendo integralmente a cota de cada disciplina antes de passar para a próxima e identificando o campo `discipline` em cada questão.
