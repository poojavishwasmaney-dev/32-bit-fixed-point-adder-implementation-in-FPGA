-------------------------------------------------------------------------------
-- Project      : FPGA Adder Architecture Study
--                RCA, CLA and Operator-Based Implementations on Xilinx 7-Series
-- File         : adder.vhd
-- Author       : Pooja
-- Email        : poojarchawde@gmail.com
-- Date         : May 2026
-- Version      : 1.0
--
-- Description  : 32-bit adder using numeric_std + operator. Infers CARRY4, dedicated carry routing.
-- Inputs       : a    [31:0]  — operand A
--                b    [31:0]  — operand B
--                cin          — carry in
-- Outputs      : sum  [31:0]  — result
--                cout         — carry out
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity adder is
generic(
    Width : integer := 32
);
port(
    a,b   : in unsigned(Width-1 downto 0);
    cin   : in std_logic;
    sum   : out unsigned(Width-1 downto 0);
    cout  : out std_logic
);
end adder;

architecture rtl of adder is
signal result : unsigned(Width downto 0);

begin
    result <= ('0' & a) + ('0' & b) + ("" & cin);
    sum    <= result(Width-1 downto 0);
    cout   <= result(Width);
    
end rtl;
