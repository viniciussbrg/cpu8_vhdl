-- Teste do conjunto CPU + Memoria
-- Memoria contem um pequeno programa para verificar a operacao das instrucoes
--
-- Compila o conjunto: Declaracao do pacote cpu_aux,        Corpo do pacote cpu_aux,
--                     Declaracao da entidade cpu 8bits,    Arquitetura teste de cpu_8bits
--                     Declaracao da entidade ram 8x8,      Arquitetura teste de ram_8x8
--                     Declaracao da entidade conjunto_5 e  Arquitetura teste de conjunto_5
--
-- Para verificar a operacao simule a entidade conjunto_5

-- Pacote auxiliar
-- Definicao de tipo contendo mnemonicos e funcao de valor numerico para mnemonico

Library IEEE;
Use IEEE.Std_Logic_1164.All;
Use IEEE.Std_Logic_arith.All; -- Biblioteca Synopsys necessaria para conversoes com Std_Logic

Package cpu_aux is
    -- Tipo contendo os possiveis estados da maquina
    Type Tipo_Estado is (busca, LDmP, LDmS, LDmA, LDdA, LDiA, STdA, STiA, Jump, JP_Z, JPNZ, JPNG, ADdA, SBdA, Call, RETN, Halt);

    Function para_estado(dado : Std_Logic_Vector(7 Downto 0)) Return Tipo_Estado;

End cpu_aux;

Package Body cpu_aux is -- corpo do pacote
    -- Funcao para converter um valor numerico no codigo do mnemonico correspondente.
    -- Entrada tipo Std_Logic_Vector; Retorna o tipo estado com o mnemonico decodificado
    Function para_estado(dado : Std_Logic_Vector(7 Downto 0)) Return Tipo_Estado is
        variable mnemonico : Tipo_Estado; -- Mnemonico interpretado
    Begin
        If (dado(7 Downto 4) /= x"f") Then
            -- Codigos entre "0" e "d". Mnemonico identificado pelos 4 bits mais significativos
            Case dado(7 Downto 4) is
                When x"0" => mnemonico := LDmp;
                When x"1" => mnemonico := LDda;
                When x"2" => mnemonico := LDia;
                When x"3" => mnemonico := STdA;
                When x"4" => mnemonico := STiA;
                When x"a" => mnemonico := ADda;
                When x"b" => mnemonico := SBdA;
                When Others => mnemonico := Halt;
            End Case;
        Else
            -- Codigos entre "f0" e "ff". Mnemonico identificado pelos 8 bits
            Case dado is
                When x"f0" => mnemonico := Jump;
                When x"f1" => mnemonico := JP_Z;
                When x"f2" => mnemonico := JPNZ;
                When x"f3" => mnemonico := JPNG;
                When x"f6" => mnemonico := LDmS;
                When x"f7" => mnemonico := LDmA;
                When x"f8" => mnemonico := Call;
                When x"f9" => mnemonico := RETN;
                When Others => mnemonico := Halt;
            End Case;
        End If;
        Return mnemonico;
    End Function;
End cpu_aux;

-- Codigo da CPU

Library IEEE;
Use IEEE.Std_Logic_1164.All;
Use IEEE.Std_Logic_arith.All;
Use IEEE.Std_Logic_unsigned.All;
Use Work.cpu_aux.All;

Entity cpu_8bits Is
    Generic (ne : Integer := 8;
             nd : Integer := 8);
    Port (ck    : In     Std_Logic;
          rst_b : In     Std_Logic;
          mrq_n : Buffer Std_Logic;
          wr_n  : Buffer Std_Logic;
          rd_n  : Buffer Std_Logic;
          Ed    : Out    Std_Logic_Vector(ne-1 Downto 0);
          Dt    : InOut  Std_Logic_Vector(nd-1 Downto 0));
End cpu_8bits;

Architecture teste Of cpu_8bits IS
    Signal Estado        : Tipo_Estado;
    Signal Passo_rd_wr   : Integer Range 0 To 3;
    Signal Passo_op_cod  : Integer Range 0 To 3;
    Signal Ler           : Boolean;
    Signal Escrever      : Boolean;

    -- Codigo nao permite alteracao nos valores de 'ne' e 'nd'
    Signal PC        : Std_Logic_Vector(ne-1 Downto 0);
    Signal pc_inc    : Std_Logic_Vector(ne-1 Downto 0);
    Signal St        : Std_Logic_Vector(ne-1 Downto 0);
    Signal st_novo   : Std_Logic_Vector(ne-1 Downto 0);
    Signal End_mem   : Std_Logic_Vector(ne-1 Downto 0);
    Signal Pg        : Std_Logic_Vector(3 Downto 0);
    Signal Ir        : Std_Logic_Vector(nd-1 Downto 0);
    Signal Acc       : Std_Logic_Vector(nd-1 Downto 0);
    Signal Aux       : Std_Logic_Vector(nd-1 Downto 0);
    Signal Dado_escr : Std_Logic_Vector(nd-1 Downto 0);
    Signal alu_s     : Std_Logic_Vector(nd-1 Downto 0);
    Signal alu_b     : Std_Logic_Vector(nd-1 Downto 0);
    Signal alu_flags : Std_Logic_Vector(1 Downto 0);
    Signal alu_n     : Std_Logic;
    Signal alu_z     : Std_Logic;

