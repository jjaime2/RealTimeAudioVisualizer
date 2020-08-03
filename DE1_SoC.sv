// Jose Jaime
// 3/6/20
// EE 371
// DE1_SoC Module
//
// Top-Level Module which manages the data transfer and over-arching control path of the
// Real-Time Audio Frequency Visualizer

module DE1_SoC #(parameter N = 1024, data_width = 24, fp_width = 32, mag_width = 10, MAX_X = 640, MAX_Y = 480)
	(
		CLOCK_50, CLOCK2_50, FPGA_I2C_SCLK, FPGA_I2C_SDAT,
		AUD_XCK, AUD_DACLRCK, AUD_ADCLRCK, AUD_BCLK, AUD_ADCDAT, AUD_DACDAT,
		VGA_R, VGA_G, VGA_B, VGA_BLANK_N, VGA_CLK, VGA_HS, VGA_SYNC_N, VGA_VS,
		KEY, SW, HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, LEDR
	);

	input logic CLOCK_50, CLOCK2_50;
	input logic [3:0] KEY;
	input logic [9:0] SW;
	output logic [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
	output logic [9:0] LEDR;
	
	// I2C Audio/Video config interface
	output FPGA_I2C_SCLK;
	inout FPGA_I2C_SDAT;
	
	// Audio CODEC
	output AUD_XCK;
	input AUD_DACLRCK, AUD_ADCLRCK, AUD_BCLK;
	input AUD_ADCDAT;
	output AUD_DACDAT;
	
	// VGA Framebuffer
	output [7:0] VGA_R;
	output [7:0] VGA_G;
	output [7:0] VGA_B;
	output VGA_BLANK_N;
	output VGA_CLK;
	output VGA_HS;
	output VGA_SYNC_N;
	output VGA_VS;
	
	// Audio CODEC Wires
	logic read_ready, write_ready, read, write;
	logic signed [data_width - 1:0] readdata_left, readdata_right;
	logic signed [data_width - 1:0] writedata_left, writedata_right;
	logic reset;
	
	assign writedata_right = readdata_right;
	
	// Int to Float Wires
	logic [fp_width - 1:0] ItoF_data;
	logic ItoF_done;
	
	// Sample Buffer Wires
	logic take_fft_sample;
	logic [fp_width - 1:0] sample_data;
	logic start_fft, sink_sop, sink_valid, sink_eop;
	
	// FFT Wires
	logic [fp_width - 1:0] real_data;
	logic [fp_width - 1:0] imag_data;
	logic source_sop, source_valid, source_eop;
	
	// FFT Buffer Wires
	logic [fp_width - 1:0] sample_real_data;
	logic [fp_width - 1:0] sample_imag_data;
	logic data_valid;
	
	// Square Wires
	logic [fp_width - 1:0] real_data_squared;
	logic [fp_width - 1:0] imag_data_squared;
	logic square_done;
	
	// Sum Wires
	logic [fp_width - 1:0] sum_data;
	logic sum_done;
	
	// Square Root Wires
	logic [fp_width - 1:0] square_root_data;
	logic square_root_done;
	
	// Float to Int Wires
	logic [fp_width - 1:0] magnitude_data;
	logic FtoI_done;
	
	// Magnitude of Frequency Spectrum Buffer Scaled for display
	logic [8:0] curr_magnitude_buffer [0:(N / 2) - 1];
	
	// VGA Framebuffer Wires
	logic [9:0] x0, x1, x;
	logic [8:0] y0, y1, y;
	logic frame_start;
	logic pixel_color;
	logic draw_done;
	
	// State Wires
	logic sample_idle, sample_load, sample_unload, fft_load, fft_send, fft_wait, FtoI_idle, FtoI_processing, draw_state, clear_state;
	
	// Clock Divider
	logic [31:0] CLK;
	
	parameter whichClock = 18;
	clock_divider cdiv (CLOCK_50, CLK);

	assign reset = ~KEY[3];
	assign {HEX0, HEX1, HEX2, HEX3, HEX4, HEX5} = '1;
	
	assign LEDR[9] = 0;
	assign LEDR[8] = 0;
	assign LEDR[7] = 0;
	assign LEDR[6] = 0;
	assign LEDR[5] = draw_state;
	assign LEDR[4] = clear_state;
	assign LEDR[3] = FtoI_idle;
	assign LEDR[2] = FtoI_processing;
	assign LEDR[1] = (ps == idle);
	assign LEDR[0] = (ps == processing);

	
	assign read = read_ready & write_ready;
	assign write = read_ready & write_ready;
	
	// Master Control Path
	enum {idle, processing} ps, ns;
	
	integer curr_n;
	
	logic load_mag_buf;
	logic process_done;
	logic is_idle;
	
	assign load_mag_buf = (ps == processing) && FtoI_done;
	assign process_done = load_mag_buf && (curr_n == (N / 2) - 1);
	assign is_idle = (ps == idle);
	
	always_comb begin
		case (ps)
			idle:				if (start_fft)			ns = processing;
								else 						ns = idle;
			processing:		if (process_done) 	ns = idle;
								else						ns = processing;
			default:										ns = idle;
		endcase
	end
	
	// Master Data Path
	always_ff @(posedge CLOCK_50) begin
		if (reset) begin
			ps <= idle;
		end else begin
			ps <= ns;
		end
	end
	
	always_ff @(posedge CLOCK_50) begin
		if ((ps == idle) || reset) begin
			curr_n <= 0;
		end
		
		if (load_mag_buf) begin 
			curr_magnitude_buffer[curr_n] <= (magnitude_data[8:0] >> 2);
			curr_n <= curr_n + 1'b1;
		end
	end
	
	
/////////////////////////////////////////////////////////////////////////////////
// userInput Module
// 
// - Limit sample requests to once per button press
/////////////////////////////////////////////////////////////////////////////////	

	userInput ui (.CLK(CLOCK_50), .RST(reset), .IN(~KEY[2]), .OUT(take_fft_sample));

/////////////////////////////////////////////////////////////////////////////////
// Audio CODEC interface. 
//
// The interface consists of the following wires:
// read_ready, write_ready - CODEC ready for read/write operation 
// readdata_left, readdata_right - left and right channel data from the CODEC
// read - send data from the CODEC (both channels)
// writedata_left, writedata_right - left and right channel data to the CODEC
// write - send data to the CODEC (both channels)
// AUD_* - should connect to top-level entity I/O of the same name.
//         These signals go directly to the Audio CODEC
// I2C_* - should connect to top-level entity I/O of the same name.
//         These signals go directly to the Audio/Video Config module
/////////////////////////////////////////////////////////////////////////////////
	clock_generator my_clock_gen(
		// inputs
		CLOCK2_50,
		1'b0,

		// outputs
		AUD_XCK
	);

	audio_and_video_config cfg(
		// Inputs
		CLOCK_50,
		1'b0,

		// Bidirectionals
		FPGA_I2C_SDAT,
		FPGA_I2C_SCLK
	);

	audio_codec codec(
		// Inputs
		CLOCK_50,
		1'b0,

		read,	write,
		writedata_left, writedata_right,

		AUD_ADCDAT,

		// Bidirectionals
		AUD_BCLK,
		AUD_ADCLRCK,
		AUD_DACLRCK,

		// Outputs
		read_ready, write_ready,
		readdata_left, readdata_right,
		AUD_DACDAT
	);
	
/////////////////////////////////////////////////////////////////////////////////
// Int to Float Conversion
//
// - Conversion from Int to Single Point Float
/////////////////////////////////////////////////////////////////////////////////

	ItoF itof (.clk(CLOCK_50), .rst(reset), .read(read), .data_in(readdata_right), .ItoF_data(ItoF_data), .ItoF_done(ItoF_done)); 
	
/////////////////////////////////////////////////////////////////////////////////
// Sample Buffer
//
// - Allows forward and inverse data I/O
// - Take sample of audio signal on user's input
/////////////////////////////////////////////////////////////////////////////////
	
	Sample_Buffer sb (.clk(CLOCK_50), .rst(reset), .ItoF_done(ItoF_done), .take_fft_sample(take_fft_sample || (draw_done)), 
						.data_in(ItoF_data), .sample_data_out(sample_data), .start_fft(start_fft),
						.sink_sop(sink_sop), .sink_valid(sink_valid), .sink_eop(sink_eop),
						.sample_idle(sample_idle), .sample_load(sample_load), .sample_unload(sample_unload));
	
/////////////////////////////////////////////////////////////////////////////////
// FFT
//
// - Sample Size = 1024
/////////////////////////////////////////////////////////////////////////////////

	fft FFT_N1024 (.clk(CLOCK_50), .reset_n(~reset), 
				.sink_valid(sink_valid), .sink_ready(), .sink_error(0), .sink_sop(sink_sop), .sink_eop(sink_eop), 
				.sink_real(sample_data), .sink_imag(), .fftpts_in(1024),
				.source_valid(source_valid), .source_ready(1'b1), .source_error(), .source_sop(source_sop), .source_eop(source_eop),
				.source_real(real_data), .source_imag(imag_data), .fftpts_out());
				
/////////////////////////////////////////////////////////////////////////////////
// FFT Buffer
//
// - Allows forward and inverse data I/O
// - Take sample of FFT results as they are output
/////////////////////////////////////////////////////////////////////////////////
	
	FFT_Buffer fb (.clk(CLOCK_50), .rst(reset), .source_valid(source_valid), .source_eop(source_eop), .FtoI_done(FtoI_done), .curr_n(curr_n),
						.real_data_in(real_data), .imag_data_in(imag_data), 
						.sample_real_data_out(sample_real_data), .sample_imag_data_out(sample_imag_data), .data_valid(data_valid),
						.fft_load(fft_load), .fft_send(fft_send), .fft_wait(fft_wait));
						
/////////////////////////////////////////////////////////////////////////////////
// Find Magnitude
//
// - Magnitude = sqrt(real^2 + imag^2)
/////////////////////////////////////////////////////////////////////////////////

	square_real_imag sri (.clk(CLOCK_50), .rst(reset), .data_valid(data_valid), .real_data_in(sample_real_data), .imag_data_in(sample_imag_data),
							.real_data_squared_out(real_data_squared), .imag_data_squared_out(imag_data_squared), .square_done(square_done));
							
	sum_real_imag sum_ri (.clk(CLOCK_50), .rst(reset), .square_done(square_done), .real_data_squared_in(real_data_squared), .imag_data_squared_in(imag_data_squared),
								.sum_data_out(sum_data), .sum_done(sum_done));
								
	square_root sq (.clk(CLOCK_50), .rst(reset), .sum_done(sum_done), .sum_data_in(sum_data),
								.square_root_data_out(square_root_data), .square_root_done(square_root_done));
								
/////////////////////////////////////////////////////////////////////////////////		
// Float to Int Conversion
//
// - Conversion to Single Point Float to Int
/////////////////////////////////////////////////////////////////////////////////

	FtoI ftoi (.clk(CLOCK_50), .rst(reset), .square_root_done(square_root_done), .square_root_data_in(square_root_data), .magnitude_data_out(magnitude_data),
					.FtoI_done(FtoI_done), .FtoI_idle(FtoI_idle), .FtoI_processing(FtoI_processing));

/////////////////////////////////////////////////////////////////////////////////
// VGA Framebuffer
//
// - Draw frequency spectrum after a sample request is processed
/////////////////////////////////////////////////////////////////////////////////

	VGA_framebuffer framebuf (.clk(CLOCK_50), .rst(1'b0), .x, .y,
				.pixel_color, .pixel_write(1'b1), .frame_start,
				.VGA_R, .VGA_G, .VGA_B, .VGA_CLK, .VGA_HS, .VGA_VS,
				.VGA_BLANK_N, .VGA_SYNC_N);
				
	line_drawer lines (.clk(CLOCK_50), .reset, .is_idle, .pixel_color, .draw_done,
				.curr_peak(curr_magnitude_buffer[x]), .x, .y, .draw_state, .clear_state);

endmodule

// divided_clocks[0] = 25MHz, [1] = 12.5MHz, ... [23] = 3Hz, [24] = 1.5Hz,
// [25] = 0.75Hz, ...
module clock_divider (CLK, divided_clocks);
		input logic CLK;
		output logic [31:0] divided_clocks;
		
		initial begin
			divided_clocks <= 0;
		end
		
		always_ff @(posedge CLK) begin
			divided_clocks <= divided_clocks + 1;
		end
endmodule
