# DELF / DALF — Diplôme d'Études en Langue Française & Diplôme Approfondi de Langue Française

> Guia de parâmetros para geração e correção de simulados pela IA — cobre **DELF B1, DELF B2 e DALF C1** com base nos modelos oficiais de **France Éducation International (FEI)**.

---

## 1. Requisitos e Estrutura Oficial

Cada exame DELF/DALF avalia 4 competências de 25 pontos cada (**total 100 pontos**). Para aprovação exigem-se **50/100 pontos totais** e **nota mínima de 5/25** em cada uma das 4 provas.

| Exame | Compréhension de l'oral (CO) | Compréhension des écrits (CE) | Production écrite (PE) | Production orale (PO) |
| :--- | :--- | :--- | :--- | :--- |
| **DELF B1** | ~25 min · 3 documentos (2 escutas) | 45 min · 2–3 textos (informativo + prático) | 45 min · 1 ensaio/carta/artigo (160–180 palavras) | 15 min (+10 min prep.) · entrevista + interação + monólogo |
| **DELF B2** | ~30 min · 2 documentos (1 escuta curta + 1 longa com 2 escutas) | 60 min · 2 ou 3 textos (informativo + argumentativo + opiniões cruzadas) | 60 min · 1 tomada de posição argumentada (≥ 250 palavras) | 20 min (+30 min prep.) · exposé argumentatif + débat |
| **DALF C1** | ~40 min · 2 documentos (1 entrevista/conferência longa + vários flashes) | 50 min · 1 texto longo literário/acadêmico (1.500–2.000 palavras) | 2h30 · **Synthèse de documents** (220–240 palavras) + **Essai argumenté** (≥ 250 palavras) | 30 min (+60 min prep.) · exposé de dossier + entretien |

### Formato renovado (FEI 2020–2026)
- Na CE e CO do **DELF B1/B2**, todas as questões passaram a ser **objetivas (QCM de 3 opções e tableau Vrai/Faux ou associação)** — eliminando questões dissertativas na compreensão para padronização da correção automatizada.
- No **DALF C1**, persistem questões abertas de compreensão com exigência de **justificativa ou reformulação** (sem cópia literal do texto), além da dupla prova escrita (*Synthèse* sem opinião pessoal + *Essai* com posicionamento crítico).

---

## 2. Lógica de Elaboração e Arquitetura dos Distratores

1. **Reformulação vs. Cópia Literal (*Piège du mot-à-mot*):** Em QCM do DELF B2 e DALF C1, a alternativa correta reformula a ideia do texto usando sinônimos ou nominalizações (*"réduire les émissions"* -> *"baisser l'empreinte carbone"*). Distratores repetem palavras exatas do parágrafo combinadas a um conectivo de negação ou condição falsa.
2. **Distinção Fato vs. Opinião / Nuance Argumentativa:** O DALF C1 e o DELF B2 exigem identificar se o autor **constata um fato**, **critica uma posição alheia**, **faz uma concessão** (*certes... mais...*, *bien que + subjonctif*) ou **ironiza**. Distratores frequentemente apresentam como tese do autor um argumento que ele citou apenas para refutar.
3. **Articulação Lógica e Coesão:** Os conectores franceses (*néanmoins, en revanche, par conséquent, faute de, dès lors que*) determinam a direção argumentativa. Alterar apenas a relação lógica no item cria o distrator clássico.
4. **Produção Escrita (PE) — Regras de Ouro:**
   - **DELF B2:** Carta formal ao prefeito/diretor/editor ou artigo crítico. Penaliza-se ausência de fórmulas protocolares (*Monsieur le Maire*, *Je vous prie d'agréer, Monsieur, l'expression de mes salutations distinguées*) e falta de progressão argumentativa com exemplos concretos.
   - **DALF C1 Synthèse:** Estritamente proibida a introdução de opinião pessoal (*"À mon avis"*) ou exemplos externos aos 2 ou 3 textos do dossiê; exige reescrita integral (proibida colagem de frases do dossiê).

---

## 3. Exemplos Reais e Modelos Comentados

