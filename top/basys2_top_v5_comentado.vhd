-- =============================================================================
-- Projeto: Top-level para Basys 2
-- Descricao: Conecta a CPU 8bits com a RAM e os perifericos da placa
--            BTN0 = Reset da CPU
--            BTN1 = Clock manual (2 apertos = 1 ciclo completo)
--            SW7  = Seletor de exibicao: 0=ACC | 1=PC
--            LEDs = Exibem ACC ou PC em binario
-- =============================================================================

Library IEEE;
Use IEEE.Std_Logic_1164.All;   -- Tipos logicos digitais
Use IEEE.Std_Logic_arith.All;  -- Operacoes aritmeticas
Use IEEE.Std_Logic_unsigned.All; -- Aritmetica sem sinal

-- Declaracao da entidade top-level
-- Define as portas fisicas da placa que serao usadas
Entity basys2_top Is
    Port (
        clk  : In  Std_Logic;                    -- Clock 50MHz da placa Basys 2
        btn0 : In  Std_Logic;                    -- Botao BTN0: Reset da CPU
        btn1 : In  Std_Logic;                    -- Botao BTN1: Clock manual passo a passo
        sw0  : In  Std_Logic;                    -- Switch SW7: 0=mostra ACC | 1=mostra PC
        led  : Out Std_Logic_Vector(7 Downto 0)  -- 8 LEDs: exibem ACC ou PC em binario
    );
End basys2_top;

Architecture Behavioral Of basys2_top Is

    -- =========================================================================
    -- Declaracao do componente CPU
    -- Deve corresponder exatamente a entidade cpu_8bits do arquivo cpu_vhdl_v3
    -- =========================================================================
    Component cpu_8bits
        Generic (ne : Integer := 8;   -- Bits de endereco
                 nd : Integer := 8);  -- Bits de dado
        Port (ck      : In     Std_Logic;                        -- Clock
              rst_b   : In     Std_Logic;                        -- Reset ativo em baixo
              mrq_n   : Buffer Std_Logic;                        -- Memory request
              wr_n    : Buffer Std_Logic;                        -- Write
              rd_n    : Buffer Std_Logic;                        -- Read
              Ed      : Out    Std_Logic_Vector(ne-1 Downto 0);  -- Barramento endereco
              Dt      : InOut  Std_Logic_Vector(nd-1 Downto 0);  -- Barramento dados
              Acc_out : Out    Std_Logic_Vector(nd-1 Downto 0);  -- Saida do ACC
              PC_out  : Out    Std_Logic_Vector(ne-1 Downto 0);  -- Saida do PC
              Acc_wr  : Out    Std_Logic);                        -- Indica escrita no ACC
    End Component;

    -- =========================================================================
    -- Declaracao do componente RAM
    -- Deve corresponder exatamente a entidade ram_8x8 do arquivo cpu_vhdl_v3
    -- =========================================================================
    Component ram_8x8
        Port (ce_n, oe_n, wr_n : In    Std_Logic;                       -- Controles
              Ed               : In    Std_Logic_Vector(7 Downto 0);     -- Endereco
              Dt               : InOut Std_Logic_Vector(7 Downto 0));    -- Dados
    End Component;

    -- =========================================================================
    -- Sinais internos de barramento CPU <-> RAM
    -- =========================================================================
    Signal mrq_n, wr_n, rd_n : Std_Logic;                  -- Sinais de controle do barramento
    Signal ce_n, oe_n        : Std_Logic;                  -- Chip enable e output enable da RAM
    Signal Ed                : Std_Logic_Vector(7 Downto 0); -- Barramento de endereco
    Signal Dt                : Std_Logic_Vector(7 Downto 0); -- Barramento de dados
    Signal rst_b             : Std_Logic;                   -- Reset interno (ativo em baixo)
    Signal Acc_out           : Std_Logic_Vector(7 Downto 0); -- Valor atual do ACC
    Signal PC_out            : Std_Logic_Vector(7 Downto 0); -- Valor atual do PC
    Signal Acc_wr            : Std_Logic;                   -- Indica quando ACC foi atualizado

    -- Latch do ACC: armazena o ultimo valor valido do ACC
    -- So atualiza quando Acc_wr = '1' (CPU escreveu no ACC)
    Signal acc_latch         : Std_Logic_Vector(7 Downto 0) := (Others => '0');

    -- =========================================================================
    -- Sinais de debounce do BTN0 (Reset)
    -- Debounce evita que um unico aperto gere multiplos pulsos por vibracoes mecanicas
    -- =========================================================================
    Signal deb_cnt0   : Std_Logic_Vector(19 Downto 0) := (Others => '0'); -- Contador de debounce
    Signal btn0_sync  : Std_Logic := '0';   -- Valor sincronizado do BTN0
    Signal btn0_clean : Std_Logic := '0';   -- Valor limpo (apos debounce) do BTN0

    -- =========================================================================
    -- Sinais de debounce do BTN1 (Clock manual)
    -- =========================================================================
    Signal deb_cnt1   : Std_Logic_Vector(19 Downto 0) := (Others => '0'); -- Contador de debounce
    Signal btn1_sync  : Std_Logic := '0';   -- Valor sincronizado do BTN1
    Signal btn1_prev  : Std_Logic := '0';   -- Valor anterior do BTN1 (para detectar borda)
    Signal btn1_pulse : Std_Logic := '0';   -- Pulso limpo: '1' por 1 ciclo a cada aperto
    Signal clk_cpu    : Std_Logic := '0';   -- Clock da CPU gerado pelo botao
    Signal clk_phase  : Std_Logic := '0';   -- Fase atual do clock (0=baixo, 1=alto)

