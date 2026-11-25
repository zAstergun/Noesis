# ENEM — Exame Nacional do Ensino Médio (Parâmetros para Geração de Simulados)

> **Banca / Órgão:** INEP (Instituto Nacional de Estudos e Pesquisas Educacionais Anísio Teixeira)  
> **Base Analisada:** Provas e Gabaritos Oficiais do ENEM (2016–2025)  
> **Uso no Noesis:** Documento-parâmetro para o Motor de Simulados gerar questões inéditas fiéis à Matriz de Referência do ENEM.

---

## 1. Requisitos e Estrutura Oficial da Prova

| Parâmetro | Especificação Oficial |
| :--- | :--- |
| **Aplicação** | 2 dias presenciais (1º e 2º domingos) |
| **1º Dia (5h30)** | **90 questões objetivas** (01–45: Linguagens, Códigos e suas Tecnologias, sendo 01–05 opção Inglês ou Espanhol; 46–90: Ciências Humanas e suas Tecnologias) + **Redação** dissertativo-argumentativa (até 30 linhas, com proposta de intervenção respeitando os direitos humanos) |
| **2º Dia (5h00)** | **90 questões objetivas** (91–135: Ciências da Natureza e suas Tecnologias; 136–180: Matemática e suas Tecnologias) |
| **Formato das Questões** | Múltipla escolha com **5 alternativas (`A` a `E`)** e **1 única resposta correta** |
| **Sistema de Pontuação** | **TRI (Teoria de Resposta ao Item)** — avalia coerência pedagógica entre acertos fáceis, médios e difíceis (não é soma linear simples). Redação avaliada de 0 a 1000 em 5 competências |
| **Competências Gerais** | Contextualização socioambiental, interdisciplinaridade, leitura de gráficos/tabelas/charges/poemas e resolução de situações-problema |

---

## 2. Lógica de Elaboração e Arquitetura das Questões

Toda questão do ENEM segue uma estrutura tripartite rigorosa (**Texto-base → Comando → 5 Alternativas**):

1. **Texto-Base / Suporte Contextualizado:**
   - Nunca apresenta pergunta seca ou puramente conteudista sem contexto.
   - Utiliza trechos literários, reportagens, artigos científicos, letras de música, charges, gráficos, tabelas ou esquemas físicos/matemáticos com referência bibliográfica completa (`AUTOR. Título. Disponível em: ... Acesso em: ...`).
2. **Comando (Enunciado de Transição):**
   - Conecta o texto-base à competência avaliada sem repetir o conteúdo do suporte.
   - Frequentemente termina em frase aberta que se completa sintaticamente com as alternativas (ex.: *"Com base no texto, a iniciativa descrita..."*, *"O jardineiro escolherá a forma de..."*).
   - O comando deve ser **100% positivo ou direto** (evita "assinale a INCORRETA" ou "EXCETO").
3. **Estrutura dos Distratores (`A`–`E`):**
   - Todas as 5 opções mantêm **paralelismo sintático e extensão similar** (substantivo + complemento, ou verbo no infinitivo + complemento).
   - **Distratores típicos do ENEM:**
     1. *Extrapolação:* vai além do que o texto-base permite inferir.
     2. *Reducionismo:* foca em um detalhe secundário como se fosse a tese central.
     3. *Contradição / Inversão:* inverte causa e consequência ou o posicionamento do autor.
     4. *Senso comum:* resposta plausível fora do contexto científico/sociológico exigido, mas incompatível com o suporte.

---

## 3. Exemplos Reais de Questões (ENEM 2024 Oficial)

### Exemplo 1 — Linguagens (Inglês) — Interpretação e Função Discursiva (ENEM 2024, Caderno 1 Azul, Q02)
**Texto-base:**
> *Holy War*  
> Oh, so we can hate each other and fear each other  
> We can build these walls between each other  
> Baby, blow by blow and brick by brick  
> Keep yourself locked in, yourself locked in [...]  
> Oh, maybe we should love somebody  
> Oh, maybe we could care a little more  
> So maybe we should love somebody  
> Instead of polishing the bombs of holy war  
> *(KEYS, A. Here. Estados Unidos: RCA Records, 2016.)*

