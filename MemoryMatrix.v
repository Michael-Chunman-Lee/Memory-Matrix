module MemoryMatrix(
	input [3:0] KEY,
	input CLOCK_50);
	
	wire resetn, start;
	assign resetn = KEY[0];
	assign start = ~KEY[1];
	
	wire [x:0] board;
	
	Board b0(
	.start(start),
	.reset(resetn),
	.clk(CLOCK_50),
	.board(board));
	
endmodule
