//TODO: (for next milestone) Create FSM to control when to check guesses remaining and when to check for correct guesses

// Main module for the memory matrix game
module MemoryMatrix(
	input [9:0] SW, 
	input [3:0] KEY,
	input CLOCK_50);
	
	wire resetn, start;
	assign resetn = KEY[0];
	assign start = ~KEY[1];
	
	wire [x:0] board; //TODO: determine size of board
	
	Board b0(
	.start(start),
	.reset(resetn),
	.clk(CLOCK_50),
	.board(board));
	
endmodule

module GuessRemaining(
	input [x:0] input_guesses,
	input clk,
	input reset,
	input enable,
	output reg [x:0] remaining_guesses);	//TODO: determine number of guesses
	
	always @(posedge clk) begin
		if (!reset)
			remaining_guesses <= input_guesses;
		else begin
			if (enable) 
				remaining_guesses <= remaining_guesses - 1;
		end
	end
	
endmodule

module CheckGuess(
	input [x:0] guess,
	input [x:0] board,
	input enable,
	input reset,
	output reg iscorrect);
	
	always @(posedge clk) begin
		if (!reset)
			iscorrect <= 1'b0;
		else if (enable
			iscorrect <= ((guess & board) > 0) ? 1'b1 : 1'b0;
	end
	
endmodule
				