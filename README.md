-------------------------------------------------------------------------------
-- Project : FPGA Adder Architecture Study
--           RCA, CLA and Operator-Based Implementations on Xilinx 7-Series
-- Author  : Pooja
-- Date    : May 2026
-- Version : 1.0
-------------------------------------------------------------------------------

# FPGA Adder Architecture Study
### RCA, CLA and Operator-Based Implementations on Xilinx 7-Series
### VHDL — Synthesis, Implementation & Timing Study

This project implements and analyses six different 32-bit adder architectures in VHDL, exploring how RTL coding style, arithmetic abstraction, carry architecture, and pipelining each affect synthesis primitive inference, logic levels, route delay, maximum operating frequency, and throughput. All designs target a Xilinx 7-series FPGA device (xc7a35t / 7z020-clg484).

---

## File Structure

```
fpga-adder-architecture-study/
├── src/
│   ├── ripplecarry_adder.vhd       # RCA — function-based full adder
│   ├── ripplecarry_gen_adder.vhd   # RCA — generate-based full adder
│   ├── adder.vhd                   # Adder using IEEE numeric_std + operator
│   ├── cla_flat_adder.vhd          # Flat CLA — generate loop (structural ripple)
│   ├── cla_hier_adder.vhd          # Hierarchical block CLA — true parallel carry
│   └── pipelined_adder.vhd         # 3-stage pipelined adder
├── sim/
│   └── adder_tb.vhd                # Unified 32-bit testbench for all designs
├── reports/
│   ├── rca_timing_report.txt
│   ├── adder_carry4_timing.txt
│   ├── cla_flat_timing.txt
│   ├── cla_hier_timing.txt
│   └── pipelined_timing_summary.txt
└── README.md
```

---

## Design Descriptions

### 1. `ripplecarry_adder.vhd` — Function-Based Ripple Carry Adder

Implements a full adder as a VHDL function returning `std_logic_vector(1 downto 0)`, called iteratively inside a process loop. Carry and intermediate results are declared as **variables** inside the process to avoid the VHDL delta-cycle issue — signal assignments inside a process are deferred to the next simulation cycle, causing carry to read a stale value on the next loop iteration. Variables update immediately and propagate correctly.

```
sum(i)     = a(i) XOR b(i) XOR carry(i)
carry(i+1) = (a(i) AND b(i)) OR (a(i) AND carry(i)) OR (b(i) AND carry(i))
```

The function wrapper returns a vector — this abstraction **prevents CARRY4 inference**. The synthesiser sees two independent logic cones rather than a carry-propagate-generate structure, and falls back to a serial LUT5 chain through general routing.

---

### 2. `ripplecarry_gen_adder.vhd` — Generate-Based Ripple Carry Adder

Implements the same 32-bit RCA using a `generate` statement to instantiate 32 structural full adder components connected through an explicit carry vector. Despite the different coding style, both RCA implementations produce **identical post-synthesis netlists**. The synthesiser reduces both to the same Boolean equations and applies the same optimisations — the abstraction boundary (function vs generate) is transparent to the synthesis engine.

---

### 3. `adder.vhd` — Arithmetic Operator Adder

Implements the adder using the IEEE `numeric_std` `+` operator on `unsigned` types, giving the synthesiser a high-level arithmetic intent it can map directly to dedicated carry primitives.

```vhdl
use ieee.numeric_std.all;

result <= ('0' & unsigned(a)) + ('0' & unsigned(b)) + ("" & cin);
sum    <= std_logic_vector(result(Width-1 downto 0));
cout   <= result(Width);
```

> `std_logic_arith` and `std_logic_unsigned` are non-standard Synopsys packages. Mixing them with `numeric_std` creates multiple `+` definitions and causes an ambiguous operator resolution error at elaboration. Use only `ieee.numeric_std`.

This is the only design that inferred `CARRY4` primitives. The carry chain propagates through dedicated silicon routing with **0.000 ns inter-stage route delay** between consecutive CARRY4s, confirming physically adjacent slice routing rather than programmable interconnect.

---

### 4. `cla_flat_adder.vhd` — Flat CLA (Structural Ripple)

Intended as a carry lookahead adder using explicit generate (`g_i`) and propagate (`p_i`) signals with a generate loop computing each carry term.

```vhdl
g_i(i) <= a(i) and b(i);
p_i(i) <= a(i) xor b(i);

c_term := c_i(0);
for k in 0 to i-1 loop
    c_term := g_i(k) or (p_i(k) and c_term);  -- still ripples
end loop;
c_i(i) <= c_term;
```

