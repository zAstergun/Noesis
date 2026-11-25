# Cisco CCNA (200-301 v1.1) — Cisco Certified Network Associate

> Guia de parâmetros para geração e correção de simulados pela IA — atualizado para o blueprint vigente **CCNA 200-301 v1.1** (`learningnetwork.cisco.com`).

---

## 1. Requisitos e Estrutura Oficial

| Parâmetro | Cisco CCNA 200-301 (v1.1) |
| :--- | :--- |
| **Duração e Volume** | **120 minutos** · ~**100–120 questões** (inclui **Performance-Based Labs / Simlets** de CLI Cisco IOS!) |
| **Escala e Corte** | **300 – 1.000 pontos** · Nota de corte típica ~**825 / 1.000** (variável por forma do exame) |
| **Regra de Navegação** | **Não é possível voltar** para questões já avançadas (*No Backtracking*) |

### Domínios Oficiais e Pesos (CCNA 200-301 v1.1)
1. **1.0 Network Fundamentals** — **20%** (OSI vs. TCP/IP, cabos/fibra, PoE, IPv4 subnetting/VLSM, IPv6 endereçamento EUI-64/SLAAC, Wi-Fi)
2. **2.0 Network Access** — **20%** (VLANs, 802.1Q trunking, Native VLAN, STP/RSTP eleições de Root Bridge, EtherChannel LACP/PAgP, WLC/APs)
3. **3.0 IP Connectivity** — **25%** *(Maior peso)* (Leitura de tabela de roteamento — Longest Prefix Match, Administrative Distance, métrica; Static routes, **OSPFv2** área única e DR/BDR, FHRP/HSRP)
4. **4.0 IP Services** — **10%** (NAT/PAT, NTP, DHCPv4 relay `ip helper-address`, DNS, SNMP, Syslog, SSH, QoS PHB)
5. **5.0 Security Fundamentals** — **15%** (ACLs Standard/Extended, Port Security, DHCP Snooping, DAI, WPA2/WPA3, AAA/RADIUS/TACACS+)
6. **6.0 Automation and Programmability** — **10%** (Controladores SDN/Cisco Catalyst Center, REST APIs, JSON, Terraform/Ansible, **Generative AI / LLMs em operações de rede** — adicionado na v1.1)

---

## 2. Lógica de Elaboração e Arquitetura dos Distratores

1. **Regra da Tabela de Roteamento (Longest Prefix Match vs. AD vs. Metric):**
   - Ao receber um pacote destino, o roteador escolhe **primeiro o prefixo mais específico** (`/26` vence `/24`, mesmo que `/24` seja rota estática AD 1 e `/26` seja OSPF AD 110!).
   - **Administrative Distance (AD)** só desempata **prefixos idênticos** anunciados por protocolos diferentes (`Connected 0 < Static 1 < eBGP 20 < EIGRP 90 < OSPF 110 < RIP 120`).
   - **Métrica** só desempata **dentro do mesmo protocolo** (ex.: custo OSPF baseado em *Reference Bandwidth / Interface Bandwidth*).
2. **Armadilhas clássicas de Layer 2 (Switching/STP/VLAN):**
   - **Eleição de Root Bridge STP:** Menor **Bridge ID** (`Priority + MAC`) vence — se as prioridades forem iguais (`32768 + VLAN ID`), vence o **menor MAC address**.
   - **Voice VLAN + Data VLAN:** Porta de acesso com telefone IP usa `switchport mode access` + `switchport access vlan <data>` + `switchport voice vlan <voice>`, **não** `mode trunk`!
   - **EtherChannel:** Exige compatibilidade exata de velocidade, duplex, modo trunk/access e VLANs permitidas; **LACP** (`active/passive` — `passive+passive` falha!) vs. **PAgP** (`desirable/auto` — `auto+auto` falha!).
3. **Leitura de saídas CLI Cisco IOS (`show ip route`, `show ip ospf neighbor`, `show interfaces trunk`, `show running-config`):** A maioria das questões apresenta uma topologia + print de terminal e pede para diagnosticar por que dois hosts não se comunicam (ex.: máscara invertida na wildcard do OSPF, `Native VLAN mismatch`, ACL aplicada na direção errada `in` vs. `out` ou sem `permit ip any any`).
4. **Subnetting & Wildcard Masks rápidos:** Confundir `/26` (`255.255.255.192`, bloco 64, 62 hosts úteis) com `/27`, ou usar máscara de sub-rede normal em vez de **wildcard mask** (`0.0.0.63`) em ACL/OSPF `network`.

---

## 3. Exemplos Reais e Modelos Comentados (Padrão CCNA 200-301)

