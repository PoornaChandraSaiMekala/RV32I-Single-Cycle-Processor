`timescale 1ns/1ps
// Checks the SYNTHESIZABLE data_memory behaviour. Compile with -DSYNTHESIS so the
// simulation-only reset-clear is excluded and only real hardware logic acts.
module tb_data_memory_hwreset;
  reg clk=0, reset=1, MemRead=0, MemWrite=0; reg [31:0] a=0, wd=0; reg inr=1; wire [31:0] rd;
  data_memory #(.HW_RESET_CLEAR(1)) dut(.clk(clk),.reset(reset),.MemRead(MemRead),.MemWrite(MemWrite),
     .address(a),.addr_in_range(inr),.write_data(wd),.read_data(rd));
  always #5 clk=~clk;
  integer err=0, i;
  task wr(input [31:0] ad, input [31:0] d); begin a=ad; wd=d; MemWrite=1; @(posedge clk); #1 MemWrite=0; end endtask
  task chk(input [31:0] ad, input [31:0] exp, input [255:0] name); begin a=ad; MemRead=1; #1;
     if (rd!==exp) begin err=err+1; $display("FAIL %0s addr=%0d got=%h exp=%h",name,ad,rd,exp); end MemRead=0; end endtask
  initial begin
    repeat(2) @(posedge clk); #1 reset=0;
    for (i=0;i<256;i=i+1) chk(i*4,0,"after-config");
    for (i=0;i<256;i=i+1) wr(i*4, 32'hA5000000+i);
    for (i=0;i<256;i=i+1) chk(i*4,32'hA5000000+i,"readback");
    // out-of-range write ignored (in_range=0)
    inr=0; wr(32'h0, 32'hDEAD); inr=1; chk(0,32'hA5000000,"oor-write-ignored");
    // write while reset high is ignored, and reset clears everything (warm reset)
    reset=1; wr(32'h8, 32'hBEEF); repeat(2) @(posedge clk); #1 reset=0;
    for (i=0;i<256;i=i+1) chk(i*4,0,"after-warm-reset");
    // memory fully usable after reset
    wr(32'h3FC, 32'h12345678); chk(32'h3FC,32'h12345678,"post-reset-write"); chk(32'h0,0,"others-still-zero");
    // word written before a SECOND reset must not reappear
    reset=1; repeat(2) @(posedge clk); #1 reset=0; chk(32'h3FC,0,"second-reset");
    $display("data_memory HW reset test: %0d errors", err); $finish;
  end
endmodule
