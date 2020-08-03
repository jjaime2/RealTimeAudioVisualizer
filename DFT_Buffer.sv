module DFT_Buffer #(parameter N = 1024, data_width = 24, fp_width = 32, mag_width = 9, MAX_X = 640, MAX_Y = 480)
	(
		input logic clk, rst, ItoF_done, take_fft_sample,
		input logic [fp_width - 1:0] data_in,
		output logic [fp_width - 1:0] data_out,
		output logic start_fft
	);
	
	integer n;
	integer buf_ctr;
	
	logic [fp_width - 1:0] audio_buffer [0:N - 1];
	logic buffer_loaded, buffer_emptied;
	
	enum {init, load_buf, unload_buf} ps, ns;
	
	assign buffer_loaded = (ps == load_buf) && (n == N - 1);
	assign buffer_emptied = (ps == unload_buf) && (n == 0);
	
	always_comb begin
		case (ps)
			init: 		if (take_fft_sample) ns = load_buf;
							else						ns = init;
			load_buf:	if (buffer_loaded) 	ns = unload_buf;
							else						ns = load_buf;			
			unload_buf:	if (buffer_emptied)	ns = init;
							else						ns = unload_buf;
		endcase
	end
	
	always_ff @(posedge clk) begin
		if (rst) begin
			ps <= init;
		end else begin
			ps <= ns;
		end
	end
	
	always_ff @(posedge clk) begin
		if (ps == init) begin
			n <= 0;
		end
		
		if ((ps == load_buf) && ItoF_done) begin
			audio_buffer[0] <= data_in;
			n <= n + 1'b1;
			for (buf_ctr = 1; buf_ctr < N; buf_ctr++) begin
				audio_buffer[buf_ctr] <= audio_buffer[buf_ctr - 1];
			end
		end
		
		if (ps == unload_buf) begin
			start_fft <= 1'b1;
			data_out <= audio_buffer[N - 1];
			n <= n - 1'b1;
			for (buf_ctr = 1; buf_ctr < N; buf_ctr++) begin
				audio_buffer[buf_ctr] <= audio_buffer[buf_ctr - 1];
			end
		end
		
		if (start_fft) begin
			start_fft <= 1'b0;
		end
	end
	
endmodule

`timescale 1 ps / 1 ps
module DFT_Buffer_testbench();
	parameter N = 1024, data_width = 24, fp_width = 32, mag_width = 9, MAX_X = 640, MAX_Y = 480;
	
	logic clk, rst, ItoF_done, take_fft_sample;
	logic [fp_width - 1:0] data_in;
	logic [fp_width - 1:0] data_out;
	logic start_fft;
	
	DFT_Buffer dut (.*);
	
	// Set up the clock
	integer ctr;
	parameter CLOCK_PERIOD = 100;
	
	initial begin
		ctr <= 0;
		clk <= 0;
		forever #(CLOCK_PERIOD / 2) clk <= ~clk;
	end
	
	initial begin
		rst <= 1'b1; @(posedge clk);
		rst <= 1'b0; @(posedge clk);
		
		
		
		ItoF_done <= 1'b0; @(posedge clk);
		take_fft_sample <= 1'b1; @(posedge clk);
		
		repeat (16 * N) begin
			data_in <= ctr; ctr <= ctr + 1'b1; ItoF_done <= ~ItoF_done; @(posedge clk);
		end
		
		$stop;
	end
endmodule

