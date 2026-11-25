# USMLE — United States Medical Licensing Examination (Step 1 & Step 2 CK)

> Guia de parâmetros para geração e correção de simulados pela IA — alinhado às diretrizes oficiais da **NBME / FSMB** (`usmle.org`) e ao banco oficial de questões comentadas (*Free 120*).

---

## 1. Requisitos e Estrutura Oficial

O USMLE é o exame em etapas exigido para residência médica e licenciamento nos Estados Unidos. Tanto o **Step 1** quanto o **Step 2 CK** utilizam exclusivamente questões de múltipla escolha baseadas em **vinhetas clínicas de pacientes reais simulados** (com 4 a 5, ocasionalmente até 10 opções em quadros comparativos, sendo **5 opções `A–E`** o padrão majoritário).

| Etapa | Foco Avaliativo | Duração e Volume | Pontuação / Aprovação |
| :--- | :--- | :--- | :--- |
| **USMLE Step 1** | **Ciências Básicas aplicadas à clínica:** Anatomia, Fisiologia, Patologia, Farmacologia, Microbiologia, Imunologia, Bioquímica, Bioestatística | **8 horas** (7 blocos de 60 min · até **280 questões**, ~40/bloco) | **Pass / Fail** (escala numérica abolida desde 2022; limiar equivalente ~196) |
| **USMLE Step 2 CK** | **Conhecimento Clínico e Manejo:** Clínica Médica, Cirurgia, Pediatria, Ginecologia/Obstetrícia, Psiquiatria, Medicina Preventiva | **9 horas** (8 blocos de 60 min · até **318 questões**, ~38–40/bloco) | **Score numérico 1–300** (nota mínima de aprovação **214**; competitiva para *Match* ≥ 250) |

*Nota sobre Step 3:* Realizado após o início da residência (2 dias, inclui simulações interativas *CCS — Computer-based Case Simulations*).

---

## 2. Lógica de Elaboração e Arquitetura dos Distratores

A NBME segue um algoritmo rigoroso chamado **"Two-Step / Three-Step Clinical Reasoning"**: a questão **nunca** pergunta apenas *"Qual é a doença do paciente?"* se puder exigir que o candidato **1) faça o diagnóstico pela vinheta** e **2) responda ao mecanismo fisiopatológico (Step 1) ou à conduta imediata (Step 2 CK)**.

### Anatomia da Vinheta NBME (Ordem Obrigatória)
1. **Demografia + Queixa Principal + Duração:** *"A 32-year-old woman comes to the physician because of a 3-month history of fatigue..."*
2. **História Médica Pregressa / Medicamentos / Hábitos:** Comorbidades relevantes ou *distratores clínicos benignos*.
3. **Exame Físico + Sinais Vitais completos:** Temperatura, FC, FR, PA, SpO₂, achados positivos e **negativos pertinentes**.
4. **Exames Laboratoriais / Imagem / Histologia / Gráfico:** Frequentemente apresentados com valores fora da referência sem rotular "elevado".
5. **Lead-in Question (*"Which of the following..."*):**
   - **Step 1:** *"Which of the following is the most likely mechanism / receptor / enzyme / pathogen / adverse effect?"*
   - **Step 2 CK:** *"Which of the following is the most appropriate next step in management?"* · *"Which of the following is the best initial diagnostic test?"* · *"Which of the following is the most likely diagnosis?"*

### Estratégia dos Distratores NBME
- **Todas as opções são homogêneas:** Se o gabarito é uma enzima, todas as 5 opções são enzimas; se é um exame, todas são modalidades diagnósticas.
- **Conduta correta em momento errado (Step 2 CK):** Uma opção traz o exame *padrão-ouro* (ex.: angiografia ou biópsia), mas antes dele exige-se um exame inicial de triagem ou estabilização (*ABCs* / ultrassom à beira-leito / ECG) — tornando o padrão-ouro um distrator!
- **Não há pistas artificiais ("buzzwords"):** A NBME substitui deliberadamente *buzzwords* clássicas (*"café-au-lait spots"*, *"bamboo spine"*) por descrições objetivas (*"hyperpigmented macules with smooth borders"*, *"fusion of vertebral bodies with loss of lumbar lordosis"*).

---

## 3. Exemplos Reais e Modelos Oficiais (`usmle.org`)

