-------------------------------------------------------------------------------
-- Project      : FPGA Adder Architecture Study
--                RCA, CLA and Operator-Based Implementations on Xilinx 7-Series
-- File         : adder_tb.vhd
-- Author       : Pooja
-- Date         : May 2026
-- Version      : 2.0
--
-- Description  : Unified 32-bit testbench for all adder implementations.
--                Covers directed corner cases, boundary conditions, walking
--                ones/zeros patterns, and 100 random stimulus vectors with
--                automatic scoreboard reporting.
--                Change DUT entity name to switch between designs.
--
-- Supported DUTs:
--   ripplecarry_adder     ripplecarry_gen_adder
--   adder                 cla_flat_adder
--   cla_hier_adder        pipelined_adder
--
-- Simulation only — not intended for synthesis.
-- Tool         : Vivado Simulator / ModelSim
-- Std          : VHDL-2008
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity adder_tb is
end entity adder_tb;

architecture test of adder_tb is

    -- -------------------------------------------------------------------------
    -- Constants
    -- -------------------------------------------------------------------------
    constant Width      : positive := 32;
    constant CLK_PERIOD : time     := 10 ns;
    constant MAX_VAL    : integer  := integer'high;  -- 2^31-1 (VHDL integer limit)

    -- -------------------------------------------------------------------------
    -- DUT signals
    -- -------------------------------------------------------------------------
    signal a, b  : std_logic_vector(Width-1 downto 0);
    signal cin   : std_logic;
    signal sum   : std_logic_vector(Width-1 downto 0);
    signal carry : std_logic;

    -- -------------------------------------------------------------------------
    -- Helper function: safe 32-bit expected sum
    -- VHDL integer is 32-bit signed so we use unsigned arithmetic via naturals
    -- -------------------------------------------------------------------------
    function expected_sum32 (
        a_v   : std_logic_vector(31 downto 0);
        b_v   : std_logic_vector(31 downto 0);
        cin_v : std_logic
    ) return std_logic_vector is
        variable res : unsigned(32 downto 0);
    begin
        res := ('0' & unsigned(a_v)) + ('0' & unsigned(b_v)) + ("" & cin_v);
        return std_logic_vector(res(31 downto 0));
    end function;

    function expected_cout32 (
        a_v   : std_logic_vector(31 downto 0);
        b_v   : std_logic_vector(31 downto 0);
        cin_v : std_logic
    ) return std_logic is
        variable res : unsigned(32 downto 0);
    begin
        res := ('0' & unsigned(a_v)) + ('0' & unsigned(b_v)) + ("" & cin_v);
        return res(32);
    end function;

