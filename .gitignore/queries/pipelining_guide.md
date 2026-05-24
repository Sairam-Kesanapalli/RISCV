# Transitioning from Multi-Cycle to Pipelined RISC-V (RV32IM)

This guide details how to restructure the multi-cycle design in [`rv32im_multi_cycle.v`](file:///home/Sairam/Documents/Cutout/RISC/RISCV_RV32IM_Multi_Cycle/src/core/rv32im_multi_cycle.v) into a classic **5-stage pipeline** (IF, ID, EX, MEM, WB). 

For this guide, we assume **hazard control** (stalls, forwarding, flushing) is kept aside, focusing strictly on the structural transformation of the datapath and control unit.

---

## 1. Paradigm Shift: Temporal FSM vs. Spatial Pipelining

In your **multi-cycle** core:
* A single instruction occupies the entire processor at any given time.
* A **State Machine (FSM)** in the control unit coordinates step-by-step execution over multiple clock cycles.
* Control signals (e.g., `RegWrite`, `MemRead`, `MemWrite`) change dynamically cycle-by-cycle for that single active instruction.

In a **pipelined** core:
* **Five different instructions** exist in the datapath simultaneously, each at a different stage of execution.
* The control unit is **completely combinational**. It decodes the instruction in the **Decode (ID)** stage, generating all control signals immediately.
* These control signals are bundled and "flow" alongside the instruction through sequential **Pipeline Registers** to trigger actions in later stages.

---

## 2. Structural Changes: Step-by-Step

To transition the hardware, follow these six primary steps:

### Step 1: Remove the FSM & Redesign the Control Unit
* **Delete the sequential FSM** from `control_unit.v`.
* Make the control unit **purely combinational**. As soon as the opcode is decoded in the **ID** stage, it must output all control signals for that instruction.
* Separate these control signals into groups based on the stage where they are consumed:
  * **Execute (EX) Signals:** `ALU_OP`, `ALUSrcA`, `ALUSrcB`, `is_mul_div`
  * **Memory (MEM) Signals:** `MemRead`, `MemWrite`, `Branch`, `Jump`
  * **Write-Back (WB) Signals:** `MemToReg`, `RegWrite`

### Step 2: Add Dedicated Hardware to Resolve Resource Conflicts
In multi-cycle, you share a single ALU to save area (using it for PC incrementing, target calculation, and main arithmetic). In a pipeline, since multiple instructions run at once, they will conflict.
1. **PC + 4 Adder:** Add a dedicated combinational adder in the **IF** stage:
   ```verilog
   wire [31:0] PC_plus_4 = PC + 4;
   ```
2. **Branch/Jump Target Adder:** Add a dedicated combinational adder in the **ID** or **EX** stage to calculate relative offsets:
   ```verilog
   wire [31:0] target_address = PC_stage_val + imm_out;
   ```
3. **Main ALU:** Restrict the main ALU to only execute arithmetic/logical instructions and address calculations (for load/store) in the **EX** stage.

### Step 3: Replace State Registers with Pipeline Registers
Delete your existing multi-cycle state registers (`IR`, `MDR`, `A`, `B`, `ALUOut`). In their place, insert four pipeline registers to act as boundaries between stages. 

These registers are updated on every `posedge clk`:

```mermaid
graph LR
    IF[Fetch] -->|IF/ID| ID[Decode]
    ID -->|ID/EX| EX[Execute]
    EX -->|EX/MEM| MEM[Memory]
    MEM -->|MEM/WB| WB[Write-back]
```

#### A. IF/ID Pipeline Register (Fetch $\rightarrow$ Decode)
Carries the instruction and its PC address to the decode stage.
```verilog
reg [31:0] if_id_pc;
reg [31:0] if_id_instr;

always @(posedge clk) begin
    if (!rst_n) begin
        if_id_pc    <= 32'b0;
        if_id_instr <= 32'h00000013; // NOP (addi x0, x0, 0)
    end else begin
        if_id_pc    <= PC;
        if_id_instr <= mem_instr;
    end
end
```

#### B. ID/EX Pipeline Register (Decode $\rightarrow$ Execute)
Carries registers read data, immediate, register addresses, PC, and control signals.
```verilog
// Control signals
reg        id_ex_RegWrite, id_ex_MemToReg;
reg        id_ex_MemRead, id_ex_MemWrite, id_ex_Branch, id_ex_Jump;
reg [2:0]  id_ex_ALU_OP;
reg        id_ex_ALUSrcA, id_ex_ALUSrcB; // modified to 1-bit or kept depending on your MUXes

// Datapath values
reg [31:0] id_ex_pc;
reg [31:0] id_ex_read_data1;
reg [31:0] id_ex_read_data2;
reg [31:0] id_ex_imm;
reg [4:0]  id_ex_rs1;
reg [4:0]  id_ex_rs2;
reg [4:0]  id_ex_rd; // CRITICAL: must carry destination register address
reg [2:0]  id_ex_funct3;
reg [6:0]  id_ex_funct7;
```

#### C. EX/MEM Pipeline Register (Execute $\rightarrow$ Memory)
Carries ALU/multiplier output, write data for store instructions, target address, and memory/writeback controls.
```verilog
// Control signals
reg        ex_mem_RegWrite, ex_mem_MemToReg;
reg        ex_mem_MemRead, ex_mem_MemWrite, ex_mem_Branch, ex_mem_Jump;

// Datapath values
reg [31:0] ex_mem_alu_result;
reg [31:0] ex_mem_write_data; // Holds rs2 register contents to write to memory
reg [4:0]  ex_mem_rd;
reg        ex_mem_zero;
```

#### D. MEM/WB Pipeline Register (Memory $\rightarrow$ Write-back)
Carries read data from memory, ALU output, and writeback controls.
```verilog
// Control signals
reg        mem_wb_RegWrite, mem_wb_MemToReg;

// Datapath values
reg [31:0] mem_wb_read_data;
reg [31:0] mem_wb_alu_result;
reg [4:0]  mem_wb_rd;
```

---

## 3. The Pipelined Datapath: Stage by Stage

Here is how the logic is distributed across the stages:

### 1. Instruction Fetch (IF)
* **Action:** Fetches the instruction from `instruction_memory` using `PC`.
* **PC Update:** Calculates `PC + 4` combinationaly.
* **Next PC Selection:** 
  ```verilog
  // Without hazard control, we check if a branch/jump is taken in EX or MEM stage
  assign PC_next = (take_branch_or_jump) ? target_address : (PC + 4);
  ```

### 2. Instruction Decode (ID)
* **Action:** 
  * Slices `if_id_instr` to get registers `rs1`, `rs2`, and `rd`.
  * Reads from the `register_file`.
  * Generates immediate `imm_out` using `imm_gen`.
  * Computes combinational control signals from the opcode.

### 3. Execute (EX)
* **Action:**
  * Performs arithmetic/logic operations using the `ALU` and `mul_div`.
  * Selects ALU inputs using MUXes based on `id_ex_ALUSrcA` and `id_ex_ALUSrcB`.
    * Input A: Selects between `id_ex_read_data1` and `id_ex_pc`.
    * Input B: Selects between `id_ex_read_data2` and `id_ex_imm`.
  * Passes the destination register `id_ex_rd` forward to `ex_mem_rd`.

### 4. Memory Access (MEM)
* **Action:**
  * Uses `ex_mem_alu_result` as the address for `data_mem`.
  * If `ex_mem_MemWrite` is high, writes `ex_mem_write_data` to memory.
  * If `ex_mem_MemRead` is high, reads data out from memory.
  * Passes `ex_mem_rd` forward to `mem_wb_rd`.

### 5. Write-Back (WB)
* **Action:**
  * Selects between the memory load output and the ALU output:
    ```verilog
    assign wb_write_data = (mem_wb_MemToReg) ? mem_wb_read_data : mem_wb_alu_result;
    ```
  * Writes `wb_write_data` back to the register file.

---

## 4. The Single Most Critical Pipelining Rule: Register Pipelining

> [!IMPORTANT]
> **You MUST carry the destination register address (`rd`) through every pipeline register.**
>
> In your multi-cycle design, you write back to the register file like this:
> ```verilog
> register_file rf(
>     .rd(rd), // Comes directly from IR (current instruction)
>     .write_data(write_data),
>     ...
> );
> ```
> In a pipelined design, when Instruction A is in the Write-Back (WB) stage, Instruction D is in the Decode (ID) stage. If you connect `rd` directly from the Decode stage, **Instruction A will write its output into Instruction D's destination register!**
>
> **The Fix:**
> Connect the write port of the register file to `mem_wb_rd`, and connect `reg_write` to `mem_wb_RegWrite`:
> ```verilog
> register_file rf(
>     .reg_write(mem_wb_RegWrite),
>     .rd(mem_wb_rd), // Comes from the instruction in WB stage!
>     .write_data(write_data),
>     ...
> );
> ```

---

## 5. Integrating the Multiplier/Divider (M-Extension)

Your design features a multi-cycle `mul_div` block:
```verilog
mul_div md(
    .clk(clk),
    .start(start),
    .Result(mul_div_result),
    .busy(busy),
    .done(done)
    ...
);
```

Since the multiplier takes multiple cycles to compute:
1. When a multiply instruction enters the **EX** stage, it asserts `start` and holds the pipeline in that stage.
2. Even without full hazard detection, you will need a structural stall to hold the **IF/ID**, **ID/EX** registers from updating, and prevent the **PC** from incrementing until `done` is asserted.
3. Once `done` goes high, the result `mul_div_result` is latched into the `EX/MEM` register, and the pipeline resumes normal flow.