This is **structurally a ripple carry adder**. The loop variable `c_term` accumulates each carry from the previous one — every `c_i(i)` depends on `c_i(i-1)`. The synthesiser correctly unrolls the loop into a serial OR-AND chain. The presence of explicit P and G signals does not change this — the serial data dependency is preserved through synthesis.

A true CLA requires every carry to be **fully expanded back to `cin`** with no dependency on any intermediate carry:

```
C(1) = G(0) | (P(0) & cin)
C(2) = G(1) | (P(1) & G(0)) | (P(1) & P(0) & cin)
C(3) = G(2) | (P(2) & G(1)) | (P(2) & P(1) & G(0)) | (P(2) & P(1) & P(0) & cin)
C(4) = G(3) | (P(3) & G(2)) | (P(3) & P(2) & G(1)) | (P(3) & P(2) & P(1) & G(0))
             | (P(3) & P(2) & P(1) & P(0) & cin)
```

In this form `cin` appears directly in every equation and `c_i` never appears on the right-hand side — the result is two levels of logic regardless of width.

---

### 5. `cla_hier_adder.vhd` — Hierarchical Block CLA

Implements a true carry lookahead adder using 4-bit CLA groups cascaded with a second-level group carry lookahead. Each carry equation is fully expanded — no carry depends on another carry. The critical path shows only `g_i`, `p_i`, and `cin` feeding each carry computation with no carry net appearing more than once.

This is the only LUT-based design that achieves genuinely parallel carry computation. The timing report confirms it with 4 actual LUT levels (vs 13 for the flat CLA) and no carry-to-carry net dependency in the critical path.

```
Level 1 : Bit-level P, G           — 1 LUT level
Level 2 : 4-bit group G*, P*       — 2 LUT levels  (AND-OR, fits LUT6)
Level 3 : Block carry CLA          — 2 LUT levels  (AND-OR, 4-input)
Level 4 : Internal carries + sum   — 2 LUT levels
```

---

### 6. `pipelined_adder.vhd` — 3-Stage Pipelined Adder

Implements a pipelined adder that splits addition across three registered stages to improve throughput. Unlike the combinational designs, timing is analysed as register-to-register paths rather than IO paths.

```
Stage 1 (Cycle N)   : Register inputs  → l1, l2 (LSBs),  l3, l4 (MSBs)
Stage 2 (Cycle N+1) : Partial sums     → r1 = l1+l2,     r2 = l3+l4
Stage 3 (Cycle N+2) : Combine          → s1 = r1[LSBs],  s2 = r1[carry] + r2
```

All three stages are written inside a single clocked process using `rising_edge(clk)`. A `wait until clk = '1'` form is not reliably synthesisable in Vivado and must not be used.

---

## Testbench — `adder_tb.vhd`

A unified 32-bit testbench covers all six implementations. Change the DUT entity name on the instantiation line to switch between designs. The testbench applies six groups of stimulus and reports a final pass/fail scoreboard.

| Group | Tests | Coverage |
|---|---|---|
| Directed corner cases | 14 | Zero, all-ones, overflow, max values |
| Boundary values | 11 | Alternating patterns, half-word carries |
| Walking ones | 32 | Each bit position — carry chain stress |
| Walking zeros | 32 | All-ones minus one bit per position |
| Carry propagation stress | 7 | Long carry chain inputs |
| Random stimulus | 100 | Pseudo-random 32-bit vectors with scoreboard |
| **Total** | **196** | |

Random generation uses 16-bit halves concatenated to avoid VHDL `real` precision loss on full 32-bit values. Expected results are computed via `unsigned(32 downto 0)` to handle overflow correctly without signed integer overflow.

---

## How to Reproduce

### Simulation

**Vivado Simulator:**

1. Open Vivado → Create Project → RTL Project
2. Add all `src/*.vhd` and `sim/adder_tb.vhd` as design sources
3. Set `adder_tb` as the simulation top module
4. In `adder_tb.vhd`, change the DUT entity name to the design under test:
   ```vhdl
   DUT : entity work.cla_hier_adder   -- change this line to switch designs
   ```
5. Run → Run Simulation → Run Behavioural Simulation
6. Check the Tcl console for the FINAL SCOREBOARD report

**ModelSim / Questa:**

```tcl
vcom -2008 src/cla_hier_adder.vhd
vcom -2008 sim/adder_tb.vhd
vsim work.adder_tb
run -all
```

