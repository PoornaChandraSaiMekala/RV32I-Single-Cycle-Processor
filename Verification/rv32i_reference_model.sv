`timescale 1ns / 1ps

module rv32i_reference_model #(
    parameter DEPTH = 256
)(
    input wire clk,
    input wire reset,

    // Expected architectural trace
    output reg        model_valid,
    output reg [31:0] model_pc,
    output reg [31:0] model_instruction,
    output reg [31:0] model_next_pc,

    output reg        model_reg_write,
    output reg [4:0]  model_rd,
    output reg [31:0] model_write_data,

    output reg        model_mem_write,
    output reg [31:0] model_mem_address,
    output reg [31:0] model_mem_write_data
);

    // =====================================================
    // ARCHITECTURAL STATE
    // =====================================================

    reg [31:0] registers [0:31];
    reg [31:0] instruction_mem [0:DEPTH-1];
    reg [31:0] data_mem [0:DEPTH-1];

    reg [31:0] pc;

    integer i;

    // =====================================================
    // INSTRUCTION FIELDS
    // =====================================================

    reg [6:0] opcode;
    reg [4:0] rd;
    reg [4:0] rs1;
    reg [4:0] rs2;
    reg [2:0] funct3;
    reg [6:0] funct7;

    // =====================================================
    // OPERANDS AND EXECUTION RESULTS
    // =====================================================

    reg [31:0] operand1;
    reg [31:0] operand2;
    reg [31:0] immediate;
    reg [31:0] alu_result;
    reg [31:0] next_pc;
    reg [31:0] writeback_data;

    reg reg_write;
    reg mem_write;

    // =====================================================
    // INSTRUCTION MEMORY INITIALIZATION
    // =====================================================

    initial begin
        for (i = 0; i < DEPTH; i = i + 1)
            instruction_mem[i] = 32'b0;

        $readmemh("program.mem", instruction_mem);
    end

    // =====================================================
    // INDEPENDENT INSTRUCTION EXECUTION MODEL
    // =====================================================

    always @(*) begin

        // Default values
        model_valid         = 1'b0;
        model_pc            = pc;
        model_instruction   = instruction_mem[pc[31:2]];
        model_next_pc       = pc + 32'd4;

        model_reg_write     = 1'b0;
        model_rd            = 5'd0;
        model_write_data    = 32'b0;

        model_mem_write     = 1'b0;
        model_mem_address   = 32'b0;
        model_mem_write_data = 32'b0;

        opcode = model_instruction[6:0];
        rd     = model_instruction[11:7];
        funct3 = model_instruction[14:12];
        rs1    = model_instruction[19:15];
        rs2    = model_instruction[24:20];
        funct7 = model_instruction[31:25];

        operand1 = (rs1 == 0) ? 32'b0 : registers[rs1];
        operand2 = (rs2 == 0) ? 32'b0 : registers[rs2];

        immediate = 32'b0;
        alu_result = 32'b0;
        next_pc = pc + 32'd4;
        writeback_data = 32'b0;

        reg_write = 1'b0;
        mem_write = 1'b0;

        // -------------------------------------------------
        // R-TYPE INSTRUCTIONS
        // -------------------------------------------------

        if (opcode == 7'b0110011) begin

            if ((funct7 == 7'b0000000 && funct3 == 3'b000) ||
                (funct7 == 7'b0100000 && funct3 == 3'b000) ||
                (funct7 == 7'b0000000 && funct3 == 3'b111) ||
                (funct7 == 7'b0000000 && funct3 == 3'b110) ||
                (funct7 == 7'b0000000 && funct3 == 3'b010)) begin

                model_valid = 1'b1;
                reg_write = 1'b1;

                case (funct3)

                    3'b000: begin
                        if (funct7 == 7'b0100000)
                            alu_result = operand1 - operand2;
                        else
                            alu_result = operand1 + operand2;
                    end

                    3'b111:
                        alu_result = operand1 & operand2;

                    3'b110:
                        alu_result = operand1 | operand2;

                    3'b010:
                        alu_result =
                            ($signed(operand1) < $signed(operand2))
                            ? 32'd1 : 32'd0;

                    default:
                        alu_result = 32'b0;

                endcase

                writeback_data = alu_result;
            end
        end

        // -------------------------------------------------
        // ADDI
        // -------------------------------------------------

        else if (opcode == 7'b0010011 &&
                 funct3 == 3'b000) begin

            model_valid = 1'b1;
            reg_write = 1'b1;

            immediate =
                {{20{model_instruction[31]}},
                  model_instruction[31:20]};

            alu_result = operand1 + immediate;
            writeback_data = alu_result;
        end

        // -------------------------------------------------
        // LW
        // -------------------------------------------------

        else if (opcode == 7'b0000011 &&
                 funct3 == 3'b010) begin

            model_valid = 1'b1;
            reg_write = 1'b1;

            immediate =
                {{20{model_instruction[31]}},
                  model_instruction[31:20]};

            alu_result = operand1 + immediate;

            model_mem_address = alu_result;

            writeback_data =
                data_mem[alu_result[31:2]];
        end

        // -------------------------------------------------
        // SW
        // -------------------------------------------------

        else if (opcode == 7'b0100011 &&
                 funct3 == 3'b010) begin

            model_valid = 1'b1;
            mem_write = 1'b1;

            immediate =
                {{20{model_instruction[31]}},
                  model_instruction[31:25],
                  model_instruction[11:7]};

            alu_result = operand1 + immediate;

            model_mem_address = alu_result;
            model_mem_write_data = operand2;

            writeback_data = alu_result;
        end

        // -------------------------------------------------
        // BEQ
        // -------------------------------------------------

        else if (opcode == 7'b1100011 &&
                 funct3 == 3'b000) begin

            model_valid = 1'b1;

            immediate =
                {{19{model_instruction[31]}},
                  model_instruction[31],
                  model_instruction[7],
                  model_instruction[30:25],
                  model_instruction[11:8],
                  1'b0};

            alu_result = operand1 - operand2;

            if (operand1 == operand2)
                next_pc = pc + immediate;

            writeback_data = alu_result;
        end

        // -------------------------------------------------
        // BNE
        // -------------------------------------------------

        else if (opcode == 7'b1100011 &&
                 funct3 == 3'b001) begin

            model_valid = 1'b1;

            immediate =
                {{19{model_instruction[31]}},
                  model_instruction[31],
                  model_instruction[7],
                  model_instruction[30:25],
                  model_instruction[11:8],
                  1'b0};

            alu_result = operand1 - operand2;

            if (operand1 != operand2)
                next_pc = pc + immediate;

            writeback_data = alu_result;
        end

        // -------------------------------------------------
        // JAL
        // -------------------------------------------------

        else if (opcode == 7'b1101111) begin

            model_valid = 1'b1;
            reg_write = 1'b1;

            immediate =
                {{11{model_instruction[31]}},
                  model_instruction[31],
                  model_instruction[19:12],
                  model_instruction[20],
                  model_instruction[30:21],
                  1'b0};

            alu_result = pc + 32'd4;
            writeback_data = pc + 32'd4;

            next_pc = pc + immediate;
        end

        // -------------------------------------------------
        // LUI
        // -------------------------------------------------

        else if (opcode == 7'b0110111) begin

            model_valid = 1'b1;
            reg_write = 1'b1;

            immediate = {
                model_instruction[31:12],
                12'b0
            };

            alu_result = immediate;
            writeback_data = immediate;
        end

        // -------------------------------------------------
        // EXPECTED TRACE OUTPUTS
        // -------------------------------------------------

        model_next_pc = next_pc;

        model_reg_write = reg_write && (rd != 5'd0);
        model_rd = rd;
        model_write_data = writeback_data;

        model_mem_write = mem_write;
        
        if (!mem_write && opcode != 7'b0000011)
            model_mem_address = alu_result;

        if (!mem_write)
            model_mem_write_data = operand2;

    end

    // =====================================================
    // ARCHITECTURAL STATE UPDATE
    // =====================================================

    always @(posedge clk) begin

        if (reset) begin

            pc <= 32'b0;

            for (i = 0; i < 32; i = i + 1)
                registers[i] <= 32'b0;

            for (i = 0; i < DEPTH; i = i + 1)
                data_mem[i] <= 32'b0;

        end

        else if (model_valid) begin

            // Register update
            if (model_reg_write)
                registers[model_rd] <= model_write_data;

            // Memory update
            if (model_mem_write)
                data_mem[model_mem_address[31:2]]
                    <= model_mem_write_data;

            // x0 is permanently zero
            registers[0] <= 32'b0;

            // Program counter update
            pc <= model_next_pc;

        end

    end

endmodule
