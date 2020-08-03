// Jose Jaime
// 3/6/20
// EE 371
// sum_real_imag Module
//
// Finds the sum of two floats by implementing the Nios II floatingpoint IP Catalog

module sum_real_imag #(parameter N = 1024, data_width = 24, fp_width = 32, mag_width = 9, MAX_X = 640, MAX_Y = 480)
	(
		input logic clk, rst, square_done,
		input logic [fp_width - 1:0] real_data_squared_in,
		input logic [fp_width - 1:0] imag_data_squared_in,
		output logic [fp_width - 1:0] sum_data_out,
		output logic sum_done
	);
	
	logic start_sum;
	logic clk_en_sum;
	logic [fp_width - 1:0] curr_real_data_squared_in;
	logic [fp_width - 1:0] curr_imag_data_squared_in;
	
	enum {idle, processing} ps, ns;
	
	// Signal span of valid data output
	assign clk_en_sum = (ps == processing);
	
	floatingpoint sum_squares (.clk(clk), .clk_en(clk_en_sum), .dataa(curr_real_data_squared_in), .datab(curr_imag_data_squared_in),
									.n(5), .reset(rst), .reset_req(1'b0), .start(start_sum),
									.done(sum_done), .result(sum_data_out));
	
	always_comb begin
		case (ps)
			idle:			if (square_done)			ns = processing;
							else 							ns = idle;
			processing:	if (sum_done)				ns = idle;
							else							ns = processing;
		endcase
	end
	
	always_ff @(posedge clk) begin
		if (rst) begin
			ps <= idle;
		end else begin
			ps <= ns;
		end
	end
	
	always_ff @(posedge clk) begin
		if (rst) begin
			start_sum <= 1'b0;
		end
		
		// Signal start of data pipeline
		if ((ps == idle) && square_done) begin
			curr_real_data_squared_in <= real_data_squared_in;
			curr_imag_data_squared_in <= imag_data_squared_in;
			start_sum <= 1'b1;
		end
		
		if (start_sum) begin
			start_sum <= 1'b0;
		end
	end
endmodule

`timescale 1 ps / 1 ps
module sum_real_imag_testbench();
	parameter N = 1024, data_width = 24, fp_width = 32, mag_width = 9, MAX_X = 640, MAX_Y = 480;
	
	logic clk, rst, square_done;
	logic [fp_width - 1:0] real_data_squared_in;
	logic [fp_width - 1:0] imag_data_squared_in;
	logic [fp_width - 1:0] sum_data_out;
	logic sum_done;
	
	sum_real_imag dut (.*);
	
	// Set up the clock
	parameter CLOCK_PERIOD = 100;
	
	integer ctr;
	
	initial begin
		ctr <= 0;
		clk <= 0;
		forever #(CLOCK_PERIOD / 2) clk <= ~clk;
	end
	
	initial begin
		rst <= 1'b1; @(posedge clk);
		rst <= 1'b0; @(posedge clk);
		
		square_done <= 1'b0; @(posedge clk);
		
		repeat (4 * N) begin
			square_done <= ~square_done; real_data_squared_in <= ctr << 19; imag_data_squared_in <= ctr << 19; ctr <= ctr + 1; @(posedge clk);
		end
		
		$stop;
	end
endmodule
