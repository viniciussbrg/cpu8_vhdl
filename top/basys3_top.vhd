-- =============================================================================
-- Projeto: Top-level para Basys 3
-- Descricao: Conecta a CPU 8bits com a RAM e os perifericos da placa
--            BTN0 = Reset da CPU
--            BTN1 = Clock manual (2 apertos = 1 ciclo completo)
--            SW0  = Seletor de exibicao: 0=ACC | 1=PC
--            LEDs = Exibem ACC ou PC em binario
-- Diferenca da Basys 2: clock de 100MHz e pinos diferentes
-- =============================================================================

Library IEEE;
Use IEEE.Std_Logic_1164.All;
Use IEEE.Std_Logic_arith.All;
Use IEEE.Std_Logic_unsigned.All;

Entity basys3_top Is
    Port (
        clk  : In  Std_Logic;                    -- Clock 100MHz da placa Basys 3
        btn0 : In  Std_Logic;                    -- Botao BTNC: Reset da CPU
        btn1 : In  Std_Logic;                    -- Botao BTNU: Clock manual
        sw0  : In  Std_Logic;                    -- Switch SW0: 0=ACC | 1=PC
        led  : Out Std_Logic_Vector(7 Downto 0)  -- 8 LEDs
    );
End basys3_top;

Architecture Behavioral Of basys3_top Is

    Component cpu_8bits
        Generic (ne : Integer := 8;
                 nd : Integer := 8);
        Port (ck      : In     Std_Logic;
              rst_b   : In     Std_Logic;
              mrq_n   : Buffer Std_Logic;
              wr_n    : Buffer Std_Logic;
              rd_n    : Buffer Std_Logic;
              Ed      : Out    Std_Logic_Vector(ne-1 Downto 0);
              Dt      : InOut  Std_Logic_Vector(nd-1 Downto 0);
              Acc_out : Out    Std_Logic_Vector(nd-1 Downto 0);
              PC_out  : Out    Std_Logic_Vector(ne-1 Downto 0);
              Acc_wr  : Out    Std_Logic);
    End Component;

    Component ram_8x8
        Port (ce_n, oe_n, wr_n : In    Std_Logic;
              Ed               : In    Std_Logic_Vector(7 Downto 0);
              Dt               : InOut Std_Logic_Vector(7 Downto 0));
    End Component;

    Signal mrq_n, wr_n, rd_n : Std_Logic;
    Signal ce_n, oe_n        : Std_Logic;
    Signal Ed                : Std_Logic_Vector(7 Downto 0);
    Signal Dt                : Std_Logic_Vector(7 Downto 0);
    Signal rst_b             : Std_Logic;
    Signal Acc_out           : Std_Logic_Vector(7 Downto 0);
    Signal PC_out            : Std_Logic_Vector(7 Downto 0);
    Signal Acc_wr            : Std_Logic;
    Signal acc_latch         : Std_Logic_Vector(7 Downto 0) := (Others => '0');

    -- Debounce BTN0
    Signal deb_cnt0   : Std_Logic_Vector(20 Downto 0) := (Others => '0'); -- 21 bits para 100MHz
    Signal btn0_sync  : Std_Logic := '0';
    Signal btn0_clean : Std_Logic := '0';

    -- Debounce BTN1
    Signal deb_cnt1   : Std_Logic_Vector(20 Downto 0) := (Others => '0'); -- 21 bits para 100MHz
    Signal btn1_sync  : Std_Logic := '0';
    Signal btn1_prev  : Std_Logic := '0';
    Signal btn1_pulse : Std_Logic := '0';
    Signal clk_cpu    : Std_Logic := '0';
    Signal clk_phase  : Std_Logic := '0';

Begin

    rst_b <= Not btn0_clean;
    ce_n  <= mrq_n;
    oe_n  <= rd_n;

    -- Debounce BTN0 (100MHz: contador de 21 bits = ~20ms)
    process(clk)
    begin
        if clk'Event and clk = '1' then
            if btn0 /= btn0_sync then
                btn0_sync <= btn0;
                deb_cnt0  <= (Others => '0');
            else
                if deb_cnt0 = "111111111111111111111" then
                    btn0_clean <= btn0_sync;
                else
                    deb_cnt0 <= deb_cnt0 + 1;
                end if;
            end if;
        end if;
    end process;

    -- Debounce BTN1 (100MHz: contador de 21 bits = ~20ms)
    process(clk)
    begin
        if clk'Event and clk = '1' then
            btn1_pulse <= '0';
            if btn1 /= btn1_sync then
                btn1_sync <= btn1;
                deb_cnt1  <= (Others => '0');
            else
                if deb_cnt1 = "111111111111111111111" then
                    if btn1_sync = '1' and btn1_prev = '0' then
                        btn1_pulse <= '1';
                    end if;
                    btn1_prev <= btn1_sync;
                else
                    deb_cnt1 <= deb_cnt1 + 1;
                end if;
            end if;
        end if;
    end process;

    -- Clock manual
    process(clk, rst_b)
    begin
        if rst_b = '0' then
            clk_cpu   <= '0';
            clk_phase <= '0';
        elsif clk'Event and clk = '1' then
            if btn1_pulse = '1' then
                if clk_phase = '0' then
                    clk_cpu   <= '1';
                    clk_phase <= '1';
                else
                    clk_cpu   <= '0';
                    clk_phase <= '0';
                end if;
            end if;
        end if;
    end process;

    -- Latch do ACC
    process(clk_cpu, rst_b)
    begin
        if rst_b = '0' then
            acc_latch <= (Others => '0');
        elsif clk_cpu'Event and clk_cpu = '1' then
            if Acc_wr = '1' then
                acc_latch <= Acc_out;
            end if;
        end if;
    end process;

    U_CPU: cpu_8bits
        Port Map(
            ck      => clk_cpu,
            rst_b   => rst_b,
            mrq_n   => mrq_n,
            wr_n    => wr_n,
            rd_n    => rd_n,
            Ed      => Ed,
            Dt      => Dt,
            Acc_out => Acc_out,
            PC_out  => PC_out,
            Acc_wr  => Acc_wr
        );

    U_RAM: ram_8x8
        Port Map(
            ce_n => ce_n,
            oe_n => oe_n,
            wr_n => wr_n,
            Ed   => Ed,
            Dt   => Dt
        );

    -- SW0=0 mostra ACC, SW0=1 mostra PC
    led <= acc_latch When sw0 = '0' Else PC_out;

End Behavioral;
