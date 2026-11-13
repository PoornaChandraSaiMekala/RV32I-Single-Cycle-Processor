`timescale 1ns / 1ps

module instruction_memory #(
    parameter DEPTH = 256
)(
    input  wire [31:0] address,

    output wire [31:0] instruction
);

    // ============================================================
    // INSTRUCTION MEMORY
    //
    // 256 words × 32 bits
    // = 1 KB
    // ============================================================

    reg [31:0] memory [0:DEPTH-1];

    integer i;

    // ============================================================
    // INITIALIZE MEMORY
    //
    // program.mem should contain one 32-bit hexadecimal
    // instruction per line.
    // ============================================================

    initial begin

        for (i = 0; i < DEPTH; i = i + 1)
            memory[i] = 32'b0;

        $readmemh("program.mem", memory);

    end

    // ============================================================
    // WORD-ALIGNED BYTE ADDRESS → WORD INDEX
    //
    // address >> 2
    //
    // Example:
    // 0x00000000 → memory[0]
    // 0x00000004 → memory[1]
    // 0x00000008 → memory[2]
    // ============================================================

    assign instruction = memory[address[31:2]];

endmodule