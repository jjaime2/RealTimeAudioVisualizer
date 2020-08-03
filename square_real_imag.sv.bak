module square_real_imag #(parameter N = 1024, K = 48000, fs = 48000, P = 10, data_width = 24, fp_width = 32)
	(
		input logic clk, rst, FFT_done,
		input logic [fp_width - 1:0] real_buffer_in [0:N - 1],
		input logic [fp_width - 1:0] imag_buffer_in [0:N - 1],
		output logic [fp_width - 1:0] magnitude_buffer [0:N - 1],
		output logic magnitude_done
	);
	
	integer n, m;
	
	logic start_square, start_sum, start_square_root;
	logic clk_en_square, clk_en_sum, clk_en_square_root;
	
	logic [fp_width - 1:0] curr_real_buffer [0:N - 1];
	logic [fp_width - 1:0] curr_imag_buffer [0:N - 1];
	
	// Current Data
	logic [fp_width - 1:0] curr_real_data_squared;
	logic [fp_width - 1:0] curr_imag_data_squared;
	logic [fp_width - 1:0] curr_sum_data;
	logic [fp_width - 1:0] curr_magnitude_data;
	
	// Current Buffers
	logic [fp_width - 1:0] curr_real_buffer_squared [0:N - 1];
	logic [fp_width - 1:0] curr_imag_buffer_squared [0:N - 1];
	logic [fp_width - 1:0] curr_sum_buffer [0:N - 1];
	logic [fp_width - 1:0] curr_magnitude_buffer [0:N - 1];

	logic square_real_done, square_imag_done, sum_done, square_root_done;
	
	floatingpoint square_real (.clk(clk), .clk_en(clk_en_square), .dataa(curr_real_buffer[n]), .datab(curr_real_buffer[n]),
									.n(4), .reset(rst), .reset_req(1'b0), .start(start_square),
									.done(square_real_done), .result(curr_real_data_squared));
									
	floatingpoint square_imag (.clk(clk), .clk_en(clk_en_square), .dataa(curr_imag_buffer[n]), .datab(curr_imag_buffer[n]),
									.n(4), .reset(rst), .reset_req(1'b0), .start(start_square),
									.done(square_imag_done), .result(curr_imag_data_squared));
									
//	floatingpoint sum_squares (.clk(clk), .clk_en(clk_en_sum), .dataa(curr_real_buffer_squared[n]), .datab(),
//									.n(5), .reset(rst), .reset_req(1'b0), .start(start_sum),
//									.done(sum_done), .result(curr_sum_data));
//									
//	floatingpoint square_root (.clk(clk), .clk_en(clk_en_square_root), .dataa(curr_sum_buffer[n]), .datab(curr_imag_buffer[n]),
//									.n(3), .reset(rst), .reset_req(1'b0), .start(start_square_root),
//									.done(square_root_done), .result(curr_magnitude_data));
	
	always_ff @(posedge clk) begin
		if (rst) begin
			clk_en_square <= 1'b0;
			clk_en_sum <= 1'b0;
			clk_en_square_root <= 1'b0;
			start_square <= 1'b0;
			start_sum <= 1'b0;
			start_square_root <= 1'b0;
		end
		
		if (FFT_done) begin
			curr_real_buffer <= real_buffer_in;
			curr_imag_buffer <= imag_buffer_in;
			n <= 0;
			clk_en_square <= 1'b1;
			start_square <= 1'b1;
		end
		
		if (start_square) begin
			start_square <= 1'b0;
		end
		
		if (square_real_done && n < N) begin
			n <= n + 1;
			clk_en_square <= 1'b1;
			start_square <= 1'b1;
			curr_real_buffer_squared[n] <= curr_real_data_squared;
		end
		
		if (square_imag_done) begin
			curr_imag_buffer_squared[n] <= curr_imag_data_squared;
		end
		
		if (square_real_done && n == N - 1) begin
			clk_en_square <= 1'b0;
			n <= 0;
		end
		
		
	end
endmodule

`timescale 1 ps / 1 ps
module square_real_imag_testbench();
	parameter N = 1024, K = 48000, fs = 48000, P = 10, data_width = 24, fp_width = 32;
	
	logic clk, rst, FFT_done;
	logic [fp_width - 1:0] real_buffer_in [0:N - 1];
	logic [fp_width - 1:0] imag_buffer_in [0:N - 1];
	logic [fp_width - 1:0] magnitude_buffer [0:N - 1];
	logic magnitude_done;
	
	find_magnitude dut (.*);
	
	// Set up the clock
	parameter CLOCK_PERIOD = 100;
	
	integer i;
	
	initial begin
		for (i = 0; i < N; i++) begin
			real_buffer_in[i] = i << 23;
			imag_buffer_in[i] = i << 23;
		end
		clk <= 0;
		forever #(CLOCK_PERIOD / 2) clk <= ~clk;
	end
	
	initial begin
		rst <= 1'b1; @(posedge clk);
		rst <= 1'b0; @(posedge clk);
		
		FFT_done <= 1'b0; @(posedge clk);
		FFT_done <= 1'b1; @(posedge clk);
		FFT_done <= 1'b0; @(posedge clk);
		
		repeat (4 * N) begin
			@(posedge clk);
		end
		
		$stop;
	end
endmodule
