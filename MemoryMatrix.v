//TODO: Determine which pins are to be used for the GPIO inputs

// Main module for the memory matrix game
module MemoryMatrix(
	input [9:0] SW, // Number of Guesses
	input [3:0] KEY,
	input CLOCK_50,
	output [6:0] HEX0, //Displays remaining guesses
	output [9:0] LEDR);//Display current board before the buttons are set up
	
	wire reset, start;
	assign reset = KEY[0];
	assign start = ~KEY[1];
	
	wire [7:0] board; 
	
	wire is_correct;
	
	Board b0(
	.start(start),
	.reset(reset),
	.clk(CLOCK_50),
	.board(board)); // solution board
		
	wire ld_play, ld_start, ld_display, ld_flash, is_solved;
	wire [7:0] num_guesses;
	
	control c0(
	.start(start),
	.reset(reset),
	.clk(CLOCK_50),
	.is_correct(is_correct),
	.is_solved(is_solved),
	.input_guesses(SW[7:0]), // Number of guesses
	.board_moved(((SW[7:0] & 8'b11111111) > 0) ? 1'b1 : 1'b0), // board_moved listener
	.ld_play(ld_play),
	.ld_start(ld_start),
	.ld_display(ld_display),
	.ld_flash(ld_flash),
	.num_guesses(num_guesses));
	
	datapath d0(
	.ld_display(ld_display),
	.clk(CLOCK_50),
	.ld_play(ld_play),
	.ld_start(ld_start),
	.flash_enable(ld_flash),
	.reset(reset),
	.solution_board(board), // solution board
	.input_guesses(SW[7:0]), // to be changed later to be the actual button inputs
	.board_led(LEDR[8:0]), 
	.iscorrect(is_correct),
	.is_solved(is_solved));
	
	//Display the number of guesses
	hex_decoder h0(
	.hex_digit(num_guesses[3:0]),
	.segments(HEX0[6:0]));
	
endmodule
	
// Module for keeping track of a remaining_guesses register and updating it as the player guesses
module GuessRemaining(
	input [7:0] input_guesses,
	input ld_guess,
	input clk,
	input reset,
	input not_correct,
	input enable,
	output reg [7:0] remaining_guesses);	
	
	always @(posedge clk) begin
		if (!reset)
			remaining_guesses <= 8'd0;
		else if (ld_guess) 
			remaining_guesses <= input_guesses;
		else begin
			if (enable && not_correct) 
				remaining_guesses <= remaining_guesses - 1;
		end
	end
	
endmodule

//Module for checking if an inputted guess was valid or not
module CheckGuess(
	input [7:0] guess,
	input [7:0] board, //The solution board
	input enable,
	input reset,
	input clk,
	output reg iscorrect,
	output reg [7:0] current_guess); // mirrors most recent guess if it was correct, else 0
	 
	always @(posedge clk) begin
		if (!reset) begin
			iscorrect <= 1'b0;
			current_guess <= 8'd0;
		end
		else begin
			iscorrect <= ((guess & board) > 0) ? 1'b1 : 1'b0;
			current_guess <= ((guess & board) > 0) ? guess : 8'd0;
		end
	end
	
endmodule

module RateDivider(q, Enable, Clock, reset_n, load);
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

//Display either the full solution board, just the current correctly guessed tiles or display the flashing notification
module DisplayBoard(
	input full_enable,
	input flash_enable,
	input clk,
	input reset,
	input [7:0] solution_board,
	input [7:0] current_board,
	output reg [8:0] board_led);
	
	wire [26:0] flash_counter;
	
	//4 Hz rate divider
	RateDivider r0(
	.q(flash_counter),
	.load({2'd0, 24'd12499999}),
	.Enable(flash_enable), 
	.Clock(clk),
	.reset_n(reset)); 
	
	reg flash_on_off;
	
	//Flash on and off 4 times per second
	always @(posedge clk) 
	begin 
		if (!reset)
			flash_on_off <= 1'b0;
		else
			if (flash_counter == 0)
				flash_on_off <= ~flash_on_off;
	end
	
	always @(posedge clk)
	begin
		if (full_enable) // flash the solution board
			board_led <= solution_board;
		else begin
			if (flash_enable) 
				//Currently will flash board_led[8] for when we add the extra led
				board_led <= {flash_on_off, 8'b11111111};
			else 
				board_led <= {1'b0, current_board};
		end
	end
	
endmodule

module control(
	input start,  
	input reset,
	input clk,
	input is_correct, 
	input [7:0] input_guesses, //The number of guesses
	input is_solved,
	input board_moved, 
	output reg ld_play, ld_start, ld_display, ld_flash, ld_guess,
	output [7:0] num_guesses); 
	
	reg [3:0] current_state, next_state;
	
	wire [25:0] wait_enable;
	reg display_enable;
	//TODO: determine maximum number of guesses
	//Enables the guess counter
	reg enable_check;
	
	localparam  S_START        = 4'd0,
					S_START_WAIT   = 4'd1,
					S_DISPLAY      = 4'd2,
					S_PLAY         = 4'd3,
					S_CHECK        = 4'd4, 
					S_CHECK_LOSE   = 4'd5,
					S_CHECK_WIN    = 4'd6,
					S_LOSE         = 4'd7,
					S_WIN          = 4'd8,
					S_WIN_WAIT     = 4'd9,
					S_LOSE_WAIT    = 4'd10,
					S_RETURN_WAIT  = 4'd11;
	
	//1 Hz rate divider
	RateDivider r0(
	.q(wait_enable), 
	.load(26'd49999999), 
	.Enable(display_enable), 
	.Clock(clk),
	.reset_n(reset)); 
	
	GuessRemaining g0(
	.input_guesses(input_guesses),	
	.clk(clk),
	.ld_guess(ld_guess),
	.reset(reset),
	.enable(enable_check),
	.not_correct(!is_correct),
	.remaining_guesses(num_guesses));
	
	always @(*)
	begin: state_table
				case(current_state)
					//Make sure the player inputs a non-zero guess before moving to the play state
					S_START: next_state = (start && (input_guesses > 0)) ? S_START_WAIT : S_START;
					S_START_WAIT: next_state = start ? S_START_WAIT : S_DISPLAY;
					S_DISPLAY: next_state = (wait_enable == 0) ? S_PLAY : S_DISPLAY;
					S_PLAY: next_state = (board_moved == 1) ? S_CHECK : S_PLAY;
					S_CHECK: next_state = S_CHECK_LOSE;
					S_CHECK_LOSE: next_state = (num_guesses == 0) ? S_LOSE : S_CHECK_WIN;
					S_CHECK_WIN: next_state = (is_solved == 1) ? S_WIN : S_RETURN_WAIT;
					S_LOSE: next_state = start ? S_LOSE_WAIT : S_LOSE;
					S_LOSE_WAIT: next_state = start ? S_LOSE_WAIT : S_START;
					S_WIN: next_state = start ? S_WIN_WAIT : S_WIN;
					S_WIN_WAIT: next_state = start ? S_WIN_WAIT : S_START;
					S_RETURN_WAIT: next_state = (board_moved == 0) ? S_PLAY : S_RETURN_WAIT;
				endcase
	end
	
	// could maybe merge lose and win states, make transition an OR. <-- different leds for win/lose
	always @(*)
	begin: enable_signals
		ld_start = 1'b0; // resets the current_board
		ld_display = 1'b0; // displays the full solution boardboard
		ld_play = 1'b0;  // enable the datapath to update the board 
		ld_flash = 1'b0; // flash enable (for the additional LED)
		ld_guess = 1'b0; //Load the number of guesses
		enable_check = 1'b0;
		display_enable = 1'b0;
		
		case(current_state)
			S_START: begin
				ld_start = 1'b1; // initial reset 
				ld_flash = 1'b1; // flash for a bit to indicate start
				ld_guess = 1'b1;
			end

			S_DISPLAY: begin
				// interact with Display using Ratedivider in order to display
				// for correct amount of time.
				display_enable = 1'b1; // start the countdown for this state
				ld_display = 1'b1; // show solution						
			end
			
			S_PLAY: begin 
				ld_play = 1'b1; // want to check guesses, update board
			end
			
			S_CHECK: begin
				enable_check = 1'b1;
			end
			
			S_WIN:begin // transition here upon solving
				ld_flash = 1'b1; // flash to indicate end
				//dont display solution board
			end
			
			S_LOSE: begin // transition here among losing
				ld_flash = 1'b1;
				
			end
			default: begin
				ld_start = 1'b0; // resets the current_board
				ld_display = 1'b0; // displays the full solution boardboard
				ld_play = 1'b0;  // enable the datapath to update the board 
				ld_flash = 1'b0; // flash enable (for the additional LED)
				enable_check = 1'b0;
				ld_guess = 1'b0;
				display_enable = 1'b0;
			end
		endcase
	end
	
	always @(posedge clk)
	begin: state_FFs
		// Possibly since reset is also give up if reset is hit in any state other than lose, start, and lose_wait go to lose state instead
		//of start
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
	input flash_enable,
	input enable_check, //If the guess was wrong enable decrement the guesses by 1
	input reset,
	input [7:0] solution_board,
	input [7:0] input_guesses, // The current guess
	output [8:0] board_led,
	output iscorrect,
	output reg is_solved); // need this to be connected to guess counter in fsm
	
	reg [7:0] current_board;
	wire [7:0] current_guess; 
	
	CheckGuess c0(
	.guess(input_guesses),
	.board(solution_board),
	.enable(enable_check),
	.reset(reset),
	.clk(clk),
	.iscorrect(iscorrect), // reflects whether current_guess is correct
	.current_guess(current_guess)); // mirrors most recent guess if it was correct, else 0

	DisplayBoard d0( // determine whether to display the solution board or the current board
	.full_enable(ld_display),
	.flash_enable(flash_enable),
	.clk(clk),
	.reset(reset),
	.solution_board(solution_board),
	.current_board(current_board), // goes from datapath into Displayboard where it could potentially be displayed
	.board_led(board_led));
	
	always @(posedge clk) begin
		if (!reset || ld_start)
			current_board <= 8'd0;
		else begin
			if (iscorrect) // if the guess was correct
				current_board <= (current_board | current_guess); // updates board_led by adding correct guesses to it
		end
	end
	
	//Check if the board is solved
	always @(posedge clk) 
	begin 
		if (!reset || ld_start)
			is_solved <= 1'b0;
		else begin	
				is_solved <= (current_board == solution_board) ? 1'b1 : 1'b0;
		end
	end
	
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
