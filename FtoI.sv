// Jose Jaime
// 3/6/20
// EE 371
// FtoI Module
//
// Converts Floats into Integers by implementing the Nios II floatingpoint IP Catalog

module FtoI #(parameter N = 1024, data_width = 24, fp_width = 32, mag_width = 9, MAX_X = 640, MAX_Y = 480)
	(
		input logic clk, rst, square_root_done,
		input logic [fp_width - 1:0] square_root_data_in,
		output logic [fp_width - 1:0] magnitude_data_out,
		output logic FtoI_done,
		output logic FtoI_idle, FtoI_processing
	);
	
	logic clk_en_FtoI;
	logic start_FtoI;
	logic [fp_width - 1:0] curr_square_root_data_in;
	
	enum {idle, processing} ps, ns;
	
	// Signal start of valid data output
	assign clk_en_FtoI = (ps == processing);
	
	assign FtoI_idle = (ps == idle);
	assign FtoI_processing = (ps == processing);
	
	floatingpoint FtoI1 (.clk(clk), .clk_en(clk_en_FtoI), .dataa(curr_square_root_data_in), .datab(0),
									.n(1), .reset(rst), .reset_req(1'b0), .start(start_FtoI),
									.done(FtoI_done), .result(magnitude_data_out));
	
	always_comb begin
		case (ps)
			idle:			if (square_root_done)	ns = processing;
							else 							ns = idle;
			processing:	if (FtoI_done)				ns = idle;
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
			start_FtoI <= 1'b0;
		end
		
		// Signal start of data pipeline
		if ((ps == idle) && square_root_done) begin
			curr_square_root_data_in <= square_root_data_in;
			start_FtoI <= 1'b1;
		end
		
		if (start_FtoI) begin
			start_FtoI <= 1'b0;
		end
	end
endmodule
	
`timescale 1 ps / 1 ps
module FtoI_testbench();
	parameter N = 1024, data_width = 24, fp_width = 32, mag_width = 9, MAX_X = 640, MAX_Y = 480;
	
	logic clk, rst, square_root_done;
	logic [fp_width - 1:0] square_root_data_in;
	logic [fp_width - 1:0] magnitude_data_out;
	logic FtoI_done;
	logic FtoI_idle, FtoI_processing;
	
	FtoI dut (.*);
	
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
		
		square_root_done <= 1'b0; @(posedge clk);
		
		repeat (8 * N) begin
			square_root_done <= ~square_root_done; square_root_data_in <= ctr << 18; ctr <= ctr + 1; @(posedge clk);
		end
		
		$stop;
	end
endmodule
