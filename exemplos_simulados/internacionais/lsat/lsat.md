# LSAT — Law School Admission Test (LSAC)

> Guia de parâmetros para geração e correção de simulados pela IA — atualizado para a estrutura vigente da **LSAC** (após a remoção oficial dos *Logic Games / Analytical Reasoning* em agosto de 2024).

---

## 1. Requisitos e Estrutura Oficial

O LSAT é o exame padronizado obrigatório para ingresso em faculdades de Direito (*JD programs*) nos EUA e Canadá. Opera na escala de **120 a 180 pontos** (mediana histórica ~152; Top-14 Law Schools exigem tipicamente **170+**). **Não penaliza erro** (apenas acertos contam para o *raw score* convertido na escala 120–180).

| Seção | Duração | Questões | Papel na Nota |
| :--- | :--- | :--- | :--- |
| **Logical Reasoning (LR) — Seção 1** | 35 min | 24–26 questões | **Pontuada (~1/3 do score)** |
| **Logical Reasoning (LR) — Seção 2** | 35 min | 24–26 questões | **Pontuada (~1/3 do score)** |
| **Reading Comprehension (RC)** | 35 min | 26–28 questões (4 passagens: 3 simples + 1 *Comparative Reading*) | **Pontuada (~1/3 do score)** |
| **Seção Experimental (Unscored)** | 35 min | 1 seção extra aleatória de LR ou RC | **Não pontuada** (pré-teste da LSAC) |
| **LSAT Writing (Argumentative Writing)** | 50 min (15 min análise + 35 min escrita) | 1 redação argumentativa online separada | Não entra no score 120–180, mas é enviada às faculdades |

*Atualização crítica:* Os antigos **Logic Games (*Analytical Reasoning*)** foram definitivamente substituídos por uma **segunda seção pontuada de Logical Reasoning**. Todas as questões possuem **5 alternativas (`A, B, C, D, E`)**.

---

## 2. Lógica de Elaboração e Arquitetura dos Distratores

O LSAT é considerado o exame de lógica verbal mais rigoroso do mundo. Cada questão de **Logical Reasoning (LR)** segue uma anatomia exata: **Estímulo (Argumento ou Conjunto de Fatos) -> Comando (*Question Stem*) -> 5 Opções (`A–E`)**.

### Taxonomia Completa dos Comandos de Logical Reasoning
1. **Family 1 — Must Be True / Inference / Most Strongly Supported:** Tudo o que está nas premissas é aceito; a resposta correta é deduzida estritamente (cuidado com saltos de *some -> most* ou *most -> all*).
2. **Family 2 — Necessary Assumption vs. Sufficient Assumption:**
   - **Necessary Assumption** (*"depends on assuming"*): Se **negada** (*Negation Test*), destrói o argumento. Costuma ter linguagem modesta (*"at least some"*, *"not entirely"*).
   - **Sufficient Assumption** (*"follows logically if assumed"*): Fecha 100% a lacuna dedutiva (`A -> B`, `B -> C`, logo `A -> C`). Costuma ser forte e formal.
3. **Family 3 — Strengthen / Weaken / Flaw / Evaluate:**
   - **Flaw in the Reasoning:** Nomear a falácia exata em linguagem abstrata (*confundir condição necessária com suficiente*, *correlação vs. causalidade*, *equívoco semântico*, *falácia de composição/divisão*).
   - **Strengthen / Weaken:** Novo fato que altera a probabilidade da conclusão (não precisa provar 100%, apenas mover a agulha lógica).
4. **Family 4 — Parallel Reasoning / Parallel Flaw / Principle / Method of Reasoning:** Requer abstrair a estrutura formal (`Se X, então Y; não Y, logo não X` ou erro `Se X, então Y; não X, logo não Y`) e encontrar outro tema com a **mesma arquitetura lógica exata**.

### Anatomia dos Distratores da LSAC
- **Out of Scope / Irrelevant Comparison:** Traz consideração moral/financeira quando a conclusão é puramente empírica ou causal.
- **Necessary vs. Sufficient Confusion:** Inverte `A -> B` para `B -> A` ou `~A -> ~B`.
- **180-Degree Opposite:** Faz exatamente o oposto do pedido (ex.: fortalece em questão de *Weaken*, ou descreve uma premissa oposta em *Point at Issue*).
- **Too Extreme:** Usa quantificadores absolutos (*all, never, only, impossible*) quando o argumento suporta apenas *some* ou *likely*.

---

## 3. Exemplos Reais e Modelos Comentados (Padrão LSAC)

