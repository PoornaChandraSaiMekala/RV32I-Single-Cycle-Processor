`timescale 1ns / 1ps

// ============================================================================
// addr_range_check
//
// Returns 1 when (a + b) lies inside the data-memory window, i.e. when
//     (a + b)[31:LOW_BITS] == 0          (LOW_BITS = 10 for 256 x 32 = 1 KB)
//
// WHY THIS MODULE EXISTS
// ----------------------
// The original design built this test from the 32-bit ALU *result*:
//     ALU carry chain  ->  22-input NOR  ->  address decode  ->  CE of 8192 FFs
// so the whole carry chain sat in series with the decode.
//
// Here the test is done directly on the two ADDER OPERANDS with no carry
// propagation through the upper bits (carry-free "A + B == 0" detection):
//
//   * Let c = carry out of the low LOW_BITS bits (a short 10-bit carry chain).
//   * Sum bit LOW_BITS is zero      <=>  (a[L] ^ b[L]) == c
//   * For i > LOW_BITS, if sum bit i-1 is zero then the carry into bit i is
//       maj(a, b, a^b) = a | b   (taken at i-1), so
//     sum bit i is zero            <=>  (a[i] ^ b[i]) == (a[i-1] | b[i-1])
//   * Every term depends on <= 4 operand bits -> one LUT4 per bit, then a
//     22-input AND tree.  No dependence on the upper adder carry chain.
//
// The result is bit-exact with  ~|(a+b)[31:LOW_BITS]  (verified by
// tb_addr_range_check.sv).
// ============================================================================
module addr_range_check #(
    parameter LOW_BITS = 10
)(
    input  wire [31:0] a,
    input  wire [31:0] b,
    output wire        in_range
);

    // Carry out of the low LOW_BITS bits (short chain, ready early)
    wire [LOW_BITS:0] low_sum = {1'b0, a[LOW_BITS-1:0]} + {1'b0, b[LOW_BITS-1:0]};
    wire              c_low   = low_sum[LOW_BITS];

    wire [31:LOW_BITS] zero_term;

    assign zero_term[LOW_BITS] = ((a[LOW_BITS] ^ b[LOW_BITS]) == c_low);

    genvar i;
    generate
        for (i = LOW_BITS + 1; i < 32; i = i + 1) begin : g_term
            assign zero_term[i] =
                ((a[i] ^ b[i]) == (a[i-1] | b[i-1]));
        end
    endgenerate

    assign in_range = &zero_term;

endmodule
