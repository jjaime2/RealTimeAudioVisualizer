// Jose Jaime
// 3/6/20
// EE 371
// Sample_Buffer Module
//
// Loads buffer with audio samples at the Audio CODEC's sampling frequency until full,
// once full, feeds audio samples into FFT at 50 MHz

module Sample_Buffer #(parameter N = 1024, data_width = 24, fp_width = 32, mag_width = 9, MAX_X = 640, MAX_Y = 480)
	(
		input logic clk, rst, ItoF_done, take_fft_sample,
		input logic [fp_width - 1:0] data_in,
		output logic [fp_width - 1:0] sample_data_out,
		output logic start_fft, sink_sop, sink_valid, sink_eop,
		output logic sample_idle, sample_load, sample_unload
	);
	
	integer n;
	integer buf_ctr;
	
	logic [fp_width - 1:0] audio_buffer [0:N - 1];
	logic buffer_loaded, buffer_emptied;
	
	enum {idle, load_buf, unload_buf} ps, ns;
	
	// Buffer status
	assign buffer_loaded = (ps == load_buf) && (n == N);
	assign buffer_emptied = (ps == unload_buf) && (n == -1);
	
	// State outputs for debugging
	assign sample_idle = (ps == idle);
	assign sample_load = (ps == load_buf);
	assign sample_unload = (ps == unload_buf);
	
	always_comb begin
		case (ps)
			idle: 		if (take_fft_sample) ns = load_buf;
							else						ns = idle;
			load_buf:	if (buffer_loaded) 	ns = unload_buf;
							else						ns = load_buf;			
			unload_buf:	if (buffer_emptied)	ns = idle;
							else						ns = unload_buf;
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
		// Empty Buffer
		if (ps == idle) begin
			n <= 0;
			start_fft <= 1'b0;
			sink_sop <= 1'b0;
			sink_valid <= 1'b0;
			sink_eop <= 1'b0;
			
			for (buf_ctr = 0; buf_ctr < N; buf_ctr++) begin
				audio_buffer[buf_ctr] <= 0;
			end
		end
		
		// Load Buffer
		if ((ps == load_buf) && ItoF_done) begin
			audio_buffer[0] <= data_in;
			n <= n + 1'b1;
			for (buf_ctr = 1; buf_ctr < N; buf_ctr++) begin
				audio_buffer[buf_ctr] <= audio_buffer[buf_ctr - 1];
			end
		end
		
		if (buffer_loaded) begin
			start_fft <= 1'b1;
		end
		
		if (start_fft) begin
			start_fft <= 1'b0;
		end
		
		// Unload Buffer
		if (ps == unload_buf) begin
			if (start_fft) begin
				sink_sop <= 1'b1;
				sink_valid <= 1'b1;
			end
			
			if (n == 1) begin
				sink_eop <= 1'b1;
			end
			
			sample_data_out <= audio_buffer[N - 1];
			n <= n - 1'b1;
			for (buf_ctr = 1; buf_ctr < N; buf_ctr++) begin
				audio_buffer[buf_ctr] <= audio_buffer[buf_ctr - 1];
			end
		end
		
		if (sink_sop) begin
			sink_sop <= 1'b0;
		end
		
		if (sink_eop) begin
			sink_eop <= 1'b0;
			sink_valid <= 1'b0;
		end
	end
	
endmodule

`timescale 1 ps / 1 ps
module Sample_Buffer_testbench();
	parameter N = 1024, data_width = 24, fp_width = 32, mag_width = 9, MAX_X = 640, MAX_Y = 480;
	
	logic clk, rst, ItoF_done, take_fft_sample;
	logic [fp_width - 1:0] data_in;
	logic [fp_width - 1:0] sample_data_out;
	logic start_fft, sink_sop, sink_valid, sink_eop;
	logic sample_idle, sample_load, sample_unload;
	
	Sample_Buffer dut (.*);
	
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

