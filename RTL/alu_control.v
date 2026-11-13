`timescale 1ns / 1ps

module alu_control (
    input  wire [1:0] ALUOp,
    input  wire [2:0] funct3,
    input  wire [6:0] funct7,

    output reg  [2:0] ALUControl
);

    // ============================================================
    // ALU CONTROL CODES
    // Must match alu.v
    // ============================================================

    localparam ALU_ADD    = 3'b000;
    localparam ALU_SUB    = 3'b001;
    localparam ALU_AND    = 3'b010;
    localparam ALU_OR     = 3'b011;
    localparam ALU_SLT    = 3'b100;
    localparam ALU_PASS_B = 3'b101;

    // ============================================================
    // ALU OPERATION CLASSES
    // Must match control_unit.v
    // ============================================================

    localparam ALUOP_ADD   = 2'b00;
    localparam ALUOP_SUB   = 2'b01;
    localparam ALUOP_RTYPE = 2'b10;
    localparam ALUOP_LUI   = 2'b11;

    // ============================================================
    // ALU CONTROL LOGIC
    // ============================================================

    always @(*) begin

        // Safe default
        ALUControl = ALU_ADD;

        case (ALUOp)

            // ----------------------------------------------------
            // ADD
            // ADDI, LW, SW
            // ----------------------------------------------------

            ALUOP_ADD: begin
                ALUControl = ALU_ADD;
            end

            // ----------------------------------------------------
            // SUB
            // BEQ / BNE
            // ----------------------------------------------------

            ALUOP_SUB: begin
                ALUControl = ALU_SUB;
            end

            // ----------------------------------------------------
            // R-TYPE
            // ADD / SUB / AND / OR / SLT
            // ----------------------------------------------------

            ALUOP_RTYPE: begin

                case (funct3)

                    3'b000: begin
                        // ADD or SUB
                        if (funct7 == 7'b0100000)
                            ALUControl = ALU_SUB;
                        else
                            ALUControl = ALU_ADD;
                    end

                    3'b111: begin
                        // AND
                        ALUControl = ALU_AND;
                    end

                    3'b110: begin
                        // OR
                        ALUControl = ALU_OR;
                    end

                    3'b010: begin
                        // SLT
                        ALUControl = ALU_SLT;
                    end

                    default: begin
                        // Unsupported R-type function
                        ALUControl = ALU_ADD;
                    end

                endcase

            end

            // ----------------------------------------------------
            // LUI
            // ----------------------------------------------------

            ALUOP_LUI: begin
                ALUControl = ALU_PASS_B;
            end

            // ----------------------------------------------------
            // Default
            // ----------------------------------------------------

            default: begin
                ALUControl = ALU_ADD;
            end

        endcase

    end

endmodule