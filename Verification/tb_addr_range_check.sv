`timescale 1ns/1ps
module tb_addr_range_check;
  reg [31:0] a, b; wire r; integer n, err=0; reg [31:0] s;
  addr_range_check #(.LOW_BITS(10)) dut(.a(a),.b(b),.in_range(r));
  task chk; begin #1; s=a+b; if (r !== (s[31:10]==0)) begin err=err+1; if (err<10) $display("MISMATCH a=%h b=%h r=%b sum=%h",a,b,r,s); end end endtask
  integer k;
  initial begin
    // directed: boundaries
    for (k=0;k<2000;k=k+1) begin
      a=$urandom%1100; b=$urandom%64; chk;                    // near window edge
      a=32'h3FC; b=$urandom%16; chk;
      a=-($urandom%2048); b=$urandom%2048; chk;               // a+b wraps through 0 / negatives
      a=32'hFFFFFFFF; b=$urandom; chk;
      a=$urandom; b=-a + ($urandom%3) - 1; chk;               // sums near zero
      a=$urandom; b=-a + ($urandom%2048); chk;                // sums in/around window, random upper bits
    end
    for (n=0;n<3000000;n=n+1) begin a=$urandom; b=$urandom; chk; end
    // sums forced into window with random operands
    for (n=0;n<2000000;n=n+1) begin a=$urandom; b=($urandom%1024) - a; chk; end
    $display("addr_range_check: %0d mismatches", err);
    $finish;
  end
endmodule
