# JLPT — Japanese-Language Proficiency Test (Nihongo Nōryoku Shiken · N5 a N1)

> Guia de parâmetros para geração e correção de simulados pela IA — cobre todos os níveis (**N5, N4, N3, N2 e N1**) com base nos cadernos de amostras oficiais publicados pela **Japan Foundation & JEES** (`jlpt.jp`).

---

## 1. Requisitos e Estrutura Oficial

O JLPT avalia exclusivamente competências receptivas (**Conhecimento Linguístico — Vocabulário/Kanji e Gramática —, Leitura e Audição**). Não possui prova de fala nem de escrita discursiva.

| Nível | Descrição | Seções e Tempo | Pontuação Total / Mínima para Aprovação |
| :--- | :--- | :--- | :--- |
| **N5** | Básico (~100 kanjis, ~800 palavras) | Vocabulário (20 min) · Gramática/Leitura (40 min) · Audição (30 min) | **80 / 180** (mín. 38/120 Linguagem+Leitura e 19/60 Audição) |
| **N4** | Básico-Intermediário (~300 kanjis, ~1.500 palavras) | Vocabulário (25 min) · Gramática/Leitura (55 min) · Audição (35 min) | **90 / 180** (mín. 38/120 e 19/60) |
| **N3** | Intermediário (~650 kanjis, ~3.750 palavras) | Vocabulário (30 min) · Gramática/Leitura (70 min) · Audição (40 min) | **95 / 180** (mín. 19/60 em cada das 3 pontuações de seção) |
| **N2** | Intermediário-Avançado (~1.000 kanjis, ~6.000 palavras) | Vocabulário+Gramática+Leitura (105 min) · Audição (50 min) | **90 / 180** (mín. 19/60 em cada uma das 3 seções) |
| **N1** | Avançado (~2.000+ kanjis, ~10.000 palavras) | Vocabulário+Gramática+Leitura (110 min) · Audição (55 min) | **100 / 180** (mín. 19/60 em cada uma das 3 seções) |

*Regra de ouro da pontuação:* Não basta atingir a nota global mínima; zerar ou ficar abaixo de **19/60** em qualquer uma das seções (ex.: Audição) reprova o candidato automaticamente (**Seção Eliminatória / 基準点**). Todas as questões objetivas têm **4 alternativas (`1・2・3・4`)**.

---

## 2. Lógica de Elaboração e Arquitetura dos Distratores

1. **Leitura de Kanji (*Kanji Yomi*) e Escrita (*Hyōki*):**
   - Distratores exploram **confusão entre leitura *On'yomi* e *Kun'yomi***, presença/ausência de *dakuten* (ex.: たてもの vs. たでもの), alongamento vocálico (*kōkō* こうこう vs. *koko* ここ) e kanjis visualmente semelhantes ou homófonos (ex.: 会社 vs. 社会, 交校 vs. 高校).
2. **Questão da Estrela (*Bun no Kumitate* — `[ ★ ]`):**
   - Formato exclusivo e emblemático do JLPT em todos os níveis: o candidato ordena **4 blocos (`1・2・3・4`)** dentro de uma frase com quatro lacunas, mas marca na folha de resposta **apenas o número correspondente à posição `[ ★ ]`** (geralmente a 3ª posição). Avalia simultaneamente valência de partículas, modificação nominal e ordem sintática SOV.
3. **Gramática em Contexto (*Bunpō Keishiki no Handan* e *Bunshō no Bunpō*):**
   - No N3–N1, os 4 distratores são expressões gramaticais do mesmo nível com **restrição sintática ou pragmática sutil** (ex.: *~kamoshirenai* [possibilidade] vs. *~wake ga nai* [impossibilidade lógica] vs. *~ni kimatte iru* [certeza subjetiva] vs. *~osore ga aru* [risco formal negativo]).
4. **Leitura (*Dokkai*) — Textos Curtos, Médios, Longos e Comparativos:**
   - **N3–N1** traz comparação de dois textos curtos sobre o mesmo tema (*Tōgō Rikai*) e busca de informação em folhetos/avisos (*Jōhō Kensaku*). Distratores repetem substantivos do texto, mas invertem o sujeito da ação, a condição (*~baai*, *~nakereba*) ou o escopo temporal.