### Exemplo 1 — USMLE Step 1 (Item Oficial de Referência — `usmle.org`)
> **Vignette:**  
> *A 32-year-old woman with type 1 diabetes mellitus has had progressive renal failure during the past 2 years. She has not yet started hemodialysis. Examination shows no abnormalities. Hemoglobin concentration is 9.0 g/dL, hematocrit is 28%, and mean corpuscular volume is 94 μm³. Peripheral blood smear shows normochromic, normocytic cells.*
>
> **Which of the following is the most likely cause of this patient's current condition?**  
> **A.** Acute blood loss  
> **B.** Chronic lymphocytic leukemia  
> **C.** Erythrocyte enzyme deficiency  
> **D.** Erythropoietin deficiency  
> **E.** Immunohemolysis  
>
> **Gabarito:** **D (Erythropoietin deficiency)**  
> **Raciocínio NBME:** Nefropatia diabética progressiva -> lesão das células intersticiais peritubulares renais -> redução da síntese de eritropoietina (EPO) -> anemia normocítica normocrômica (Hb 9.0, VCM 94). **A** poderia ser normocítica, mas sem história de sangramento/instabilidade; **C/E** causariam reticulocitose, esferócitos/bite cells ou icterícia.

### Exemplo 2 — USMLE Step 2 CK (Raciocínio "Next Step in Management")
> **Vignette modelo NBME:**  
> *A 58-year-old man comes to the emergency department 40 minutes after the sudden onset of severe substernal chest pain radiating to his left jaw. He has hypertension and smokes 1 pack of cigarettes daily. Temperature is 37.0°C, pulse is 102/min, respirations are 20/min, and blood pressure is 148/92 mm Hg. Physical examination shows diaphoresis and normal heart sounds. An ECG shows 3-mm ST-segment elevations in leads II, III, and aVF.*
>
> **In addition to aspirin and heparin, which of the following is the most appropriate next step in management?**  
> **A.** Measure serum troponin I concentration  
> **B.** Perform urgent percutaneous coronary intervention (PCI)  
> **C.** Administer intravenous nitroglycerin before obtaining right-sided ECG leads  
> **D.** Order transthoracic echocardiography  
> **E.** Schedule an exercise stress test  
>
> **Gabarito:** **B (Urgent PCI)**  
> **Raciocínio:** Supra de ST inferior (II, III, aVF) + quadro agudo = IAMCSST (STEMI). Nunca se atrasa a terapia de reperfusão (**PCI imediata**) aguardando resultado de troponina (**A**) ou eco (**D**); além disso, **C** é perigoso em IAM inferior pelo risco de envolvimento de VD e hipotensão grave com nitrato!

---

## 4. Diretrizes Obrigatórias para a IA (Geração de Simulados)

1. **Estrutura estrita de vinheta NBME:** Todo item gerado para USMLE Step 1 ou Step 2 CK deve conter **idade, sexo, queixa + tempo de evolução, sinais vitais completos e achados objetivos sem *buzzwords* fáceis**, finalizando com comando padronizado (*"Which of the following..."*).
2. **Linguagem e Unidades:** Por padrão, redija vinhetas de USMLE em **inglês médico norte-americano** com unidades convencionais americanas (`mg/dL`, `g/dL`, `mm Hg`, `μm³`, `mEq/L`), fornecendo tradução/comentário didático em português apenas se o usuário solicitar em português.
3. **Diferenciação Step 1 vs. Step 2 CK:**
   - Se o usuário pedir **Step 1**: o comando final deve mirar o **mecanismo molecular/fisiológico, enzima, receptor, agente etiológico, achado histopatológico ou mecanismo de fármaco** (não a prescrição clínica direta).
   - Se o usuário pedir **Step 2 CK**: exija **diagnóstico mais provável, exame diagnóstico inicial vs. padrão-ouro, conduta terapêutica imediata (*next step in management*) ou prevenção/rastreamento (USPSTF)**.
4. **Inclua matriz de exclusão de distratores:** No gabarito, explique exatamente qual dado da vinheta descarta cada uma das alternativas incorretas (`A–E`).
5. **Divisão Sequencial por Cadernos/Disciplinas (Sem Mistura Aleatória):** Ao gerar simulados ou baterias sequenciais, **não misture disciplinas alternadamente dentro do mesmo bloco**. Respeite rigorosamente a ordem dos blocos da prova (1) Pathophysiology & Basic Sciences (Step 1) -> 2) Internal Medicine & Clinical Diagnosis -> 3) Next Step in Management & Preventive Care), preenchendo integralmente a cota de cada disciplina antes de passar para a próxima e identificando o campo `discipline` em cada questão.
