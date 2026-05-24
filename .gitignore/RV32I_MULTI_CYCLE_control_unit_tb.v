`timescale 1ps/1ps

module control_unit_tb;

reg clk;
reg rst_n;
reg [6:0] op_code;
reg branch_taken;
reg is_busy;
reg alu_done;

wire PCWrite;
wire IRWrite;
wire RegWrite;
wire MemRead;
wire MemWrite;
wire Branch;
wire Jump;
wire [1:0] ALUSrcA_ctrl;
wire [1:0] ALUSrcB_ctrl;
wire [1:0] PCSource_ctrl;
wire MemToReg;
wire [2:0] ALU_OP;

control_unit cu (
    .clk(clk),
    .rst_n(rst_n),
    .op_code(op_code),
    .branch_taken(branch_taken),
    .is_busy(is_busy),
    .alu_done(alu_done),
    .PCWrite(PCWrite),
    .IRWrite(IRWrite),
    .RegWrite(RegWrite),
    .MemRead(MemRead),
    .MemWrite(MemWrite),
    .Branch(Branch),
    .Jump(Jump),
    .ALUSrcA_ctrl(ALUSrcA_ctrl),
    .ALUSrcB_ctrl(ALUSrcB_ctrl),
    .PCSource_ctrl(PCSource_ctrl),
    .MemToReg(MemToReg),
    .ALU_OP(ALU_OP)
);

// Clock Generation
always #5 clk = ~clk;

// Task to verify combinational outputs at any active state
task check_outputs(
    input [3:0] state_id,
    input exp_PCWrite, exp_IRWrite, exp_RegWrite, exp_MemRead, exp_MemWrite, exp_Branch, exp_Jump,
    input [1:0] exp_ALUSrcA, input [1:0] exp_ALUSrcB, input [1:0] exp_PCSource,
    input exp_MemToReg, input [2:0] exp_ALU_OP
);
    begin
        #1; // Let outputs settle
        if (
            (PCWrite === exp_PCWrite) &&
            (IRWrite === exp_IRWrite) &&
            (RegWrite === exp_RegWrite) &&
            (MemRead === exp_MemRead) &&
            (MemWrite === exp_MemWrite) &&
            (Branch === exp_Branch) &&
            (Jump === exp_Jump) &&
            (ALUSrcA_ctrl === exp_ALUSrcA) &&
            (ALUSrcB_ctrl === exp_ALUSrcB) &&
            (PCSource_ctrl === exp_PCSource) &&
            (MemToReg === exp_MemToReg) &&
            (ALU_OP === exp_ALU_OP)
        ) begin
            $display("[PASS] State %0d control signals match expected for opcode 7'b%07b", state_id, op_code);
        end else begin
            $display("[FAIL] State %0d mismatch for opcode 7'b%07b!", state_id, op_code);
            $display("       PCWrite:  exp=%b, got=%b", exp_PCWrite, PCWrite);
            $display("       IRWrite:  exp=%b, got=%b", exp_IRWrite, IRWrite);
            $display("       RegWrite: exp=%b, got=%b", exp_RegWrite, RegWrite);
            $display("       MemRead:  exp=%b, got=%b", exp_MemRead, MemRead);
            $display("       MemWrite: exp=%b, got=%b", exp_MemWrite, MemWrite);
            $display("       Branch:   exp=%b, got=%b", exp_Branch, Branch);
            $display("       Jump:     exp=%b, got=%b", exp_Jump, Jump);
            $display("       ALUSrcA:  exp=%b, got=%b", exp_ALUSrcA, ALUSrcA_ctrl);
            $display("       ALUSrcB:  exp=%b, got=%b", exp_ALUSrcB, ALUSrcB_ctrl);
            $display("       PCSource: exp=%b, got=%b", exp_PCSource, PCSource_ctrl);
            $display("       MemToReg: exp=%b, got=%b", exp_MemToReg, MemToReg);
            $display("       ALU_OP:   exp=%d, got=%d", exp_ALU_OP, ALU_OP);
        end
        #1;
    end
endtask

// Task to reset FSM
task reset_fsm;
    begin
        rst_n = 0;
        @(posedge clk);
        #1;
        rst_n = 1;
        #1; // Settle in the new cycle well before next clock edge
    end
endtask

initial begin
    $dumpfile("control_unit.vcd");                  
    $dumpvars(0, control_unit_tb);             
end

initial begin
    clk = 0;
    rst_n = 0;
    op_code = 0;
    branch_taken = 0;
    is_busy = 0;
    alu_done = 0;
    
    #10;
    
    // =========================================================================
    // 1. R-TYPE / MUL (7'b0110011)
    // =========================================================================
    $display("\n--- Testing R-Type / MUL (7'b0110011) ---");
    op_code = 7'b0110011;
    alu_done = 1;
    reset_fsm(); // Enter FETCH
    check_outputs(0,  0, 1, 0, 0, 0, 0, 0,  2'b00, 2'b00, 2'b00,  0, 3'd0); // FETCH
    
    @(posedge clk); // Transition to DECODE
    check_outputs(1,  0, 0, 0, 0, 0, 0, 0,  2'b00, 2'b10, 2'b00,  0, 3'd3); // DECODE
    
    @(posedge clk); // Transition to EXEC_R_OR_MUL
    check_outputs(2,  0, 0, 0, 0, 0, 0, 0,  2'b01, 2'b00, 2'b00,  0, 3'd2); // EXEC_R_OR_MUL
    
    @(posedge clk); // Transition to PC_INC
    check_outputs(11, 1, 0, 1, 0, 0, 0, 0,  2'b00, 2'b01, 2'b00,  0, 3'd3); // PC_INC

    // =========================================================================
    // 2. I-TYPE (7'b0010011)
    // =========================================================================
    $display("\n--- Testing I-Type (7'b0010011) ---");
    op_code = 7'b0010011;
    reset_fsm(); // Enter FETCH
    check_outputs(0,  0, 1, 0, 0, 0, 0, 0,  2'b00, 2'b00, 2'b00,  0, 3'd0); // FETCH
    
    @(posedge clk); // Transition to DECODE
    check_outputs(1,  0, 0, 0, 0, 0, 0, 0,  2'b00, 2'b10, 2'b00,  0, 3'd3); // DECODE
    
    @(posedge clk); // Transition to EXEC_I
    check_outputs(3,  0, 0, 0, 0, 0, 0, 0,  2'b01, 2'b10, 2'b00,  0, 3'd0); // EXEC_I
    
    @(posedge clk); // Transition to PC_INC
    check_outputs(11, 1, 0, 1, 0, 0, 0, 0,  2'b00, 2'b01, 2'b00,  0, 3'd3); // PC_INC

    // =========================================================================
    // 3. LW (Load - 7'b0000011)
    // =========================================================================
    $display("\n--- Testing LW (7'b0000011) ---");
    op_code = 7'b0000011;
    reset_fsm(); // Enter FETCH
    check_outputs(0,  0, 1, 0, 0, 0, 0, 0,  2'b00, 2'b00, 2'b00,  0, 3'd0); // FETCH
    
    @(posedge clk); // DECODE
    check_outputs(1,  0, 0, 0, 0, 0, 0, 0,  2'b00, 2'b10, 2'b00,  0, 3'd3); // DECODE
    
    @(posedge clk); // Transition to MEM_ADDR
    check_outputs(4,  0, 0, 0, 0, 0, 0, 0,  2'b01, 2'b10, 2'b00,  0, 3'd3); // MEM_ADDR
    
    @(posedge clk); // Transition to MEM_READ
    check_outputs(5,  0, 0, 0, 1, 0, 0, 0,  2'b00, 2'b00, 2'b00,  0, 3'd0); // MEM_READ
    
    @(posedge clk); // Transition to MEM_WB
    check_outputs(6,  1, 0, 1, 0, 0, 0, 0,  2'b00, 2'b01, 2'b00,  1, 3'd3); // MEM_WB

    // =========================================================================
    // 4. SW (Store - 7'b0100011)
    // =========================================================================
    $display("\n--- Testing SW (7'b0100011) ---");
    op_code = 7'b0100011;
    reset_fsm(); // Enter FETCH
    check_outputs(0,  0, 1, 0, 0, 0, 0, 0,  2'b00, 2'b00, 2'b00,  0, 3'd0); // FETCH
    
    @(posedge clk); // DECODE
    check_outputs(1,  0, 0, 0, 0, 0, 0, 0,  2'b00, 2'b10, 2'b00,  0, 3'd3); // DECODE
    
    @(posedge clk); // Transition to MEM_ADDR
    check_outputs(4,  0, 0, 0, 0, 0, 0, 0,  2'b01, 2'b10, 2'b00,  0, 3'd3); // MEM_ADDR
    
    @(posedge clk); // Transition to MEM_WRITE
    check_outputs(7,  1, 0, 0, 0, 1, 0, 0,  2'b00, 2'b01, 2'b00,  0, 3'd3); // MEM_WRITE

    // =========================================================================
    // 5. BEQ (Branch - 7'b1100011)
    // =========================================================================
    $display("\n--- Testing BEQ (7'b1100011) ---");
    op_code = 7'b1100011;
    branch_taken = 1;
    reset_fsm(); // Enter FETCH
    check_outputs(0,  0, 1, 0, 0, 0, 0, 0,  2'b00, 2'b00, 2'b00,  0, 3'd0); // FETCH
    
    @(posedge clk); // DECODE
    check_outputs(1,  0, 0, 0, 0, 0, 0, 0,  2'b00, 2'b10, 2'b00,  0, 3'd3); // DECODE
    
    @(posedge clk); // Transition to BRANCH_EX (taken)
    check_outputs(8,  1, 0, 0, 0, 0, 1, 0,  2'b01, 2'b00, 2'b01,  0, 3'd1); // BRANCH_EX (taken)

    // =========================================================================
    // 6. JAL (7'b1101111)
    // =========================================================================
    $display("\n--- Testing JAL (7'b1101111) ---");
    op_code = 7'b1101111;
    reset_fsm(); // Enter FETCH
    check_outputs(0,  0, 1, 0, 0, 0, 0, 0,  2'b00, 2'b00, 2'b00,  0, 3'd0); // FETCH
    
    @(posedge clk); // DECODE
    check_outputs(1,  0, 0, 0, 0, 0, 0, 0,  2'b00, 2'b01, 2'b00,  0, 3'd3); // DECODE
    
    @(posedge clk); // Transition to JUMP_EX
    check_outputs(9,  1, 0, 1, 0, 0, 0, 1,  2'b00, 2'b10, 2'b00,  0, 3'd3); // JUMP_EX

    $finish;
end

endmodule