### Synthesis and Implementation

1. Create a new Vivado RTL project
2. Set target device to `xc7a35t-cpg236-1` (Artix-7) or `xc7z020-clg484-1` (Zynq-7000)
3. Add the desired `src/*.vhd` file as the top module
4. For `pipelined_adder.vhd`, create an XDC constraint file:
   ```tcl
   create_clock -period 10.000 -name clk [get_ports clk]
   set_input_delay  -clock clk -max 2.0 [get_ports {a[*] b[*] cin}]
   set_input_delay  -clock clk -min 0.5 [get_ports {a[*] b[*] cin}]
   set_output_delay -clock clk -max 2.0 [get_ports {sum[*] cout}]
   set_output_delay -clock clk -min 0.5 [get_ports {sum[*] cout}]
   ```
5. Run Synthesis → Run Implementation
6. Open Implemented Design and run reports:
   ```tcl
   report_timing -from [all_inputs] -to [all_outputs] -verbose
   report_utilization
   report_design_analysis -logic_level_distribution
   report_timing_summary
   ```

---

## Synthesis Results — Resource Utilisation

| Design | LUTs | Primitive Type | CARRY Inferred |
|---|---|---|---|
| `ripplecarry_adder.vhd` | 16 × LUT5 | Serial LUT chain | No |
| `ripplecarry_gen_adder.vhd` | 16 × LUT5 | Serial LUT chain | No |
| `adder.vhd` | 1 × LUT2 + 9 × CARRY4 | Dedicated carry fabric | Yes — CARRY4 |
| `cla_flat_adder.vhd` | LUT3×1 + LUT5×4 + LUT6×8 | Serial LUT chain | No |
| `cla_hier_adder.vhd` | LUT3×1 + LUT4×1 + LUT6×2 | Parallel LUT groups | No |
| `pipelined_adder.vhd` | FDRE×N + CARRY4×4 | Registered + dedicated carry | Yes — CARRY4 |

Both RCA implementations produce identical utilisation — the synthesiser collapses both to the same Boolean equations regardless of coding style. The flat CLA uses a mix of LUT sizes because the synthesiser merged multiple carry bits per LUT where fan-in permitted, but the chain remains serial. The hierarchical CLA uses significantly fewer and smaller LUTs because the parallel carry structure eliminates redundant logic.

---

## Timing Reports — Critical Path (32-bit, Slow Process Corner)

### Pad Overhead

All combinational reports include IBUF and OBUF delays present only at top-level IO pins. These are removed to obtain the actual in-system adder delay when driven by internal registers:

```
Pad overhead (RCA / CLA designs) = IBUF(0.921) + in-net(0.800) + out-net(0.800) + OBUF(2.584) = 5.105 ns
Pad overhead (adder.vhd)         = IBUF(0.921) + in-net(0.800) + out-net(0.800) + OBUF(2.833) = 5.354 ns
```

The pipelined adder report is register-to-register — no pad overhead applies.

### Timing Summary

| Design | Total Delay | Logic Delay | Route Delay | Route % | Logic Levels | LUT Levels | In-System Delay |
|---|---|---|---|---|---|---|---|
| `ripplecarry_adder.vhd` | 14.016 ns | 5.412 ns | 8.604 ns | 61% | 18 | 16 | 8.911 ns |
| `ripplecarry_gen_adder.vhd` | 14.016 ns | 5.412 ns | 8.604 ns | 61% | 18 | 16 | 8.911 ns |
| `cla_flat_adder.vhd` | 12.220 ns | 5.136 ns | 7.084 ns | 58% | 15 | 13 | 7.115 ns |
| `cla_hier_adder.vhd` | 7.663 ns | 4.002 ns | 3.661 ns | 48% | 6 | 4 | 2.558 ns |
| `adder.vhd` | 7.120 ns | 5.512 ns | 1.608 ns | 23% | 12 | — | 1.766 ns |
| `pipelined_adder.vhd` | 2.712 ns* | 1.720 ns | 0.992 ns | 37% | 4 (CARRY4) | — | 2.712 ns* |

*Register-to-register path. No pad overhead. Directly comparable to in-system delay of combinational designs.

### Route Delay as a Diagnostic

Route delay percentage is the primary indicator of carry chain quality:

