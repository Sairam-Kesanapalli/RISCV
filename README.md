# 🏛️ Progressive RISC-V Processor Architectures

Welcome to the **RISC-V Workspace**—a progressive showcase of RISC-V computer architectures implemented in synthesizable Verilog. This repository serves as both a pedagogical pathway and a rigorous engineering demonstration, tracking the evolution of a CPU from a simple **Single-Cycle RV32I** to a high-performance **5-Stage Pipelined RV32IM** processor.

Each implementation is fully self-contained with its own testbenches, cycle-accurate Python co-simulation models, and automated build scripts.

---

## 🗺️ Architectural Roadmap & Workspace Structure

The workspace is organized into four progressive tiers of processor complexity:

1. **[Single-Cycle RV32I Base](file:///home/Sairam/Documents/Cutout/RISCV/RISCV_RV32I_Single_Cycle)**
   - **Concepts**: Combinational control, direct data paths, and single-cycle retirement.
   - **Purpose**: Ideal teaching vehicle demonstrating the baseline RV32I ISA datapath without scheduling overhead.
2. **[Multi-Cycle RV32I Base](file:///home/Sairam/Documents/Cutout/RISCV/RISCV_RV32I_Multi_cycle)**
   - **Concepts**: Finite State Machine (FSM) control (3–5 cycles per instruction), shared hardware resources (single ALU/memory).
   - **Purpose**: Reduces critical path delay compared to single-cycle by time-multiplexing hardware.
3. **[Multi-Cycle RV32IM with M-Extension](file:///home/Sairam/Documents/Cutout/RISCV/RISCV_RV32IM_Multi_Cycle)**
   - **Concepts**: Iterative 32-cycle hardware multiplier and restoring divider integration, dynamic FSM stalling.
   - **Purpose**: Introduces hardware acceleration for multiplication and division within a resource-shared architecture.
4. **[5-Stage Pipelined RV32IM Core](file:///home/Sairam/Documents/Cutout/RISCV/RISCV_RV32IM_Pipelined)** *(Flagship)*
   - **Concepts**: 5-stage spatial pipelining (`IF`, `ID`, `EX`, `MEM`, `WB`), hazard detection, EX-to-EX and MEM-to-EX forwarding, load-use stalls, branch control flushes.
   - **Purpose**: Represents the pinnacle of performance and complexity in this workspace, featuring full sub-word access (`LB`/`LH`/`LHU`/`SB`/`SH`) with byte enables and robust cycle-by-cycle register/memory validation.

---

## 📊 Architectural Comparison Matrix

| Specification | Single-Cycle RV32I | Multi-Cycle RV32I | Multi-Cycle RV32IM | Pipelined RV32IM (Flagship) |
| :--- | :---: | :---: | :---: | :---: |
| **ISA Subset** | RV32I (Base) | RV32I (Base) | RV32IM (Base + Math) | **RV32IM** (Base + Math) |
| **Execution Architecture** | Single-cycle datapath | 3–5 Cycle FSM | 3–35 Cycle FSM | **5-Stage Spatial Pipeline** |
| **Instruction Cache/Memory** | Word-addressed ROM | Word-addressed ROM | Runtime Hex-injected ROM | **Runtime Hex-injected ROM** |
| **Data Memory Interface** | Word-Aligned (LW/SW) | Word-Aligned (LW/SW) | Word-Aligned (LW/SW) | **Byte-Enabled (LB/LH/LHU/SB/SH/LW/SW)** |
| **Branch Penalty** | 0 cycles | 0 extra cycles | 0 extra cycles | **2 cycles (Instruction Flush)** |
| **Load-Use Penalty** | 0 cycles | 0 extra cycles | 0 extra cycles | **1 cycle (Pipeline Stall)** |
| **M-Extension Acceleration** | N/A | N/A | Iterative 32-cycle (`mul_div.v`) | **Iterative 32-cycle (`mul_div.v`)** |
| **Average CPI** | 1.00 | 3.00 – 5.00 | 3.00 – 37.00 | **~1.00 (Ideal) / ~1.15 (Typical)** |
| **Verification Method** | Main Testbench | Co-Simulation SVT / Python ISS | Co-Simulation SVT / Python ISS | **Co-Simulation SVT / Python ISS + Regressions** |
| **GitHub Actions CI** | No | Yes | Yes | **Yes (Full Regression Suite)** |

---

## 🔍 Verification & Testing Philosophy

To ensure absolute functional correctness across design changes (e.g. refactoring or adding instructions), the multi-cycle and pipelined designs employ a state-of-the-art **Software Verification Testbench (SVT)** framework:

```
                  ┌──────────────────────┐
                  │  Assembly/Hex Test   │
                  └──────────┬───────────┘
                             │
              ┌──────────────┴──────────────┐
              ▼                             ▼
   ┌────────────────────┐        ┌────────────────────┐
   │ Python Golden Model│        │ Verilog RTL (RTL)  │
   │ (Instruction Set   │        │ (Simulated via     │
   │  Simulator / ISS)  │        │  Icarus Verilog)   │
   └──────────┬─────────┘        └──────────┬─────────┘
              │                             │
              ▼ (Auto-Generates)            ▼
     expected_regs.hex                      │
     expected_mem.hex                       │
     expected_pc.hex                        │
              │                             │
              └──────────────┬──────────────┘
                             ▼
                 ┌──────────────────────┐
                 │  svt_tb.v (Asserts)  │  ◄── Cycle-by-cycle co-simulation assertion
                 └──────────┬───────────┘
                            │
               ┌────────────┴────────────┐
               ▼                         ▼
         [SVT PASS]                [SVT FAIL]
```

### Key Framework Capabilities
- **Cycle-Accurate ISS**: The Python-based Instruction Set Simulator matches the exact cycle behavior of the target Verilog implementation (including FSM cycles or pipeline stall sequences).
- **Categorized Regressions**: Automated testing tracks specific operations: `R-Type`, `I-Type`, `U-Type`, `J-Type`, `Mul`, `Div`, and complex arithmetic `Edge_Cases` (e.g., dividing by zero or signed overflows).
- **Strict CI Pipelines**: GitHub Actions compile the Verilog source, run the golden simulator, perform the hardware simulations, and fail/pass the PR/commit using exit-status matching.

---

## 🚀 Workspace Quick Start

### 📋 Prerequisites
You will need `iverilog`, `python3`, and `make` on a Unix/Linux environment:
```bash
sudo apt-get update
sudo apt-get install -y iverilog python3 make
```

### 🛠️ Compilation and Run Guide

Each core is self-contained. Navigate to any subdirectory to run its respective simulation:

```bash
# Example: Running co-simulation on the Pipelined RV32IM processor
cd RISCV_RV32IM_Pipelined

# Run a co-simulation sanity program
make svt

# Run the complete categorized regression suite (7 test folders)
make regression

# Clean all generated binary and waveform artifacts
make clean
```

---

## 📜 License
This workspace is released under the **MIT License**. See individual directories for licensing details.
