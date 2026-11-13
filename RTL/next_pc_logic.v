`timescale 1ns / 1ps

module next_pc_logic (
    input  wire [31:0] PC,
    input  wire [31:0] PCPlus4,

    input  wire        Branch,
    input  wire        BranchTaken,
    input  wire        Jump,

    input  wire [31:0] Immediate,

    output reg  [31:0] next_PC
);

    // ============================================================
    // NEXT PC LOGIC
    //
    // Priority:
    //
    // 1. JUMP
    // 2. TAKEN BRANCH
    // 3. NORMAL PC + 4
    // ============================================================

    always @(*) begin

        // Default: sequential execution
        next_PC = PCPlus4;

        // Unconditional jump
        if (Jump) begin
            next_PC = PC + Immediate;
        end

        // Conditional branch
        else if (Branch && BranchTaken) begin
            next_PC = PC + Immediate;
        end

    end

endmodule