`timescale 1ns / 1ps

module pc (
    input  wire        clk,
    input  wire        reset,

    input  wire [31:0] next_PC,

    output reg  [31:0] PC
);

    // ============================================================
    // PROGRAM COUNTER
    // ============================================================

    always @(posedge clk) begin

        if (reset)
            PC <= 32'h00000000;
        else
            PC <= next_PC;

    end

endmodule