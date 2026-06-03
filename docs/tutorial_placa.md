# Tutorial de Gravação na Placa — CPU 8 bits + RAM 8x8

Este tutorial guia a síntese, geração de bitstream e gravação do projeto nas placas
Basys 2 e Basys 3.

---

## Basys 2 (Spartan-3E, XC3S100E) — via ISE 14.7 + VM

### Pré-requisitos

- Windows 10/11
- VirtualBox instalado
- ISE 14.7 Virtual Machine instalada (fornecida pela AMD/Xilinx)
- Digilent Adept 2 Runtime + Utilities instalados
- Placa Basys 2 com cabo USB

> ⚠️ O ISE 14.7 não roda nativamente no Windows 11. É necessário usar a versão com máquina virtual.

### 1. Abrir a VM do ISE

1. Abra o VirtualBox
2. Inicie a máquina **ISE_14.7_VIRTUAL_MACHINE**
3. No desktop da VM, dê duplo clique em **Project Navigator**

### 2. Criar o projeto no ISE

1. Clique em **New Project**
2. Nome: `cpu_8bits`; Location: `/home/ise/`
3. Configurações do dispositivo:
   - Family: **Spartan3E**
   - Device: **XC3S100E**
   - Package: **CP132**
   - Speed: **-5**
   - Simulator: **ISim (VHDL/Verilog)**
   - Preferred Language: **VHDL**
4. Clique em **Finish**

### 3. Copiar os arquivos para a VM

Na pasta compartilhada `C:\ISE_Project\` (Windows), coloque:
- `src/cpu_vhdl_v3_comentado.vhd`
- `top/basys2_top_v5_comentado.vhd`
- `constraints/basys2_top_sw7_comentado.ucf`

Na VM eles ficam acessíveis em `/home/ise/ISE_Project/`.

### 4. Adicionar os arquivos ao projeto

1. **Project → Add Source**
2. Navegue até `/home/ise/ISE_Project/`
3. Selecione `cpu_vhdl_v3_comentado.vhd` e `basys2_top_v5_comentado.vhd`
4. Adicione também o `basys2_top_sw7_comentado.ucf`
5. Clique com botão direito em `basys2_top` → **Set as Top Module**

### 5. Sintetizar, implementar e gerar o bitstream

No painel de processos (lado esquerdo):
1. Duplo clique em **Synthesize - XST**
2. Duplo clique em **Implement Design**
3. Duplo clique em **Generate Programming File**

Todos devem terminar com ✅ verde.

### 6. Copiar o bitstream para o Windows

No terminal da VM:
```bash
cp /home/ise/cpu_8bits/basys2_top.bit /home/ise/ISE_Project/
```

O arquivo aparecerá em `C:\ISE_Project\basys2_top.bit`.

### 7. Gravar na placa

1. Conecte a Basys 2 via USB e ligue a placa
2. Abra o **Prompt de Comando (cmd)** no Windows
3. Execute:
```
"C:\Program Files (x86)\Digilent\AdeptUtilities\djtgcfg.exe" prog -d Basys2 -i 0 -f "C:\ISE_Project\basys2_top.bit"
```
4. Digite **Y** quando perguntar sobre o startup clock
5. Aguarde: `Programming succeeded.`

> Para gravar em definitivo na Flash ROM (persiste ao desligar):
> ```
> "C:\Program Files (x86)\Digilent\AdeptUtilities\djtgcfg.exe" prog -d Basys2 -i 1 -f "C:\ISE_Project\basys2_top.bit"
> ```
> Certifique-se que o jumper **JP3** está na posição **FLASH**.

### 8. Usar a placa

| Controle | Pino | Função |
|---|---|---|
| BTN0 | G12 | Reset da CPU |
| BTN1 | C11 | Clock manual (2 apertos = 1 instrução) |
| SW7 baixo | N3 | LEDs mostram ACC |
| SW7 alto | N3 | LEDs mostram PC |

**Sequência de teste:**
1. Pressione **BTN0** (reset) — LEDs apagam
2. Aperte **BTN1** repetidamente — CPU avança passo a passo
3. Com **SW7 baixo**: observe o ACC mudando pelos valores `0x77`, `0x7A`, `0x25`...
4. Com **SW7 alto**: observe o PC avançando pelos endereços do programa

---

## Basys 3 (Artix-7, XC7A35T) — via Vivado 2025.2

### Pré-requisitos

- Vivado ML Edition 2025.2 instalado
- Placa Basys 3 com cabo USB micro
- Drivers USB instalados (incluídos no Vivado)

### 1. Criar o projeto no Vivado

1. Abra o Vivado → **Create Project**
2. Nome: `cpu_8bits_basys3`
3. Selecione **RTL Project** → **Do not specify sources at this time**
4. Em **Default Part**:
   - Family: **Artix-7**
   - Package: **cpg236**
   - Speed: **-1**
   - Device: **xc7a35tcpg236-1**
5. Clique em **Finish**

### 2. Adicionar os arquivos

1. **Add Sources** → **Add or create design sources** → **Next**
2. Adicione:
   - `src/cpu_vhdl_v3_comentado.vhd`
   - `top/basys3_top.vhd`
3. **Finish**

4. **Add Sources** → **Add or create constraints** → **Next**
5. Adicione:
   - `constraints/basys3_top.xdc`
6. **Finish**

### 3. Sintetizar

1. Clique em **Run Synthesis** no painel esquerdo
2. Aguarde: `Synthesis successfully completed`
3. Selecione **Run Implementation** → **OK**

### 4. Implementar

1. Aguarde a implementação terminar
2. O aviso de **Methodology Violations** é esperado — não impede a gravação
3. Verifique: `All user specified timing constraints are met`

### 5. Gerar o bitstream

1. Clique em **Generate Bitstream**
2. Aguarde: `Bitstream Generation successfully completed`
3. O arquivo `.bit` é gerado em:
   ```
   <projeto>/cpu_8bits_basys3.runs/impl_1/basys3_top.bit
   ```

### 6. Gravar na placa

1. Conecte a Basys 3 via USB e ligue a placa
2. Selecione **Open Hardware Manager** → **Open Target** → **Auto Connect**
3. Clique com botão direito na placa → **Program Device**
4. Selecione o arquivo `basys3_top.bit`
5. Clique em **Program**

> Alternativamente, pelo Adept:
> ```
> "C:\Program Files (x86)\Digilent\AdeptUtilities\djtgcfg.exe" prog -d Basys3 -i 0 -f "caminho\basys3_top.bit"
> ```

### 7. Usar a placa

| Controle | Pino | Função |
|---|---|---|
| BTNC | U18 | Reset da CPU |
| BTNU | T18 | Clock manual (2 apertos = 1 instrução) |
| SW0 baixo | V17 | LEDs mostram ACC |
| SW0 alto | V17 | LEDs mostram PC |

**Sequência de teste:**
1. Pressione **BTNC** (reset) — LEDs apagam
2. Aperte **BTNU** repetidamente — CPU avança passo a passo
3. Com **SW0 baixo**: observe o ACC mudando pelos valores `0x77`, `0x7A`, `0x25`...
4. Com **SW0 alto**: observe o PC avançando pelos endereços do programa
