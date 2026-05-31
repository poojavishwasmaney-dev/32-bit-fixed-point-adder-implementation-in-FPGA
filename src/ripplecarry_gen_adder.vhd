-------------------------------------------------------------------------------
-- Project      : FPGA Adder Architecture Study
--                RCA, CLA and Operator-Based Implementations on Xilinx 7-Series
-- File         : ripplecarry_gen_adder.vhd
-- Author       : Pooja
-- Email        : poojarchawde@gmail.com
-- Date         : May 2026
-- Version      : 1.0
--
-- Description  : 32-bit RCA — generate-based. Identical netlist to function-based RCA post-synthesis.
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

entity ripplecarry_gen_addder is
generic(
    Width : integer := 32
);
port(
    a,b   : in std_logic_vector(Width-1 downto 0);
    cin   : in std_logic;
    sum   : out std_logic_vector(Width-1 downto 0);
    cout  : out std_logic
);
end ripplecarry_gen_addder;

architecture rtl of ripplecarry_gen_addder is
signal carry : std_logic_vector(Width downto 0);

begin
    carry(0) <= cin;
    sum_generate : for i in 0 to Width-1 generate
        sum(i) <= a(i) xor b(i) xor carry(i);
        carry(i+1) <= (a(i) and b(i)) or(a(i) and carry(i)) or(b(i) and carry(i));
    end generate sum_generate;

    
    cout     <= carry(Width);
    
end rtl;
