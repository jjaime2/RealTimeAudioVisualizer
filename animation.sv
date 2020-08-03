// Jose Jaime
// 2/5/20
// EE 371
// animation Module
//
// Uses the line_drawer module to create an animation using lines with different coordinates
module animation #(parameter N = 1024, data_width = 24, fp_width = 32, mag_width = 10, MAX_X = 640, MAX_Y = 480)
	(
		input logic clk, reset, process_done, clear_done,
		input logic [8:0] curr_magnitude_buffer [0:(N / 2) - 1],
		output logic pixel_color,
		output logic [9:0] x0, x1,
		output logic [8:0] y0, y1,
		output logic drawDone
	);
	
	logic [1:0] counter;
	
	always_ff @(posedge clk) begin
		if (reset || process_done) begin
			pixel_color <= 1'b0;
			counter <= 1'b0;
			x0 <= 0;
			x1 <= 0;
			y0 <= 480;
			y1 <= 480;
		end else begin
			counter <= counter + 1'b1;
			if (counter == 2'b00) begin				
				if (x0 >= 0 && x0 < (N / 2)) begin
					drawDone <= 1'b0;
					pixel_color <= 1'b1;
					x0 <= x0 + 1'b1;
					x1 <= x1 + 1'b1;
					
					if (curr_magnitude_buffer[x0] > 479) begin
						y1 <= 0;
					end else begin
						y1 <= 479 - curr_magnitude_buffer[x0];
					end
				end else begin
					x0 <= 0;
					x1 <= 0;
					drawDone <= 1'b1;
					pixel_color <= 1'b0;
				end
			end
		end
	end
endmodule

// Used to test the animation module
//module animation_testbench();
//	parameter N = 1024, data_width = 24, fp_width = 32, mag_width = 10, MAX_X = 640, MAX_Y = 480;
//
//	logic clk, reset;
//	logic [8:0] curr_magnitude_buffer [0:N - 1]; 
//	logic pixel_color;
//	logic drawDone;
//	
//	// x and y coordinates for the start and end points of the line
//	logic [9:0]	x0, x1; 
//	logic [8:0] y0, y1;
//	
//	parameter CLK_Period = 100;
//	integer ctr;
//	
//	initial begin
//		for (ctr = 0; ctr < N; ctr++) begin
//			curr_magnitude_buffer[ctr] = ctr;
//		end
//		clk <= 1'b0;
//		forever #(CLK_Period/2) clk <= ~clk;
//	end
//	
//	animation dut (.*);
//	
//	initial begin
//		reset <= 1; @(posedge clk);
//		reset <= 0; @(posedge clk);
//		
//		repeat(3000) begin
//			@(posedge clk);
//		end
//		
//		$stop();
//	end
//endmodule