Begin

    -- Maquina principal responsavel pela decodificacao das instrucoes e realizacao das operacoes
    -- Trabalha em conjunto com a maquina que realiza o acesso a memoria denominada: 'borda_descida'
    -- Informacoes enviadas para maquina 'borda_descida' via os sinais 'Ler' e 'Escrever'
    -- Informacoes recebidas da maquina 'borda_descida' via o sinal 'Passo_rd_wr'
    borda_subida: Process (ck, rst_b)
    Variable salta : Boolean;
    Begin
        -- Preparacao: inicializacao assincrona
        If rst_b ='0' Then
            Ler <= False; 
            Escrever <= False;
            Estado <= Busca;
            Passo_op_cod <= 0;
            Pc <= (Others => '0');
            End_mem <= (Others => '0');
            
        -- Operacao normal    
        Elsif ck'Event And ck='1' Then   
            Case Estado Is
                -- Busca na memoria da proxima operacao
                When Busca =>

                    If    Passo_rd_wr = 0 Then Ler <= True; end_mem <= Pc;
                    Elsif Passo_rd_wr = 2 Then Ir <= Dt;
                    Elsif Passo_rd_wr = 3 Then Estado <= para_estado(Ir); Ler <= False;
                    End If;

                When LDmP =>
                    Pg <= Ir(3 Downto 0); Pc <= pc_inc; Estado <= Busca;

                When LDmA =>
                    If    Passo_rd_wr = 0 Then Ler <= True; End_mem <= pc_inc;
                    Elsif Passo_rd_wr = 2 Then Acc <= Dt; Pc <= pc_inc;
                    Elsif Passo_rd_wr = 3 Then Estado <= busca; Pc <= pc_inc; Ler <= False;
                    End If;

                When LDmS =>
                    If    Passo_rd_wr = 0 Then Ler <= True; End_mem <= pc_inc;
                    Elsif Passo_rd_wr = 2 Then St <= Dt; Pc <= pc_inc;
                    Elsif Passo_rd_wr = 3 Then Estado <= busca; Pc <= pc_inc; Ler <= False;
                    End If;

                When LDdA =>
                    If    Passo_rd_wr = 0 Then Ler <= True; End_mem <= Pg & Ir(3 Downto 0);
                    Elsif Passo_rd_wr = 2 Then Acc <= Dt; Pc <= pc_inc;
                    Elsif Passo_rd_wr = 3 Then Estado <= busca; Ler <= False;
                    End If;

                When STdA =>
                    If    Passo_rd_wr = 0 Then Escrever <= True; Dado_escr <= Acc; End_mem <= Pg & Ir(3 Downto 0);
                    Elsif Passo_rd_wr = 2 Then Pc <= pc_inc;
                    Elsif Passo_rd_wr = 3 Then Estado <= busca; Escrever <= False;
                    End If;

                When LDiA =>
                    If Passo_op_cod = 0 Then
                        If    Passo_rd_wr = 0 Then Ler <= True; End_mem <= Pg & Ir(3 Downto 0);
                        Elsif Passo_rd_wr = 2 Then Aux <= Dt;
                        Elsif Passo_rd_wr = 3 Then Passo_op_cod <= 1; Ler <= False;
                        End If;
                    Else
                        If    Passo_rd_wr = 0 Then Ler <= True; End_mem <= Aux;
                        Elsif Passo_rd_wr = 2 Then Acc <= Dt; Pc <= pc_inc;
                        Elsif Passo_rd_wr = 3 Then Estado <= busca; Ler <= False; Passo_op_cod <= 0;
                        End If;
                    End If;

                When STiA =>
                    If Passo_op_cod = 0 Then
                        If    Passo_rd_wr = 0 Then Ler <= True; End_mem <= Pg & Ir(3 Downto 0);
                        Elsif Passo_rd_wr = 2 Then Aux <= Dt;
                        Elsif Passo_rd_wr = 3 Then Passo_op_cod <= 1; Ler <= False;
                        End If;
                    Else
                        If    Passo_rd_wr = 0 Then Escrever <= True; Dado_escr <= Acc; End_mem <= Aux;
                        Elsif Passo_rd_wr = 2 Then Pc <= pc_inc;
                        Elsif Passo_rd_wr = 3 Then Estado <= busca; Escrever <= False; Passo_op_cod <= 0;
                        End If;
                    End If;

                When Jump | JP_Z | JPNZ | JPNG =>
                    If     Estado = Jump  Then salta := True;
                    Elsif  Estado = JP_Z And alu_flags(1) = '1' Then salta := True;
                    Elsif  Estado = JPNZ And alu_flags(1) = '0' Then salta := True;
                    Elsif  Estado = JPNG And alu_flags(0) = '1' Then salta := True;
                    Else   salta := False;
                    End If;

                    If salta Then
                        If    Passo_rd_wr = 0 Then Ler <= True; end_mem <= pc_inc;
                        Elsif Passo_rd_wr = 2 Then Pc <= Dt;
                        Elsif Passo_rd_wr = 3 Then Estado <= busca; Ler <= False;
                        End If;
                    Else
                        If    Passo_op_cod = 0 Then Pc <= pc_inc; Passo_op_cod <= 1;
                        Else  Pc <= pc_inc; Estado <= Busca; Passo_op_cod <= 0;
                        End If;
                    End If;

                When ADdA | SBdA =>
                    If    Passo_rd_wr = 0 Then Ler <= True; end_mem <= Pg & Ir(3 Downto 0);
                    Elsif Passo_rd_wr = 2 Then alu_b <= Dt; Pc <= pc_inc;
                    Elsif Passo_rd_wr = 3 Then Acc <= alu_s; alu_flags <= alu_z & alu_n; Estado <= Busca; Ler <= False;
                    End If;

                When Call =>
                    If Passo_op_cod = 0 Then
                        If    Passo_rd_wr = 0 Then Ler <= True; End_mem <= pc_inc;
                        Elsif Passo_rd_wr = 2 Then Aux <= Dt; Pc <= pc_inc;
                        Elsif Passo_rd_wr = 3 Then Passo_op_cod <= 1; Ler <= False;
                        End If;
                    Else
                        If    Passo_rd_wr = 0 Then Escrever <= True; Dado_escr <= pc_inc; End_mem <= St;
                        Elsif Passo_rd_wr = 2 Then St <= st_novo; Pc <= Aux;
                        Elsif Passo_rd_wr = 3 Then Estado <= busca; Escrever <= False; Passo_op_cod <= 0;
                        End If;
                    End If;

                When RETN =>
                    If    Passo_rd_wr = 0 Then Ler <= True; End_mem <= st_novo;
                    Elsif Passo_rd_wr = 2 Then Pc <= Dt; St <= st_novo;
                    Elsif Passo_rd_wr = 3 Then Estado <= Busca; Ler <= False;
                    End If;
                    
                When Halt =>
                    Estado <= Halt;

            End Case;
        End If;
    End Process;

    borda_descida: Process (ck, rst_b)
    Begin
        If rst_b ='0' Then
            mrq_n <= '1'; wr_n <= '1'; rd_n <='1'; Passo_rd_wr <= 0;
        Elsif ck'Event And ck='0' Then
            Case Passo_rd_wr Is
                When 0 =>
                    If    Ler      Then Passo_rd_wr <= 1; mrq_n <= '0'; rd_n <='0';
                    Elsif Escrever Then Passo_rd_wr <= 1; mrq_n <= '0';
                    End If;
                When 1 =>
                    If    Ler      Then Passo_rd_wr <= 2;
                    Elsif Escrever Then Passo_rd_wr <= 2; wr_n <= '0';
                    End If;
                When 2 =>
                    If    Ler      Then Passo_rd_wr <= 3; mrq_n <= '1'; rd_n <='1';
                    Elsif Escrever Then Passo_rd_wr <= 3; mrq_n <= '1'; wr_n <= '1';
                    End If;
                When 3 =>
                    Passo_rd_wr <= 0;
            End Case;
        End If;
    End Process;

    Ed <= end_mem;

    Dt <= dado_escr When (Escrever And mrq_n ='0') Else (Others => 'Z');

    Unidade_logica: Block
    Constant zero : Std_Logic_Vector(alu_s'Range) := (Others => '0');
    Begin
        alu_s <= Acc + alu_b When (Estado = ADdA) Else
                 Acc - alu_b;
        alu_z <= '1' When (alu_s = zero) Else '0';
        alu_n <= '1' When (alu_s(alu_s'High) = '1') Else '0';
    End Block;

    Contador_Programa: Block
    Begin
        pc_inc <= Pc + 1;
    End Block;

    pilha: Block
    Begin
        st_novo <= St - 1 When (Estado = Call) Else
                   St + 1;
    End Block;

End teste;

-- Celula de memoria com programa para teste

Library IEEE;
Use IEEE.Std_Logic_1164.All;
Use IEEE.Std_Logic_arith.All;
Use IEEE.Std_Logic_unsigned.All;
Use Work.cpu_aux.All;

Entity ram_8x8 Is
    Port (ce_n, oe_n, wr_n : In    Std_Logic;
          Ed               : In    Std_Logic_Vector(7 Downto 0);
          Dt               : InOut Std_Logic_Vector(7 Downto 0));
End ram_8x8;

Architecture teste Of ram_8x8 Is
    Type arranjo_memoria Is Array (Natural Range <>) Of Std_Logic_Vector(7 Downto 0);
    Signal dados : arranjo_memoria(0 To 255) :=
    (16#00# => x"0A",
     16#01# => x"f6",
     16#02# => x"FF",

     16#03# => x"10",  -- Load Direct Acc
     16#04# => x"af",  -- Add Direct Acc
     16#05# => x"31",  -- Store Indirect Acc

     16#06# => x"2E",  -- Load Indirect Acc   (Acc =77) (77 e' o valor contido no endereco A0)
     16#07# => x"BF",  --                      (Acc =77+02) (02 e' o valor contido no endereco AF)
                       --                      (Endereco Al recebe o valor 79)

     16#08# => x"4C",  --                      (Acc =25) (Acc recebe o valor
     16#09# => x"f0",  --                      (Endereco A3, apontado pelo endereco AC, recebe o valor 23)
     16#0A# => x"3A",  --                      (Salto para no caso "3A")
     
     16#3A# => x"f7",
     16#3B# => x"fb",
     16#3C# => x"a7",
     16#3D# => x"f3",
     16#3E# => x"40",

     16#40# => x"f8",
     16#41# => x"70",  -- dado de Call
     16#42# => x"ff",

     16#70# => x"f7",   -- Load Immediate Acc  (Acc recebe o valor 3)
     16#71# => x"03",
     16#72# => x"BB",
     16#73# => x"f2",
     16#74# => x"72",
     16#75# => x"f9",

     16#A0# => x"77",
     16#A1# => x"FF",
     16#A2# => x"25",
     16#A3# => x"FF",

     16#A7# => x"04",

     16#AB# => x"01",
     16#AC# => x"A3",
     16#AD# => x"03",
     16#AE# => x"A2",
     16#AF# => x"03",

     Others => x"ff"); -- halt

Begin
    Process(ce_n, oe_n, wr_n, dados, Dt, Ed)
    Begin
        If rising_edge(oe_n) Then
            If ce_n = '0' Then
                dados(Conv_Integer(Ed)) <= Dt;
            End If;
        End if;
        
        if ce_n = '0' And oe_n = '0' And wr_n = '1' Then 
            Dt <= dados(Conv_Integer(Ed)) After 10 ns; 
        Else
            Dt <= (Others => 'Z') After 10 ns;
        End if;
    End Process;
End teste;

-- Teste do conjunto CPU + Memoria
-- Geracao de estimulos contidos no codigo
-- Simula conjunto de cpu 8bits com ram 8x8

Library IEEE;
Use IEEE.Std_Logic_1164.All;
Use IEEE.Std_Logic_arith.All;
Use IEEE.Std_Logic_unsigned.All;

Entity conjunto_5 Is
End conjunto_5;

Architecture teste Of conjunto_5 IS
    Component cpu_8bits
    Port (ck, rst_b          : In     Std_Logic;
          mrq_n, wr_n, rd_n  : Buffer Std_Logic;
          Ed                  : Out    Std_Logic_Vector(7 Downto 0);
          Dt                  : InOut  Std_Logic_Vector(7 Downto 0));
    End Component;

    Component ram_8x8
    Port (ce_n, oe_n, wr_n : In    Std_Logic;
          Ed               : In    Std_Logic_Vector(7 Downto 0);
          Dt               : InOut Std_Logic_Vector(7 Downto 0));
    End Component;

    Signal ck         : Std_Logic := '0';
    Signal rst_b         : Std_Logic := '0';
    Signal mrq_n, wr_n, rd_n : Std_Logic;
    Signal ce_n, oe_n        : Std_Logic;
    Signal Ed                : Std_Logic_Vector(7 Downto 0);
    Signal Dt                : Std_Logic_Vector(7 Downto 0);

Begin
    ce_n <= mrq_n;
    oe_n <= rd_n;
    x0: cpu_8bits Port Map(ck, rst_b, mrq_n, wr_n, rd_n, Ed, Dt);
    x1: ram_8x8   Port Map(ce_n, oe_n, wr_n, Ed, Dt);

    ck    <= Not ck After 50 ns;
    rst_b <= '1' After 150 ns;

End teste;
