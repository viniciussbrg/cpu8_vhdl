-- =============================================================================
-- Projeto: CPU 8bits com RAM para Basys 2
-- Descricao: CPU de 8 bits com conjunto de instrucoes completo
--            Expoe ACC, PC e sinal Acc_wr para uso externo
-- =============================================================================

-- -----------------------------------------------------------------------------
-- PACOTE AUXILIAR: define os tipos e funcoes usados pela CPU
-- -----------------------------------------------------------------------------
Library IEEE;                                          -- Biblioteca padrao IEEE
Use IEEE.Std_Logic_1164.All;                          -- Tipos logicos digitais (Std_Logic)
Use IEEE.Std_Logic_arith.All;                         -- Operacoes aritmeticas

Package cpu_aux is
    -- Tipo enumerado com todos os estados possiveis da maquina de estados da CPU
    -- Cada estado corresponde a uma instrucao ou etapa de execucao
    Type Tipo_Estado is (
        busca,   -- Busca da proxima instrucao na memoria
        LDmP,    -- Load Memory Page: carrega o numero da pagina de memoria
        LDmS,    -- Load Memory Stack: carrega o ponteiro de pilha
        LDmA,    -- Load Memory Accumulator: carrega ACC com valor imediato da memoria
        LDdA,    -- Load Direct Accumulator: carrega ACC com valor direto da memoria
        LDiA,    -- Load Indirect Accumulator: carrega ACC com enderecamento indireto
        STdA,    -- Store Direct Accumulator: salva ACC na memoria (direto)
        STiA,    -- Store Indirect Accumulator: salva ACC na memoria (indireto)
        Jump,    -- Salto incondicional para endereco
        JP_Z,    -- Salto condicional se ACC = zero
        JPNZ,    -- Salto condicional se ACC diferente de zero
        JPNG,    -- Salto condicional se ACC negativo
        ADdA,    -- Add Direct Accumulator: soma valor da memoria com ACC
        SBdA,    -- Subtract Direct Accumulator: subtrai valor da memoria do ACC
        Call,    -- Chama sub-rotina: salva PC na pilha e salta para endereco
        RETN,    -- Return: retorna da sub-rotina recuperando PC da pilha
        Halt     -- Para a execucao da CPU
    );

    -- Declaracao da funcao que converte um byte em um estado (instrucao)
    Function para_estado(dado : Std_Logic_Vector(7 Downto 0)) Return Tipo_Estado;

End cpu_aux;

Package Body cpu_aux is
    -- Corpo da funcao: converte o opcode (byte) no estado correspondente
    Function para_estado(dado : Std_Logic_Vector(7 Downto 0)) Return Tipo_Estado is
        variable mnemonico : Tipo_Estado; -- Variavel local que armazena o estado decodificado
    Begin
        -- Verifica se os 4 bits mais significativos sao diferentes de 0xF
        If (dado(7 Downto 4) /= x"f") Then
            -- Instrucoes com opcode entre 0x00 e 0xEF
            -- Identificadas pelos 4 bits mais significativos
            Case dado(7 Downto 4) is
                When x"0" => mnemonico := LDmP; -- 0x0X = Load Memory Page
                When x"1" => mnemonico := LDdA; -- 0x1X = Load Direct Accumulator
                When x"2" => mnemonico := LDiA; -- 0x2X = Load Indirect Accumulator
                When x"3" => mnemonico := STdA; -- 0x3X = Store Direct Accumulator
                When x"4" => mnemonico := STiA; -- 0x4X = Store Indirect Accumulator
                When x"a" => mnemonico := ADdA; -- 0xAX = Add Direct Accumulator
                When x"b" => mnemonico := SBdA; -- 0xBX = Subtract Direct Accumulator
                When Others => mnemonico := Halt; -- Qualquer outro = Halt
            End Case;
        Else
            -- Instrucoes com opcode entre 0xF0 e 0xFF
            -- Identificadas pelo byte completo
            Case dado is
                When x"f0" => mnemonico := Jump; -- 0xF0 = Salto incondicional
                When x"f1" => mnemonico := JP_Z; -- 0xF1 = Salto se zero
                When x"f2" => mnemonico := JPNZ; -- 0xF2 = Salto se nao zero
                When x"f3" => mnemonico := JPNG; -- 0xF3 = Salto se negativo
                When x"f6" => mnemonico := LDmS; -- 0xF6 = Load Stack
                When x"f7" => mnemonico := LDmA; -- 0xF7 = Load Immediate Accumulator
                When x"f8" => mnemonico := Call; -- 0xF8 = Chamada de sub-rotina
                When x"f9" => mnemonico := RETN; -- 0xF9 = Retorno de sub-rotina
                When Others => mnemonico := Halt; -- Qualquer outro = Halt
            End Case;
        End If;
        Return mnemonico; -- Retorna o estado decodificado
    End Function;