**Comando:** Nessa letra de canção, que aborda um contexto de ódio e intolerância, o marcador `"instead of"` introduz a ideia de  
- **A)** mudança de comportamento.
- **B)** panorama de conflitos.
- **C)** rotina de isolamento.
- **D)** perspectiva bélica.
- **E)** cenário religioso.

**Gabarito Oficial:** **A**  
**Lógica da Questão:** Avalia o valor semântico de um conector em contexto (*instead of* = "em vez de"), contrapondo a proposta de amar/cuidar (*love somebody / care a little more*) à prática anterior de conflito, indicando mudança de atitude. Os distratores B, C, D e E capturam palavras isoladas do texto (*war*, *locked in*, *bombs*, *holy*) fora da função lógica do marcador.

---

### Exemplo 2 — Linguagens (Português) — Variação Linguística e Cultura (ENEM 2024, Caderno 1 Azul, Q06)
**Texto-base:** Reportagem sobre o livro *Amazonês: expressões e termos usados no Amazonas* (cerca de 1.100 expressões do falar "caboco") e a coleção de camisetas *Caboquês Ilustrado*, cujo criador afirma buscar *"resgatar o orgulho do povo manauara, do povo do Norte"*.  
*(Disponível em: https://g1.globo.com. Acesso em: 15 jan. 2024 (adaptado).)*

**Comando:** A reportagem apresenta duas iniciativas: o livro *Amazonês* e as camisetas do *Caboquês Ilustrado*. Com temática em comum, essas iniciativas  
- **A)** recomendam produtos feitos por empreendedores da região Norte.
- **B)** ressaltam diferenças entre o falar manauara e outros falares.
- **C)** reverenciam o trabalho feito por pesquisadores brasileiros.
- **D)** destacam a descontração no jeito de ser do amazonense.
- **E)** valorizam o repertório linguístico do povo do Amazonas.

**Gabarito Oficial:** **E**  
**Lógica da Questão:** Todas as opções começam com verbo no presente do indicativo (paralelismo perfeito). A correta sintetiza o objetivo comum às duas iniciativas (registrar a linguagem e resgatar o orgulho pela fala local), enquanto B reduz ao contraste citado brevemente e A/D distorcem o propósito cultural para consumo ou traço comportamental.

---

### Exemplo 3 — Ciências Humanas — Geopolítica e Economia (ENEM 2024, Caderno 1 Azul, Q46)
**Texto-base:** Dados sobre a assimetria comercial Brasil–China: 75% a 80% das exportações brasileiras são produtos básicos (soja, minério de ferro, petróleo), enquanto ~95% das importações oriundas da China são produtos industrializados, incluindo máquinas e equipamentos de alto valor. *(LEÃO, V. C. Ipea, 2015.)*

**Comando:** Uma ação estatal de longo prazo capaz de reduzir a assimetria na balança comercial brasileira, conforme exposto no texto, é o(a)  
- **A)** expansão do setor extrativista.
- **B)** incremento da atividade agrícola.
- **C)** diversificação da matriz energética.
- **D)** fortalecimento da pesquisa científica.
- **E)** monitoramento do fluxo alfandegário.

**Gabarito Oficial:** **D**  
**Lógica da Questão:** Exige inferência de solução estrutural de longo prazo: para sair da pauta primário-exportadora (soja/minério) e agregar valor tecnológico, o país precisa de P&D. A e B agravariam a assimetria (reforçam commodities); C e E não atacam o conteúdo tecnológico da pauta industrial.

---

### Exemplo 4 — Ciências da Natureza — Física / Efeito Doppler (ENEM 2024, Caderno 5 Amarelo, Q117)
**Texto-base:** Uma ambulância em alta velocidade com a sirene ligada desloca-se em direção a um radar operado por uma pessoa. O radar emite ondas de rádio com frequência $f_0$ que são refletidas pela dianteira da ambulância, retornando para o detector com frequência $f_r$. A percepção do operador do radar, em relação ao som emitido pela sirene, é de que este se altera à medida que a ambulância se aproxima ou se afasta.

