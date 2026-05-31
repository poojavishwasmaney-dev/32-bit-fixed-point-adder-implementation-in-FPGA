-------------------------------------------------------------------------------
-- Project      : FPGA Adder Architecture Study
--                RCA, CLA and Operator-Based Implementations on Xilinx 7-Series
-- File         : cla_flat_adder.vhd
-- Author       : Pooja
-- Email        : poojarchawde@gmail.com
-- Date         : May 2026
-- Version      : 1.0
--
-- Description  : 32-bit flat CLA — generate loop. Structurally ripple despite P/G signals.
-- Inputs       : a    [31:0]  — operand A
--                b    [31:0]  — operand B
--                cin          — carry in
-- Outputs      : sum  [31:0]  — result
--                cout         — carry out
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity cla_flat_adder is
generic(
    Width : integer := 32
);
port(
    a,b   : in std_logic_vector(Width-1 downto 0);
    cin   : in std_logic;
    sum   : out std_logic_vector(Width-1 downto 0);
    cout  : out std_logic
);
end cla_flat_adder;

architecture rtl of cla_flat_adder is

signal g_i : std_logic_vector(Width-1 downto 0);
signal p_i : std_logic_vector(Width-1 downto 0);
signal s_i : std_logic_vector(Width-1 downto 0);
signal c_i : std_logic_vector(Width downto 0);

begin
    g_generate_for : for i in 0 to Width-1 generate 
        g_i(i)      <= a(i) and b(i);
        p_i(i)      <= a(i) xor b(i);
    end generate g_generate_for;

    s_generate_for : for i in 0 to Width-1 generate
        s_i(i)      <= p_i(i) xor c_i(i);
    end generate s_generate_for;


    c_i(0)      <= cin;
    sum         <= s_i;
    cout        <= c_i(Width);

    --Carry still ripples through here eventhough the process term has only c_i(0)
    gen_carry : for i in 1 to Width generate
        process(g_i, p_i, c_i(0))
            variable c_term : std_logic;
        begin
            c_term := c_i(0);
            for k in 0 to i-1 loop
                c_term := g_i(k) or (p_i(k) and c_term);
            end loop;
            c_i(i) <= c_term;
        end process;
    end generate;


end rtl;
