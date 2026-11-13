`timescale 1ns / 1ps

module alu (
    input  wire [31:0] A,
    input  wire [31:0] B,
    input  wire [2:0]  ALUControl,

    output reg  [31:0] Result,
    output wire        Zero,
    output wire        Equal      // A == B, carry-free (used by BEQ/BNE)
);

    // ALU operation codes
    localparam ALU_ADD    = 3'b000;
    localparam ALU_SUB    = 3'b001;
    localparam ALU_AND    = 3'b010;
    localparam ALU_OR     = 3'b011;
    localparam ALU_SLT    = 3'b100;
    localparam ALU_PASS_B = 3'b101;

    always @(*) begin

        case (ALUControl)

            ALU_ADD:
                Result = A + B;

            ALU_SUB:
                Result = A - B;

            ALU_AND:
                Result = A & B;

            ALU_OR:
                Result = A | B;

            ALU_SLT:
                Result = ($signed(A) < $signed(B)) ? 32'd1 : 32'd0;

            ALU_PASS_B:
                Result = B;

            default:
                Result = 32'b0;

        endcase

    end

    // Zero flag
    assign Zero = (Result == 32'b0);

    // BEQ/BNE only need (A - B == 0), i.e. A == B.  Comparing the operands
    // directly removes the 32-bit subtract carry chain from the branch path.
    assign Equal = (A == B);

endmodule