### Exemplo 1 — Necessary Assumption (Padrão LSAC)
> **Stimulus:** *Architect: The city's new public library building features an innovative glass-and-steel atrium designed to maximize natural sunlight. Because studies show that natural sunlight significantly boosts workplace productivity and overall mood, the employees working in this new library will inevitably experience higher morale and efficiency than they did in the old, windowless building.*
>
> **Question Stem:** Which one of the following is an assumption on which the architect's argument depends?  
> **A.** The old library building had no artificial lighting capable of mimicking the effects of natural sunlight.  
> **B.** The employees will spend a significant portion of their working hours inside or directly affected by the light of the new atrium.  
> **C.** Most modern public libraries are moving toward glass-and-steel architectural designs.  
> **D.** Increased employee morale is more important to the city than the financial cost of constructing the atrium.  
> **E.** The architectural design of the new library will not create any structural maintenance issues in the future.  
>
> **Gabarito:** **B**  
> **Teste da Negação:** Se negarmos **B** (*"Employees will NOT spend a significant portion of their working hours affected by the light of the atrium"* — ex.: trabalham em porões/arquivos fechados), a luz natural do átrio não os atinge e a conclusão desaba. **A** é forte demais; **D** e **E** são *out of scope*.

### Exemplo 2 — Weaken (Falácia Causal — Padrão LSAC)
> **Stimulus:** *A recent study of city motorists found that drivers who regularly listened to high-tempo, energetic music while commuting had a 30 percent higher rate of traffic violations—such as speeding and running red lights—than drivers who listened to talk radio or low-tempo music. Therefore, to reduce the frequency of traffic violations on city roads, local authorities should ban drivers from playing high-tempo music through their vehicle audio systems.*
>
> **Question Stem:** Which one of the following, if true, most seriously weakens the argument?  
> **A.** Many drivers who listen to talk radio during their commutes report feeling more drowsy and less alert than those who listen to music.  
> **B.** The city's police force has historically targeted drivers playing loud music more frequently than other motorists.  
> **C.** Drivers prone to aggressive behavior and risk-taking are significantly more likely to choose high-tempo music than other drivers.  
> **D.** Modern vehicle audio systems make it easy for drivers to switch between talk radio and music channels seamlessly.  
> **E.** The cost of enforcing a ban on high-tempo music would exceed the financial savings generated by reducing traffic accidents.  
>
> **Gabarito:** **C**  
> **Comentário:** O estímulo comete a falácia *Correlação -> Causalidade*. **C** apresenta uma **terceira causa comum / viés de autosseleção**: motoristas já agressivos escolhem música agitada; logo, proibir a música não eliminará o comportamento agressivo nem as infrações. (**E** é irrelevante ao objetivo estrito de *reduzir infrações*).

### Exemplo 3 — Reading Comprehension (Comparative Reading)
> No LSAT, **Passage 4 (Comparative Reading)** traz dois textos curtos **Passage A** e **Passage B** (ex.: duas decisões jurídicas divergentes ou duas teorias filosóficas sobre propriedade intelectual) com questões do tipo: *"Both authors would be most likely to agree with which statement?"* ou *"Passage B's discussion of X serves primarily to undermine which claim in Passage A?"*.

---

## 4. Diretrizes Obrigatórias para a IA (Geração de Simulados)

1. **NÃO gere Logic Games (Analytical Reasoning):** A menos que o usuário peça explicitamente o formato legado pré-2024, gere simulados compostos estritamente por **Logical Reasoning** (prioritário) e **Reading Comprehension** (incluindo *Comparative Reading* A/B).
2. **Precisão formal de quantificadores e condicionais:** Em *LR*, preze pelo uso cirúrgico de operadores lógicos em inglês (`all, most, some, none, only if, unless, if and only if`). Lembre que `unless X` equivale logicamente a `if not X`.
3. **5 alternativas (`A–E`) em inglês jurídico/acadêmico denso:** Evite frases simplórias; cada estímulo deve conter premissas bem delimitadas e uma lacuna lógica testável de forma inequívoca.
4. **No gabarito comentado:** Sempre explicite:
   - **Estrutura do argumento** (Premissas + Premissa Subentendida/Falácia + Conclusão);
   - **Por que a correta resolve o comando** (aplicando *Negation Test* em Necessary Assumption ou diagrama condicional `A -> B` em Flaw/Sufficient);
   - **Diagnóstico de cada distrator (`A–E`)** usando nomenclatura técnica (*Out of Scope, Opposite, Necessary/Sufficient Reversal, Too Strong*).
5. **Divisão Sequencial por Cadernos/Disciplinas (Sem Mistura Aleatória):** Ao gerar simulados ou baterias sequenciais, **não misture disciplinas alternadamente dentro do mesmo bloco**. Respeite rigorosamente a ordem dos blocos da prova (1) Logical Reasoning -> 2) Reading Comprehension & Comparative), preenchendo integralmente a cota de cada disciplina antes de passar para a próxima e identificando o campo `discipline` em cada questão.
