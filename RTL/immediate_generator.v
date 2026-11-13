`timescale 1ns / 1ps

module immediate_generator (
    input  wire [31:0] instruction,
    input  wire [2:0]  ImmType,

    output reg  [31:0] immediate
);

    // Immediate type definitions
    localparam IMM_I = 3'b000;
    localparam IMM_S = 3'b001;
    localparam IMM_B = 3'b010;
    localparam IMM_J = 3'b011;
    localparam IMM_U = 3'b100;

    always @(*) begin

        case (ImmType)

            // ----------------------------------------
            // I-Type
            // ADDI, LW
            // ----------------------------------------

            IMM_I: begin

                immediate = {
                    {20{instruction[31]}},
                    instruction[31:20]
                };

            end

            // ----------------------------------------
            // S-Type
            // SW
            // ----------------------------------------

            IMM_S: begin

                immediate = {
                    {20{instruction[31]}},
                    instruction[31:25],
                    instruction[11:7]
                };

            end

            // ----------------------------------------
            // B-Type
            // BEQ, BNE
            // ----------------------------------------

            IMM_B: begin

                immediate = {
                    {19{instruction[31]}},
                    instruction[31],
                    instruction[7],
                    instruction[30:25],
                    instruction[11:8],
                    1'b0
                };

            end

            // ----------------------------------------
            // J-Type
            // JAL
            // ----------------------------------------

            IMM_J: begin

                immediate = {
                    {11{instruction[31]}},
                    instruction[31],
                    instruction[19:12],
                    instruction[20],
                    instruction[30:21],
                    1'b0
                };

            end

            // ----------------------------------------
            // U-Type
            // LUI
            // ----------------------------------------

            IMM_U: begin

                immediate = {
                    instruction[31:12],
                    12'b0
                };

            end

            // ----------------------------------------
            // Default
            // ----------------------------------------

            default: begin

                immediate = 32'b0;

            end

        endcase

    end

endmodule