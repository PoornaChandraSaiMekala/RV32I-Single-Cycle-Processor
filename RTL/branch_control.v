`timescale 1ns / 1ps

module branch_control (
    input  wire [2:0] funct3,
    input  wire       Branch,
    input  wire       Zero,

    output reg        BranchTaken
);

    // ============================================================
    // RISC-V BRANCH FUNCT3 VALUES
    // ============================================================

    localparam FUNCT3_BEQ = 3'b000;
    localparam FUNCT3_BNE = 3'b001;

    // ============================================================
    // BRANCH DECISION LOGIC
    // ============================================================

    always @(*) begin

        // Default: branch is not taken
        BranchTaken = 1'b0;

        if (Branch) begin

            case (funct3)

                // ------------------------------------------------
                // BEQ
                // Take branch when A == B
                // ------------------------------------------------

                FUNCT3_BEQ: begin
                    BranchTaken = Zero;
                end

                // ------------------------------------------------
                // BNE
                // Take branch when A != B
                // ------------------------------------------------

                FUNCT3_BNE: begin
                    BranchTaken = ~Zero;
                end

                // ------------------------------------------------
                // Unsupported branch type
                // ------------------------------------------------

                default: begin
                    BranchTaken = 1'b0;
                end

            endcase

        end

    end

endmodule