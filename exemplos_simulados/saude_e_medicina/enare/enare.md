# ENARE — Exame Nacional de Residência (Ebserh / FGV — Medicina e Multiprofissional)

> Guia de parâmetros para geração e correção de simulados pela IA — alinhado às provas oficiais de **Acesso Direto** do **ENARE** (organização **Ebserh** e banca executora **FGV** nas edições recentes).

---

## 1. Requisitos e Estrutura Oficial

O ENARE unifica a seleção para programas de **Residência Médica** (Acesso Direto e Pré-requisito) e **Residência Multiprofissional/Uniprofissional em Saúde** em dezenas de hospitais universitários e instituições públicas do Brasil.

| Modalidade | Prova Objetiva | Questões e Alternativas | Pontuação e Análise Curricular |
| :--- | :--- | :--- | :--- |
| **Medicina — Acesso Direto** | 5 horas · **100 questões** | **20 questões por Grande Área** · **5 alternativas (`A–E`)** | **90%** Prova Objetiva + **10%** Análise Curricular |
| **Medicina — Áreas com Pré-requisito** | 4–5 horas · **80 questões** | Conteúdo específico da especialidade base · **5 alternativas (`A–E`)** | **90%** Prova Objetiva + **10%** Análise Curricular |
| **Multiprofissional** | 4 horas · **60 questões** | **20 comuns (SUS/Saúde Coletiva)** + **40 específicas** · `A–E` | **90%** Prova Objetiva + **10%** Análise Curricular |

### Distribuição das 5 Grandes Áreas (Medicina — Acesso Direto)
1. **Clínica Médica** (20 questões)
2. **Cirurgia Geral** (20 questões)
3. **Ginecologia e Obstetrícia** (20 questões)
4. **Pediatria** (20 questões)
5. **Medicina Preventiva e Social / Saúde Coletiva** (20 questões — SUS, atenção primária, epidemiologia e ética médica)

---

## 2. Lógica de Elaboração e Arquitetura dos Distratores (Padrão Ebserh / FGV)

Com a assunção da execução pela **FGV** nos editais recentes do ENARE, o nível de exigência clínica e textual aproximou-se dos grandes exames de São Paulo (USP/UNICAMP/UNIFESP), mantendo forte alinhamento aos protocolos brasileiros (**Ministério da Saúde, PCDTs, ATLS, ACLS, PALS, FEBRASGO, SBP**):

1. **Casos Clínicos Longos e Completos:** Diferente de bancas decorebas, os enunciados trazem anamnese detalhada, sinais vitais, exames laboratoriais e frequentemente descrição ou imagem de ECG, radiografia, tomografia, partograma ou curva de crescimento da caderneta da criança.
2. **Cobrança de Diretrizes Recentes e Protocolos Nacionais (SUS):**
   - **Preventiva:** Leis `8.080/90` e `8.142/90`, PNAB, financiamento do SUS, vigilância epidemiológica, notificações compulsórias (imediatas em 24h vs. semanais), sensibilidade/especificidade/VPP/NNT e bioética.
   - **Clínica/Infecto:** Novas diretrizes de sepse, insuficiência cardíaca (iSGLT2, ARNI), bactérias multirresistentes (CRAB/KPC), tuberculose e arboviroses (manejo da Dengue — grupos A, B, C e D do MS!).
3. **Arquitetura dos 5 Distratores (`A–E`) no Estilo FGV/ENARE:**
   - **Alternativas longas e pareadas:** As 5 opções costumam ser frases completas contendo **"Conduta + Justificativa/Condição"**. Se a primeira metade da frase está certa (ex.: *"Solicitar internação em UTI"*), a segunda metade traz uma contraindicação ou erro sutil (*"...e iniciar anticoagulação plena antes da TC de crânio"*).
   - **Erro de escalonamento terapêutico:** Misturar tratamento de **1ª linha** com de **2ª linha** ou reservar terapia combinada para cenários graves versus leves.
   - **Troca de grupos de risco ou idade gestacional/pediátrica:** Ex.: aplicar esquema antibiótico de lactente jovem (< 2 meses) em pré-escolar, ou confundir critérios de pré-eclâmpsia com sinais de gravidade vs. hipertensão gestacional.

---

## 3. Exemplos Reais e Modelos Comentados (Padrão ENARE / FGV)

