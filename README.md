# cpu8-vhdl

CPU 8 bits + RAM 8x8 em VHDL implementada em FPGA.

Trabalho da disciplina de **Sistemas Reconfiguráveis**,  
ministrada pelo prof. **Vinicius da Silva Borges**.  
Semestre **2026/1**.

## Integrante

- Gustavo Correa Pedro de Carvalho

## Descrição

Este trabalho implementa, em VHDL, um sistema computacional composto por uma CPU de 8 bits baseada em acumulador e uma RAM de 256 posições × 8 bits, compartilhando um barramento bidirecional de dados. A CPU possui um conjunto de 17 estados (incluindo Halt) que cobrem instruções de carga e armazenamento (direto e indireto), aritméticas (ADD/SUB), saltos condicionais e incondicionais, chamada e retorno de sub-rotina, e seleção de página de memória. A integração CPU + memória é verificada pela entidade `conjunto_5`, que simula a execução de um programa carregado na RAM.

A implementação foi realizada e validada em duas placas FPGA: **Digilent Basys 2** (Spartan-3E, XC3S100E) utilizando o Xilinx ISE 14.7, e **Digilent Basys 3** (Artix-7, XC7A35T) utilizando o Vivado 2025.2.

## Estrutura do repositório

```
cpu8-vhdl/
├── src/
│   └── cpu_vhdl_v3_comentado.vhd   CPU + RAM + Pacote auxiliar (arquivo único)
├── sim/
│   └── conjunto_5.vhd              Testbench integrando CPU + RAM
├── constraints/
│   ├── basys2_top_sw7_comentado.ucf  Mapeamento de pinos para Basys 2 (ISE)
│   └── basys3_top.xdc                Mapeamento de pinos para Basys 3 (Vivado)
├── top/
│   ├── basys2_top_v5_comentado.vhd   Top-level sintetizável para Basys 2
│   └── basys3_top.vhd                Top-level sintetizável para Basys 3
├── bitstream/
│   ├── basys2_top.bit                Bitstream pronto para gravar na Basys 2
│   └── basys3_top.bit                Bitstream pronto para gravar na Basys 3
└── docs/
    ├── tutorial_simulacao.md         Como simular no Vivado
    ├── tutorial_placa.md             Como gravar na placa
    └── documentacao_projeto.md       Documentação técnica completa
```

## Arquivos de código

| Arquivo | Descrição |
|---|---|
| `src/cpu_vhdl_v3_comentado.vhd` | Pacote `cpu_aux` (Tipo_Estado + para_estado), entidade `cpu_8bits` com duas FSMs cooperantes (borda_subida e borda_descida), ALU, e entidade `ram_8x8` com programa de teste pré-carregado. Expõe `Acc_out`, `PC_out` e `Acc_wr` como portas. |
| `sim/conjunto_5.vhd` | Testbench `conjunto_5`: instancia CPU e RAM, conecta `mrq_n→ce_n` e `rd_n→oe_n`, gera clock (100ns) e reset (150ns) |
| `top/basys2_top_v5_comentado.vhd` | Top-level para Basys 2: clock manual (BTN1), reset (BTN0), seletor ACC/PC (SW7), LEDs |
| `top/basys3_top.vhd` | Top-level para Basys 3: clock manual (BTNU), reset (BTNC), seletor ACC/PC (SW0), LEDs |
| `constraints/basys2_top_sw7_comentado.ucf` | Constraints UCF para Basys 2 (ISE 14.7) |
| `constraints/basys3_top.xdc` | Constraints XDC para Basys 3 (Vivado 2025.2) |

## Documentação

- [Tutorial de simulação](./docs/tutorial_simulacao.md) — como simular `conjunto_5` no Vivado passo a passo
- [Tutorial de gravação na placa](./docs/tutorial_placa.md) — como sintetizar, gerar bitstream e gravar na FPGA
- [Documentação técnica](./docs/documentacao_projeto.md) — ISA completa, registradores, FSMs e barramentos

## Ferramentas utilizadas

| Ferramenta | Versão | Uso |
|---|---|---|
| Xilinx ISE WebPACK | 14.7 | Síntese e gravação na Basys 2 |
| Vivado ML Edition | 2025.2 | Síntese e gravação na Basys 3 |
| Digilent Adept | 2.30.4 | Programação da Basys 2 via USB |
| VirtualBox | 7.x | VM para rodar o ISE no Windows 11 |
| Placa FPGA | Digilent Basys 2 (XC3S100E) | Implementação hardware |
| Placa FPGA | Digilent Basys 3 (XC7A35T) | Implementação hardware |

## Por onde começar

Para uma **simulação rápida** (apenas ver funcionando):
1. Abrir o Vivado e criar um projeto com `src/cpu_vhdl_v3_comentado.vhd` e `sim/conjunto_5.vhd`
2. Definir `conjunto_5` como top da simulação
3. Clicar em `Run Simulation` → `Run Behavioral Simulation`
4. Estender o tempo de simulação para alguns microssegundos

Para **reproduzir o projeto do zero**, siga esta ordem:
1. **Entenda a ISA e a arquitetura** lendo a [documentação técnica](./docs/documentacao_projeto.md)
2. **Simule no Vivado** seguindo o [tutorial de simulação](./docs/tutorial_simulacao.md)
3. **Grave na placa** seguindo o [tutorial de gravação](./docs/tutorial_placa.md)

## Uso na placa

### Basys 2
| Controle | Função |
|---|---|
| BTN0 (G12) | Reset da CPU |
| BTN1 (C11) | Clock manual — 2 apertos = 1 ciclo completo |
| SW7 (N3) baixo | LEDs mostram ACC (acumulador) |
| SW7 (N3) alto | LEDs mostram PC (program counter) |

### Basys 3
| Controle | Função |
|---|---|
| BTNC (U18) | Reset da CPU |
| BTNU (T18) | Clock manual — 2 apertos = 1 ciclo completo |
| SW0 (V17) baixo | LEDs mostram ACC (acumulador) |
| SW0 (V17) alto | LEDs mostram PC (program counter) |

## Demonstração

Vídeo da CPU em execução na placa Digilent Basys 3, mostrando o avanço manual do clock e a visualização do acumulador (ACC) e do contador de programa (PC) nos LEDs:

https://github.com/viniciussbrg/cpu8_vhdl/raw/main/media/demonstracao_basys3.mp4


O arquivo de vídeo está disponível em media/demonstracao_basys3.mp4.
