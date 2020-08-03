// Jose Jaime
// 3/6/20
// EE 371
// ItoF Module
//
// Converts Integers into Floats by implementing the Nios II floatingpoint IP Catalog

module ItoF #(parameter N = 1024, data_width = 24, fp_width = 32, mag_width = 9, MAX_X = 640, MAX_Y = 480)
	(
		input logic clk, rst, read,
		input logic [data_width - 1:0] data_in,
		output logic [fp_width - 1:0] ItoF_data,
		output logic ItoF_done
	);
	
	// Control Flags
	logic start_ItoF;
	logic clk_en_ItoF;
	
	// Current Sample
	logic [data_width - 1:0] curr_sample;
	
	enum {idle, processing} ps, ns;
	
	// Signal span of valid data output
	assign clk_en_ItoF = (ps == processing);
	
	floatingpoint ItoF1 (.clk(clk), .clk_en(clk_en_ItoF), .dataa({{8{curr_sample[data_width - 1]}}, curr_sample}), .datab(0),
									.n(2), .reset(rst), .reset_req(1'b0), .start(start_ItoF),
									.done(ItoF_done), .result(ItoF_data));
	
	always_comb begin
		case (ps)
			idle:			if (read)					ns = processing;
							else 							ns = idle;
			processing:	if (ItoF_done)				ns = idle;
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
			start_ItoF <= 1'b0;
		end
		
		// Signal start of data pipeline
		if ((ps == idle) && read) begin
			curr_sample <= data_in;
			start_ItoF <= 1'b1;
		end
		
		if (start_ItoF) begin
			start_ItoF <= 1'b0;
		end
	end
endmodule
	
`timescale 1 ps / 1 ps
module ItoF_testbench();
	parameter N = 1024, data_width = 24, fp_width = 32, mag_width = 9, MAX_X = 640, MAX_Y = 480;
	
	logic clk, rst, read;
	logic [data_width - 1:0] data_in;
	logic [fp_width - 1:0] ItoF_data;
	logic ItoF_done;
	
	ItoF dut (.*);
	
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
		
		read <= 1'b1; @(posedge clk);
		
		repeat (500) begin
			read <= ~read; data_in <= ctr; ctr <= ctr + 1'b1; @(posedge clk);
		end
		
		$stop;
	end
endmodule
