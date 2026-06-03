# Documentação Técnica — CPU 8 bits + RAM 8x8

## 1. Visão geral do sistema

O sistema implementa uma CPU de 8 bits baseada em acumulador comunicando-se com uma RAM de 256 posições × 8 bits por meio de um barramento bidirecional de dados (`Dt`), um barramento de endereço de 8 bits (`Ed`) e três sinais de controle (`mrq_n`, `rd_n`, `wr_n`). O modelo adotado é **Von Neumann**: instruções e dados compartilham a mesma memória.

## 2. Diagrama de blocos do sistema integrado

```
         +------------------+          +------------------+
         |    cpu_8bits     |          |     ram_8x8      |
         |                  |          |                  |
         |  mrq_n (Buffer)--|--ce_n--->|ce_n (In)         |
         |  rd_n  (Buffer)--|--oe_n--->|oe_n (In)         |
         |  wr_n  (Buffer)--|--------->|wr_n (In)         |
         |  Ed    (Out)-----|--------->|Ed   (In)         |
         |  Dt    (InOut)<--|--------->|Dt   (InOut)      |
         |                  |          |                  |
         |  Acc_out (Out)   |          +------------------+
         |  PC_out  (Out)   |
         |  Acc_wr  (Out)   |
         +------------------+

Mapeamento feito no top-level:
  mrq_n → ce_n
  rd_n  → oe_n
  wr_n  → wr_n
```

## 3. Diagrama de blocos interno da CPU

```
+----------------------------------------------------------+
|                        cpu_8bits                         |
|                                                          |
|  +----------+   +----------+   +----------+             |
|  |    PC    |   |    Ir    |   |   Acc    |---> Acc_out |
|  +----------+   +----------+   +----------+             |
|       |               |               |                 |
|  +----------+   +----------+   +----------+             |
|  |  pc_inc  |   |   Aux    |   |  alu_b   |             |
|  |(Contador)|   +----------+   +----------+             |
|  +----------+                       |                   |
|       |         +----------+   +----------+             |
|  +----------+   |    Pg    |   |  alu_s   |             |
|  |  PC_out  |   +----------+   |(Unidade  |             |
|  +----------+                  | Logica)  |             |
|                +----------+   +----------+              |
|                |    St    |   | alu_flags|              |
|                +----------+   +----------+              |
|                |  st_novo |                             |
|                |  (pilha) |                             |
|                +----------+                             |
|                                                         |
|  +-------------------------+  +---------------------+  |
|  |     borda_subida        |  |    borda_descida     |  |
|  | (FSM principal - ck↑)  |  | (FSM barramento-ck↓)|  |
|  |  Ler, Escrever →        |  |  ← Passo_rd_wr      |  |
|  +-------------------------+  +---------------------+  |
+----------------------------------------------------------+
```

## 4. Registradores internos da CPU

| Registrador | Largura | Função |
|---|---|---|
| PC | 8 bits | Program Counter — endereço da próxima instrução |
| Ir | 8 bits | Instruction Register — instrução em execução |
| Acc | 8 bits | Acumulador — operando e destino das operações aritméticas |
| Aux | 8 bits | Registrador auxiliar (endereçamento indireto e Call) |
| Pg | 4 bits | Página atual de dados (carregada por LDmP) |
| St | 8 bits | Stack Pointer (carregado por LDmS) |
| alu_flags | 2 bits | Flags Z (bit 1) e N (bit 0) atualizadas por ADD/SUB |
| End_mem | 8 bits | Endereço apresentado no barramento Ed |
| Dado_escr | 8 bits | Dado apresentado em Dt durante escrita |

## 5. Interface da entidade cpu_8bits

