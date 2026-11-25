# HSK — Hanyu Shuiping Kaoshi (Exame Oficial de Proficiência em Mandarim)

> Guia de parâmetros para geração e correção de simulados pela IA — cobre os **Níveis HSK 1 a 6** (formato padrão Hanban / Chinese Testing International `chinesetest.cn` e referência à transição HSK 3.0).

---

## 1. Requisitos e Estrutura Oficial

O HSK avalia **Compreensão Auditiva (听力 Tīnglì)**, **Compreensão de Leitura (阅读 Yuèdú)** e, a partir do **HSK 3**, **Expressão Escrita (书写 Shūxiě)**. O exame de fala (**HSKK**) é separado (ou integrado a partir do HSK 3+ nos centros que adotam a unificação recente).

| Nível | Vocabulário (HSK 2.0) | Estrutura Resumida | Pinyin presente? | Nota Máxima / Aprovação |
| :--- | :--- | :--- | :--- | :--- |
| **HSK 1** | 150 palavras | 40 questões (20 Audição + 20 Leitura) · ~40 min | **Sim** (em todas as questões) | **120 / 200** |
| **HSK 2** | 300 palavras | 60 questões (35 Audição + 25 Leitura) · ~55 min | **Sim** (em todas as questões) | **120 / 200** |
| **HSK 3** | 600 palavras | **80 questões:** Audição (40) · Leitura (30, 25 min) · Escrita (10, 15 min) | **Sim** (apenas apoio nos textos/opções) | **180 / 300** |
| **HSK 4** | 1.200 palavras | **100 questões:** Audição (45) · Leitura (40, 40 min) · Escrita (15, 25 min) | **Não** (removido integralmente) | **180 / 300** |
| **HSK 5** | 2.500 palavras | **100 questões:** Audição (45) · Leitura (45, 45 min) · Escrita (10, 40 min) | **Não** | **180 / 300** |
| **HSK 6** | 5.000+ palavras | **101 questões:** Audição (50) · Leitura (50, 50 min) · Escrita (1 resumo de ~400 car., 45 min) | **Não** | **180 / 300** |

*Nota sobre HSK 3.0 (Novos Padrões):* Os níveis avançados 7–9 foram introduzidos para pós-graduação/tradução; para estudantes e bolsas na China (CSC), os níveis 3 a 6 continuam sendo a referência principal.

---

## 2. Lógica de Elaboração e Arquitetura dos Distratores

1. **Transição crítica do HSK 3 para o HSK 4 (Remoção do Pinyin):** A partir do HSK 4 o candidato depende 100% do reconhecimento de caracteres simplificados (**简体字**) e de palavras dissílabas formadas por composição semântica.
2. **Arquitetura da Leitura (HSK 3 e HSK 4):**
   - **Emparelhamento de diálogos/frases (HSK 3 Parte 1):** Cinco frases-estímulo combinadas a cinco respostas funcionais (1 item extra de exemplo). Testa atos de fala cotidianos e coerência pragmática.
   - **Preenchimento de lacunas com banco de palavras (HSK 3/4 Parte 1):** Avalia **classe gramatical e colocação** (ex.: distinguir verbo separável `逛街`, substantivo `历史` vs. adjetivo `热情` / `友善`).
   - **Ordenação de 3 segmentos A/B/C (HSK 4/5 Escrita Parte 1 & Leitura Parte 2):** Avalia estrutura sintática chinesa (**Tópico + Tempo/Lugar + Sujeito + Advérbio + Verbo + Complemento + Objeto**), uso de `把 (bǎ)`, `被 (bèi)`, `虽然...但是...` e `不但...而且...`.
3. **Armadilhas típicas do HSK 5 e HSK 6:**
   - **HSK 6 Leitura Parte 1 (病句 — Identificação da frase gramaticalmente incorreta):** 4 frases onde 3 estão corretas e 1 contém erro sutil (colocação verbo-objeto incompatível, dupla negação invertida, falta de sujeito com preposição inicial *通过...使...*, ou erro de ordem de modificadores).
   - **HSK 6 Escrita (缩写 — Resumo):** Leitura de um texto narrativo de ~1.000 caracteres durante 10 minutos sem poder fazer anotações, seguida de reescrita resumida em ~400 caracteres nos 35 minutos seguintes (com o texto recolhido!).