- **58–61%** — carry in general programmable interconnect; serial chain behaviour. All three LUT-chain designs fall here.
- **48%** — carry partially parallelised; approaching logic-dominated profile. Hierarchical CLA.
- **37%** — registered path with CARRY4; healthy logic-dominated profile. Pipelined adder.
- **23%** — carry in dedicated CARRY4 silicon; inter-stage route delay is 0.000 ns. Only `adder.vhd`.

The healthy target for a correctly inferred or correctly structured adder is **logic-dominated (~70–80% logic, ~20–30% route)**.

### Critical Path Evidence — Flat CLA vs Hierarchical CLA

The net names in the timing report directly reveal the carry structure:

```
Flat CLA critical path:
  b[1] → c_i[2] → c_i[7] → c_i[12] → c_i[17] → c_i[22] → c_i[24] → c_i[26] → c_i[28] → sum[28]
  Carry feeds carry — serial ripple confirmed.

Hierarchical CLA critical path:
  a[5] → LUT6 → LUT4 → LUT6 → LUT3 → sum[12]
  No carry net in path — parallel computation confirmed.
```

---

## TCLA Calculation

### tgate Extraction

Gate delay `tgate` is the propagation delay through a single LUT stage, read directly from the timing reports:

**Flat CLA** (LUT mix, averaged):
```
LUT delays: 0.150, 0.124, 0.124, 0.124, 0.116, 0.124 ns
tgate = 0.762 / 6 = 0.127 ns
```

**Hierarchical CLA** (consistent across all LUT types):
```
LUT6, LUT4, LUT6, LUT3 all show: 0.124 ns
tgate = 0.124 ns
```

### Formula

```
TCLA = 2 × tgate × (1 + logk(n))

k = 6   (LUT6 dominant primitive)
n = 32  (bit width)

log6(32) = log(32) / log(6) = 1.5051 / 0.7782 = 1.934
```

**Flat CLA:**
```
TCLA = 2 × 0.127 × (1 + 1.934) = 0.254 × 2.934 = 0.745 ns  (theoretical)
Actual in-system                                  = 7.115 ns
Ratio (actual / theoretical)                      = 9.55×  off
```

**Hierarchical CLA:**
```
TCLA = 2 × 0.124 × (1 + 1.934) = 0.248 × 2.934 = 0.728 ns  (theoretical)
Actual in-system                                  = 2.558 ns
Ratio (actual / theoretical)                      = 3.51×  off
```

The hierarchical CLA closes the gap from 9.55× to 3.51× off the theoretical minimum. The remaining gap has three sources:

**Structural precondition not met for flat CLA.** The formula assumes true 2-level logic. With 13 serial LUT levels the carry is still rippling — the lower bound does not apply.

**Route delay not in the formula.** Each LUT-to-LUT hop on an unplaced design contributes ~0.449–1.122 ns not captured by `tgate`.

**Wide AND terms exceed LUT fan-in.** The fully expanded carry for bit 32 contains a 33-input AND term. With LUT6 fan-in of 6 this decomposes into `ceil(log6(32)) = 2` additional LUT levels per wide AND gate.

---

## Maximum Operating Frequency and Throughput

### Fmax Calculation

```
Combinational designs:
  Fmax = 1 / (Tpd_in_system + Tsetup + Tco)
  Register overhead (7-series): Tsetup = 0.058 ns, Tco = 0.456 ns → 0.514 ns total

Pipelined design:
  Fmax = 1 / (Tperiod - WNS) = 1 / (10.000 - 7.184) = 355 MHz
```

### Full Comparison

| Design | Type | In-System Delay | Fmax | Comb. Throughput | Reg. Throughput | Latency |
|---|---|---|---|---|---|---|
| `ripplecarry_adder.vhd` | Combinational | 8.911 ns | 106 MHz | 112 M/sec | 106 M/sec | Tpd |
| `ripplecarry_gen_adder.vhd` | Combinational | 8.911 ns | 106 MHz | 112 M/sec | 106 M/sec | Tpd |
| `cla_flat_adder.vhd` | Combinational | 7.115 ns | 131 MHz | 141 M/sec | 131 M/sec | Tpd |
| `cla_hier_adder.vhd` | Combinational | 2.558 ns | 326 MHz | 391 M/sec | 326 M/sec | Tpd |
| `adder.vhd` | Combinational | 1.766 ns | 438 MHz | 566 M/sec | 438 M/sec | Tpd |
| `pipelined_adder.vhd` | Registered 3-stage | 2.712 ns* | **355 MHz** | — | **355 M/sec** | 3 cycles |

*Register-to-register path delay.

### Performance Progression

