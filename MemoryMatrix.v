//TODO: (for next milestone) Create FSM to control when to check guesses remaining and when to check 
//	for correct guesses
//TODO: Determine which pins are to be used for the GPIO inputs
//TODO: in play state utilize board_moved to decide when to update the board, etc...

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

// Module for keeping track of a remaining_guesses register and updating it as the player guesses
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

//Module for checking if an inputted guess was valid or not
module CheckGuess(
	input [7:0] guess,
	input [7:0] board,
	input enable,
	input reset,
	input clk,
	output reg iscorrect,
	output reg [7:0] current_guess);
	
	always @(posedge clk) begin
		if (!reset) begin
			iscorrect <= 1'b0;
			current_guess <= 8'd0;
		end
		else if (enable) begin
			iscorrect <= ((guess & board) > 0) ? 1'b1 : 1'b0;
			current_guess <= ((guess & board) > 0) ? guess : 8'd0;
		end
	end
	
endmodule

module RateDivider(q, Enable, Clock, reset_n);
	input [25:0] load, Enable, Clock, reset_n;
	output reg [25:0] q;
	
	always @(posedge Clock)
	begin
		if (reset_n == 1'b0)
			q <= load;
		else if (Enable == 1'b1)
			begin
				if (q == 0)
					q <= load;
				else
					q <= q - 1'b1;
			end
	end
	
endmodule

//Display either the full solution board, just the current correctly guessed tiles 
module DisplayBoard(
	input full_enable,
	input flash_enable,
	input clk,
	input reset,
	input [7:0] solution_board,
	input [7:0] current_board,
	output reg [7:0] board_led);
	
	RateDivider r0(
	.q(flash_counter),
	.load({2'd0, 24'd12499999}),
	.Enable(flash_enable),
	.Clock(clk),
	.reset_n(reset));
	
	wire [26:0] flash_counter;
	wire flash;
	assign flash = (flash_counter == 0) ? 1'b1 : 1'b0;
	
	always @(posedge clk)
	begin
		if (full_enable)
			board_led <= solution_board;
		else begin
			if (flash_enable) 
				//Currently will flash board_led[8] for when we add the extra led
				{board_led[7:0], board_led[8]} <= {current_board, flash} 
			else 
				board_led <= current_board;
		end
	end
	
endmodule

//TODO: Add other input/output as required
module control(
	input start,
	input reset,
	input clk,
	input is_correct,
	input [7:0] input_guesses,
	input board_moved, //I.E ({....} & 8'b11111111) == 1 ? 1'b1 : 1'b0 where .... is the button input
	output ld_play, ld_start, ld_display, ld_flash); 
	
	reg [3:0] current_state, next_state;
	
	wire [25:0] wait_enable;
	wire display_enable;
	//TODO: determine maximum number of guesses
	wire [x:0] num_guesses;
	wire is_solved;
	
	localparam  S_START        = 4'd0,
					S_START_WAIT   = 4'd1,
					S_DISPLAY      = 4'd2,
					S_PLAY         = 4'd4,
					S_CHECK_LOSE   = 4'd5,
					S_CHECK_WIN    = 4'd6,
					S_LOSE         = 4'd5,
					S_WIN          = 4'd6,
					S_WIN_WAIT     = 4'd7,
					S_LOSE         = 4'd8,
					S_LOSE_WAIT    = 4'd9;
	
	RateDivider r0(
	.q(wait_enable),
	.load(26'd49999999),
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
					S_CHECK_WIN: next_state = (is_solved == 1) ? S_WIN : S_PLAY;
					S_LOSE: next_state = start ? S_LOSE_WAIT : S_LOSE;
					S_LOSE_WAIT: next_state = start ? S_LOSE_WAIT : S_LOSE;
					S_WIN: next_state = start ? S_WIN_WAIT : S_WIN;
					S_WIN_WAIT: next_state = start ? S_WIN_WAIT : S_START;
				endcase
	end
	
	//TODO: complete remaining enable signals for the states
	always @(*)
	begin: enable_signals
		ld_start = 1'b0;
		ld_display = 1'b0;
		ld_play = 1'b0;
		ld_flash = 1'b0;
		case(current_state)
			S_START: begin
				ld_start = 1'b1;
				ld_flash = 1'b1;
			end
			
			//ADD REMAINING SIGNALS FOR CASES
			
			S_LOSE: begin
				//...Add remaining signals
				ld_flash = 1'b1;
			end
		endcase
	end
	
	always @(posedge clk)
	begin: state_FFs
		if (!reset)
			current_state <= S_START;
		else
			current_state <= next_state;
	end

endmodule

module datapath(
	input ld_display,
	input clk,
	input ld_play,
	input ld_start,
	input reset,
	input [7:0] solution_board,
	input [7:0] input_guesses,
	output reg [7:0] board_led);
	
	reg [7:0] current_board;
	reg [7:0] current_guess; 
	
	wire iscorrect;
	
	CheckGuess c0(
	.guess(input_guesses),
	.board(current_board),
	.enable(ld_play),
	.reset(reset),
	.iscorrect(iscorrect),
	.current_guess(current_guess));
	
	DisplayBoard d0(
	.full_enable(ld_display),
	.solution_board(solution_board),
	.current_board(current_board),
	.board_led(board_led));
	
	always @(posedge clk) begin
		if (!reset || ld_start)
			current_board <= 0;
		else begin
			 if (ld_play)
				board_led <= board_led || current_guess;
		end
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
