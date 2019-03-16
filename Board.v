// Board interface
module Board(
	input start,
	input reset,
	input clk,
	output board);
	

endmodule

//Generates a random board using a linear-feedback shift register (LFSR)
//Code for random counter from: http://www.asic-world.com/examples/verilog/lfsr.html
module BoardGenerator(
	input enable,
	input clk,
	input reset,
	output reg [x:0] board_values); //TODO: determine board size
	
	input data[x:0];
	wire linear_feedback;
	
	assign linear_feedback = !(out[7] ^ out[3]);
	
	always (@posedge clk) begin
		if (!reset) 
			out <= x'b0;
		else if (enable)
			out <= {out[x], ..., out[0], linear_feedback};
	end
	
endmodule
