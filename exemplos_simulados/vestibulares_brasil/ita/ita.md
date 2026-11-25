# ITA — Instituto Tecnológico de Aeronáutica (Parâmetros para Geração de Simulados)

> **Banca:** Comissão de Vestibular do ITA  
> **Base Analisada:** Provas e Gabaritos Oficiais de 1ª e 2ª Fases do ITA (2016–2026)  
> **Uso no Noesis:** Parâmetro para geração de questões de altíssima dificuldade em Matemática, Física, Química e Inglês (nível olímpico/engenharia de ponta).

---

## 1. Requisitos e Estrutura Oficial da Prova

| Parâmetro | Especificação Oficial |
| :--- | :--- |
| **Fases** | 2 fases presenciais |
| **1ª Fase (5h00)** | **48 questões objetivas** (12 Matemática, 12 Física, 12 Química, 12 Inglês). A nota de Inglês é eliminatória/independente; Matemática, Física e Química compõem a média da 1ª fase |
| **Formato (1ª Fase)** | Múltipla escolha com **5 alternativas (`A` a `E`)**, 1 única resposta correta |
| **2ª Fase (4 dias / provas dissertativas)** | Provas dissertativas de Matemática, Física, Química e Português + Redação (10 questões dissertativas por matéria específica nos cadernos tradicionais) |
| **Constantes e Convenções** | Explicitadas na abertura de cada caderno ($\mathbb{N}=\{1,2,3,\dots\}$, $\mathbb{R}$, $i^2=-1$, $g=10\text{ m/s}^2$, $G=6,7\times 10^{-11}$, $hc=1240\text{ eV}\cdot\text{nm}$, $\varepsilon_0=8,85\times 10^{-12}$) |

---

## 2. Lógica de Elaboração e Arquitetura das Questões

O vestibular do ITA possui um perfil técnico e lógico único no Brasil:

1. **Enunciados Curtos, Formais e Densos:**
   - Quase não há textos motivadores narrativos em Exatas; o enunciado vai direto ao modelo matemático ou físico com notação rigorosa ($a \in \mathbb{R}$, $x(t)=\sqrt{D^2+(Vt-D)^2}$, conjuntos e quantificadores).
2. **Questões de Afirmações I, II, III (Combinatória de Julgamento):**
   - Muito frequente em Matemática, Física e Química: apresenta 3 afirmações (`I.`, `II.`, `III.`) exigindo análise de existência/verdade/contraexemplo, com alternativas do tipo: *A) I e II; B) I e III; C) II e III; D) apenas I; E) nenhuma*.
   - **Lógica por trás:** impede o chute por eliminação simples — o candidato precisa provar ou refutar **cada uma das 3 proposições** (muitas vezes encontrando contraexemplos sutis como poliedros não convexos ou casos de borda $n=1$).
3. **Integração de Múltiplos Tópicos em Uma Única Questão:**
   - Uma questão de Física une Cinemática vetorial/gráfica + Conservação de Energia + Colisão inelástica em uma única expressão literal.
   - Uma questão de Matemática une Números Complexos + Plano de Argand-Gauss + Área de triângulo; ou Binômio de Newton + Produto de dois polinômios; ou Cônicas + Trigonometria.
4. **Respostas Algébricas / Literais e Casos Limite:**
   - Alternativas frequentemente vêm em forma literal (ex.: $\frac{1}{2}\sqrt{2a_0\ell+4gR}$), onde análise dimensional já elimina opções mal construídas se não houver cuidado — por isso os distratores do ITA têm **dimensão física correta**, errando apenas fatores numéricos ($2$, $\sqrt{2}$, $1/2$) ou sinais!

---

## 3. Exemplos Reais de Questões (ITA 2025 — 1ª Fase Oficial)

### Exemplo 1 — Matemática: Complexos e Geometria Analítica (ITA 2025, 1ª Fase, Q01)
**Enunciado:** Seja $z = a + 2i$ um número complexo, em que $a \in \mathbb{R}$ é positivo. O valor de $a$ para que as representações de $1, z$ e $z^2$ no plano de Argand-Gauss formem um triângulo de área $200$ é  
- **A)** $14$.
- **B)** $15$.
- **C)** $16$.
- **D)** $17$.
- **E)** $18$.

**Gabarito Oficial:** **B**  
**Lógica da Questão:** Os vértices são $A(1,0)$, $B(a,2)$ e $C(a^2-4, 4a)$. Calculando a área via determinante $S = \frac{1}{2}|\det|$, chega-se a uma equação polinomial em $a > 0$ que resulta em $a = 15$. Distratores são inteiros consecutivos ($14, 15, 16, 17, 18$), impedindo aproximações grosseiras.

---

### Exemplo 2 — Matemática: Julgamento I, II, III / Geometria Espacial (ITA 2025, 1ª Fase, Q02)
**Enunciado:** Considere as afirmações:  
I. Existe um poliedro formado por $3$ faces triangulares e as demais faces quadrangulares.  
II. Existe um poliedro não convexo com $5$ vértices, $9$ arestas e $6$ faces.  
III. Existe um poliedro convexo com $7$ vértices, $16$ arestas e $11$ faces.  

