module fft_N1024 #(parameter N = 1024, data_width = 24, fp_width = 32, mag_width = 9, MAX_X = 640, MAX_Y = 480)
	(
		input logic clk, rst, start_fft,
		input logic [fp_width - 1:0] real_data_in,
		output logic [fp_width - 1:0] real_data_out,
		output logic [fp_width - 1:0] imag_data_out,
		output logic source_valid, source_eop
	);
	
	integer n;
	logic sink_valid;
	logic sink_sop, sink_eop;
	logic source_sop;
	logic [fp_width - 1:0] curr_real_data_in;
	logic [fp_width - 1:0] curr_real_data_out, curr_imag_data_out;
	
	enum {idle, load_fft, unload_fft} ps, ns;
	
	assign sink_valid = (ps == load_fft);
	assign sink_eop = (ps == load_fft) && (n == N - 1);
	
	fft ft (.clk(clk), .reset_n(~rst), 
				.sink_valid(sink_valid), .sink_ready(sink_valid), .sink_error(0), .sink_sop(sink_sop), .sink_eop(sink_eop), 
				.sink_real(real_data_in), .sink_imag(0), .fftpts_in(1024),
				.source_valid(source_valid), .source_ready(1'b1), .source_error(), .source_sop(source_sop), .source_eop(source_eop),
				.source_real(real_data_out), .source_imag(imag_data_out), .fftpts_out());
	
	always_comb begin
		case (ps)
			idle:			if (start_fft) 	ns = load_fft;
							else 					ns = idle;
			load_fft:	if (sink_eop)		ns = unload_fft;
							else 					ns = load_fft;
			unload_fft:	if (source_eop)	ns = idle;
							else					ns = unload_fft;
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
			sink_sop <= 1'b0;
		end
		
		if (ps == idle) begin
			n <= 0;
		end
		
		if (start_fft) begin
			sink_sop <= 1'b1;
		end
		
		if (sink_sop) begin
			sink_sop <= 1'b0;
		end
		
		if (ps == load_fft) begin
			n <= n + 1'b1;
		end
		
		if (sink_eop) begin
			n <= 0;
		end
//		
//		if (source_eop) begin
//			n <= 0;
//			FFT_done <= 1'b1;
//		end else begin
//			FFT_done <= 1'b0;
//		end
	end
endmodule

`timescale 1 ps / 1 ps
module fft_testbench();
	parameter N = 1024, data_width = 24, fp_width = 32, mag_width = 9, MAX_X = 640, MAX_Y = 480;
	
	logic clk, rst, start_fft;
	logic [fp_width - 1:0] real_data_in;
	logic [fp_width - 1:0] real_data_out;
	logic [fp_width - 1:0] imag_data_out;
	logic source_valid, source_eop;
	
	fft_N1024 dut (.*);
	
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
		
		real_data_in <= 0; @(posedge clk);
		start_fft <= 1'b1; @(posedge clk);
		start_fft <= 1'b0; @(posedge clk);
		
		repeat (4 * N) begin
			real_data_in <= ctr << 19; @(posedge clk);
		end
		
		$stop;
	end
endmodule
