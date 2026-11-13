`timescale 1ns / 1ps

// ============================================================================
// DATA MEMORY  -  256 words x 32 bits (1 KB)
//
// Timing-optimised version.
//
// What changed vs. the original
// -----------------------------
// ORIGINAL : reg array with a synchronous-reset loop  ->  8192 FDRE flip-flops,
//            a per-word clock-enable decoded from the *full 32-bit ALU result*,
//            and a 256:1 x 32 read mux (~2.7k LUTs).
//            Critical path:  ALU carry chain -> 5 LUT levels -> CE of 8192 FFs.
//
// NOW      : array has NO hardware reset, so Vivado maps it to distributed RAM
//            (RAM256X1S, async read / sync write):
//              * 8192 FFs  -> 0 FFs  (clock-net fanout 8670 -> ~500)
//              * read mux  -> built into the LUTRAM (~1 ns)
//              * write enable is ONE net (we) instead of 256 decoded CEs
//            The "address in range" qualifier arrives pre-computed from
//            addr_range_check (carry-free, computed from the adder operands).
//
// Reset semantics
// ---------------
//  * SIMULATION (always): reset clears the whole array exactly like the
//    original, so the testbench's hierarchical memory[] checks are unchanged.
//  * HARDWARE, HW_RESET_CLEAR = 1 (DEFAULT, architecturally identical to the
//        original): a 256-bit valid vector is cleared by reset; a word not
//        written since reset reads as 0.  Costs 256 FFs + a 1-bit 256:1 mux
//        in the read path.
//  * HARDWARE, HW_RESET_CLEAR = 0 (fastest, NOT reset-equivalent):
//        contents are zero at FPGA configuration only and are NOT wiped by a
//        later warm reset.
//
// Writes are ignored while reset is high and when the address is outside the
// 1 KB window (same as the original out-of-range behaviour).
// ============================================================================
module data_memory #(
    parameter DEPTH          = 256,
    parameter HW_RESET_CLEAR = 1
)(
    input  wire        clk,
    input  wire        reset,

    input  wire        MemRead,
    input  wire        MemWrite,

    input  wire [31:0] address,
    input  wire        addr_in_range,   // (address[31:IDXW+2] == 0), from addr_range_check
    input  wire [31:0] write_data,

    output wire [31:0] read_data
);

    localparam IDXW = $clog2(DEPTH);

    (* ram_style = "distributed" *)
    reg [31:0] memory [0:DEPTH-1];

    wire [IDXW-1:0] widx = address[IDXW+1:2];
    wire            we   = MemWrite & addr_in_range & ~reset;

    integer i;

    // Power-up contents = 0 (becomes the LUTRAM INIT value; also sim init)
    initial begin
        for (i = 0; i < DEPTH; i = i + 1)
            memory[i] = 32'b0;
    end

    // ------------------------------------------------------------------
    // Write port.  Reset-clear loop is SIMULATION ONLY (SYNTHESIS is
    // defined by Vivado synthesis) so the array can map to LUTRAM.
    // ------------------------------------------------------------------
    always @(posedge clk) begin
`ifndef SYNTHESIS
        if (reset) begin
            for (i = 0; i < DEPTH; i = i + 1)
                memory[i] <= 32'b0;
        end
        else
`endif
        if (we)
            memory[widx] <= write_data;
    end

    // ------------------------------------------------------------------
    // Asynchronous read (LW)
    // ------------------------------------------------------------------
    wire [31:0] ram_q = memory[widx];
    wire [31:0] rd_raw;

    generate
        if (HW_RESET_CLEAR) begin : g_valid
            // valid[k] = word k written since reset.  Write-set decode is
            // split so the LATE signal (we) passes through one LUT level:
            //   idx -> lo_dec / hi_sel (early, predecoded)
            //   we  -> we_hi[a] -> valid[k] clock-enable
            localparam LO = IDXW / 2;
            localparam HI = IDXW - LO;

            reg  [DEPTH-1:0]      valid = {DEPTH{1'b0}};
            wire [(1<<HI)-1:0]    we_hi;
            wire [(1<<LO)-1:0]    lo_dec;

            genvar a, b, k;
            for (a = 0; a < (1<<HI); a = a + 1) begin : g_hi
                assign we_hi[a] = we & (widx[IDXW-1:LO] == a);
            end
            for (b = 0; b < (1<<LO); b = b + 1) begin : g_lo
                assign lo_dec[b] = (widx[LO-1:0] == b);
            end
            for (k = 0; k < DEPTH; k = k + 1) begin : g_v
                always @(posedge clk) begin
                    if (reset)
                        valid[k] <= 1'b0;
                    else if (we_hi[k >> LO] & lo_dec[k & ((1<<LO)-1)])
                        valid[k] <= 1'b1;
                end
            end

            assign rd_raw = valid[widx] ? ram_q : 32'b0;
        end
        else begin : g_novalid
            assign rd_raw = ram_q;
        end
    endgenerate

    assign read_data = MemRead ? rd_raw : 32'b0;

endmodule
