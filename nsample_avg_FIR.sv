module nsample_avg_FIR #(parameter N = 16, data_width = 24)
	(
		input logic clk, en, rst,
		input logic signed [data_width - 1:0] data_in,
		output logic signed [data_width - 1:0] data_out
	);
	
	logic signed [data_width - 1:0] div_sample;			// Sample loaded from input divided by N
	logic signed [data_width - 1:0] oldest_sample;		// Oldest sample output from buffer
	logic signed [data_width - 1:0] adjust;				// Recalculation of average, (div_sample - oldest_sample)
	logic signed [data_width - 1:0] old_data_out;		// Data from previous cycle
	
	assign div_sample = (en) ? (data_in / N):0;
	assign adjust = div_sample - oldest_sample;
	assign data_out = old_data_out + adjust;
	
	// On reset, old_data_out is considered 0, else takes in current data on next clock cycle
	always_ff @(posedge clk) begin
		if (rst) begin
			old_data_out <= 0;
		end else if (data_out && en) begin
			old_data_out <= data_out;
		end else begin
			old_data_out <= 0;
		end
	end
	
	// Buffer that holds N data points
	buffer_n bn (clk, en, rst, div_sample, oldest_sample);
endmodule

module nsample_avg_FIR_testbench();
	parameter N = 16, data_width = 24;
	logic clk, en, rst;
	logic signed [data_width - 1:0] data_in;
	logic signed [data_width - 1:0] data_out;
	
	nsample_avg_FIR dut (.*);
	
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
		rst <= 1'b0; @(posedge clk);
		
		
		repeat (N**2) begin
			en <= 1'b1; data_in <= ctr + 3000; ctr <= ctr + 40; @(posedge clk);
		end
		
		$stop;
	end
endmodule