| Porta | Tipo | Função |
|---|---|---|
| ck | Std_Logic (In) | Clock |
| rst_b | Std_Logic (In) | Reset assíncrono ativo em baixo |
| mrq_n | Std_Logic (Buffer) | Memory Request ativo em baixo |
| rd_n | Std_Logic (Buffer) | Read ativo em baixo |
| wr_n | Std_Logic (Buffer) | Write ativo em baixo |
| Ed | Std_Logic_Vector(7:0) (Out) | Endereço de memória |
| Dt | Std_Logic_Vector(7:0) (InOut) | Dado bidirecional |
| Acc_out | Std_Logic_Vector(7:0) (Out) | Saída direta do acumulador |
| PC_out | Std_Logic_Vector(7:0) (Out) | Saída direta do PC |
| Acc_wr | Std_Logic (Out) | Indica quando ACC foi atualizado |

## 6. Interface da entidade ram_8x8

| Porta | Tipo | Função |
|---|---|---|
| ce_n | Std_Logic (In) | Chip Enable ativo em baixo |
| oe_n | Std_Logic (In) | Output Enable ativo em baixo |
| wr_n | Std_Logic (In) | Write ativo em baixo |
| Ed | Std_Logic_Vector(7:0) (In) | Endereço acessado |
| Dt | Std_Logic_Vector(7:0) (InOut) | Dado lido/escrito |

## 7. Parâmetros (generics) da CPU

| Generic | Padrão | Descrição |
|---|---|---|
| ne | 8 | Largura do barramento de endereço |
| nd | 8 | Largura do barramento de dados |

> ⚠️ Embora os generics existam, o código interno está atrelado a 8 bits e não suporta alteração nesses valores.

## 8. Especificação da ISA (Instruction Set Architecture)

**Largura da instrução:** 8 bits

**Dois formatos de codificação:**
- **Formato curto:** opcode no nibble alto `Ir(7:4)`, operando de 4 bits no nibble baixo `Ir(3:0)`. Usado quando `Ir(7:4) ≠ 0xF`
- **Formato longo:** opcode ocupa os 8 bits completos (0xF0...0xFF); o operando, quando existe, vem no byte seguinte da memória

### Tabela de instruções

| Opcode | Mnemônico | Formato | Operação |
|---|---|---|---|
| 0x0n | LDmP | curto | `Pg ← n` — carrega a página de dados |
| 0x1n | LDdA | curto | `Acc ← M[Pg & n]` — load direto |
| 0x2n | LDiA | curto | `Acc ← M[M[Pg & n]]` — load indireto |
| 0x3n | STdA | curto | `M[Pg & n] ← Acc` — store direto |
| 0x4n | STiA | curto | `M[M[Pg & n]] ← Acc` — store indireto |
| 0xAn | ADdA | curto | `Acc ← Acc + M[Pg & n]`; atualiza Z, N |
| 0xBn | SBdA | curto | `Acc ← Acc - M[Pg & n]`; atualiza Z, N |
| 0xF0 | Jump | longo | `PC ← M[PC+1]` — salto incondicional |
| 0xF1 | JP_Z | longo | Salta se Z = 1 |
| 0xF2 | JPNZ | longo | Salta se Z = 0 |
| 0xF3 | JPNG | longo | Salta se N = 1 |
| 0xF6 | LDmS | longo | `St ← M[PC+1]` — inicializa pilha |
| 0xF7 | LDmA | longo | `Acc ← M[PC+1]` — load imediato |
| 0xF8 | Call | longo | Empilha PC+2 em M[St], decrementa St, salta para M[PC+1] |
| 0xF9 | RETN | longo | Incrementa St, `PC ← M[St]` |
| 0xFF | Halt | longo | Para a execução (estado fixo em Halt) |

**Nota sobre decodificação:** a função `para_estado` (em `cpu_aux`) implementa essa tabela com dois `case`: primeiro testa se `Ir(7:4) = 0xF`; se sim, decodifica o byte inteiro; se não, decodifica apenas o nibble alto. Opcodes não mapeados são interpretados como Halt.

## 9. Organização da memória (ram_8x8)