---

## 3. Exemplos Reais e Modelos Oficiais (Hanban / CTI)

### Exemplo 1 — HSK 3 Leitura Parte 1 (Associação Pergunta–Resposta)
> **Estímulos:**  
> 1. 喂，请问张经理在吗？ *(Alô, por favor, o gerente Zhang está?)*  
> 2. 你觉得这件衣服怎么样？ *(O que você acha desta roupa?)*  
> 3. 咱们下午去踢足球，好不好？ *(Vamos jogar futebol hoje à tarde?)*  
>
> **Opções:**  
> A. 颜色很好看，我很喜欢。 *(A cor é muito bonita, eu gosto muito.)*  
> B. 对不起，他出去开会了。 *(Desculpe, ele saiu para uma reunião.)*  
> C. 太好了！我也正想去呢。 *(Ótimo! Eu também estava pensando em ir.)*  
>
> **Gabarito:** `1-B`, `2-A`, `3-C`.

### Exemplo 2 — HSK 4 Leitura Parte 1 (Preenchimento de Lacunas / Colocação)
> **Banco de palavras:** `A. 热情` · `B. 历史` · `C. 逛` · `D. 友善`  
> 1. 这棵树已经有两百年的 `_______` 了，依然长得非常茂盛。  
> 2. 经理虽然平时对我们很严格，但为人十分 `_______`。  
>
> **Gabarito:** `1-B (历史)` · `2-D (友善)`  
> **Comentário:** Em (1), o classificador `两百年的...` pede o substantivo `历史` (história/idade acumulada). Em (2), a conjunção concessiva `虽然...但...` exige contraste entre `严格` (rigoroso) e o adjetivo positivo `友善` (amigável/cordial).

### Exemplo 3 — HSK 4 Escrita Parte 1 (Ordenação Sintática)
> **Segmentos:** `A. 认真地` · `B. 老师正在` · `C. 批改作业`  
> **Ordem correta:** `B -> A -> C` (`老师正在认真地批改作业。` — O professor está corrigindo as tarefas atentamente.)  
> **Lógica:** A marca aspectual progressiva `正在` precede o advérbio de modo com `地`, que obrigatoriamente precede o verbo transitivo + objeto (`批改作业`).

---

## 4. Diretrizes Obrigatórias para a IA (Geração de Simulados)

1. **Utilize sempre Chinês Simplificado (简体字):**
   - Inclua **Pinyin com marcação tonal correta** nos enunciados de **HSK 1, 2 e 3**.
   - **Remova o Pinyin dos enunciados** ao gerar questões para **HSK 4, 5 e 6**, mantendo-o apenas no gabarito comentado para fins didáticos.
2. **Controle rigoroso de vocabulário:** Respeite a lista lexical do nível alvo (não use *chengyu* de HSK 5/6 em simulados de HSK 3).
3. **Inclua formatos autênticos de cada nível:**
   - **HSK 3–4:** Associação lógica de frases, lacunas por classe gramatical, ordenação de 3–5 fragmentos (*连词成句*) e parágrafos curtos com 1–2 perguntas (`A/B/C/D`).
   - **HSK 5–6:** Lacunas com palavras quase sinônimas (*近义词辨析*, ex.: `突然` vs. `忽然`, `曾经` vs. `已经`), identificação de frase gramaticalmente defeituosa (**病句**) no HSK 6 e textos de interpretação com 3–4 itens.
4. **No gabarito comentado:** Forneça sempre **Caracteres + Pinyin + Tradução + Regra de colocação/estrutura sintática**.
5. **Divisão Sequencial por Cadernos/Disciplinas (Sem Mistura Aleatória):** Ao gerar simulados ou baterias sequenciais, **não misture disciplinas alternadamente dentro do mesmo bloco**. Respeite rigorosamente a ordem dos blocos da prova (1) Vocabulário & Lacunas (选词填空) -> 2) Sintaxe, Ordenação & 病句 -> 3) Compreensão de Leitura (阅读理解)), preenchendo integralmente a cota de cada disciplina antes de passar para a próxima e identificando o campo `discipline` em cada questão.