### Exemplo 1 — Network Access: Voice & Data VLAN (Modelo Oficial CCNA)
> **Question:** A network engineer is configuring a switch interface to connect to an external VoIP phone and a corporate PC. The phone passes tagged voice traffic belonging to VLAN 20, and the PC passes untagged data traffic meant for VLAN 10.  
> **Which set of commands correctly configures the switch port interface to handle both data and voice VLAN traffic?**  
> **A.**  
> ```text
> Switch(config-if)# switchport mode access
> Switch(config-if)# switchport access vlan 10
> Switch(config-if)# switchport voice vlan 20
> ```
> **B.**  
> ```text
> Switch(config-if)# switchport mode trunk
> Switch(config-if)# switchport trunk native vlan 10
> Switch(config-if)# switchport trunk allowed vlan 10,20
> ```
> **C.** `switchport mode dynamic desirable` + `switchport access vlan 10`  
> **D.** `switchport mode dot1q-tunnel` + `switchport access vlan 10`  
>
> **Gabarito:** **A**  
> **Comentário:** **A** configura uma porta de acesso padrão para o tráfego não-tagueado do PC na VLAN 10 enquanto habilita a VLAN auxiliar de voz (CDP/LLDP instrui o telefone IP a taguear voz na VLAN 20). **B** expõe o PC corporativo a configuração de *trunking*; **C** tenta negociar DTP; **D** é túnel QinQ de provedor.

### Exemplo 2 — IP Connectivity: Roteamento & Longest Prefix Match
> **Enunciado:** Um roteador Cisco possui as seguintes entradas na tabela de roteamento (`show ip route`):  
> - `S    10.10.20.0/24 [1/0] via 192.168.1.2`  
> - `O    10.10.20.64/26 [110/20] via 192.168.2.2`  
> - `D    10.10.0.0/16 [90/2170112] via 192.168.3.2`  
> Para qual próximo salto (*next-hop*) o roteador encaminhará um pacote com destino `10.10.20.75`?  
> **A.** `192.168.1.2` (Static tem AD 1)  
> **B.** `192.168.2.2` (OSPF tem o prefixo mais longo `/26`)  
> **C.** `192.168.3.2` (EIGRP tem AD menor que OSPF)  
> **D.** O pacote será descartado por empate de métrica  
>
> **Gabarito:** **B (`192.168.2.2`)**  
> **Comentário:** O endereço `10.10.20.75` pertence a `/16`, `/24` (`10.10.20.0–255`) e `/26` (`10.10.20.64–127`). Como `/26` é a máscara mais específica (**Longest Prefix Match**), ela vence independentemente da AD (`1` vs. `110`)! **A** e **C** são os distratores clássicos de AD antes de checar comprimento do prefixo.

### Exemplo 3 — Lab Prático CLI (Simlet CCNA)
> **Enunciado típico:** *"Configure OSPF Process ID 10 on R1 and R2 in Area 0, set Router-ID `1.1.1.1` on R1, ensure passive-interface on `Gig0/1`, and verify neighbor adjacency reaches `FULL`."*  
> **Comandos essenciais:** `router ospf 10` -> `router-id 1.1.1.1` -> `network 10.0.0.0 0.0.0.3 area 0` -> `passive-interface GigabitEthernet0/1` -> `do show ip ospf neighbor`.

---

## 4. Diretrizes Obrigatórias para a IA (Geração de Simulados)

1. **Respeite a distribuição de pesos v1.1:** Concentre 45% das questões em **IP Connectivity (25%)** e **Network Access (20%)**, mas inclua obrigatoriamente **Security Fundamentals (15%)** e **Automation/APIs/JSON (10%)**.
2. **Inclua blocos autênticos de CLI Cisco IOS (`show ...`) e JSON/REST:** Sempre que testar troubleshooting de OSPF, VLAN/STP, ACLs ou NAT, apresente uma **saída realista de console Cisco** para o candidato diagnosticar a falha.
3. **Inclua 1 mini-laboratório CLI por simulado:** Peça a sequência exata de comandos em modo de configuração global/interface (`Router(config-if)# ...`) e forneça o gabarito comentado com comandos de verificação (`show ip route`, `show vlan brief`, `show access-lists`).
4. **Atenção matemática nas questões de Subnetting e Wildcard:** Verifique rigorosamente cálculo binário (endereço de rede, primeiro/último host válido, broadcast e máscara curinga) antes de fechar o gabarito.
5. **Divisão Sequencial por Cadernos/Disciplinas (Sem Mistura Aleatória):** Ao gerar simulados ou baterias sequenciais, **não misture disciplinas alternadamente dentro do mesmo bloco**. Respeite rigorosamente a ordem dos blocos da prova (1) Network Fundamentals -> 2) Network Access (VLAN/STP) -> 3) IP Connectivity (Routing/OSPF) -> 4) IP Services -> 5) Security Fundamentals -> 6) Automation & Programmability), preenchendo integralmente a cota de cada disciplina antes de passar para a próxima e identificando o campo `discipline` em cada questão.