---

## 3. Exemplos Reais e Modelos Oficiais (`jlpt.jp`)

### Exemplo 1 — N5 Escrita em Kanji (*Hyōki*)
> **Enunciado:** まいにち **(こうこう)** へ 行きます。  
> **Alternativas:** `1. 高校` · `2. 校高` · `3. 交校` · `4. 校交`  
> **Gabarito:** **1** (`高校` = *kōkō*, ensino médio).  
> **Lógica:** Distratores usam inversão de ordem dos kanjis (`2`) ou troca por kanji homófono de leitura *kō* (`交`).

### Exemplo 2 — N5/N4 Ordenação Sintática (*Bun no Kumitate* `[ ★ ]`)
> **Enunciado:** きょうは、`(　　)` `(　　)` `[ ★ ]` `(　　)` べんきょうします。  
> **Opções:** `1. 日本語を` · `2. にほん` *(ou `ごぜん`)* · `3. で` · `4. かいしゃ`  
> **Montagem correta:** `かいしゃ (4)` `で (3)` `日本語を (1)` *(se 4 lacunas: ex. かいしゃ で ともだちと 日本語を)* -> Marca-se apenas o item que cai na posição `[ ★ ]`.

### Exemplo 3 — N3 Gramática em Contexto (*Bunpō Keishiki no Handan*)
> **Enunciado:** あしたは 雨（あめ）が ふる `(　　)`、きょうのうちに 洗濯（せんたく）を しておこう。  
> **Alternativas:**  
> 1. おそれがある (*há risco grave/formal de*)  
> 2. にきまっている (*com certeza vai*)  
> 3. わけがない (*não há a menor possibilidade de*)  
> 4. かもしれない (*talvez / pode ser que*)  
> **Gabarito:** **4** (*かもしれない*).  
> **Comentário:** O comando *~te okō* (preparar-se preventivamente) harmoniza com uma possibilidade cotidiana neutra (*kamoshirenai*), enquanto *osore ga aru* exige registro formal de desastre/prejuízo grave e *wake ga nai* tem sentido oposto.

### Exemplo 4 — N1/N2 Leitura Comparativa e Uso de Partículas/Keigo
> Nos níveis N2 e N1, questões de **Uso de Palavras (*Yōhō*)** apresentam uma palavra-alvo (ex.: 渋滞 *jūtai* ou 率直 *sotchoku*) e **4 frases completas** de uso contextual; apenas uma emprega a colocação e o campo semântico corretos sem violar restrições de animacidade ou registro.

---

## 4. Diretrizes Obrigatórias para a IA (Geração de Simulados)

1. **Fidelidade à notação japonesa do nível:**
   - **N5 e N4:** Escreva palavras com kanjis além do nível sempre com **furigana entre parênteses** (ex.: `洗濯（せんたく）`), e espace palavras quando simular N5 inicial se necessário.
   - **N3, N2 e N1:** Reduza o furigana apenas a termos raros ou nomes próprios; mantenha ortografia autêntica japonesa sem espaços entre palavras.
2. **Sempre inclua questões no formato `[ ★ ]` (Estrela):** Em simulados de gramática de qualquer nível do JLPT, inclua pelo menos 2 itens do tipo **Ordenação `[ ★ ]`** com 4 blocos e peça explicitamente o número que ocupa `[ ★ ]`.
3. **4 alternativas numeradas `1・2・3・4`:** O JLPT utiliza números arábicos `1, 2, 3, 4` (não letras `A/B/C/D`).
4. **Explicações bilíngues/didáticas:** No gabarito comentado em português, apresente a leitura em **hiragana/romaji**, a tradução da frase completa e a explicação do ponto gramatical (ex.: restrição de registro formal no *N2/N1* ou distinção entre verbos transitivos/intransitivos).
5. **Divisão Sequencial por Cadernos/Disciplinas (Sem Mistura Aleatória):** Ao gerar simulados ou baterias sequenciais, **não misture disciplinas alternadamente dentro do mesmo bloco**. Respeite rigorosamente a ordem dos blocos da prova (1) 言), preenchendo integralmente a cota de cada disciplina antes de passar para a próxima e identificando o campo `discipline` em cada questão.
