
// Board interface
module Board(
	input start,
	input reset,
	input clk,
	output [7:0] board); 
	
	wire ld_board, non_zero;
	
	datapath d0(
	.ld_board(ld_board),
	.clk(clk),
	.reset(reset),
	.non_zero(non_zero),
	.board(board));
	
	control c0(
	.start(start),
	.reset(reset),
	.clk(clk),
	.non_zero(non_zero),
	.ld_board(ld_board));
	
endmodule

//Generates a pseudo-random board using a linear-feedback shift register (LFSR)
//Logic for pseudo-random counter from: http://www.doe.carleton.ca/~jknight/97.478/97.478_03F/Advdig5cirJ.pdf
module BoardGenerator(
	input enable,
	input clk,
	input reset,
	output reg [7:0] out); 
		
	always @(posedge clk) begin
		if (!reset) 
			out <= 8'b11111111;
		else if (enable)
			out <= {out[6:1], out[7]^out[0], out[7]};
	end
	
endmodule

module control(
	input start,
	input reset,
	input clk,
	input non_zero,
	output reg ld_board);
	
	reg [1:0] current_state, next_state;
	
	
	localparam  S_GENERATE               = 2'd0,
				   S_GENERATE_WAIT          = 2'd1,
					S_GENERATE_CORRECT_BOARD = 2'd2,
					S_PLAY                   = 2'd3;
	
	always @(*)
	begin: state_table
				case(current_state)
					S_GENERATE: next_state = start ? S_GENERATE_WAIT : S_GENERATE;
					S_GENERATE_WAIT: next_state = start ? S_GENERATE_WAIT : S_GENERATE_CORRECT_BOARD;
					S_GENERATE_CORRECT_BOARD: next_state = non_zero ? S_PLAY : S_GENERATE_CORRECT_BOARD;
					S_PLAY: next_state = S_PLAY;
					default: next_state = S_GENERATE;
				endcase
	end
	
	always @(*)
	begin: enable_signals
		ld_board = 1'b0;
		
		case (current_state)
			S_GENERATE: ld_board = 1'b1;
			default: ld_board = 1'b0;
		endcase
	end
	
	always @(posedge clk) 
	begin: state_FFs
		if (!reset)
			current_state <= S_GENERATE;
		else
			current_state <= next_state;
	end
	
endmodule

module datapath(
	input ld_board,
	input clk,
	input reset,
	output non_zero,
	output reg [7:0] board); 
	
	wire [7:0] randomized_board;
	
	BoardGenerator b0(
		.enable(ld_board),
		.clk(clk),
		.reset(reset),
		.out(randomized_board));
		
	always @(posedge clk) begin
		if (!reset) 
			board <= 8'b0;
		else begin
			if (ld_board && non_zero)
				board <= randomized_board;
		end
	end
	
	assign non_zero = (randomized_board > 0) ? 1'b1 : 1'b0;
endmodule
