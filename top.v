module top(
  	input rst,
	input sclk,
	input [3:0] data,
	output ack,
	output [15:0] outhigh
	);
	
	wire ack_m1_m0;
	wire slc_m1_m2;
	wire sda_m1_m2;
	
ptosda ptosda_inst(
	.rst(rst),
	.sclk(sclk),
	.ack(ack_m1_m0),
	.scl(slc_m1_m2),
	.sda(sda_m1_m2),
	.data(data)	
	);

   assign ack = ack_m1_m0;
   
out16hi out16hi_inst(
	.scl(slc_m1_m2),
	.sda(sda_m1_m2),
	.outhigh(outhigh)
	);
	
	
endmodule