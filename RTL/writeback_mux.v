`timescale 1ns / 1ps

module writeback_mux (
    input wire [31:0] ALUResult,
    input wire [31:0] MemoryData,
    input wire [31:0] PCPlus4,

    input wire [1:0]  WBSelect,

    output reg [31:0] WriteData
);

    // ============================================================
    // WRITEBACK SELECTION
    //
    // 00 → ALU Result
    // 01 → Memory Data
    // 10 → PC + 4
    // ============================================================

    localparam WB_ALU = 2'b00;
    localparam WB_MEM = 2'b01;
    localparam WB_PC4 = 2'b10;

    always @(*) begin

        // Safe default
        WriteData = 32'b0;

        case (WBSelect)

            WB_ALU: begin
                WriteData = ALUResult;
            end

            WB_MEM: begin
                WriteData = MemoryData;
            end

            WB_PC4: begin
                WriteData = PCPlus4;
            end

            default: begin
                WriteData = 32'b0;
            end

        endcase

    end

endmodule