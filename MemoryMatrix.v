
// Main module for the memory matrix game
module MemoryMatrix(
	input [7:0] SW, // Input guesses
	input [3:0] KEY,
	input CLOCK_50,
	output [6:0] HEX0, //Displays remaining guesses
	output [16:0] GPIO_1);
	
	wire reset, start, give_up, increment;
	assign reset = KEY[0];
	assign start = ~KEY[1];
	assign give_up = ~KEY[2]; 
	assign increment = ~KEY[3];
	
	wire [7:0] board; 
	
	//Wire to check if a certain guess is correct
	wire is_correct;
	
	//Check if the board has moved or not
	wire board_moved;
	assign board_moved = (((SW[7:0] & 8'b11111111)) > 0) ? 1'b1 : 1'b0; 
	
	Board b0(
	.start(ld_start),
	.reset(reset),
	.clk(CLOCK_50),
	.board(board)); // solution board
	
	//The control signals
	wire ld_play, ld_start, ld_display, ld_flash, is_solved;
	//Maximum 15 guesses 
	wire [3:0] num_guesses;
	
	control c0(
	.start(start),
	.reset(reset),
	.clk(CLOCK_50),
	.is_correct(is_correct),
	.is_solved(is_solved),
	.board_moved(board_moved), // board_moved listener
	.ld_play(ld_play),
	.board(board),
	.ld_start(ld_start),
	.ld_display(ld_display),
	.ld_flash(ld_flash),
	.increment(increment),
	.num_guesses(num_guesses),
	.give_up(give_up));

	datapath d0(
	.ld_display(ld_display),
	.clk(CLOCK_50),
	.ld_play(ld_play),
	.ld_start(ld_start),
	.flash_enable(ld_flash),
	.reset(reset),
	.solution_board(board), // solution board
   .input_guesses({SW[7:0]}),
	.board_led({GPIO_1[16], GPIO_1[0], GPIO_1[2], GPIO_1[4], GPIO_1[6], GPIO_1[8], GPIO_1[10], GPIO_1[12], GPIO_1[14]}), 
	.iscorrect(is_correct),
	.is_solved(is_solved));
	
	//Display the number of guesses
	hex_decoder h0(
	.hex_digit(num_guesses[3:0]),
	.segments(HEX0[6:0]));
	
endmodule
	
// Module for keeping track of a remaining_guesses register and updating it as the player guesses
module GuessRemaining(
	input ld_guess,
	input clk,
	input reset,
	input not_correct,
	input enable,
	input start,
	input increment,
	output reg [3:0] remaining_guesses);	
	
	always @(posedge clk) begin
		if (!reset || start) 
			//If reset was pressed or the game is in the start state reset the number of guesses to 0
			remaining_guesses <= 4'd0;
		else if (ld_guess) begin 
			//In the load state, on each increment signal, increment the guesses by 1
			if (increment)
				remaining_guesses <= remaining_guesses + 1;
		end
		else begin 
			//Process the remaining guesses depending on if the guess is correct or not
			if (enable && not_correct) begin
				if (remaining_guesses == 0)
					remaining_guesses <= 0;
				else
					remaining_guesses <= remaining_guesses - 1;
			end
		end
	end
	
endmodule

//Module for checking if an inputted guess was valid or not
module CheckGuess(
	input [7:0] guess, //The current guess
	input [7:0] board, //The solution board
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
	input [25:0] load;
	input Enable, Clock, reset_n;
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
		if (full_enable) begin 
			// flash the solution board
			if (flash_enable) 
				board_led <= {flash_on_off, solution_board};
			else 
				board_led <= {1'b0, solution_board};
		end
		else begin
			if (flash_enable) 
				board_led <= {flash_on_off, 8'b11111111};
			else 
				board_led <= {1'b0, current_board};
		end
	end
	
endmodule

module control(
	input start, //Control signal to indicate that the game is in the start state
	input reset, 
	input clk,
	input is_correct, //Control signal to indicate whether or not a guess is correct 
	input is_solved, //Control signal to indicate whether or not the board was solved
	input board_moved, //Control signal to indicate whether or not the board moved
	input [7:0] board, //Board values to check for a correctly generated board
	input increment, //Increment signal to increment the guesses
	input give_up, //Control signal to indicate that the player has given up
	output reg ld_play, ld_start, ld_display, ld_flash,
	output [3:0] num_guesses); 
	
	reg [3:0] current_state, next_state;
	
	wire [25:0] wait_enable;
	reg display_enable;
	//Enables the guess counter
	reg enable_check;
	//Loads the remaining number of guesses
	reg ld_guess;

	localparam  S_START        = 4'd0,
					S_START_WAIT   = 4'd1,
					S_BOARD_WAIT   = 4'd2,
					S_LOAD         = 4'd3,
					S_LOAD_WAIT    = 4'd4,
					S_BEGIN_WAIT   = 4'd5,
					S_DISPLAY      = 4'd6,
					S_PLAY         = 4'd7,
					S_CHECK        = 4'd8, 
					S_CHECK_LOSE   = 4'd9,
					S_CHECK_WIN    = 4'd10,
					S_LOSE         = 4'd11,
					S_WIN          = 4'd12,
					S_WIN_WAIT     = 4'd13,
					S_LOSE_WAIT    = 4'd14,
					S_RETURN_WAIT  = 4'd15;
	
	//1 Hz rate divider
	RateDivider r0(
	.q(wait_enable), 
	.load(26'd49999999), 
	.Enable(display_enable), 
	.Clock(clk),
	.reset_n(reset));

	//Keep track of the remaining number of guesses
	GuessRemaining g0(
	.clk(clk),
	.ld_guess(ld_guess),
	.reset(reset),
	.enable(enable_check),
	.start(ld_start),
	.increment(increment),
	.not_correct(!is_correct),
	.remaining_guesses(num_guesses));
	
	always @(*)
	begin: state_table
				case(current_state)
					S_START: next_state = start ? S_START_WAIT : S_START;
					S_START_WAIT: next_state = start ? S_START_WAIT : S_BOARD_WAIT;
					//Make sure the board generated is a non-zero board
					S_BOARD_WAIT: next_state = board > 0 ? S_LOAD : S_BOARD_WAIT;
					//Make sure the player inputs a non-zero guess before moving to the play state
					S_LOAD: begin 
						if (increment)
							next_state = S_LOAD_WAIT;
						else if (start && (num_guesses > 0))
							next_state = S_BEGIN_WAIT;
						else
							next_state = S_LOAD;
					end
					S_LOAD_WAIT: next_state = increment ? S_LOAD_WAIT: S_LOAD;
					S_BEGIN_WAIT: next_state = start ? S_BEGIN_WAIT : S_DISPLAY;
					S_DISPLAY: next_state = (wait_enable == 0) ? S_PLAY : S_DISPLAY;
					S_PLAY: next_state = (board_moved == 1'b1) ? S_CHECK : S_PLAY;
					S_CHECK: next_state = S_CHECK_LOSE;
					S_CHECK_LOSE: next_state = (num_guesses == 0) ? S_LOSE : S_CHECK_WIN;
					S_CHECK_WIN: next_state = (is_solved == 1) ? S_WIN : S_RETURN_WAIT;
					S_LOSE: next_state = start ? S_LOSE_WAIT : S_LOSE;
					S_LOSE_WAIT: next_state = start ? S_LOSE_WAIT : S_START;
					S_WIN: next_state = start ? S_WIN_WAIT : S_WIN;
					S_WIN_WAIT: next_state = start ? S_WIN_WAIT : S_START;
					S_RETURN_WAIT: next_state = (board_moved == 1'b0) ? S_PLAY : S_RETURN_WAIT;
				endcase
	end
	
	always @(*)
	begin: enable_signals
		ld_start = 1'b0; // resets the current board
		ld_display = 1'b0; // displays the full solution boardboard
		ld_play = 1'b0;  // enable the datapath to update the board 
		ld_flash = 1'b0; // flash enable (for the additional LED)
		ld_guess = 1'b0; //Load the number of guesses
		enable_check = 1'b0; //Enable the guessesremaining register to possibly decrement the number of guesses
		display_enable = 1'b0; //Enable the full board display
		
		case(current_state)
			S_START: begin
				ld_start = 1'b1; // initial reset 
				ld_flash = 1'b1; // flash for a bit to indicate start
			end
			
			S_LOAD: begin
				ld_guess = 1'b1; //Load the guesses
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
				ld_display = 1'b1; 
			end
			
			S_LOSE: begin // transition here upon losing
				ld_flash = 1'b1;
				ld_display = 1'b1; //Display the full solution board
			end
			
			default: begin
				ld_start = 1'b0; // resets the current board
				ld_display = 1'b0; // displays the full solution boardboard
				ld_play = 1'b0;  // enable the datapath to update the board 
				ld_flash = 1'b0; // flash enable (for the additional LED)
				ld_guess = 1'b0; //Load the number of guesses
				enable_check = 1'b0; //Enable the guessesremaining register to possibly decrement the number of guesses
				display_enable = 1'b0; //Enable the full board display
			end
		endcase
	end
	
	always @(posedge clk)
	begin: state_FFs
		if (!reset) 
			current_state <= S_START;
		else if (give_up) begin
			if (current_state == S_PLAY)
				current_state <= S_LOSE;
		end
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
	input reset,
	input [7:0] solution_board,
	input [7:0] input_guesses, // The current guess
	output [8:0] board_led,
	output iscorrect,
	output reg is_solved);
	
	reg [7:0] current_board;
	wire [7:0] current_guess; 

	CheckGuess c0(
	.guess(input_guesses),
	.board(solution_board),
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

module hex_decoder(hex_digit, segments); 
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
