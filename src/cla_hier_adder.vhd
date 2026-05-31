-------------------------------------------------------------------------------
-- Project      : FPGA Adder Architecture Study
--                RCA, CLA and Operator-Based Implementations on Xilinx 7-Series
-- File         : cla_hier_adder.vhd
-- Author       : Pooja
-- Email        : poojarchawde@gmail.com
-- Date         : May 2026
-- Version      : 1.0
--
-- Description  : 16-bit hierarchical block CLA — true parallel carry, fully expanded equations.
-- Inputs       : a    [31:0]  — operand A
--                b    [31:0]  — operand B
--                cin          — carry in
-- Outputs      : sum  [31:0]  — result
--                cout         — carry out
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cla_hier_adder is
generic(
    Width   : integer := 16
);
    port(
        a, b : in  std_logic_vector(Width-1 downto 0);
        cin  : in  std_logic;
        sum    : out std_logic_vector(Width-1 downto 0);
        cout : out std_logic
    );
end cla_hier_adder;

architecture rtl of cla_hier_adder is
    signal G, P : std_logic_vector(Width-1 downto 0);
    signal G_star, P_star : std_logic_vector(3 downto 0);
    signal C_block : std_logic_vector(4 downto 0);  -- C_block(0)=cin, (4)=cout
    type internal_carry_t is array (0 to 3) of std_logic_vector(2 downto 0);
    signal C_int : internal_carry_t;
begin
    -- Bit-level P and G
    bit_gen: for i in 0 to Width-1 generate
        G(i) <= a(i) and b(i);
        P(i) <= a(i) xor b(i);
    end generate;
    
    -- Block-level P* and G*
    block_gen: for b in 0 to 3 generate
        constant idx : integer := b * 4;
    begin
        P_star(b) <= P(idx+3) and P(idx+2) and P(idx+1) and P(idx);
        G_star(b) <= G(idx+3) or 
                     (P(idx+3) and G(idx+2)) or 
                     (P(idx+3) and P(idx+2) and G(idx+1)) or 
                     (P(idx+3) and P(idx+2) and P(idx+1) and G(idx));
    end generate;
    
    -- Block carries (second-level CLA)
    C_block(0) <= cin;
    C_block(1) <= G_star(0) or (P_star(0) and C_block(0));
    C_block(2) <= G_star(1) or (P_star(1) and G_star(0)) or 
                  (P_star(1) and P_star(0) and C_block(0));
    C_block(3) <= G_star(2) or (P_star(2) and G_star(1)) or 
                  (P_star(2) and P_star(1) and G_star(0)) or 
                  (P_star(2) and P_star(1) and P_star(0) and C_block(0));
    C_block(4) <= G_star(3) or (P_star(3) and G_star(2)) or 
                  (P_star(3) and P_star(2) and G_star(1)) or 
                  (P_star(3) and P_star(2) and P_star(1) and G_star(0));
    cout <= C_block(4);
    
    -- Internal carries for each block
    int_carry_gen: for b in 0 to 3 generate
        constant idx : integer := b * 4;
    begin
        C_int(b)(0) <= G(idx) or (P(idx) and C_block(b));     -- C1 of block
        C_int(b)(1) <= G(idx+1) or (P(idx+1) and G(idx)) or 
                       (P(idx+1) and P(idx) and C_block(b));  -- C2 of block
        C_int(b)(2) <= G(idx+2) or (P(idx+2) and G(idx+1)) or 
                       (P(idx+2) and P(idx+1) and G(idx)) or 
                       (P(idx+2) and P(idx+1) and P(idx) and C_block(b));  -- C3 of block
    end generate;
    
    -- Final sums
    sum_gen: for b in 0 to 3 generate
        constant idx : integer := b * 4;
    begin
        sum(idx)   <= P(idx)   xor C_block(b);     -- uses block carry in
        sum(idx+1) <= P(idx+1) xor C_int(b)(0);    -- uses C1 of block
        sum(idx+2) <= P(idx+2) xor C_int(b)(1);    -- uses C2 of block
        sum(idx+3) <= P(idx+3) xor C_int(b)(2);    -- uses C3 of block
    end generate;
    
end rtl;