Begin

    -- Converte BTN0: pressionado(alto) = reset ativo(baixo)
    rst_b <= Not btn0_clean;

    -- Conecta sinais de controle da CPU com a RAM
    ce_n <= mrq_n; -- Chip enable da RAM = Memory request da CPU
    oe_n <= rd_n;  -- Output enable da RAM = Read da CPU

    -- =========================================================================
    -- PROCESSO: Debounce do BTN0 (Reset)
    -- Aguarda 2^20 ciclos (~20ms a 50MHz) de nivel estavel antes de aceitar
    -- Elimina o ruido mecanico do botao
    -- =========================================================================
    process(clk)
    begin
        if clk'Event and clk = '1' then
            if btn0 /= btn0_sync then
                -- Botao mudou: reinicia contador e atualiza valor sincronizado
                btn0_sync <= btn0;
                deb_cnt0  <= (Others => '0');
            else
                -- Botao estavel: incrementa contador
                if deb_cnt0 = x"FFFFF" then
                    -- Contador chegou ao limite: aceita o valor como estavel
                    btn0_clean <= btn0_sync;
                else
                    deb_cnt0 <= deb_cnt0 + 1; -- Continua contando
                end if;
            end if;
        end if;
    end process;

    -- =========================================================================
    -- PROCESSO: Debounce do BTN1 (Clock manual)
    -- Gera um pulso limpo de 1 ciclo a cada aperto do botao
    -- =========================================================================
    process(clk)
    begin
        if clk'Event and clk = '1' then
            btn1_pulse <= '0'; -- Por padrao, sem pulso

            if btn1 /= btn1_sync then
                -- Botao mudou: reinicia contador
                btn1_sync <= btn1;
                deb_cnt1  <= (Others => '0');
            else
                if deb_cnt1 = x"FFFFF" then
                    -- Detecta borda de subida apos estabilizacao
                    if btn1_sync = '1' and btn1_prev = '0' then
                        btn1_pulse <= '1'; -- Gera pulso limpo de 1 ciclo
                    end if;
                    btn1_prev <= btn1_sync; -- Atualiza valor anterior
                else
                    deb_cnt1 <= deb_cnt1 + 1; -- Continua contando
                end if;
            end if;
        end if;
    end process;

    -- =========================================================================
    -- PROCESSO: Gerador de clock manual para a CPU
    -- 1 aperto = meio ciclo (sobe ou desce)
    -- 2 apertos = 1 ciclo completo
    -- A CPU precisa de multiplos ciclos por instrucao
    -- =========================================================================
    process(clk, rst_b)
    begin
        if rst_b = '0' then
            -- Reset: clock volta a zero e fase reseta
            clk_cpu   <= '0';
            clk_phase <= '0';
        elsif clk'Event and clk = '1' then
            if btn1_pulse = '1' then
                -- A cada pulso do botao, alterna o clock
                if clk_phase = '0' then
                    clk_cpu   <= '1'; -- Sobe o clock
                    clk_phase <= '1'; -- Marca fase como alta
                else
                    clk_cpu   <= '0'; -- Desce o clock
                    clk_phase <= '0'; -- Marca fase como baixa
                end if;
            end if;
        end if;
    end process;

    -- =========================================================================
    -- PROCESSO: Latch do ACC
    -- Armazena o valor do ACC somente quando Acc_wr = '1'
    -- Evita que os LEDs mostrem valores intermediarios ou incorretos
    -- =========================================================================
    process(clk_cpu, rst_b)
    begin
        if rst_b = '0' then
            acc_latch <= (Others => '0'); -- Reset: ACC = 0
        elsif clk_cpu'Event and clk_cpu = '1' then
            if Acc_wr = '1' then
                -- CPU escreveu no ACC: atualiza latch com novo valor
                acc_latch <= Acc_out;
            end if;
            -- Se Acc_wr = '0': latch mantem valor anterior (nao muda)
        end if;
    end process;

    -- =========================================================================
    -- Instancia da CPU
    -- Conecta todos os sinais internos com as portas da CPU
    -- =========================================================================
    U_CPU: cpu_8bits
        Port Map(
            ck      => clk_cpu,  -- Clock manual gerado pelo BTN1
            rst_b   => rst_b,    -- Reset gerado pelo BTN0
            mrq_n   => mrq_n,    -- Memory request -> conectado ao ce_n da RAM
            wr_n    => wr_n,     -- Write -> conectado ao wr_n da RAM
            rd_n    => rd_n,     -- Read -> conectado ao oe_n da RAM
            Ed      => Ed,       -- Barramento de endereco
            Dt      => Dt,       -- Barramento de dados (bidirecional)
            Acc_out => Acc_out,  -- Valor atual do ACC (para o latch)
            PC_out  => PC_out,   -- Valor atual do PC (direto para os LEDs)
            Acc_wr  => Acc_wr    -- Indica quando ACC foi atualizado
        );

    -- =========================================================================
    -- Instancia da RAM
    -- Conecta barramento e sinais de controle
    -- =========================================================================
    U_RAM: ram_8x8
        Port Map(
            ce_n => ce_n,  -- Chip enable (= mrq_n da CPU)
            oe_n => oe_n,  -- Output enable (= rd_n da CPU)
            wr_n => wr_n,  -- Write (= wr_n da CPU)
            Ed   => Ed,    -- Barramento de endereco
            Dt   => Dt     -- Barramento de dados
        );

    -- =========================================================================
    -- Multiplexador dos LEDs
    -- SW7=0: exibe ACC travado (ultimo valor valido calculado)
    -- SW7=1: exibe PC atual (endereco sendo executado)
    -- =========================================================================
    led <= acc_latch When sw0 = '0' Else PC_out;

End Behavioral;