### Exemplo 1 — Compréhension des écrits (Padrão DELF B2 — QCM 3 opções)
> **Extrait (article d'opinion sur le télétravail):**  
> *"Si le travail à distance a indéniablement permis aux salariés de gagner du temps dans les transports, certaines études sociologiques pointent toutefois un risque d'isolement professionnel et un effacement progressif de la frontière entre vie privée et vie active. Dès lors, de plus en plus d'entreprises reviennent sur le tout-distanciel pour privilégier des modèles hybrides."*
>
> **Question :** Selon l'article, pourquoi de nombreuses entreprises choisissent-elles aujourd'hui le travail hybride ?  
> **A.** Parce que le télétravail complet réduit la productivité technique des équipes.  
> **B.** Afin de limiter les effets négatifs du travail exclusivement à distance sur les employés.  
> **C.** Pour répondre aux demandes des syndicats concernant le temps de transport.  
>
> **Gabarito:** **B**  
> **Comentário:** "Dès lors" conecta os riscos de isolamento e perda de limite vida privada/profissional à adoção de modelos híbridos (**B**). **A** inventa um argumento de produtividade não mencionado (*extrapolation*); **C** distorce a informação sobre tempo de transporte atribuindo-a a sindicatos (*hors-sujet*).

### Exemplo 2 — Compréhension des écrits (Padrão DALF C1 — Nuance / Attitudinal)
> **Extrait (essai académique):**  
> *"L'auteur ne nie pas l'efficacité des algorithmes de recommandation dans la diffusion culturelle ; il s'inquiète cependant de l'uniformisation des goûts qu'ils engendrent insidieusement."*
>
> **Question (QCM / Repérage de point de vue) :** Quelle est l'attitude de l'auteur face aux algorithmes culturels ?  
> **A.** Un rejet catégorique de leur utilité pratique.  
> **B.** Une reconnaissance nuancée accompagnée d'une mise en garde.  
> **C.** Un enthousiasme modéré face à leur potentiel démocratisant.  
>
> **Gabarito:** **B**  
> **Comentário:** Estrutura concessiva ("ne nie pas... cependant s'inquiète") corresponde exatamente a reconhecimento parcial + alerta crítico (**B**).

### Exemplo 3 — Production écrite (Modelo DELF B2 — Prise de position)
> **Consigne :** *Vous habitez dans une ville dont le centre historique va être entièrement interdit aux voitures. Vous écrivez au maire de votre ville pour lui faire part de votre point de vue sur cette décision. Vous exposez vos arguments de manière claire et structurée afin de le convaincre (250 mots minimum).*
>
> **Critérios da grade oficial (25 pts):** *Respect de la consigne* (2 pts), *Correction sociolinguistique* (2 pts), *Capacité à argumenter* (5 pts), *Cohérence et cohésion* (4 pts), *Compétence lexicale* (6 pts), *Compétence grammaticale* (6 pts).

---

## 4. Diretrizes Obrigatórias para a IA (Geração de Simulados)

1. **QCM no formato FEI (3 opções `A / B / C`):** Para **DELF B1 e DELF B2**, gere questões de compreensão com **3 alternativas** (ou matriz *Vrai / Faux + justification* apenas se especificar o formato clássico ou DALF C1).
2. **Textos em francês autêntico de imprensa francófona:** Utilize temas típicos da França e francofonia (ecologia urbana, *laïcité*, educação, mundo do trabalho, inteligência artificial, consumo responsável), com extensão entre 400–600 palavras no B2 e 900–1.500 palavras no C1.
3. **Na geração de tarefas de Production Écrite:**
   - Para **B1** (160–180 palavras): Inclua estímulo simples (fórum, e-mail de amigo, carta a revista) pedindo relato + opinião.
   - Para **B2** (≥ 250 palavras): Exija **contexto comunicativo formal**, destinatário institucional (*Monsieur le Directeur*, *Monsieur le Maire*) e defesa de tese com concessão e refutação.
   - Para **C1** (Synthèse + Essai): Se simular o DALF C1 completo, forneça **2 a 3 textos curtos convergentes/divergentes** para síntese objetiva (sem opinião pessoal) seguida de questão dissertativa opinativa.
4. **Evite distratores gramaticalmente absurdos:** Todas as alternativas devem estar em francês correto; a distinção deve residir estritamente na interpretação semântica, escopo ou atitude discursiva do texto.
5. **Divisão Sequencial por Cadernos/Disciplinas (Sem Mistura Aleatória):** Ao gerar simulados ou baterias sequenciais, **não misture disciplinas alternadamente dentro do mesmo bloco**. Respeite rigorosamente a ordem dos blocos da prova (1) Compréhension · Texte Informatif -> 2) Compréhension · Texte Argumentatif & Nuance), preenchendo integralmente a cota de cada disciplina antes de passar para a próxima e identificando o campo `discipline` em cada questão.
