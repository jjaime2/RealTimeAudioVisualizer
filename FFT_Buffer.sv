// Jose Jaime
// 3/6/20
// EE 371
// FFT_Buffer Module
//
// Loads in real and imaginary FFT output until full,
// once full, sends pair of samples one at a time through arithmetic pipeline to find magnitude of a particular frequency until empty.

module FFT_Buffer #(parameter N = 1024, data_width = 24, fp_width = 32, mag_width = 9, MAX_X = 640, MAX_Y = 480)
	(
		input logic clk, rst, source_valid, source_eop, FtoI_done,
		input logic [31:0] curr_n,
		input logic [fp_width - 1:0] real_data_in,
		input logic [fp_width - 1:0] imag_data_in,
		output logic [fp_width - 1:0] sample_real_data_out,
		output logic [fp_width - 1:0] sample_imag_data_out,
		output logic data_valid,
		output logic fft_load, fft_send, fft_wait
	);
	
	integer n;
	integer buf_ctr;
	
	logic start_process;
	logic [fp_width - 1:0] real_buffer [0:(N / 2) - 1];
	logic [fp_width - 1:0] imag_buffer [0:(N / 2) - 1];
	
	assign fft_load = (ps == load_on_valid);
	assign fft_send = (ps == send_sample);
	assign fft_wait = (ps == wait_for_arithmetic);
	
	enum {load_on_valid, send_sample, wait_for_arithmetic} ps, ns;
	
	
	always_comb begin
		case (ps)
			load_on_valid:			if (source_eop) 				ns = send_sample;
										else								ns = load_on_valid;			
			send_sample:			if (curr_n == N/2 - 1)		ns = load_on_valid;
										else 								ns = wait_for_arithmetic;
			wait_for_arithmetic:	if (FtoI_done)					ns = send_sample;
										else								ns = wait_for_arithmetic;
		endcase
	end
	
	always_ff @(posedge clk) begin
		if (rst) begin
			ps <= load_on_valid;
		end else begin
			ps <= ns;
		end
	end
	
	always_ff @(posedge clk) begin
		if ((ps == load_on_valid) || rst) begin
			n <= 0;
		end
		
		// Load Buffer when data source is valid
		if ((ps == load_on_valid) && source_valid) begin
			n <= n + 1;
			
			if (n < (N / 2)) begin
				real_buffer[0] <= real_data_in;
				imag_buffer[0] <= imag_data_in;
				for (buf_ctr = 1; buf_ctr < (N / 2); buf_ctr++) begin
					real_buffer[buf_ctr] <= real_buffer[buf_ctr - 1];
					imag_buffer[buf_ctr] <= imag_buffer[buf_ctr - 1];
				end
			end
		end
		
		if ((ps == load_on_valid) && source_eop) begin
			start_process <= 1'b1;
		end
		
		if ((ps == wait_for_arithmetic) && FtoI_done) begin
			start_process <= 1'b1;
		end

		if (start_process) begin
			start_process <= 1'b0;
		end
		
		// Send data sample when not currently processing another sample
		if ((ps == send_sample) && start_process) begin
			sample_real_data_out <= real_buffer[(N / 2) - 1];
			sample_imag_data_out <= imag_buffer[(N / 2) - 1];
			data_valid <= 1'b1;			
			for (buf_ctr = 1; buf_ctr < (N / 2); buf_ctr++) begin
				real_buffer[buf_ctr] <= real_buffer[buf_ctr - 1];
				imag_buffer[buf_ctr] <= imag_buffer[buf_ctr - 1];
			end
		end else begin
			data_valid <= 1'b0;
		end
	end
	
endmodule

`timescale 1 ps / 1 ps
module FFT_Buffer_testbench();
	parameter N = 1024, data_width = 24, fp_width = 32, mag_width = 9, MAX_X = 640, MAX_Y = 480;
	
	logic clk, rst, source_valid, source_eop, FtoI_done;
	logic [31:0] curr_n;
	logic [fp_width - 1:0] real_data_in;
	logic [fp_width - 1:0] imag_data_in;
	logic [fp_width - 1:0] sample_real_data_out;
	logic [fp_width - 1:0] sample_imag_data_out;
	logic data_valid;
	logic fft_load, fft_send, fft_wait;
	
	FFT_Buffer dut (.*);
	
	// Set up the clock
	parameter CLOCK_PERIOD = 100;
	
	initial begin
		clk <= 0;
		forever #(CLOCK_PERIOD / 2) clk <= ~clk;
	end
	
	initial begin
		rst <= 1'b1; @(posedge clk);
		rst <= 1'b0; @(posedge clk);
		
		real_data_in <= 1'b0; imag_data_in <= 1'b0; source_valid <= 1'b1; curr_n <= 0; @(posedge clk);
		
		repeat (N) begin
			
			if (curr_n == N - 2) begin
				source_eop <= 1'b1; real_data_in <= real_data_in + 1; imag_data_in <= imag_data_in + 1; curr_n <= curr_n + 1; @(posedge clk);
			end else begin
				real_data_in <= real_data_in + 1; imag_data_in <= imag_data_in + 1; curr_n <= curr_n + 1; @(posedge clk);
			end
			
			if (source_eop) begin
				source_eop <= 1'b0; source_valid <= 1'b0; @(posedge clk);
			end
		end
		
		repeat (3*N) begin
			@(posedge clk);
		end
		
		$stop;
	end
endmodule

