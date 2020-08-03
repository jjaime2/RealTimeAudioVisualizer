// Jose Jaime
// 3/6/20
// EE 371
// square_root Module
//
// Finds the square root of a float by implementing the Nios II floatingpoint IP Catalog

module square_root #(parameter N = 1024, data_width = 24, fp_width = 32, mag_width = 9, MAX_X = 640, MAX_Y = 480)
	(
		input logic clk, rst, sum_done,
		input logic [fp_width - 1:0] sum_data_in,
		output logic [fp_width - 1:0] square_root_data_out,
		output logic square_root_done
	);
	
	integer n;
	
	logic start_square_root;
	logic clk_en_square_root;
	logic [fp_width - 1:0] curr_sum_data_in;
	
	enum {idle, processing} ps, ns;
	
	// Signal span of valid data output
	assign clk_en_square_root = (ps == processing);
	
	floatingpoint sqrt (.clk(clk), .clk_en(clk_en_square_root), .dataa(curr_sum_data_in), .datab(),
									.n(3), .reset(rst), .reset_req(1'b0), .start(start_square_root),
									.done(square_root_done), .result(square_root_data_out));
									
	always_comb begin
		case (ps)
			idle:			if (sum_done)				ns = processing;
							else 							ns = idle;
			processing:	if (square_root_done)	ns = idle;
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
			start_square_root <= 1'b0;
		end
		
		// Signal start of data pipeline
		if ((ps == idle) && sum_done) begin
			curr_sum_data_in <= sum_data_in;
			start_square_root <= 1'b1;
		end
		
		if (start_square_root) begin
			start_square_root <= 1'b0;
		end
	end	
endmodule

`timescale 1 ps / 1 ps
module square_root_testbench();
	parameter N = 1024, data_width = 24, fp_width = 32, mag_width = 9, MAX_X = 640, MAX_Y = 480;
	
	logic clk, rst, sum_done;
	logic [fp_width - 1:0] sum_data_in;
	logic [fp_width - 1:0] square_root_data_out;
	logic square_root_done;
	
	square_root dut (.*);
	
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
		
		sum_done <= 1'b0; @(posedge clk);
		
		repeat (4 * N) begin
			sum_done <= ~sum_done; sum_data_in <= ctr << 19; ctr <= ctr + 1;@(posedge clk);
		end
		
		$stop;
	end
endmodule