End cpu_aux;

-- -----------------------------------------------------------------------------
-- ENTIDADE: cpu_8bits
-- Descricao: CPU de 8 bits com barramento de dados e endereco
--            Expoe ACC, PC e Acc_wr para monitoramento externo
-- -----------------------------------------------------------------------------
Library IEEE;
Use IEEE.Std_Logic_1164.All;
Use IEEE.Std_Logic_arith.All;
Use IEEE.Std_Logic_unsigned.All;
Use Work.cpu_aux.All;                                 -- Usa o pacote auxiliar definido acima

Entity cpu_8bits Is
    Generic (ne : Integer := 8;                       -- Numero de bits do endereco (8 bits = 256 posicoes)
             nd : Integer := 8);                      -- Numero de bits do dado (8 bits)
    Port (ck      : In     Std_Logic;                 -- Clock da CPU
          rst_b   : In     Std_Logic;                 -- Reset ativo em baixo (0 = reseta)
          mrq_n   : Buffer Std_Logic;                 -- Memory Request: indica acesso a memoria (ativo em baixo)
          wr_n    : Buffer Std_Logic;                 -- Write: indica escrita na memoria (ativo em baixo)
          rd_n    : Buffer Std_Logic;                 -- Read: indica leitura da memoria (ativo em baixo)
          Ed      : Out    Std_Logic_Vector(ne-1 Downto 0); -- Barramento de endereco
          Dt      : InOut  Std_Logic_Vector(nd-1 Downto 0); -- Barramento de dados (bidirecional)
          Acc_out : Out    Std_Logic_Vector(nd-1 Downto 0); -- Saida direta do valor do ACC
          PC_out  : Out    Std_Logic_Vector(ne-1 Downto 0); -- Saida direta do valor do PC
          Acc_wr  : Out    Std_Logic);                -- Sinal que indica quando ACC foi atualizado
End cpu_8bits;

Architecture teste Of cpu_8bits IS
    Signal Estado        : Tipo_Estado;               -- Estado atual da maquina de estados
    Signal Passo_rd_wr   : Integer Range 0 To 3;      -- Passo atual do ciclo de leitura/escrita (0 a 3)
    Signal Passo_op_cod  : Integer Range 0 To 3;      -- Passo atual da execucao da instrucao
    Signal Ler           : Boolean;                   -- Flag: indica que a CPU quer ler da memoria
    Signal Escrever      : Boolean;                   -- Flag: indica que a CPU quer escrever na memoria

    Signal PC        : Std_Logic_Vector(ne-1 Downto 0); -- Program Counter: endereco da proxima instrucao
    Signal pc_inc    : Std_Logic_Vector(ne-1 Downto 0); -- PC + 1: proximo endereco calculado
    Signal St        : Std_Logic_Vector(ne-1 Downto 0); -- Stack Pointer: aponta para o topo da pilha
    Signal st_novo   : Std_Logic_Vector(ne-1 Downto 0); -- Novo valor do Stack Pointer apos operacao
    Signal End_mem   : Std_Logic_Vector(ne-1 Downto 0); -- Endereco atual sendo acessado na memoria
    Signal Pg        : Std_Logic_Vector(3 Downto 0);    -- Pagina de memoria atual (4 bits)
    Signal Ir        : Std_Logic_Vector(nd-1 Downto 0); -- Instruction Register: armazena instrucao atual
    Signal Acc       : Std_Logic_Vector(nd-1 Downto 0); -- Acumulador: registrador principal de dados
    Signal Aux       : Std_Logic_Vector(nd-1 Downto 0); -- Registrador auxiliar para instrucoes indiretas
    Signal Dado_escr : Std_Logic_Vector(nd-1 Downto 0); -- Dado a ser escrito na memoria
    Signal alu_s     : Std_Logic_Vector(nd-1 Downto 0); -- Resultado da ULA (soma ou subtracao)
    Signal alu_b     : Std_Logic_Vector(nd-1 Downto 0); -- Segundo operando da ULA
    Signal alu_flags : Std_Logic_Vector(1 Downto 0);    -- Flags da ULA: bit1=zero, bit0=negativo
    Signal alu_n     : Std_Logic;                        -- Flag negativo: '1' se resultado negativo
    Signal alu_z     : Std_Logic;                        -- Flag zero: '1' se resultado = 0
    Signal Acc_wr_i  : Std_Logic;                        -- Sinal interno de escrita no ACC