256 posições endereçáveis (0x00 a 0xFF) de 8 bits cada. Não há separação física entre instruções e dados:

| Região | Endereços | Conteúdo |
|---|---|---|
| Programa principal | 0x00 – 0x0A | Instruções iniciais |
| Sub-rotina de salto | 0x3A – 0x3E | Código após Jump |
| Chamada de sub-rotina | 0x40 – 0x42 | Call + Halt |
| Sub-rotina de contagem | 0x70 – 0x75 | Loop com SBdA |
| Dados (página A) | 0xA0 – 0xAF | Variáveis e ponteiros |
| Topo da pilha | 0xFF | Endereço inicial do St |

## 10. Endereçamento efetivo no formato curto

O endereço de memória usado por `LDdA`, `LDiA`, `STdA`, `STiA`, `ADdA` e `SBdA` é formado pela concatenação `Pg & Ir(3:0)` (8 bits = 4 bits da página corrente + 4 bits do operando). Cada instrução `LDmP` troca a página de dados visível por essas instruções.

**Exemplo:** `LDmP 0xA` seguido de `LDdA 0x0` acessa `M[0xA0]`.

## 11. Funcionamento interno — duas FSMs cooperantes

### borda_subida (processo principal)
- Atua na **borda de subida** do clock
- Decodifica a instrução em Ir, gerencia Estado, PC, Acc, etc.
- Solicita acessos à memória pelos sinais booleanos `Ler` e `Escrever`
- Observa `Passo_rd_wr` para saber em que etapa do acesso está

### borda_descida (processo de barramento)
- Atua na **borda de descida** do clock
- Sequencia o handshake de memória em 4 passos (`Passo_rd_wr`):

| Passo | Ação (Leitura) | Ação (Escrita) |
|---|---|---|
| 0 | Ativa `mrq_n=0`, `rd_n=0` | Ativa `mrq_n=0` |
| 1 | Aguarda | Ativa `wr_n=0` |
| 2 | Desativa `mrq_n`, `rd_n` | Desativa `mrq_n`, `wr_n` |
| 3 | Reinicia ciclo | Reinicia ciclo |

No passo 2 o dado lido já está estável em `Dt`; no passo 3 a transação encerra.

### Instruções multi-acesso
`LDiA`, `STiA` e `Call` usam `Passo_op_cod` (0 ou 1) para distinguir:
- **Passo 0:** leitura do ponteiro/endereço alvo (armazenado em `Aux`)
- **Passo 1:** leitura/escrita efetiva ou empilhamento

## 12. Blocos combinacionais auxiliares

### Unidade_logica (ALU)
```
alu_s = Acc + alu_b   (se Estado = ADdA)
      = Acc - alu_b   (caso contrário)
alu_z = '1' se alu_s = 0
alu_n = alu_s(7)      (bit de sinal)
```

### Contador_Programa
```
pc_inc = PC + 1   (combinacional)
```

### pilha
```
st_novo = St - 1   (em Call — pilha cresce para baixo)
        = St + 1   (em RETN — desempilha)
```

## 13. Driver tri-state do barramento de dados

A CPU dirige `Dt` com `Dado_escr` apenas durante uma operação de escrita ativa (`Escrever AND mrq_n = '0'`); caso contrário, libera o barramento (`'Z'`). A RAM segue o mesmo princípio — libera `Dt` quando não está sendo lida.

## 14. Programa de teste contido em ram_8x8

