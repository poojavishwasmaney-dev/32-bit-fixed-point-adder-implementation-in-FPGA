library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity pipelined_adder is
generic (
    Width : integer := 31;
    Width1 : integer := 15;
    Width2 : integer := 16
);
port(
    x,y : in std_logic_vector(Width-1 downto 0);
    sum : out std_logic_vector(Width-1 downto 0);
    LSBs_Carry : out std_logic;
    clk : in std_logic
);
end pipelined_adder;

architecture rtl of pipelined_adder is

signal l1, l2, s1 : std_logic_vector(width1-1 downto 0);
signal r1           : std_logic_vector(Width1 downto 0);
signal l3, l4, r2, s2 : std_logic_vector(Width2-1 downto 0);

begin
    process(clk)
begin
    if rising_edge(clk) then
        l1 <= x(Width1-1 downto 0);
        l2 <= y(Width1-1 downto 0);

        l3 <= x(Width-1 downto Width1);
        l4 <= y(Width-1 downto Width1);

        r1 <= ('0' & l1) + ('0' & l2);
        r2 <= l3 + l4;

        s1 <= r1(Width1-1 downto 0);
        s2 <= r1(Width1) + r2;
    end if;
end process;
    LSBs_Carry <= r1(Width1);

    sum <= s2 & s1;
end rtl;