begin

    -- -------------------------------------------------------------------------
    -- DUT instantiation — change entity name to switch between designs
    -- -------------------------------------------------------------------------
    DUT : entity work.adder
        generic map (Width => Width)
        port map (
            a    => a,
            b    => b,
            cin  => cin,
            sum  => sum,
            cout => carry
        );

    -- -------------------------------------------------------------------------
    -- Stimulus and scoreboard process
    -- -------------------------------------------------------------------------
    process
        variable test_num  : integer := 0;
        variable pass_cnt  : integer := 0;
        variable fail_cnt  : integer := 0;

        variable seed1, seed2 : positive := 42;
        variable rand_r        : real;
        variable a_rand        : unsigned(31 downto 0);
        variable b_rand        : unsigned(31 downto 0);
        variable cin_rand      : std_logic;
        variable lo, hi        : unsigned(15 downto 0);

        -- Apply stimulus and check after propagation delay
        procedure apply_and_check (
            a_v    : in std_logic_vector(31 downto 0);
            b_v    : in std_logic_vector(31 downto 0);
            cin_v  : in std_logic;
            label  : in string
        ) is
            variable exp_sum  : std_logic_vector(31 downto 0);
            variable exp_cout : std_logic;
        begin
            a   <= a_v;
            b   <= b_v;
            cin <= cin_v;
            wait for CLK_PERIOD;

            exp_sum  := expected_sum32(a_v, b_v, cin_v);
            exp_cout := expected_cout32(a_v, b_v, cin_v);
            test_num := test_num + 1;

            if (sum = exp_sum) and (carry = exp_cout) then
                report "Test " & integer'image(test_num) & " PASSED : " & label;
                pass_cnt := pass_cnt + 1;
            else
                report "Test " & integer'image(test_num) & " FAILED : " & label &
                       "  got sum=" & integer'image(to_integer(unsigned(sum))) &
                       " cout=" & std_logic'image(carry) &
                       "  exp sum=" & integer'image(to_integer(unsigned(exp_sum))) &
                       " cout=" & std_logic'image(exp_cout)
                    severity error;
                fail_cnt := fail_cnt + 1;
            end if;
        end procedure;

    begin

        report "========================================";
        report " Starting 32-bit Adder Testbench";
        report " DUT: cla_hier_adder";
        report "========================================";

        -- =====================================================================
        -- GROUP 1 — Directed Corner Cases
        -- =====================================================================
        report "--- Group 1: Directed Corner Cases ---";

        apply_and_check(x"00000000", x"00000000", '0', "0+0+0 = 0");
        apply_and_check(x"00000000", x"00000000", '1', "0+0+1 = 1");
        apply_and_check(x"00000001", x"00000001", '0', "1+1+0 = 2");
        apply_and_check(x"00000001", x"00000001", '1', "1+1+1 = 3");
        apply_and_check(x"7FFFFFFF", x"00000000", '0', "MAX_POS+0+0");
        apply_and_check(x"7FFFFFFF", x"00000000", '1', "MAX_POS+0+1");
        apply_and_check(x"7FFFFFFF", x"7FFFFFFF", '0', "MAX_POS+MAX_POS no cin");
        apply_and_check(x"7FFFFFFF", x"7FFFFFFF", '1', "MAX_POS+MAX_POS+1");
        apply_and_check(x"FFFFFFFF", x"00000001", '0', "ALL_ONES+1 overflow");
        apply_and_check(x"FFFFFFFF", x"FFFFFFFF", '0', "ALL_ONES+ALL_ONES");
        apply_and_check(x"FFFFFFFF", x"FFFFFFFF", '1', "ALL_ONES+ALL_ONES+1");
        apply_and_check(x"80000000", x"80000000", '0', "MSB+MSB overflow");
        apply_and_check(x"FFFFFFFF", x"00000000", '0', "ALL_ONES+0");
        apply_and_check(x"FFFFFFFF", x"00000000", '1', "ALL_ONES+0+1 overflow");

        -- =====================================================================
        -- GROUP 2 — Boundary Values
        -- =====================================================================
        report "--- Group 2: Boundary Values ---";

        apply_and_check(x"00000001", x"FFFFFFFF", '0', "1+ALL_ONES overflow");
        apply_and_check(x"00000000", x"FFFFFFFF", '1', "0+ALL_ONES+1 overflow");
        apply_and_check(x"55555555", x"AAAAAAAA", '0', "ALT_01+ALT_10 = ALL_ONES");
        apply_and_check(x"55555555", x"AAAAAAAA", '1', "ALT_01+ALT_10+1 overflow");
        apply_and_check(x"AAAAAAAA", x"55555555", '0', "ALT_10+ALT_01 = ALL_ONES");
        apply_and_check(x"12345678", x"87654321", '0', "complementary pattern");
        apply_and_check(x"12345678", x"87654321", '1', "complementary+cin");
        apply_and_check(x"0000FFFF", x"0000FFFF", '0', "LSB_HALF+LSB_HALF");
        apply_and_check(x"FFFF0000", x"FFFF0000", '0', "MSB_HALF+MSB_HALF overflow");
        apply_and_check(x"0000FFFF", x"FFFF0000", '0', "LSB_HALF+MSB_HALF = ALL_ONES");
        apply_and_check(x"0000FFFF", x"FFFF0000", '1', "LSB_HALF+MSB_HALF+1 overflow");

        -- =====================================================================
        -- GROUP 3 — Walking Ones (carry chain stress)
        -- =====================================================================
        report "--- Group 3: Walking Ones (carry chain stress) ---";

        for i in 0 to 31 loop
            apply_and_check(
                std_logic_vector(to_unsigned(2**i, 32)),
                std_logic_vector(to_unsigned(2**i, 32)),
                '0',
                "2^" & integer'image(i) & " + 2^" & integer'image(i)
            );
        end loop;

        -- =====================================================================
        -- GROUP 4 — Walking Zeros
        -- =====================================================================
        report "--- Group 4: Walking Zeros ---";

        for i in 0 to 31 loop
            -- All ones except bit i
            apply_and_check(
                std_logic_vector(unsigned(x"FFFFFFFF") xor to_unsigned(2**i, 32)),
                x"00000001",
                '0',
                "ALL_ONES_except_bit_" & integer'image(i) & "+1"
            );
        end loop;

        -- =====================================================================
        -- GROUP 5 — Carry Propagation Stress
        -- These patterns maximise carry chain length
        -- =====================================================================
        report "--- Group 5: Carry Propagation Stress ---";

        -- Long carry chain: adding 1 to all-ones subfields
        apply_and_check(x"0FFFFFFF", x"00000001", '0', "long carry chain bits 0-27");
        apply_and_check(x"00FFFFFF", x"00000001", '0', "long carry chain bits 0-23");
        apply_and_check(x"000FFFFF", x"00000001", '0', "long carry chain bits 0-19");
        apply_and_check(x"7FFFFFFE", x"00000001", '0', "near max no overflow");
        apply_and_check(x"7FFFFFFE", x"00000001", '1', "near max with cin");
        apply_and_check(x"FFFFFFFE", x"00000001", '0', "all ones minus 1 + 1");
        apply_and_check(x"FFFFFFFE", x"00000001", '1', "all ones minus 1 + 1 + cin");

        -- =====================================================================
        -- GROUP 6 — Random Stimulus (100 vectors)
        -- =====================================================================
        report "--- Group 6: Random Stimulus (100 vectors) ---";

        for i in 1 to 100 loop
            -- Generate random 32-bit values using 16-bit halves
            -- (VHDL real precision limits direct 32-bit random generation)
            uniform(seed1, seed2, rand_r);
            lo := to_unsigned(integer(rand_r * 65535.0), 16);
            uniform(seed1, seed2, rand_r);
            hi := to_unsigned(integer(rand_r * 65535.0), 16);
            a_rand := hi & lo;

            uniform(seed1, seed2, rand_r);
            lo := to_unsigned(integer(rand_r * 65535.0), 16);
            uniform(seed1, seed2, rand_r);
            hi := to_unsigned(integer(rand_r * 65535.0), 16);
            b_rand := hi & lo;

            uniform(seed1, seed2, rand_r);
            if rand_r < 0.5 then cin_rand := '0'; else cin_rand := '1'; end if;

            apply_and_check(
                std_logic_vector(a_rand),
                std_logic_vector(b_rand),
                cin_rand,
                "random_" & integer'image(i)
            );
        end loop;

        -- =====================================================================
        -- Final Scoreboard
        -- =====================================================================
        wait for CLK_PERIOD;

        report "========================================";
        report "           FINAL SCOREBOARD             ";
        report "========================================";
        report "Total  Tests : " & integer'image(test_num);
        report "Passed Tests : " & integer'image(pass_cnt);
        report "Failed Tests : " & integer'image(fail_cnt);
        report "Pass Rate    : " &
               integer'image((pass_cnt * 100) / test_num) & "%";
        report "========================================";

        if fail_cnt = 0 then
            report "SUCCESS: All " & integer'image(test_num) & " tests passed!"
                severity note;
        else
            report "FAILURE: " & integer'image(fail_cnt) & " tests failed!"
                severity failure;
        end if;

        wait;
    end process;

end architecture test;