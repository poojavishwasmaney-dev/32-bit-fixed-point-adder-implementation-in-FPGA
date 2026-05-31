-------------------------------------------------------------------------------
-- Project      : FPGA Adder Architecture Study
--                RCA, CLA and Operator-Based Implementations on Xilinx 7-Series
-- File         : ripplecarry_adder.vhd
-- Author       : Pooja Ramesh
-- Email        : poojarchawde@gmail.com
-- Date         : May 2026
-- Version      : 1.0
--
-- Description  : 32-bit Ripple Carry Adder — function-based full adder
--                implementation. Carry propagated through variable assignment
--                to avoid VHDL delta-cycle deferral within process loop.
--                Targets Xilinx 7-series FPGA. CARRY4 not inferred due to
--                function abstraction obscuring the carry-propagate-generate
--                pattern from the synthesiser.
--
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

entity ripplecarry_addder is
generic(
    Width : integer := 16
);
port(
    a,b   : in std_logic_vector(Width-1 downto 0);
    cin   : in std_logic;
    sum   : out std_logic_vector(Width-1 downto 0);
    cout  : out std_logic
);
end ripplecarry_addder;

architecture rtl of ripplecarry_addder is

function fa (x,y,c : std_logic) return std_logic_vector is
variable sum : std_logic_vector(1 downto 0) := (others => '0');
begin
    sum(0) := x xor y xor c;
    sum(1) := (x and y) or (x and c) or (y and c);
    return std_logic_vector(sum);
end function fa;



begin
    process(a,b,cin) 
    variable carry : std_logic_vector(Width downto 0);
    variable fa_result : std_logic_vector( 1 downto 0);
    begin 
        carry(0) := cin;
        for i in 0 to Width-1 loop
            fa_result   := fa(a(i), b(i), carry(i));
            sum(i)      <= fa_result(0);
            carry(i+1)  := fa_result(1);

        end loop;
        cout <= carry(Width);
    end process;
end rtl;
