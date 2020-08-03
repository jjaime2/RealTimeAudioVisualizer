module buffer_n #(parameter N = 16, data_width = 24)
	(
		input logic clk, en, rst,
		input logic signed [data_width - 1:0] data_in,
		output logic signed [data_width - 1:0] data_out
	);
	
	// Buffer
	logic [data_width - 1:0] buffer [0:N - 1];
	assign data_out = buffer[N - 1];			// Oldest sample from buffer
	
	integer buf_ctr;
	
	// On reset, buffer is filled with 0s, else buffer loads in new data and outputs oldest data sample
	always_ff @(posedge clk) begin
		if (rst) begin
			for (buf_ctr = 0; buf_ctr < N; buf_ctr++) begin
				buffer[buf_ctr] <= 0;
			end
		end else if (en) begin
			buffer[0] <= data_in;
			
			for (buf_ctr = 1; buf_ctr < N; buf_ctr++) begin
				buffer[buf_ctr] <= buffer[buf_ctr - 1];
			end
		end
	end
endmodule

module buffer_n_testbench();
	parameter N = 16, data_width = 24;
	logic clk, en, rst;
	logic signed [data_width - 1:0] data_in;
	logic signed [data_width - 1:0] data_out;
	
	buffer_n dut (.*);
	
	// Set up the clock
	integer ctr;
	parameter CLOCK_PERIOD = 100;
	
	initial begin
		ctr <= 0;
		clk <= 0;
		forever #(CLOCK_PERIOD / 2) clk <= ~clk;
	end
	
	initial begin
	rst <= 1'b1; en <= 1'b0; @(posedge clk);
	rst <= 1'b0; en <= 1'b1; @(posedge clk);
	
	
	repeat (2 * N) begin
		data_in <= ctr; ctr <= ctr + 1'b1; @(posedge clk);
	end
	
	$stop;
	end
endmodule
