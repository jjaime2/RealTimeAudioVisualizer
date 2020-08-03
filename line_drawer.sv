// Jose Jaime
// 3/6/20
// EE 371
// line_drawer Module
//
// Draws a column at each x coordinate to represent the magnitude of a particular frequency n
module line_drawer #(parameter N = 1024, data_width = 24, fp_width = 32, mag_width = 10, MAX_X = 640, MAX_Y = 480)
	(
		input logic clk, reset, is_idle,
		
		// current magnitude to draw at frequency bin (x)
		input logic [8:0] curr_peak,

		//outputs cooresponding to the coordinate pair (x, y)
		output logic [9:0] x,
		output logic [8:0] y,
		output logic pixel_color, draw_done,
		output logic draw_state, clear_state
	);
	
	enum {drawing, clearing} ps, ns;
	
	logic clear_done;
	integer draw_reps;
	
	assign draw_state = (ps == drawing);
	assign clear_state = (ps == clearing);
	assign pixel_color = (ps == drawing);
	
	always_comb begin
		case (ps) 
			drawing:		if (draw_done) 				ns = clearing;
							else								ns = drawing;
			clearing:	if (clear_done && is_idle)	ns = drawing;
							else 								ns = clearing;
		endcase
	end
	
	always_ff @(posedge clk) begin
		if (reset) begin
			ps <= clearing;
		end else begin
			ps <= ns;
		end
	end

	always_ff @(posedge clk) begin
		// Clear the screen
		if (ps == clearing) begin
			draw_done <= 1'b0;
			
			if (x < N / 2) begin
				x <= x + 1'b1;
			end else begin
				x <= 0;
				
				if (y > 0) begin
					y <= y - 1'b1;
				end else begin
					y <= 479;
					clear_done <= 1'b1;
				end
			end
		end
		
		// Draw the column
		if (ps == drawing) begin
			clear_done <= 1'b0;
			
			if (y > (479 - curr_peak)) begin
				y <= y - 1'b1;
			end else begin
				y <= 479;
				
				if (x < N / 2) begin
					x <= x + 1'b1;
				end else begin
					x <= 0;
					draw_reps <= draw_reps + 1;
					if (draw_reps == 10) begin
						draw_reps <= 0;
						draw_done <= 1'b1;
					end
				end
			end
		end
	end
endmodule

//// Used to test the line_drawer module
//module line_drawer_testbench();
//	logic clk, reset, drawDone;
//	
//	// x and y coordinates for the start and end points of the line
//	logic [9:0]	x0, x1; 
//	logic [8:0] y0, y1;
//
//	//outputs cooresponding to the coordinate pair (x, y)
//	logic [9:0] x;
//	logic [8:0] y;
//	
//	// debug signals
//	logic is_steep;
//	logic [10:0] calc_x0, calc_x1, calc_x;
//	logic [10:0] calc_y0, calc_y1, calc_y;
//	logic signed [10:0] error;
//	logic signed [10:0] calc_error;
//	logic signed [10:0] abs_dx;
//	logic signed [10:0] abs_dy;
//	logic signed [10:0] calc_dx;
//	logic signed [10:0] calc_abs_dy;
//	logic signed [1:0] y_step;
//	
//	parameter CLK_Period = 100;
//	
//	initial begin
//		clk <= 1'b0;
//		forever #(CLK_Period/2) clk <= ~clk;
//	end
//	
//	line_drawer dut (clk, reset, drawDone, x0, x1, y0, y1, x, y, is_steep, calc_x0, calc_x1, calc_x, calc_y0, calc_y1, calc_y, error, calc_error, abs_dx, abs_dy, calc_dx, calc_abs_dy, y_step);
//	
//	initial begin
//		reset <= 1; x0 <= 0; y0 <= 0; x1 <= 240; y1 <= 240; @(posedge clk);
//		reset <= 0; @(posedge clk);
//		
//		repeat(500) begin
//			@(posedge clk);
//		end
//		
//		reset <= 1; x0 <= 0; y0 <= 0; x1 <= 10; y1 <= 240; @(posedge clk);
//		reset <= 0; @(posedge clk);
//		
//		repeat(500) begin
//			@(posedge clk);
//		end
//		
//		reset <= 1; x0 <= 260; y0 <= 0; x1 <=40; y1 <= 240; @(posedge clk);
//		reset <= 0; @(posedge clk);
//		
//		repeat(500) begin
//			@(posedge clk);
//		end
//		
//		reset <= 1; x0 <= 40; y0 <= 0; x1 <=260; y1 <= 240; @(posedge clk);
//		reset <= 0; @(posedge clk);
//		
//		repeat(500) begin
//			@(posedge clk);
//		end
//		
//		reset <= 1; x0 <= 40; y0 <= 120; x1 <=260; y1 <= 120; @(posedge clk);
//		reset <= 0; @(posedge clk);
//		
//		repeat(500) begin
//			@(posedge clk);
//		end
//		
//		$stop();
//	end
//endmodule
