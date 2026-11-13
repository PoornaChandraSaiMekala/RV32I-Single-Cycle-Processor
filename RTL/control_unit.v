`timescale 1ns / 1ps

module control_unit (
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    input  wire [6:0] funct7,

    output reg        InstructionValid,

    output reg        RegWrite,
    output reg        ALUSrc,
    output reg        MemRead,
    output reg        MemWrite,
    output reg        Branch,
    output reg        Jump,

    output reg [1:0]  WBSelect,
    output reg [2:0]  ImmType,
    output reg [1:0]  ALUOp
);

    // Immediate encodings must match immediate_generator.v.
    localparam IMM_I = 3'b000;
    localparam IMM_S = 3'b001;
    localparam IMM_B = 3'b010;
    localparam IMM_J = 3'b011;
    localparam IMM_U = 3'b100;

    localparam WB_ALU = 2'b00;
    localparam WB_MEM = 2'b01;
    localparam WB_PC4 = 2'b10;

    localparam ALUOP_ADD   = 2'b00;
    localparam ALUOP_SUB   = 2'b01;
    localparam ALUOP_RTYPE = 2'b10;
    localparam ALUOP_LUI   = 2'b11;

    // One decode point performs both instruction legality checking
    // and control generation. Unsupported encodings retain safe controls.
    always @(*) begin
        InstructionValid = 1'b0;

        RegWrite = 1'b0;
        ALUSrc   = 1'b0;
        MemRead  = 1'b0;
        MemWrite = 1'b0;
        Branch   = 1'b0;
        Jump     = 1'b0;

        WBSelect = WB_ALU;
        ImmType  = IMM_I;
        ALUOp    = ALUOP_ADD;

        case (opcode)

            // R-type: ADD, SUB, AND, OR, SLT only.
            7'b0110011: begin
                case ({funct7, funct3})
                    {7'b0000000, 3'b000},
                    {7'b0100000, 3'b000},
                    {7'b0000000, 3'b111},
                    {7'b0000000, 3'b110},
                    {7'b0000000, 3'b010}: begin
                        InstructionValid = 1'b1;
                        RegWrite = 1'b1;
                        ALUOp = ALUOP_RTYPE;
                    end
                    default: begin
                        // Safe defaults.
                    end
                endcase
            end

            // ADDI
            7'b0010011: begin
                if (funct3 == 3'b000) begin
                    InstructionValid = 1'b1;
                    RegWrite = 1'b1;
                    ALUSrc = 1'b1;
                    ALUOp = ALUOP_ADD;
                    ImmType = IMM_I;
                end
            end

            // LW
            7'b0000011: begin
                if (funct3 == 3'b010) begin
                    InstructionValid = 1'b1;
                    RegWrite = 1'b1;
                    ALUSrc = 1'b1;
                    MemRead = 1'b1;
                    ALUOp = ALUOP_ADD;
                    ImmType = IMM_I;
                    WBSelect = WB_MEM;
                end
            end

            // SW
            7'b0100011: begin
                if (funct3 == 3'b010) begin
                    InstructionValid = 1'b1;
                    ALUSrc = 1'b1;
                    MemWrite = 1'b1;
                    ALUOp = ALUOP_ADD;
                    ImmType = IMM_S;
                end
            end

            // BEQ / BNE
            7'b1100011: begin
                if ((funct3 == 3'b000) || (funct3 == 3'b001)) begin
                    InstructionValid = 1'b1;
                    Branch = 1'b1;
                    ALUOp = ALUOP_SUB;
                    ImmType = IMM_B;
                end
            end

            // JAL: preserve the existing opcode-only validity rule.
            7'b1101111: begin
                InstructionValid = 1'b1;
                RegWrite = 1'b1;
                Jump = 1'b1;
                ImmType = IMM_J;
                WBSelect = WB_PC4;
            end

            // LUI: preserve the existing opcode-only validity rule.
            7'b0110111: begin
                InstructionValid = 1'b1;
                RegWrite = 1'b1;
                ALUSrc = 1'b1;
                ALUOp = ALUOP_LUI;
                ImmType = IMM_U;
                WBSelect = WB_ALU;
            end

            default: begin
                // Unsupported opcode: safe defaults.
            end
        endcase
    end
endmodule
