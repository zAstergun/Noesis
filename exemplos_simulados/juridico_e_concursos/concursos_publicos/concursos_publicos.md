# Concursos Públicos Brasileiros — Cebraspe (Certo/Errado), FGV & Cesgranrio (CNU)

> Guia de parâmetros para geração e correção de simulados pela IA — cobre os três estilos dominantes das grandes bancas brasileiras (**CEBRASPE/CESPE**, **FGV** e **CESGRANRIO / Concurso Nacional Unificado**).

---

## 1. Requisitos e Perfil Comparativo das Bancas

| Banca | Formato Padrão | Sistema de Pontuação | Perfil de Cobrança |
| :--- | :--- | :--- | :--- |
| **CEBRASPE** *(antigo CESPE/UnB — PF, PRF, TCU, Receita/Tribunais)* | **120 itens** binários (**Certo / Errado**) *(ou 5 opções em editais específicos)* | **Fator de correção 1:1** (`+1` acerto, **`-1` erro**, `0` em branco — *1 errada anula 1 certa*) | Princípio da integralidade, exceções literais de lei seca, jurisprudência STF/STJ e interpretação textual fina |
| **FGV** *(Receita Federal, Senado, Câmara, CGU, Tribunais, OAB/ENAM)* | **5 alternativas (`A–E`)** (70–100 questões) | Sem penalização negativa (salvo edital raro) | Altíssima densidade interpretativa em Português, **casos práticos extensos** em Direito e raciocínio lógico/matemático complexo |
| **CESGRANRIO / CNU** *(Banco do Brasil, Petrobras, Caixa, CNU)* | **5 alternativas (`A–E`)** (70 questões no CNU + Discursiva) | Sem fator negativo (no CNU há pesos por Eixo Temático conforme o cargo) | Enunciados claros, políticas públicas e administração pública (no CNU), matemática financeira/ti (BB/Caixa) e aderência literal às referências |

---

## 2. Lógica de Elaboração e Arquitetura dos Distratores por Banca

### A. CEBRASPE (Certo / Errado — *Princípio da Integralidade*)
1. **Regra do 100% Verdadeiro:** Um item longo com quatro informações verdadeiras e **um único detalhe falso** no final é **ERRADO**. Não existe "parcialmente certo".
2. **Técnicas clássicas de anulação de item:**
   - **Troca de conectivo ou exceção legal:** O texto constitucional diz *"salvo em caso de..."* e o item afirma *"em nenhuma hipótese"* / *"sempre"* / *"apenas"*.
   - **Inversão de competência/quórum:** Troca *Congresso Nacional* por *Senado Federal*, *maioria absoluta* por *três quintos*, ou *prazo de 15 dias* por *30 dias*.
   - **Verdade fora do escopo textual (Português):** Afirma algo factualmente verdadeiro no mundo real, porém **não sustentado pelo texto** quando o comando diz *"Com base exclusivamente nas ideias do texto..."*.

### B. FGV (Casos Concretos + Português Semântico)
1. **Português da FGV:** Não cobra nomenclatura gramatical decoreba; cobra **reescrita de frases**, **ambiguidade**, **valor semântico de preposições/conjunções**, **tipos textuais** (*descritivo, narrativo, injuntivo, argumentativo, expositivo*) e **inferência sutil**.
2. **Direito / Administração na FGV:** Todo enunciado traz um **personagem nominal** (*"João, servidor público estável, praticou..."*). As 5 opções têm estrutura **"Conclusão + Fundamento Jurídico"** — o candidato precisa acertar *os dois lados* da alternativa.

### C. CESGRANRIO & CNU (Concurso Nacional Unificado)
1. **Eixos Temáticos Integrados (CNU):** Mistura políticas públicas brasileiras, direitos humanos, gestão governamental, ética no serviço público e dados socioeconômicos (IBGE/IPEA).
2. **Técnica de Distratores Cesgranrio:** Alternativas têm tamanhos equilibrados e foco em **conceitos administrativos exatos** (ex.: eficiência vs. eficácia vs. efetividade; descentralização vs. desconcentração; orçamento-programa vs. PPA/LDO/LOA).

---

## 3. Exemplos Reais e Modelos Comentados

### Exemplo 1 — CEBRASPE Direito Constitucional (Padrão Oficial Certo/Errado)
> **Comando padrão:** *Acerca dos direitos e garantias fundamentais na Constituição Federal de 1988, julgue o item subsequente.*  
> **Item:** *"Os tratados e convenções internacionais sobre direitos humanos que forem aprovados, em cada Casa do Congresso Nacional, em dois turnos, por três quintos dos votos dos respectivos membros, serão equivalentes às emendas constitucionais."*  
> `( ) Certo` · `( ) Errado`  
>
> **Gabarito:** **Certo**  
> **Justificativa:** Reprodução literal e integral do **art. 5º, § 3º, da CF/88**. *(Pegadinha típica caso fosse "Errado": trocar "em dois turnos" por "em turno único", "três quintos" por "dois terços", ou estender a tratados comerciais).*