### Exemplo 1 — Clínica Médica / Infectologia (Baseado em prova oficial ENARE Acesso Direto)
> **Enunciado:** Paciente de 68 anos, internado em Unidade de Terapia Intensiva após trauma abdominal, encontra-se sob ventilação mecânica invasiva e desenvolve pneumonia associada à ventilação no 12º dia de internação. A cultura do aspirado endotraqueal isola *Acinetobacter baumannii* resistente a meropenem, imipenem, ciprofloxacino e piperacilina-tazobactam, caracterizando infecção por CRAB.  
> Considerando as recomendações atuais para o tratamento de infecção invasiva por *Acinetobacter baumannii* resistente a carbapenêmicos, assinale a estratégia antimicrobiana preferencial:
>
> **A.** Sulbactam-durlobactam em monoterapia, reservando a associação com carbapenêmico para isolados com resistência intermediária.  
> **B.** Ampicilina-sulbactam em altas doses associada à polimixina B, independentemente da disponibilidade de sulbactam-durlobactam.  
> **C.** Sulbactam-durlobactam associado à polimixina B, evitando carbapenêmicos diante da resistência microbiológica documentada.  
> **D.** Polimixina B associada ao meropenem em infusão prolongada quando demonstrado sinergismo *in vitro* entre os dois agentes.  
> **E.** Sulbactam-durlobactam associado a imipenem-cilastatina ou meropenem.  
>
> **Gabarito:** **E**  
> **Comentário:** Diretrizes IDSA/infectologia atualizadas recomendam **sulbactam-durlobactam associado a um carbapenêmico (imipenem-cilastatina ou meropenem)** como regime preferencial para CRAB (reservando ampicilina-sulbactam + segundo agente apenas quando sulbactam-durlobactam não está disponível). Note o típico padrão FGV em que as 5 opções citam exatamente os mesmos fármacos combinados de formas sutis!

### Exemplo 2 — Medicina Preventiva / Epidemiologia (Padrão ENARE)
> **Enunciado modelo:** Um município implementa novo teste rápido para rastreamento de infecção sexualmente transmissível em população de baixa prevalência (1%). Sabe-se que o teste possui sensibilidade de 95% e especificidade de 90%. Sobre os indicadores de validade e desempenho desse teste nesse cenário populacional, assinale a afirmativa correta:
>
> **A.** A alta sensibilidade garante que o Valor Preditivo Positivo (VPP) será superior a 90%.  
> **B.** A redução da prevalência da doença na população testada tende a reduzir o VPP e elevar o Valor Preditivo Negativo (VPN).  
> **C.** Sensibilidade e especificidade variam diretamente conforme a prevalência da doença na comunidade.  
> **D.** Para confirmar casos em teste de rastreamento inicial, prioriza-se um segundo exame de alta sensibilidade e baixa especificidade.  
> **E.** O número de falsos negativos supera expressivamente o número de falsos positivos em cenários de baixa prevalência.  
>
> **Gabarito:** **B**  
> **Comentário:** Sensibilidade e especificidade são propriedades intrínsecas do teste (não variam com a prevalência — descarta **C**). Já o **VPP** cai drasticamente em populações de baixa prevalência (muitos falsos positivos frente a poucos doentes reais — descarta **A** e **E**), enquanto o **VPN** aumenta.

---

## 4. Diretrizes Obrigatórias para a IA (Geração de Simulados)

1. **Equilíbrio exato das 5 Grandes Áreas:** Quando gerar simulados completos ou parciais de **ENARE Acesso Direto**, distribua as questões igualmente entre **Clínica Médica, Cirurgia Geral, GO, Pediatria e Medicina Preventiva** (20% cada).
2. **Estilo clínico brasileiro + padrão FGV:** Redija casos clínicos ricos com dados vitais e exames em unidades usadas no Brasil (ex.: `mg/dL`, `mEq/L`, `mmHg`, `bpm`, `irpm`), adotando condutas dos **Protocolos do Ministério da Saúde / PCDT / SBP / FEBRASGO / ATLS-ACLS**.
3. **Construção de alternativas com dupla proposição:** Em ao menos 50% das questões, construa opções `A–E` que contenham **conduta + justificativa/complemento**, exigindo leitura integral da alternativa para evitar cair em meias-verdades.
4. **Gabarito médico estruturado:** Para cada item, apresente:
   - **Diagnóstico sindrômico/etiológico** extraído da vinheta;
   - **Fundamentação pela diretriz atual** que valida o gabarito;
   - **Por que cada distrator (`A–E`) está errado** (ex.: erro de estadiamento, exame proscrito, dose inadequada, falha de conceito epidemiológico).
5. **Divisão Sequencial por Cadernos/Disciplinas (Sem Mistura Aleatória):** Ao gerar simulados ou baterias sequenciais, **não misture disciplinas alternadamente dentro do mesmo bloco**. Respeite rigorosamente a ordem dos blocos da prova (1) Clínica Médica -> 2) Cirurgia Geral -> 3) Ginecologia e Obstetrícia -> 4) Pediatria -> 5) Medicina Preventiva e Social (SUS)), preenchendo integralmente a cota de cada disciplina antes de passar para a próxima e identificando o campo `discipline` em cada questão.
