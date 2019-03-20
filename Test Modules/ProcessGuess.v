//Test module for milestone 1 to demonstrate part 1
module ProcessGuess(
	input [9:0] SW, // for testing purposes
	input [3:0] KEY,
	input CLOCK_50,
	output [3:0] HEX0,
	output [7:0] LEDR);
	
	wire reset, start, guess, enable;
	assign reset = KEY[0];
	assign start = ~KEY[1];
	assign guess = ~KEY[2];
	assign enable = ~KEY[3];
	
	//Display remaining guesses on HEX0 and as input have 7 guesses total
	GuessRemaining g0(
	.input_guesses(8'd7),
	.clk(CLOCK_50),
	.reset(reset),
	.enable(guess),
	.remaining_guesses({3'b0, HEX0}));
	
	//Display the current guess on the LEDR and input the guess through SW[9:5] and the board through SW[4:0] and process guesses upon enable press
	CheckGuess g1(
	.guess({3'b0, SW[9:5]}),
	.board({3'b0, SW[4:0]}),
	.enable(enable),
	.reset(reset),
	.iscorrect(LEDR[0]),
	.current_guess({1'b0, LEDR[7:1]}));
	
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
	output reg iscorrect,
	output reg [7:0] current_guess);
	
	always @(posedge clk) begin
		if (!reset)
			iscorrect <= 1'b0;
			current_guess <= 8'b0;
		else if (enable)
			iscorrect <= ((guess & board) > 0) ? 1'b1 : 1'b0;
			//Not sure if you can do this
			current_guess <= ((guess & board) > 0) ? guess : current_guess;
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