Está(ão) correta(s):  
- **A)** I e II.
- **B)** I e III.
- **C)** II e III.
- **D)** apenas III.
- **E)** apenas II.

**Gabarito Oficial:** **E**  
**Lógica da Questão:**
- I é falsa pela paridade das arestas: $2A = 3\cdot 3 + 4q$ → $9+4q$ é ímpar (impossível!).
- II é verdadeira (note $V - A + F = 5 - 9 + 6 = 2$, e um poliedro não convexo pode ter essas contagens sem violar graus mínimos).
- III é falsa: embora $7-16+11=2$ satisfaça Euler, para um poliedro convexo com $F=11$, cada face tem $\ge 3$ arestas ($2A \ge 3F = 33 \Rightarrow A \ge 17$), logo $A=16$ é impossível! Armadilha clássica: testar apenas Euler ($V-A+F=2$) não basta!

---

### Exemplo 3 — Matemática: Funções e Composição (ITA 2025, 1ª Fase, Q04)
**Enunciado:** Sejam $f(x)$ e $g(x)$ funções reais definidas para todo $x \in \mathbb{R}$. Se para todo $x > 0$ vale a igualdade $g(x^2) = f(2x^2 - x + 1)$, podemos afirmar que  
- **A)** $f$ não é sobrejetora.
- **B)** $f$ não é injetora.
- **C)** $g$ não é sobrejetora.
- **D)** $g$ não é injetora.
- **E)** $f(a) \neq g(a)$ para todo $a > 0$.

**Gabarito Oficial:** **D**  
**Lógica da Questão:** A igualdade vale apenas para $x > 0$, ou seja, para o argumento $x^2 > 0$ de $g$. Mesmo assim, $2x^2 - x + 1$ possui vértice em $x = 1/4 > 0$, atingindo valores repetidos para dois valores positivos de $x$ (ex.: $x_1$ e $x_2$ simétricos em torno de $1/4$ dentro de $(0, 1/2)$), o que força $g(x_1^2) = g(x_2^2)$ com $x_1^2 \neq x_2^2 \Rightarrow g$ não é injetora! Questão puramente lógica sem contas pesadas.

---

### Exemplo 4 — Física: Mecânica Multi-Etapas e Expressão Literal (ITA 2025, 1ª Fase, Q14)
**Enunciado:** Um carrinho realiza um percurso sobre um trilho em um plano vertical. Partindo do repouso no ponto $A$, percorre distância $\ell$ até $B$ com aceleração constante $a_0$. Em $B$, segue uma trajetória circular de raio $R$ sob ação da gravidade até o ponto $C$ (no topo/desnível do círculo), passando a executar MRU até $D$, onde realiza colisão perfeitamente inelástica com outro carrinho de mesma massa. Desconsiderando atrito, assinale o módulo da velocidade após o choque:  
- **A)** $\frac{1}{2}\sqrt{2a_0\ell + 4gR}$
- **B)** $\sqrt{\frac{1}{2}(a_0\ell + gR)}$
- **C)** $\sqrt{a_0\ell + 2gR}$
- **D)** $\frac{1}{2}\sqrt{a_0\ell + 2gR}$
- **E)** $\sqrt{2(a_0\ell + 2gR)}$

**Gabarito Oficial:** **A**  
**Lógica da Questão:** 1) Torricelli $A \to B$: $v_B^2 = 2a_0\ell$; 2) Conservação de energia $B \to C$: $v_C^2 = v_B^2 + 4gR$ (queda de diâmetro $2R$, se $B$ acima de $C$); 3) Colisão perfeitamente inelástica de massas iguais: $v_f = v_C / 2 = \frac{1}{2}\sqrt{2a_0\ell + 4gR}$. Observe que **todas as 5 alternativas têm a mesma dimensão física** ($\sqrt{L^2/T^2} = L/T$)!

---

## 4. Diretrizes Obrigatórias para a IA (Motor de Simulados Noesis)

1. **Nível de profundidade elevado:** nunca gerar questões de aplicação imediata de fórmula única; combinar pelo menos **2 conceitos distintos** ou exigir **condições de existência/borda**.
2. **Incluir questões no formato `I, II, III`:** exigir prova ou contraexemplo para cada proposição, utilizando a estrutura *"Está(ão) correta(s): A) I e II; B) I e III; ...; E) nenhuma"*.
3. **Homogeneidade dimensional e numérica dos distratores:** em respostas literais, garantir que todos os distratores tenham a **mesma dimensão física** da resposta correta; em respostas numéricas, usar inteiros consecutivos ou variações por fator $2$ / sinal.
4. **Explicitar convenções matemáticas/físicas** quando houver ambiguidade (ex.: se $0 \in \mathbb{N}$ ou $\mathbb{N}=\{1,2,3,\dots\}$; valor de $g$).
5. **Divisão Sequencial por Cadernos/Disciplinas (Sem Mistura Aleatória):** Ao gerar simulados ou baterias sequenciais, **não misture disciplinas alternadamente dentro do mesmo bloco**. Respeite rigorosamente a ordem dos blocos da prova (1) Matemática -> 2) Física -> 3) Química -> 4) Inglês & Português), preenchendo integralmente a cota de cada disciplina antes de passar para a próxima e identificando o campo `discipline` em cada questão.
