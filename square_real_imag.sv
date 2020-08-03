// Jose Jaime
// 3/6/20
// EE 371
// square_real_imag Module
//
// Finds the square of a real and imaginary input by implementing the Nios II floatingpoint IP Catalog

module square_real_imag #(parameter N = 1024, data_width = 24, fp_width = 32, mag_width = 9, MAX_X = 640, MAX_Y = 480)
	(
		input logic clk, rst, data_valid,
		input logic [fp_width - 1:0] real_data_in,
		input logic [fp_width - 1:0] imag_data_in,
		output logic [fp_width - 1:0] real_data_squared_out,
		output logic [fp_width - 1:0] imag_data_squared_out,
		output logic square_done
	);
	
	logic start_square;
	logic clk_en_square;
	logic square_imag_done;
	
	logic [fp_width - 1:0] curr_real_data_in;
	logic [fp_width - 1:0] curr_imag_data_in;
	
	enum {idle, processing} ps, ns;
	
	// Signal span of valid data output
	assign clk_en_square = (ps == processing);
	
	floatingpoint square_real (.clk(clk), .clk_en(clk_en_square), .dataa(curr_real_data_in), .datab(curr_real_data_in),
									.n(4), .reset(rst), .reset_req(1'b0), .start(start_square),
									.done(square_done), .result(real_data_squared_out));
									
	floatingpoint square_imag (.clk(clk), .clk_en(clk_en_square), .dataa(curr_imag_data_in), .datab(curr_imag_data_in),
									.n(4), .reset(rst), .reset_req(1'b0), .start(start_square),
									.done(square_imag_done), .result(imag_data_squared_out));
	
	always_comb begin
		case (ps)
			idle:			if (data_valid)			ns = processing;
							else 							ns = idle;
			processing:	if (square_done)			ns = idle;
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
			start_square <= 1'b0;
		end
		
		// Signal start of data pipeline
		if ((ps == idle) && data_valid) begin
			curr_real_data_in <= real_data_in;
			curr_imag_data_in <= imag_data_in;
			start_square <= 1'b1;
		end
		
		if (start_square) begin
			start_square <= 1'b0;
		end
	end
endmodule

`timescale 1 ps / 1 ps
module square_real_imag_testbench();
	parameter N = 1024, data_width = 24, fp_width = 32, mag_width = 9, MAX_X = 640, MAX_Y = 480;
	
	logic clk, rst, data_valid;
	logic [fp_width - 1:0] real_data_in;
	logic [fp_width - 1:0] imag_data_in;
	logic [fp_width - 1:0] real_data_squared_out;
	logic [fp_width - 1:0] imag_data_squared_out;
	logic square_done;
	
	square_real_imag dut (.*);
	
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
		
		data_valid <= 1'b0; @(posedge clk);
		
		repeat (4 * N) begin
			data_valid <= ~data_valid; real_data_in <= ctr << 19; imag_data_in <= ctr << 19; ctr <= ctr + 1; @(posedge clk);
		end
		
		$stop;
	end
endmodule
