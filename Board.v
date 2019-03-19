//TODO: Replace all values of 'x' with the appropriate size of the board

// Board interface
module Board(
	input start,
	input reset,
	input clk,
	output [7:0] board); 
	
	wire ld_board;
	
	datapath d0(
	.ld_board(ld_board),
	.clk(clk),
	.reset(reset),
	.board(board));
	
	control c0(
	.start(start),
	.reset(reset),
	.clk(clk),
	.ld_board(ld_board));
	
endmodule

//Generates a pseudo-random board using a linear-feedback shift register (LFSR)
//Logic for pseudo-random counter from: http://www.asic-world.com/examples/verilog/lfsr.html
module BoardGenerator(
	input enable,
	input clk,
	input reset,
	output reg [7:0] board_values); 
	
	input data[x:0];
	wire linear_feedback;
	
	assign linear_feedback = !(out[7] ^ out[3]); 
	
	always (@posedge clk) begin
		if (!reset) 
			out <= x'b0;
		else if (!enable)
			out <= {out[6], out[5], out[4], out[3], out[2], out[1], out[0], linear_feedback};
	end
	
endmodule

module control(
	input start,
	input reset,
	input clk,
	output reg ld_board);
	
	reg [1:0] current_state, next_state;
	
	localparam  S_GENERATE =      2'b0,
				   S_GENERATE_WAIT = 2'b1,
					S_PLAY =          2'b2;
	
	always @(*)
	begin: state_table
				case(current_state)
					S_GENERATE: next_state = start ? S_GENERATE_WAIT : S_GENERATE;
					S_GENERATE_WAIT: next_state = start ? S_GENERATE_WAIT : S_PLAY;
					S_PLAY: next_state = S_PLAY;
					default: next_state = S_GENERATE;
	end
	
	always @(*)
	begin: enable_signals
		ld_board = 1'b0;
		
		case (current_state)
			S_GENERATE: ld_board = 1'b1;
			default: ld_board = 1'b0;
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
	output reg [7:0] board); 
	
	wire [7:0] randomized_board;
	
	BoardGenerator b0(
		.enable(ld_board),
		.clk(clk),
		.reset(reset),
		.board_values(randomized_board));
		
	always @(posedge clk) begin
		if (!reset) 
			board <= 8'b0;
		else begin
			if (ld_board)
				board <= load_board;
		end
	end
	
endmodule