**Comando:** Durante a aproximação, como o operador percebe o som da sirene e qual é a relação entre as frequências $f_r$ e $f_0$ medidas pelo radar?  
- **A)** Mais grave do que o som emitido e $f_r < f_0$.
- **B)** Mais agudo do que o som emitido e $f_r < f_0$.
- **C)** Mais agudo do que o som emitido e $f_r = f_0$.
- **D)** Mais agudo do que o som emitido e $f_r > f_0$.
- **E)** Mais grave do que o som emitido e $f_r > f_0$.

**Gabarito Oficial:** **D**  
**Lógica da Questão:** Combina interpretação qualitativa (aproximação aumenta a frequência percebida → som mais agudo) com princípio físico do radar (efeito Doppler em ondas eletromagnéticas refletidas → $f_r > f_0$). Distratores combinam sistematicamente os pares (grave/agudo × $<, =, >$).

---

### Exemplo 5 — Matemática — Geometria / Otimização com Perímetro Fixo (ENEM 2024, Caderno 5 Amarelo, Q147)
**Texto-base:** Um jardineiro dispõe de $k$ metros lineares de cerca baixa para fazer um jardim ornamental. O jardim, delimitado por essa cerca, deve ter a forma de um triângulo equilátero, um quadrado ou um hexágono regular. A escolha será pela forma que resulte na maior área.

**Comando:** O jardineiro escolherá a forma de  
- **A)** hexágono regular, pois a área do jardim, em metro quadrado, será $\frac{k^2\sqrt{3}}{24}$.
- **B)** hexágono regular, pois a área do jardim, em metro quadrado, será $\frac{3\sqrt{3}}{2}k^2$.
- **C)** quadrado, pois a área do jardim, em metro quadrado, será $\frac{k^2}{16}$.
- **D)** triângulo equilátero, pois a área do jardim, em metro quadrado, será $\frac{k^2\sqrt{3}}{36}$.
- **E)** triângulo equilátero, pois a área do jardim, em metro quadrado, será $\frac{k^2\sqrt{3}}{4}$.

**Gabarito Oficial:** **A**  
**Lógica da Questão:** Com perímetro fixo $k$, quanto maior o número de lados do polígono regular, maior a área: lado do hexágono $l = k/6$, área $A = 6 \cdot \frac{(k/6)^2 \sqrt{3}}{4} = \frac{k^2\sqrt{3}}{24}$. Distrator B esquece de dividir $k$ por 6 (erro algébrico clássico); C e D calculam corretamente a área do quadrado/triângulo, mas erram a comparação de otimização.

---

## 4. Diretrizes Obrigatórias para a IA (Motor de Simulados Noesis)

Ao gerar simulados no padrão **ENEM**, a IA deve:
1. **Sempre** construir um **texto-base contextualizado** (caso real, dado estatístico, excerto literário/científico ou problema cotidiano) antes da pergunta.
2. Usar **5 alternativas (`A` a `E`)** com paralelismo gramatical rigoroso e sem "Todas as anteriores" / "Nenhuma das anteriores".
3. Evitar enunciados de memorização pura (*"Qual a fórmula de..."*, *"Em que ano ocorreu..."*); exigir **aplicação, interpretação ou modelagem**.
4. Em Matemática e Natureza, construir distratores com **erros de modelagem plausíveis** (esquecer fator 2, trocar unidade, confundir área com perímetro).
5. Em Humanas e Linguagens, evitar termos absolutos nos corretos ("sempre", "nunca", "exclusivamente") e usá-los estrategicamente nos distratores de extrapolação.
6. **Divisão Sequencial por Cadernos/Disciplinas (Sem Mistura Aleatória):** Ao gerar simulados ou baterias sequenciais, **não misture disciplinas alternadamente dentro do mesmo bloco**. Respeite rigorosamente a ordem dos blocos da prova (1) Linguagens, Códigos e suas Tecnologias -> 2) Ciências Humanas e suas Tecnologias -> 3) Ciências da Natureza e suas Tecnologias -> 4) Matemática e suas Tecnologias), preenchendo integralmente a cota de cada disciplina antes de passar para a próxima e identificando o campo `discipline` em cada questão.
