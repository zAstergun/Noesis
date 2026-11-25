# DELE — Diplomas de Español como Lengua Extranjera (Instituto Cervantes)

> Guia de parâmetros para geração e correção de simulados pela IA — cobre os níveis mais demandados (**B1, B2 e C1**) com base no formato oficial do Instituto Cervantes e no QECR (Marco Común Europeo de Referencia).

---

## 1. Requisitos e Estrutura Oficial

Os exames DELE avaliam 4 provas agrupadas em dois blocos de aprovação (**Apto / No Apto**, exigindo **30/50** em cada grupo de provas, totalizando mínimo de **60/100** pontos).

| Nível QECR | Compreensão de Leitura (CL) | Compreensão Auditiva (CA) | Expressão e Interação Escritas (EIE) | Expressão e Interação Orais (EIO) | Nota de Corte |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **B1** | 70 min · 5 tarefas · 30 itens | 40 min · 5 tarefas · 30 itens | 60 min · 2 tarefas | 15 min (+15 min prep.) · 4 tarefas | 30/50 Grupo 1 + 30/50 Grupo 2 |
| **B2** | 70 min · 4 tarefas · 36 itens | 40 min · 5 tarefas · 30 itens | 80 min · 2 tarefas | 20 min (+20 min prep.) · 3 tarefas | 30/50 Grupo 1 + 30/50 Grupo 2 |
| **C1** | 90 min · 5 tarefas · 40 itens | 50 min · 4 tarefas · 30 itens | 80 min · 2 tarefas | 20 min (+20 min prep.) · 3 tarefas | 30/50 Grupo 1 + 30/50 Grupo 2 |

### Detalhamento das Tarefas de Leitura e Escrita (B2 — referência padrão)
- **CL Tarea 1 (6 itens, 3 opções `a/b/c`):** Texto informativo/acadêmico (~400–450 palavras). Itens seguem a ordem do texto.
- **CL Tarea 2 (10 itens, emparelhamento `A–D`):** Quatro depoimentos ou opiniões curtas de pessoas diferentes sobre o mesmo tema (ex.: teletrabalho, voluntariado) associados a 10 afirmações.
- **CL Tarea 3 (6 itens, reconstrução textual):** Inserção de fragmentos/frases (`a–h`, sendo 2 sobressalentes) em lacunas de um artigo ou reportagem.
- **CL Tarea 4 (14 itens no modelo de uso da língua/léxico-gramática, 3 opções):** Preenchimento de lacunas gramaticais e lexicais em texto histórico/cultural (conectores, subjuntivo, perífrases, colocações).
- **EIE Tarea 1 (150–180 palavras):** Integração áudio + escrita — o candidato ouve uma notícia/entrevista de rádio duas vezes e redige carta ou e-mail formal (reclamação, solicitação, opinião a jornal).
- **EIE Tarea 2 (150–180 palavras):** Escolha entre duas opções: **Artigo de opinião/blog** (a partir de gráfico/dados estatísticos) ou **Carta formal/artigo argumentativo**.

---

## 2. Lógica de Elaboração e Arquitetura dos Distratores

1. **Paráfrase semântica obrigatória na CL:** As questões de 3 opções (`a/b/c`) nunca repetem literalmente as palavras-chave da frase correta. Quando uma alternativa copia palavras exatas do texto original, geralmente altera o escopo, o sujeito ou a polaridade, configurando **distrator lexical por correspondência superficial**.
2. **Armadilhas típicas dos 3 distratores (`a`, `b`, `c`):**
   - **Distrator por extrapolação / inferência não sustentada:** Traz uma verdade plausível de senso comum que o autor não afirmou.
   - **Distrator por distorção de sujeito/tempo/quantidade:** Troca "la mayoría" por "todos", ou atribui a opinião de um entrevistado ao autor principal.
3. **Critério pan-hispânico:** O DELE contempla variedades lexicais e fonéticas da Espanha e da América Hispânica (voseo receptivo na CA, vocabulário regional contextualizado sem prejudicar a compreensão padrão).
4. **Uso do Subjuntivo e Conectores em lacunas (Tarea 4 / C1 Tarea 4):** Testa regência modal (*a pesar de que* + indicativo vs. subjuntivo, *con tal de que* + subjuntivo, *de ahí que* + subjuntivo) e colocações fixas (*tomar medidas*, *llevar a cabo*, *dar lugar a*).
5. **EIE Penalização por gênero e estímulo:** Na Tarea 1, ignorar os dados do estímulo auditivo ou errar o registro formal (*Estimados señores* / *Atentamente* com tratamento de *usted*) reduz drasticamente a nota em *Coherencia* e *Adecuación*.

---

## 3. Exemplos Reais e Modelos Comentados

