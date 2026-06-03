# Tutorial de Simulação — CPU 8 bits + RAM 8x8

Este tutorial guia a simulação comportamental do sistema CPU + RAM no Vivado,
usando o testbench `conjunto_5`.

## Pré-requisitos

- Vivado ML Edition 2025.2 (ou superior) instalado
- Windows 10/11 ou Linux
- Arquivos do repositório clonados localmente

## 1. Criar o projeto no Vivado

1. Abra o Vivado
2. Clique em **Create Project**
3. Dê o nome `cpu8_sim` e escolha um diretório
4. Selecione **RTL Project** → marque **Do not specify sources at this time** → **Next**
5. Em **Default Part**, selecione qualquer dispositivo (a simulação não depende do hardware)
6. Clique em **Finish**

## 2. Adicionar os arquivos fonte

> ⚠️ A ordem de compilação é importante: `cpu_vhdl_v3_comentado.vhd` deve ser adicionado **antes** de `conjunto_5.vhd`, pois define o pacote `cpu_aux` usado pelos demais.

1. Clique em **Add Sources** no painel esquerdo
2. Selecione **Add or create design sources** → **Next**
3. Clique em **Add Files** e selecione:
   - `src/cpu_vhdl_v3_comentado.vhd`
4. Clique **Finish**

5. Clique em **Add Sources** novamente
6. Selecione **Add or create simulation sources** → **Next**
7. Clique em **Add Files** e selecione:
   - `sim/conjunto_5.vhd`
8. Clique **Finish**

## 3. Configurar o testbench como topo da simulação

1. No painel **Sources**, expanda **Simulation Sources**
2. Clique com botão direito em `conjunto_5` → **Set as Top**

O testbench `conjunto_5` já contém:
- Gerador de clock: período de 100 ns (50 MHz equivalente)
- Reset assíncrono: `rst_b` sobe para `'1'` em 150 ns

## 4. Executar a simulação

1. No painel **Flow Navigator**, clique em **Run Simulation** → **Run Behavioral Simulation**
2. O Vivado abrirá o **Waveform Viewer** automaticamente

## 5. Configurar o tempo de simulação

O programa completo leva aproximadamente **50 µs** para executar. Para estender:

1. Na barra de ferramentas do Waveform, localize o campo de tempo
2. Digite `50` e selecione `us`
3. Clique no botão **Run for specified time** (▶)

## 6. Sinais recomendados para observar

Adicione os seguintes sinais ao waveform para acompanhar a execução:

**Da CPU (instância `x0`):**
| Sinal | Formato | O que mostra |
|---|---|---|
| `Estado` | Enum | Instrução atual sendo executada |
| `Passo_rd_wr` | Decimal | Etapa do ciclo de memória (0 a 3) |
| `Passo_op_cod` | Decimal | Etapa da instrução (0 ou 1) |
| `PC` | Hexadecimal | Endereço da instrução atual |
| `Ir` | Hexadecimal | Instrução em execução |
| `Acc` | Hexadecimal | Valor atual do acumulador |
| `Aux` | Hexadecimal | Registrador auxiliar |
| `Pg` | Hexadecimal | Página de memória atual |
| `St` | Hexadecimal | Stack pointer |
| `alu_flags` | Binário | Flags Z (bit 1) e N (bit 0) |

**Do barramento:**
| Sinal | Formato | O que mostra |
|---|---|---|
| `Ed` | Hexadecimal | Endereço no barramento |
| `Dt` | Hexadecimal | Dado no barramento |
| `mrq_n` | Binário | Memory request (ativo em baixo) |
| `rd_n` | Binário | Read (ativo em baixo) |
| `wr_n` | Binário | Write (ativo em baixo) |

> 💡 Para exibir `Estado` como enum (não binário): clique com botão direito no sinal → **Radix** → **Enum**

## 7. Resultado esperado

A tabela abaixo mostra os principais eventos que devem aparecer no waveform:

| Endereço (PC) | Instrução | Efeito esperado |
|---|---|---|
| `0x00` | `LDmP 0xA` | `Pg = 0xA` — define página A |
| `0x01` | `LDmS 0xFF` | `St = 0xFF` — inicializa pilha |
| `0x03` | `LDdA 0x0` | `Acc = 0x77` — carrega mem[A0] |
| `0x04` | `ADdA 0xF` | `Acc = 0x7A` — 0x77 + 0x03 |
| `0x05` | `STdA 0x1` | mem[A1] ← 0x7A |
| `0x06` | `LDiA 0xE` | `Acc = 0x25` — indireto via mem[AE]→mem[A2] |
| `0x08` | `STiA 0xC` | mem[mem[AC]] ← 0x25 |
| `0x09` | `Jump 0x3A` | PC ← 0x3A — salto incondicional |
| `0x3A` | `LDmA 0xFB` | `Acc = 0xFB` |
| `0x3C` | `ADdA 0x7` | `Acc = 0xFF` — 0xFB + 0x04 |
| `0x3D` | `JPNG 0x40` | Salta para 0x40 (Acc negativo) |
| `0x40` | `Call 0x70` | Empilha retorno, salta para 0x70 |
| `0x70` | `LDmA 0x03` | `Acc = 0x03` |
| `0x72` | `SBdA 0xB` | `Acc = 0x02` — loop de contagem |
| `0x72` | `SBdA 0xB` | `Acc = 0x01` |
| `0x72` | `SBdA 0xB` | `Acc = 0x00` |
| `0x75` | `RETN` | Retorna para 0x42 |
| `0x42` | `Halt` | CPU para — Estado permanece em Halt |

## 8. Verificando o resultado

A simulação está correta quando:
- ✅ `Estado` passa por `Busca`, decodifica cada instrução e retorna a `Busca`
- ✅ `Acc` assume os valores `0x77`, `0x7A`, `0x25`, `0xFB`, `0xFF`, `0x03`, `0x02`, `0x01`, `0x00` na sequência
- ✅ `PC` avança de `0x00` até `0x42` seguindo os saltos do programa
- ✅ `Estado` trava em `Halt` ao chegar em `0x42`