### Exemplo 2 — FGV Português (Reescrita / Semântica — Padrão Oficial FGV)
> **Enunciado modelo FGV:** *"Embora a transição energética exija investimentos iniciais elevados, seus benefícios ambientais compensam o custo no longo prazo."*  
> Assinale a opção em que a reescrita da frase acima mantém o sentido original **sem alteração da relação lógica**:  
> **A.** *Visto que* a transição energética exige investimentos iniciais elevados, seus benefícios ambientais compensam o custo no longo prazo.  
> **B.** A transição energética exige investimentos iniciais elevados; *portanto*, seus benefícios ambientais compensam o custo no longo prazo.  
> **C.** *Conquanto* a transição energética exija investimentos iniciais elevados, seus benefícios ambientais compensam o custo no longo prazo.  
> **D.** *Caso* a transição energética exija investimentos iniciais elevados, seus benefícios ambientais compensarão o custo no longo prazo.  
> **E.** Os benefícios ambientais da transição energética compensam o custo no longo prazo *porque* exigem investimentos iniciais elevados.  
>
> **Gabarito:** **C (`Conquanto`)**  
> **Comentário:** `Embora` é conjunção **concessiva**, equivalente semântica direta de `Conquanto` (**C**). **A** e **E** trocam concessão por causa; **B** troca por conclusão; **D** troca por condição.

### Exemplo 3 — CESGRANRIO / CNU (Administração Pública / Políticas Públicas)
> **Enunciado modelo:** Na avaliação de políticas públicas governamentais, um programa de vacinação atingiu 98% do público-alvo dentro do orçamento previsto, porém um surto ocorreu devido ao armazenamento inadequado que inutilizou a eficácia imunológica das doses aplicadas. Sob a ótica da gestão por resultados (3Es), o programa apresentou:  
> **A.** Alta efetividade e baixa economicidade.  
> **B.** Alta eficiência operacional no gasto e na cobertura de aplicação, mas baixa eficácia e efetividade no impacto final.  
> **C.** Baixa eficiência e alta efetividade social.  
> **D.** Falha exclusiva de economicidade orçamentária.  
> **E.** Plena eficácia por ter cumprido a meta física de doses aplicadas.  
>
> **Gabarito:** **B** — **Eficiência** = fazer certo usando bem os recursos; **Eficácia** = atingir o resultado imediato real (imunização falhou); **Efetividade** = transformação duradoura na sociedade (surto não foi contido).

---

## 4. Diretrizes Obrigatórias para a IA (Geração de Simulados)

1. **Pergunte ou identifique a banca-alvo antes de gerar o estilo:**
   - **Se CEBRASPE:** Gere blocos de afirmações declarativas **`( ) Certo / ( ) Errado`** precedidas pelo comando *"Acerca de [...], julgue os itens a seguir"*. Ao corrigir a bateria do usuário, **calcule a nota líquida com penalidade `Acertos - Erros`**!
   - **Se FGV:** Gere **5 alternativas (`A–E`)** com casos concretos nominais em Direito, questões semânticas/textuais refinadas em Português e enunciados com alternativas do tipo *"Afirmação + Justificativa"*.
   - **Se CESGRANRIO / CNU:** Gere **5 alternativas (`A–E`)** com foco em administração pública, políticas públicas, realidade brasileira ou conhecimentos bancários/TI conforme a área.
2. **Rigor normativo atualizado (Brasil):** Observe estritamente a **CF/88 atualizada**, a **Nova Lei de Licitações (`Lei 14.133/2021`)**, a **Lei de Improbidade reformada (`Lei 14.230/2021`)**, o **CPC/2015** e súmulas vinculantes/jurisprudência recente do STF e STJ.
3. **Justificativa item a item:** No gabarito, cite o **dispositivo legal exato** ou a **regra gramatical/conceitual** e sinalize onde estava a eventual palavra-armadilha (*"sempre", "apenas", troca de prazo ou de quórum*).
4. **Divisão Sequencial por Cadernos/Disciplinas (Sem Mistura Aleatória):** Ao gerar simulados ou baterias sequenciais, **não misture disciplinas alternadamente dentro do mesmo bloco**. Respeite rigorosamente a ordem dos blocos da prova (1) Língua Portuguesa & Interpretação -> 2) Direito Constitucional -> 3) Direito Administrativo & Licitações -> 4) Raciocínio Lógico & Informática -> 5) Conhecimentos Específicos & Políticas Públicas), preenchendo integralmente a cota de cada disciplina antes de passar para a próxima e identificando o campo `discipline` em cada questão.