Begin
    -- Conecta sinais internos as saidas da entidade
    Acc_out <= Acc;      -- Expoe o valor atual do ACC para o mundo externo
    PC_out  <= PC;       -- Expoe o valor atual do PC para o mundo externo
    Acc_wr  <= Acc_wr_i; -- Expoe o sinal de escrita do ACC para o mundo externo

    -- =========================================================================
    -- PROCESSO: borda_subida
    -- Maquina de estados principal da CPU
    -- Executa na borda de subida do clock
    -- Responsavel por decodificar e executar as instrucoes
    -- =========================================================================
    borda_subida: Process (ck, rst_b)
    Variable salta : Boolean; -- Variavel local: indica se um salto deve ser realizado
    Begin
        -- Reset assincrono: quando rst_b = '0', inicializa tudo
        If rst_b ='0' Then
            Ler          <= False;              -- Desativa flag de leitura
            Escrever     <= False;              -- Desativa flag de escrita
            Estado       <= Busca;             -- Volta ao estado inicial de busca
            Passo_op_cod <= 0;                 -- Reseta contador de passos da instrucao
            Pc           <= (Others => '0');   -- PC = 0 (inicio da memoria)
            End_mem      <= (Others => '0');   -- Endereco de memoria = 0
            Acc          <= (Others => '0');   -- ACC = 0
            Acc_wr_i     <= '0';               -- Sinal de escrita do ACC = inativo

        -- Operacao normal na borda de subida do clock
        Elsif ck'Event And ck='1' Then
            Acc_wr_i <= '0'; -- Por padrao, ACC nao foi escrito neste ciclo

            Case Estado Is

                -- -------------------------------------------------------------
                -- ESTADO: Busca
                -- Busca a proxima instrucao na memoria
                -- Usa 4 passos (Passo_rd_wr 0 a 3) para completar a leitura
                -- -------------------------------------------------------------
                When Busca =>
                    If    Passo_rd_wr = 0 Then
                        Ler <= True;      -- Solicita leitura da memoria
                        end_mem <= Pc;    -- Endereco a ler = PC atual
                    Elsif Passo_rd_wr = 2 Then
                        Ir <= Dt;         -- Armazena dado lido no Instruction Register
                    Elsif Passo_rd_wr = 3 Then
                        Estado <= para_estado(Ir); -- Decodifica instrucao e muda estado
                        Ler <= False;              -- Desativa leitura
                    End If;

                -- -------------------------------------------------------------
                -- ESTADO: LDmP (Load Memory Page)
                -- Define qual pagina de memoria sera usada
                -- Os 4 bits menos significativos do IR definem a pagina
                -- -------------------------------------------------------------
                When LDmP =>
                    Pg <= Ir(3 Downto 0); -- Carrega pagina com nibble baixo do IR
                    Pc <= pc_inc;         -- Avanca PC para proxima instrucao
                    Estado <= Busca;      -- Volta a buscar proxima instrucao

                -- -------------------------------------------------------------
                -- ESTADO: LDmA (Load Memory Accumulator - Imediato)
                -- Carrega ACC com valor que esta na posicao seguinte ao opcode
                -- -------------------------------------------------------------
                When LDmA =>
                    If    Passo_rd_wr = 0 Then
                        Ler <= True;          -- Solicita leitura
                        End_mem <= pc_inc;    -- Le o byte seguinte ao opcode
                    Elsif Passo_rd_wr = 2 Then
                        Acc <= Dt;            -- ACC recebe o valor lido
                        Pc <= pc_inc;         -- Avanca PC
                        Acc_wr_i <= '1';      -- Indica que ACC foi atualizado
                    Elsif Passo_rd_wr = 3 Then
                        Estado <= busca;      -- Volta a buscar proxima instrucao
                        Pc <= pc_inc;         -- Avanca PC novamente
                        Ler <= False;         -- Desativa leitura
                    End If;

                -- -------------------------------------------------------------
                -- ESTADO: LDmS (Load Memory Stack)
                -- Carrega o Stack Pointer com valor da memoria
                -- -------------------------------------------------------------
                When LDmS =>
                    If    Passo_rd_wr = 0 Then
                        Ler <= True;          -- Solicita leitura
                        End_mem <= pc_inc;    -- Le byte seguinte ao opcode
                    Elsif Passo_rd_wr = 2 Then
                        St <= Dt;             -- Stack Pointer recebe valor lido
                        Pc <= pc_inc;         -- Avanca PC
                    Elsif Passo_rd_wr = 3 Then
                        Estado <= busca;      -- Volta a buscar proxima instrucao
                        Pc <= pc_inc;         -- Avanca PC
                        Ler <= False;         -- Desativa leitura
                    End If;

                -- -------------------------------------------------------------
                -- ESTADO: LDdA (Load Direct Accumulator)
                -- Carrega ACC com valor de endereco direto na pagina atual
                -- O endereco e formado por: Pagina & nibble baixo do IR
                -- -------------------------------------------------------------
                When LDdA =>
                    If    Passo_rd_wr = 0 Then
                        Ler <= True;                        -- Solicita leitura
                        End_mem <= Pg & Ir(3 Downto 0);    -- Endereco = Pagina + offset do IR
                    Elsif Passo_rd_wr = 2 Then
                        Acc <= Dt;                          -- ACC recebe valor lido
                        Pc <= pc_inc;                       -- Avanca PC
                        Acc_wr_i <= '1';                    -- Indica que ACC foi atualizado
                    Elsif Passo_rd_wr = 3 Then
                        Estado <= busca;                    -- Volta a buscar proxima instrucao
                        Ler <= False;                       -- Desativa leitura
                    End If;

                -- -------------------------------------------------------------
                -- ESTADO: STdA (Store Direct Accumulator)
                -- Salva o valor do ACC em endereco direto na pagina atual
                -- -------------------------------------------------------------
                When STdA =>
                    If    Passo_rd_wr = 0 Then
                        Escrever <= True;                   -- Solicita escrita
                        Dado_escr <= Acc;                   -- Dado a escrever = ACC
                        End_mem <= Pg & Ir(3 Downto 0);    -- Endereco = Pagina + offset do IR
                    Elsif Passo_rd_wr = 2 Then
                        Pc <= pc_inc;                       -- Avanca PC
                    Elsif Passo_rd_wr = 3 Then
                        Estado <= busca;                    -- Volta a buscar proxima instrucao
                        Escrever <= False;                  -- Desativa escrita
                    End If;

                -- -------------------------------------------------------------
                -- ESTADO: LDiA (Load Indirect Accumulator)
                -- Carrega ACC com enderecamento indireto (dois acessos a memoria)
                -- Passo 0: le o endereco intermediario
                -- Passo 1: usa esse endereco para ler o valor final
                -- -------------------------------------------------------------
                When LDiA =>
                    If Passo_op_cod = 0 Then
                        -- Primeiro acesso: busca o endereco intermediario
                        If    Passo_rd_wr = 0 Then
                            Ler <= True;                     -- Solicita leitura
                            End_mem <= Pg & Ir(3 Downto 0); -- Le da pagina + offset
                        Elsif Passo_rd_wr = 2 Then
                            Aux <= Dt;                       -- Armazena endereco intermediario em Aux
                        Elsif Passo_rd_wr = 3 Then
                            Passo_op_cod <= 1;               -- Avanca para o segundo passo
                            Ler <= False;                    -- Desativa leitura
                        End If;
                    Else
                        -- Segundo acesso: usa Aux como endereco para buscar valor final
                        If    Passo_rd_wr = 0 Then
                            Ler <= True;      -- Solicita leitura
                            End_mem <= Aux;   -- Endereco = valor lido no primeiro passo
                        Elsif Passo_rd_wr = 2 Then
                            Acc <= Dt;        -- ACC recebe valor final
                            Pc <= pc_inc;     -- Avanca PC
                            Acc_wr_i <= '1'; -- Indica que ACC foi atualizado
                        Elsif Passo_rd_wr = 3 Then
                            Estado <= busca;      -- Volta a buscar proxima instrucao
                            Ler <= False;         -- Desativa leitura
                            Passo_op_cod <= 0;    -- Reseta contador de passos
                        End If;
                    End If;

                -- -------------------------------------------------------------
                -- ESTADO: STiA (Store Indirect Accumulator)
                -- Salva ACC em endereco indireto (dois acessos a memoria)
                -- -------------------------------------------------------------
                When STiA =>
                    If Passo_op_cod = 0 Then
                        -- Primeiro acesso: busca endereco onde salvar
                        If    Passo_rd_wr = 0 Then
                            Ler <= True;                     -- Solicita leitura
                            End_mem <= Pg & Ir(3 Downto 0); -- Le da pagina + offset
                        Elsif Passo_rd_wr = 2 Then
                            Aux <= Dt;                       -- Armazena endereco em Aux
                        Elsif Passo_rd_wr = 3 Then
                            Passo_op_cod <= 1;               -- Avanca para segundo passo
                            Ler <= False;                    -- Desativa leitura
                        End If;
                    Else
                        -- Segundo acesso: escreve ACC no endereco encontrado
                        If    Passo_rd_wr = 0 Then
                            Escrever <= True;   -- Solicita escrita
                            Dado_escr <= Acc;   -- Dado = ACC
                            End_mem <= Aux;     -- Endereco = valor do primeiro passo
                        Elsif Passo_rd_wr = 2 Then
                            Pc <= pc_inc;       -- Avanca PC
                        Elsif Passo_rd_wr = 3 Then
                            Estado <= busca;        -- Volta a buscar proxima instrucao
                            Escrever <= False;      -- Desativa escrita
                            Passo_op_cod <= 0;      -- Reseta contador de passos
                        End If;
                    End If;

                -- -------------------------------------------------------------
                -- ESTADO: Jump | JP_Z | JPNZ | JPNG
                -- Instrucoes de salto condicional e incondicional
                -- Verifica condicao e salta para endereco na memoria se verdadeiro
                -- -------------------------------------------------------------
                When Jump | JP_Z | JPNZ | JPNG =>
                    -- Verifica qual tipo de salto e se a condicao e verdadeira
                    If     Estado = Jump  Then
                        salta := True;                              -- Jump: sempre salta
                    Elsif  Estado = JP_Z  And alu_flags(1) = '1' Then
                        salta := True;                              -- JP_Z: salta se zero
                    Elsif  Estado = JPNZ  And alu_flags(1) = '0' Then
                        salta := True;                              -- JPNZ: salta se nao zero
                    Elsif  Estado = JPNG  And alu_flags(0) = '1' Then
                        salta := True;                              -- JPNG: salta se negativo
                    Else
                        salta := False;                             -- Condicao falsa: nao salta
                    End If;

                    If salta Then
                        -- Condicao verdadeira: busca endereco de destino e salta
                        If    Passo_rd_wr = 0 Then
                            Ler <= True;          -- Solicita leitura do endereco destino
                            end_mem <= pc_inc;    -- Le byte seguinte (endereco do salto)
                        Elsif Passo_rd_wr = 2 Then
                            Pc <= Dt;             -- PC recebe endereco de destino
                        Elsif Passo_rd_wr = 3 Then
                            Estado <= busca;      -- Volta a buscar (no novo endereco)
                            Ler <= False;         -- Desativa leitura
                        End If;
                    Else
                        -- Condicao falsa: apenas pula o byte do endereco e continua
                        If    Passo_op_cod = 0 Then
                            Pc <= pc_inc;         -- Pula o byte do endereco
                            Passo_op_cod <= 1;    -- Avanca passo
                        Else
                            Pc <= pc_inc;         -- Avanca PC
                            Estado <= Busca;      -- Volta a buscar proxima instrucao
                            Passo_op_cod <= 0;    -- Reseta contador
                        End If;
                    End If;

                -- -------------------------------------------------------------
                -- ESTADO: ADdA | SBdA (Add/Subtract Direct Accumulator)
                -- Soma ou subtrai valor da memoria com ACC
                -- Atualiza flags zero e negativo
                -- -------------------------------------------------------------
                When ADdA | SBdA =>
                    If    Passo_rd_wr = 0 Then
                        Ler <= True;                        -- Solicita leitura do operando
                        end_mem <= Pg & Ir(3 Downto 0);    -- Endereco = Pagina + offset
                    Elsif Passo_rd_wr = 2 Then
                        alu_b <= Dt;                        -- Segundo operando da ULA = valor lido
                        Pc <= pc_inc;                       -- Avanca PC
                    Elsif Passo_rd_wr = 3 Then
                        Acc <= alu_s;                       -- ACC = resultado da operacao
                        alu_flags <= alu_z & alu_n;        -- Atualiza flags (zero e negativo)
                        Estado <= Busca;                    -- Volta a buscar proxima instrucao
                        Ler <= False;                       -- Desativa leitura
                        Acc_wr_i <= '1';                    -- Indica que ACC foi atualizado
                    End If;

                -- -------------------------------------------------------------
                -- ESTADO: Call (Chamada de sub-rotina)
                -- Salva PC na pilha e salta para endereco da sub-rotina
                -- Passo 0: busca endereco da sub-rotina
                -- Passo 1: salva PC na pilha e salta
                -- -------------------------------------------------------------
                When Call =>
                    If Passo_op_cod = 0 Then
                        -- Primeiro passo: busca endereco de destino
                        If    Passo_rd_wr = 0 Then
                            Ler <= True;          -- Solicita leitura
                            End_mem <= pc_inc;    -- Le byte seguinte (endereco da sub-rotina)
                        Elsif Passo_rd_wr = 2 Then
                            Aux <= Dt;            -- Guarda endereco da sub-rotina em Aux
                            Pc <= pc_inc;         -- Avanca PC (aponta para instrucao apos Call)
                        Elsif Passo_rd_wr = 3 Then
                            Passo_op_cod <= 1;    -- Avanca para segundo passo
                            Ler <= False;         -- Desativa leitura
                        End If;
                    Else
                        -- Segundo passo: salva PC na pilha e salta para sub-rotina
                        If    Passo_rd_wr = 0 Then
                            Escrever <= True;       -- Solicita escrita
                            Dado_escr <= pc_inc;    -- Dado = PC atual (endereco de retorno)
                            End_mem <= St;          -- Escreve no endereco do Stack Pointer
                        Elsif Passo_rd_wr = 2 Then
                            St <= st_novo;          -- Decrementa Stack Pointer
                            Pc <= Aux;              -- PC = endereco da sub-rotina
                        Elsif Passo_rd_wr = 3 Then
                            Estado <= busca;        -- Volta a buscar (na sub-rotina)
                            Escrever <= False;      -- Desativa escrita
                            Passo_op_cod <= 0;      -- Reseta contador
                        End If;
                    End If;

                -- -------------------------------------------------------------
                -- ESTADO: RETN (Return from subroutine)
                -- Recupera PC da pilha e retorna para o ponto apos o Call
                -- -------------------------------------------------------------
                When RETN =>
                    If    Passo_rd_wr = 0 Then
                        Ler <= True;          -- Solicita leitura
                        End_mem <= st_novo;   -- Le do endereco do Stack Pointer + 1
                    Elsif Passo_rd_wr = 2 Then
                        Pc <= Dt;             -- PC = endereco de retorno recuperado da pilha
                        St <= st_novo;        -- Incrementa Stack Pointer
                    Elsif Passo_rd_wr = 3 Then
                        Estado <= Busca;      -- Volta a buscar (no ponto de retorno)
                        Ler <= False;         -- Desativa leitura
                    End If;

                -- -------------------------------------------------------------
                -- ESTADO: Halt
                -- Para a execucao da CPU indefinidamente
                -- -------------------------------------------------------------
                When Halt =>
                    Estado <= Halt; -- Permanece no estado Halt

            End Case;
        End If;
    End Process;

    -- =========================================================================
    -- PROCESSO: borda_descida
    -- Maquina de estados do ciclo de leitura/escrita na memoria
    -- Executa na borda de descida do clock
    -- Controla os sinais mrq_n, wr_n, rd_n e o contador Passo_rd_wr
    -- =========================================================================
    borda_descida: Process (ck, rst_b)
    Begin
        If rst_b ='0' Then
            mrq_n <= '1';       -- Desativa memory request
            wr_n  <= '1';       -- Desativa escrita
            rd_n  <= '1';       -- Desativa leitura
            Passo_rd_wr <= 0;   -- Reseta contador de passos
        Elsif ck'Event And ck='0' Then
            Case Passo_rd_wr Is
                When 0 =>
                    -- Passo 0: verifica se ha pedido de leitura ou escrita
                    If    Ler      Then
                        Passo_rd_wr <= 1;  -- Avanca para passo 1
                        mrq_n <= '0';      -- Ativa memory request
                        rd_n  <= '0';      -- Ativa leitura
                    Elsif Escrever Then
                        Passo_rd_wr <= 1;  -- Avanca para passo 1
                        mrq_n <= '0';      -- Ativa memory request
                    End If;
                When 1 =>
                    -- Passo 1: aguarda estabilizacao dos sinais
                    If    Ler      Then Passo_rd_wr <= 2;             -- Avanca para passo 2
                    Elsif Escrever Then Passo_rd_wr <= 2; wr_n <= '0'; -- Ativa escrita
                    End If;
                When 2 =>
                    -- Passo 2: finaliza o ciclo desativando os sinais
                    If    Ler      Then
                        Passo_rd_wr <= 3;  -- Avanca para passo 3
                        mrq_n <= '1';      -- Desativa memory request
                        rd_n  <= '1';      -- Desativa leitura
                    Elsif Escrever Then
                        Passo_rd_wr <= 3;  -- Avanca para passo 3
                        mrq_n <= '1';      -- Desativa memory request
                        wr_n  <= '1';      -- Desativa escrita
                    End If;
                When 3 =>
                    Passo_rd_wr <= 0; -- Volta ao passo 0 (inicio do proximo ciclo)
            End Case;
        End If;
    End Process;

    Ed <= end_mem; -- Conecta endereco interno ao barramento de endereco externo

    -- Barramento de dados: coloca dado_escr quando escrevendo, alta impedancia caso contrario
    Dt <= dado_escr When (Escrever And mrq_n ='0') Else (Others => 'Z');

    -- =========================================================================
    -- BLOCO: Unidade_logica (ULA)
    -- Realiza operacoes aritmeticas: soma e subtracao
    -- Calcula flags zero e negativo
    -- =========================================================================
    Unidade_logica: Block
    Constant zero : Std_Logic_Vector(alu_s'Range) := (Others => '0'); -- Constante zero para comparacao
    Begin
        -- Resultado: soma se ADdA, subtracao caso contrario
        alu_s <= Acc + alu_b When (Estado = ADdA) Else Acc - alu_b;
        -- Flag zero: '1' se resultado = 0
        alu_z <= '1' When (alu_s = zero) Else '0';
        -- Flag negativo: '1' se bit mais significativo do resultado = 1
        alu_n <= '1' When (alu_s(alu_s'High) = '1') Else '0';
    End Block;

    -- =========================================================================
    -- BLOCO: Contador_Programa
    -- Calcula PC + 1 (proximo endereco)
    -- =========================================================================
    Contador_Programa: Block
    Begin
        pc_inc <= Pc + 1; -- Incrementa PC
    End Block;

    -- =========================================================================
    -- BLOCO: pilha
    -- Calcula novo valor do Stack Pointer
    -- Decrementa no Call (empilha), incrementa no RETN (desempilha)
    -- =========================================================================
    pilha: Block
    Begin
        st_novo <= St - 1 When (Estado = Call) Else St + 1;
    End Block;

End teste;

-- =============================================================================
-- ENTIDADE: ram_8x8
-- Memoria RAM de 256 posicoes de 8 bits
-- Contem o programa de teste pre-carregado
-- =============================================================================
Library IEEE;
Use IEEE.Std_Logic_1164.All;
Use IEEE.Std_Logic_arith.All;
Use IEEE.Std_Logic_unsigned.All;
Use Work.cpu_aux.All;

Entity ram_8x8 Is
    Port (ce_n, oe_n, wr_n : In    Std_Logic;          -- ce_n=chip enable, oe_n=output enable, wr_n=write
          Ed               : In    Std_Logic_Vector(7 Downto 0);  -- Barramento de endereco
          Dt               : InOut Std_Logic_Vector(7 Downto 0)); -- Barramento de dados
End ram_8x8;

Architecture teste Of ram_8x8 Is
    -- Tipo array de 256 posicoes de 8 bits cada
    Type arranjo_memoria Is Array (Natural Range <>) Of Std_Logic_Vector(7 Downto 0);

    -- Memoria inicializada com o programa de teste
    Signal dados : arranjo_memoria(0 To 255) :=
    -- Endereco 0x00: LDmP 0x0A - Define pagina A
    (16#00# => x"0A",
     -- Endereco 0x01: LDmS - Carrega Stack Pointer
     16#01# => x"f6",
     -- Endereco 0x02: 0xFF - Valor do Stack Pointer (255)
     16#02# => x"FF",
     -- Endereco 0x03: LDdA 0 - Carrega ACC com mem[A0] = 0x77
     16#03# => x"10",
     -- Endereco 0x04: ADdA F - Soma ACC com mem[AF] = 0x03, ACC = 0x7A
     16#04# => x"af",
     -- Endereco 0x05: STdA 1 - Salva ACC em mem[A1]
     16#05# => x"31",
     -- Endereco 0x06: LDiA E - Carrega ACC indiretamente via mem[AE]
     16#06# => x"2E",
     -- Endereco 0x07: STiA F - Salva ACC indiretamente via mem[AF] -> mem[A3]... (nao usado diretamente)
     16#07# => x"BF",
     -- Endereco 0x08: STiA C - Salva ACC indiretamente via mem[AC] -> mem[A3]
     16#08# => x"4C",
     -- Endereco 0x09: Jump - Salto incondicional
     16#09# => x"f0",
     -- Endereco 0x0A: 0x3A - Endereco de destino do salto
     16#0A# => x"3A",
     -- Sub-rotina em 0x3A
     16#3A# => x"f7", -- LDmA - Carrega ACC com proximo byte
     16#3B# => x"fb", -- 0xFB - Valor carregado no ACC
     16#3C# => x"a7", -- ADdA 7 - Soma ACC com mem[A7] = 0x04
     16#3D# => x"f3", -- JPNG - Salta se negativo
     16#3E# => x"40", -- 0x40 - Endereco de salto se negativo
     -- Chamada de sub-rotina
     16#40# => x"f8", -- Call - Chama sub-rotina
     16#41# => x"70", -- 0x70 - Endereco da sub-rotina
     16#42# => x"ff", -- Halt - Para apos retorno
     -- Sub-rotina em 0x70: contagem regressiva 3 -> 0
     16#70# => x"f7", -- LDmA - Carrega ACC com proximo byte
     16#71# => x"03", -- 0x03 - Valor inicial (3)
     16#72# => x"BB", -- SBdA B - Subtrai mem[AB] = 0x01 do ACC
     16#73# => x"f2", -- JPNZ - Salta se ACC nao zero
     16#74# => x"72", -- 0x72 - Volta para SBdA (loop)
     16#75# => x"f9", -- RETN - Retorna da sub-rotina
     -- Dados na pagina A
     16#A0# => x"77", -- Dado: 0x77 (119 decimal)
     16#A1# => x"FF", -- Inicialmente 0xFF (sera sobrescrito)
     16#A2# => x"25", -- Dado: 0x25 (37 decimal)
     16#A3# => x"FF", -- Inicialmente 0xFF (sera sobrescrito)
     16#A7# => x"04", -- Dado: 0x04 (4 decimal)
     16#AB# => x"01", -- Dado: 0x01 (subtraendo da contagem)
     16#AC# => x"A3", -- Ponteiro indireto para 0xA3
     16#AD# => x"03", -- Dado: 0x03
     16#AE# => x"A2", -- Ponteiro indireto para 0xA2
     16#AF# => x"03", -- Dado: 0x03 (somando da adicao)
     Others => x"ff"); -- Todas as outras posicoes = 0xFF (Halt)

Begin
    Process(ce_n, oe_n, wr_n, dados, Dt, Ed)
    Begin
        -- Escrita na memoria: ocorre na borda de subida de oe_n quando ce_n = '0'
        If rising_edge(oe_n) Then
            If ce_n = '0' Then
                dados(Conv_Integer(Ed)) <= Dt; -- Escreve Dt na posicao Ed da memoria
            End If;
        End if;

        -- Leitura da memoria: quando chip habilitado e leitura ativa
        if ce_n = '0' And oe_n = '0' And wr_n = '1' Then
            Dt <= dados(Conv_Integer(Ed)) After 10 ns; -- Le dado com atraso de 10ns
        Else
            Dt <= (Others => 'Z') After 10 ns; -- Alta impedancia quando nao lendo
        End if;
    End Process;
End teste;
