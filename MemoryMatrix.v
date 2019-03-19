//TODO: (for next milestone) Create FSM to control when to check guesses remaining and when to check 
//	for correct guesses
//TODO: Determine which pins are to be used for the GPIO inputs

// Main module for the memory matrix game
module MemoryMatrix1(
	input [9:0] SW, // for testing purposes, to be removed at a later date 
	input [3:0] KEY,
	input CLOCK_50);
	
	wire resetn, start;
	assign resetn = KEY[0];
	assign start = ~KEY[1];
	
	wire [7:0] board; 
	
	Board b0(
	.start(start),
	.reset(resetn),
	.clk(CLOCK_50),
	.board(board));
	
endmodule

module GuessRemaining(
	input [7:0] input_guesses,
	input clk,
	input reset,
	input enable,
	output reg [7:0] remaining_guesses);	
	
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
	input [7:0] guess,
	input [7:0] board,
	input enable,
	input reset,
	output reg iscorrect);
	
	always @(posedge clk) begin
		if (!reset)
			iscorrect <= 1'b0;
		else if (enable)
			iscorrect <= ((guess & board) > 0) ? 1'b1 : 1'b0;
	end
	
endmodule



module MemoryMatrix( // augmented top-level module, for testing 

	input [9:0] SW,
	input [3:0] KEY,
	input CLOCK_50,
	output LEDR,
	output HEX0);
	
	wire resetn, start;
	assign resetn = KEY[0];
	assign start = ~KEY[1];
	
	wire [7:0] board; 
	
	Board b0(
	.start(start),
	.reset(resetn),
	.clk(CLOCK_50),
	.board(board));
	
	
	wire ic;
	wire [3:0] remaining_guesses;

	assign LEDR[9] = ic;
	assign LEDR[7:0] = board;
	
	hex_decoder d1(remaining_guesses, HEX0);
	
	GuessRemaining (
		.input_guesses(8), // difficulty selection coming in m3 
		.clk(CLOCK_50),
		.reset(resetn),
		.enable(~ic),
		.remaining_guesses()
		);
	
	CheckGuess ( 
		.guess(SW[7:0]), // test using 8 gameplay buttons.
		.board(board),  
		.enable(SW[9]),
		.reset(resetn),
		.iscorrect(ic)
		);
		
		
	
endmodule

module hex_decoder(hex_digit, segments); // for testing purposes.
    input [3:0] hex_digit;
    output reg [6:0] segments;
   
    always @(*)
        case (hex_digit)
            4'h0: segments = 7'b100_0000;
            4'h1: segments = 7'b111_1001;
            4'h2: segments = 7'b010_0100;
            4'h3: segments = 7'b011_0000;
            4'h4: segments = 7'b001_1001;
            4'h5: segments = 7'b001_0010;
            4'h6: segments = 7'b000_0010;
            4'h7: segments = 7'b111_1000;
            4'h8: segments = 7'b000_0000;
            4'h9: segments = 7'b001_1000;
            4'hA: segments = 7'b000_1000;
            4'hB: segments = 7'b000_0011;
            4'hC: segments = 7'b100_0110;
            4'hD: segments = 7'b010_0001;
            4'hE: segments = 7'b000_0110;
            4'hF: segments = 7'b000_1110;   
            default: segments = 7'h7f;
        endcase
endmodule