```
ripplecarry_adder.vhd     106 MHz  ████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
ripplecarry_gen_adder.vhd 106 MHz  ████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
cla_flat_adder.vhd        131 MHz  █████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
cla_hier_adder.vhd        326 MHz  █████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
pipelined_adder.vhd       355 MHz  ██████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
adder.vhd (CARRY4)        438 MHz  █████████████████░░░░░░░░░░░░░░░░░░░░░░░░░░
```

### Pipelined Adder — Latency vs Throughput

```
Pipeline depth : 3 stages
Latency        : 3 cycles = 30.0 ns at 100 MHz  /  8.5 ns at Fmax (355 MHz)
Throughput     : 1 result per cycle once pipeline full = Fmax
WNS            : 7.184 ns  (design over-constrained at 100 MHz)
WHS            : 0.152 ns  (tightest hold — direct FF-to-FF, zero logic)
```

Pipelining does not reduce per-operation latency — it increases it from 1 propagation delay to 3 clock cycles. The benefit is that throughput equals Fmax regardless of pipeline depth, because a new result emerges every cycle once the pipeline is filled.

---

## Key Observations

**RTL abstraction defeats primitive inference.** The synthesiser infers CARRY4 by pattern-matching on carry-propagate-generate structures. Wrapping full adder logic in a function that returns `std_logic_vector` obscures this pattern. The tool sees two independent logic cones and falls back to a serial LUT chain.

**Generate vs function makes no difference.** Both are RTL abstractions that collapse to identical netlists after elaboration. The metric is whether the resulting equations match the tool's carry inference pattern.

**Loop-based CLA is structurally identical to RCA.** A generate loop that accumulates carry through a variable is a ripple carry adder regardless of explicit P and G signals. The serial data dependency survives synthesis.

**True CLA requires explicit parallel equations.** Every carry equation must reference only `g_i`, `p_i`, and `cin` — never another carry signal. The moment `c_i(j)` appears on the right-hand side, the lookahead property is broken.

**Route delay is the carry chain diagnostic.** Route delay above 50% indicates carry in general routing. Logic-dominated delay (~70–80%) indicates dedicated routing or true parallel logic. Use `report_design_analysis -logic_level_distribution` to assess across all paths.

**Fewer logic levels does not mean faster.** The hierarchical CLA has 4 LUT levels vs 12 for CARRY4 — yet CARRY4 wins by 45% because dedicated routing eliminates inter-stage route delay entirely (0.000 ns between CARRY4 stages).

**CARRY4 vs CARRY8.** These experiments target 7-series (CARRY4, 4-bit, 9 instances for 32 bits). On UltraScale+ (Kria KV260) the equivalent is CARRY8 — 8 bits per primitive, 4 instances for 32 bits — with corresponding timing improvement. The `+` operator infers CARRY8 automatically on UltraScale+ targets.

**Hold slack requires attention in pipelined designs.** The direct FF-to-FF path in the pipelined adder (r1→s1, zero logic levels) shows WHS = 0.152 ns. No combinational logic between registers means no added hold margin. This needs floorplanning care at higher frequencies.

---

## Trade-Off Summary

| Requirement | Recommended Design |
|---|---|
| Maximum Fmax, known Xilinx target | `adder.vhd` — `+` operator |
| High throughput in clocked system | `pipelined_adder.vhd` |
| Vendor-portable IP, ASIC + FPGA | Explicit RCA with P/G signals |
| True CLA, portable, no primitive dependency | `cla_hier_adder.vhd` |
| Carry save / Wallace tree multiplier | Explicit structural RTL |
| Mid-chain pipeline register insertion | Explicit structural RTL |
| Observability via ILA or simulation | Named carry signals (any explicit RTL) |
| Formal verification / DO-254 audit trail | Explicit structural RTL |
| Low latency, single-cycle result | Any combinational design |

---

## Vivado Commands Reference

```tcl
# Full critical path with per-cell delay breakdown
report_timing -from [all_inputs] -to [all_outputs] -verbose

# Logic vs route delay split, top 5 worst paths
report_timing -nworst 5 -path_type short

# Logic level histogram across all paths in the design
report_design_analysis -logic_level_distribution

# Resource utilisation
report_utilization

# Cell propagation delay for the target device and speed grade
report_datasheet

# High fanout nets — important for clocks, resets, enables
report_high_fanout_nets

# Timing summary for registered designs (WNS, TNS, WHS, THS)
report_timing_summary

# CDC check — relevant when extending to multi-clock designs
report_cdc
```