| Endereço | Opcode | Instrução | Efeito |
|---|---|---|---|
| 0x00 | 0x0A | LDmP 0xA | Pg = 0xA — define página A |
| 0x01 | 0xF6 | LDmS | St = M[0x02] = 0xFF |
| 0x03 | 0x10 | LDdA 0x0 | Acc = M[A0] = 0x77 |
| 0x04 | 0xAF | ADdA 0xF | Acc = 0x77 + M[AF] = 0x77 + 0x03 = 0x7A |
| 0x05 | 0x31 | STdA 0x1 | M[A1] = 0x7A |
| 0x06 | 0x2E | LDiA 0xE | Acc = M[M[AE]] = M[A2] = 0x25 |
| 0x08 | 0x4C | STiA 0xC | M[M[AC]] = M[A3] = 0x25 |
| 0x09 | 0xF0 | Jump | PC = M[0x0A] = 0x3A |
| 0x3A | 0xF7 | LDmA | Acc = M[0x3B] = 0xFB |
| 0x3C | 0xA7 | ADdA 0x7 | Acc = 0xFB + M[A7] = 0xFB + 0x04 = 0xFF (N=1) |
| 0x3D | 0xF3 | JPNG | N=1 → salta para M[0x3E] = 0x40 |
| 0x40 | 0xF8 | Call | Empilha retorno (0x42) em M[0xFF], St=0xFE, PC=0x70 |
| 0x70 | 0xF7 | LDmA | Acc = M[0x71] = 0x03 |
| 0x72 | 0xBB | SBdA 0xB | Acc = 0x03 - M[AB] = 0x03 - 0x01 = 0x02 |
| 0x73 | 0xF2 | JPNZ | Z=0 → volta para 0x72 |
| 0x72 | 0xBB | SBdA 0xB | Acc = 0x02 - 0x01 = 0x01 |
| 0x73 | 0xF2 | JPNZ | Z=0 → volta para 0x72 |
| 0x72 | 0xBB | SBdA 0xB | Acc = 0x01 - 0x01 = 0x00 (Z=1) |
| 0x73 | 0xF2 | JPNZ | Z=1 → não salta, continua |
| 0x75 | 0xF9 | RETN | St=0xFF, PC = M[0xFF] = 0x42 |
| 0x42 | 0xFF | Halt | CPU para indefinidamente |

**Sequência do ACC:** `0x00 → 0x77 → 0x7A → 0x25 → 0xFB → 0xFF → 0x03 → 0x02 → 0x01 → 0x00 → Halt`

## 15. Mapeamento físico na placa

### Basys 2 (UCF)

| Sinal VHDL | Pino | Componente | Função |
|---|---|---|---|
| clk | B8 | Clock 50MHz | Clock do sistema |
| btn0 | G12 | BTN0 | Reset |
| btn1 | C11 | BTN1 | Clock manual |
| sw0 | N3 | SW7 | Seletor ACC/PC |
| led[0..7] | M5, M11, P7, P6, N5, N4, P4, G1 | LD0..LD7 | Exibição |

### Basys 3 (XDC)

| Sinal VHDL | Pino | Componente | Função |
|---|---|---|---|
| clk | W5 | Clock 100MHz | Clock do sistema |
| btn0 | U18 | BTNC | Reset |
| btn1 | T18 | BTNU | Clock manual |
| sw0 | V17 | SW0 | Seletor ACC/PC |
| led[0..7] | U16, E19, U19, V19, W18, U15, U14, V14 | LD0..LD7 | Exibição |

## 16. Dependências e ambiente

| Componente | Versão |
|---|---|
| Vivado ML Edition | 2025.2 |
| Xilinx ISE WebPACK (via VM) | 14.7 |
| VirtualBox | 7.x |
| Digilent Adept Runtime | 2.30.4 |
| Placa | Digilent Basys 2 (XC3S100E) |
| Placa | Digilent Basys 3 (XC7A35T) |
| Biblioteca | IEEE.Std_Logic_1164 |
| Biblioteca | IEEE.Std_Logic_arith (Synopsys) |
| Biblioteca | IEEE.Std_Logic_unsigned (Synopsys) |

> As bibliotecas `IEEE.Std_Logic_arith` e `IEEE.Std_Logic_unsigned` são bibliotecas Synopsys necessárias para os operadores aritméticos sobre `Std_Logic_Vector` usados no código.
