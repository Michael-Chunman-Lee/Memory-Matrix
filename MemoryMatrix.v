//TODO: (for next milestone) Create FSM to control when to check guesses remaining and when to check 
//	for correct guesses
//TODO: Determine which pins are to be used for the GPIO inputs

// Main module for the memory matrix game
module MemoryMatrix1(
	input [9:0] SW, // for testing purposes, to be removed at a later date 
	input [3:0] KEY,
	input CLOCK_50);
	
	wire reset, start;
	assign reset = KEY[0];
	assign start = ~KEY[1];
	
	wire [7:0] board; 
	
	Board b0(
	.start(start),
	.reset(reset),
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

//0.5Hz RateDivider
module RateDivider(q, Enable, Clock, reset_n);
	input Enable, Clock, reset_n;
	output reg [26:0] q;
	
	always @(posedge Clock)
	begin
		if (reset_n == 1'b0)
			q <= 27'd99999999;
		else if (Enable == 1'b1)
			begin
				if (q == 0)
					q <= 27'd99999999;
				else
					q <= q - 1'b1;
			end
	end
	
endmodule

module DisplayBoard();

endmodule

//TODO: Add other input/output as required
module control(
	input start,
	input reset,
	input clk,
	input is_correct,
	input [x:0] input_guesses,
	);
	
	reg [2:0] current_state, next_state;
	
	wire [26:0] wait_enable;
	wire display_enable;
	wire [x:0] num_guesses;

	localparam  S_START        = 3'd0,
					S_START_WAIT   = 3'd1,
					S_DISPLAY      = 3'd2,
					S_PLAY         = 3'd4,
					S_CHECK_LOSE   = 3'd5,
					S_CHECK_WIN    = 3'd6,
					S_LOSE         = 3'd5,
					S_WIN          = 3'd6,
					S_WIN_WAIT     = 3'd7;
	
	RateDivider r0(
	.q(wait_enable),
	.Enable(display_enable),
	.Clock(clk),
	.reset_n(reset));
	
	GuessRemaining g0(
	.input_guesses(input_guesses),
	.clk(clk),
	.reset(reset),
	.enable(!is_correct),
	.remaining_guesses(num_guesses));
	
	always @(*)
	begin: state_table
				case(current_state)
					S_START: next_state = start ? S_START_WAIT : S_START;
					S_START_WAIT: next_state = start ? S_START_WAIT : S_DISPLAY;
					S_DISPLAY: next_state = (wait_enable == 0) ? S_PLAY : S_DISPLAY;
					S_PLAY: next_state = (board_moved == 1) ? S_CHECK_LOSE : S_PLAY;
					S_CHECK_LOSE: next_state = (num_guesses == 0) ? S_LOSE : S_CHECK_WIN;
					S_CHECK_WIN: next_state = (issolved == 1) ? S_WIN : S_PLAY;
					S_WIN: next_state = start ? S_WIN_WAIT : S_WIN;
					S_WIN_WAIT: next_state = start ? S_WIN_WAIT : S_START;
	end
	
	always @(*)
	begin: enable_signals
		case(current_state)
	end
	
	always @(posedge clk)
	begin: state_FFs
		if (!reset)
			current_state <= S_START;
		else
			current_state <= next_state;
	end

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