### Exemplo 1 — Compreensão de Leitura (DELE B2, Tarea 1 — estilo Instituto Cervantes)
> **Fragmento adaptado de modelo oficial (tema: musicoterapia / salud pública):**  
> *"Aunque el uso de la música con fines curativos se remonta a la Antigüedad, no fue hasta mediados del siglo XX cuando la musicoterapia se consolidó como disciplina clínica reglada. Hoy en día, numerosos hospitales la emplean como complemento —y nunca como sustituto— de los tratamientos farmacológicos convencionales en pacientes con dolor crónico o trastornos neurológicos."*
>
> **Pregunta:** Según el texto, en la actualidad la musicoterapia en el ámbito hospitalario...  
> **a)** sustituye progresivamente a los medicamentos tradicionales en dolencias crónicas.  
> **b)** actúa como una terapia de apoyo junto con los tratamientos médicos habituales.  
> **c)** carece todavía de reconocimiento como práctica clínica formal.  
>
> **Gabarito:** **b)**  
> **Comentário:** "como complemento —y nunca como sustituto—" é parafraseado em **b** ("terapia de apoyo junto con los tratamientos médicos habituales"). **a** inverte exatamente a restrição do texto; **c** contradiz "se consolidó como disciplina clínica reglada".

### Exemplo 2 — Léxico e Gramática em Contexto (DELE B2, Tarea 4 / C1)
> **Enunciado:** Complete el hueco con la opción gramatical y léxicamente adecuada:  
> *"La empresa decidió ampliar el horario de atención al cliente ______ que las quejas por demoras en las entregas habían aumentado un 30 % en el último trimestre."*
>
> **a)** dado  
> **b)** puesto que  
> **c)** por mucho que  
>
> **Gabarito:** **a)** (*dado que*)  
> **Comentário:** Como o "que" já está fora da lacuna (*______ que*), somente **a)** (*dado*) forma a locução causal *dado que* + indicativo. **b)** duplicaria a conjunção (*puesto que que*); **c)** expressaria concessão (*por mucho que*) incompatível com a relação de causa e consequência do enunciado.

### Exemplo 3 — Expressão e Interação Escritas (DELE B2, Tarea 1 — Estímulo + Carta Formal)
> **Estímulo (síntese do áudio de rádio):** Um consumidor denuncia no rádio atrasos recorrentes de uma operadora de fibra óptica e falta de ressarcimento na fatura.  
> **Consigna:** Usted lleva semanas con graves problemas de conexión en su domicilio. Escriba una carta formal de reclamación al servicio de atención al cliente (150–180 palabras). Debe:
> 1. Presentarse y exponer el motivo de su reclamación.  
> 2. Referirse a las quejas similares escuchadas en la radio y detallar sus incidencias previas.  
> 3. Exigir una compensación económica y especificar las medidas que tomará si no obtiene respuesta.  
>
> **Rubrica avaliativa (Escala 0–3 em 4 critérios):** *Adecuación al género y registro*, *Coherencia*, *Corrección gramatical* e *Alcance léxico*.

---

## 4. Diretrizes Obrigatórias para a IA (Geração de Simulados)

1. **Respeite rigorosamente a tridimensionalidade `a / b / c`:** Provas do DELE B1/B2/C1 usam **3 alternativas** (e não 4 ou 5) nos blocos de múltipla escolha de Leitura e Audição. Nunca gere 5 alternativas para questões no padrão DELE.
2. **Calibração por nível QECR:**
   - **B1:** Conectores simples (*porque, aunque, sin embargo*), contraste pretérito indefinido vs. imperfecto, futuro simples, vocabulário cotidiano/viagem/trabalho.
   - **B2:** Subjuntivo em orações subordinadas e concessivas (*aunque*, *a pesar de*, *por más que*), passiva reflexa, estilo indireto, artigos jornalísticos/divulgativos de 400–450 palavras.
   - **C1:** Léxico culto e idiomático, perífrases verbais avançadas, reconstrução de parágrafos extensos (6 lacunas com 7–8 fragmentos), registros jurídicos/acadêmicos/literários e nuance pragmática.
3. **Na produção de tarefas de escrita (EIE):** Forneça sempre o **roteiro do estímulo** (texto-base ou transcrição resumida do áudio), os **4 pontos obrigatórios de desenvolvimento** (bullet points), o **gênero textual**, o **destinatário** e a **faixa estrita de palavras** (ex.: 150–180 para B2; 180–220 para C1).
4. **Proibição de gabaritos ambíguos:** Garanta que os dois distratores falhem por razões textuais verificáveis (extrapolação ou contradição) ou gramaticais objetivas (regência/concordância/tempo verbal).
5. **Divisão Sequencial por Cadernos/Disciplinas (Sem Mistura Aleatória):** Ao gerar simulados ou baterias sequenciais, **não misture disciplinas alternadamente dentro do mesmo bloco**. Respeite rigorosamente a ordem dos blocos da prova (1) Comprensión de Lectura (Tareas 1–3) -> 2) Léxico, Subjuntivo y Conectores (Tarea 4)), preenchendo integralmente a cota de cada disciplina antes de passar para a próxima e identificando o campo `discipline` em cada questão.
