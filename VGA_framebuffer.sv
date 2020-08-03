// VGA driver: provides I/O timing and double-buffering for the VGA port.

module VGA_framebuffer(
	input logic clk, rst,
	input logic [9:0] x, // The x coordinate to write to the buffer.
	input logic [8:0] y, // The y coordinate to write to the buffer.
	input logic pixel_color, pixel_write, // The data to write (color) and write-enable.
	
	output logic frame_start,   // Pulse is fired at the start of a frame.
	
	// Outputs to the VGA port.
	output logic [7:0] VGA_R, VGA_G, VGA_B,
	output logic VGA_CLK, VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N
);
	
	/*
	*
	* HCOUNT 1599 0             1279       1599 0
	*            _______________              ________
	* __________|    Video      |____________|  Video
	* 
	* 
	* |SYNC| BP |<-- HACTIVE -->|FP|SYNC| BP |<-- HACTIVE
	*       _______________________      _____________
	* |____|       VGA_HS          |____|
	*
	*/
	
	// Constants for VGA timing.
	localparam HPX = 11'd640*2, HFP = 11'd16*2, HSP = 11'd96*2, HBP = 11'd48*2;
	localparam VLN = 11'd480,   VFP = 10'd11,   VSP = 10'd2,    VBP = 10'd31;
	localparam HTOTAL = HPX + HFP + HSP + HBP; // 800*2=1600
	localparam VTOTAL = VLN + VFP + VSP + VBP; // 524

	// Horizontal counter.
	logic [10:0] h_count;
	logic end_of_line;

	assign end_of_line = h_count == HTOTAL - 1;

	always_ff @(posedge clk)
		if (rst) h_count <= 0;
		else if (end_of_line) h_count <= 0;
		else h_count <= h_count + 11'd1;

	// Vertical counter & buffer swapping.
	logic [9:0] v_count;
	logic end_of_field;
	logic front_odd; // whether odd address is the front buffer.

	assign end_of_field = v_count == VTOTAL - 1;
	assign frame_start = !h_count && !v_count;

	always_ff @(posedge clk)
		if (rst) begin
			v_count <= 0;
			front_odd <= 0;
		end else if (end_of_line)
			if (end_of_field) begin
				v_count <= 0;
				front_odd <= !front_odd;
			end else
				v_count <= v_count + 10'd1;

	// Sync signals.
	assign VGA_CLK = h_count[0]; // 25 MHz clock: pixel latched on rising edge.
	assign VGA_HS = !(h_count - (HPX + HFP) < HSP);
	assign VGA_VS = !(v_count - (VLN + VFP) < VSP);
	assign VGA_SYNC_N = 1; // Unused by VGA

	// Blank area signal.
	logic blank;
	assign blank = h_count >= HPX || v_count >= VLN;

	// Double-buffering.
	logic buffer[640*480*2-1:0];
	logic [19:0] wr_addr, rd_addr;
	logic rd_data;

	assign wr_addr = {y * 19'd640 + x, !front_odd};
	assign rd_addr = {v_count * 19'd640 + (h_count / 19'd2), front_odd};

	always_ff @(posedge clk) begin
		if (pixel_write) buffer[wr_addr] <= pixel_color;
		if (VGA_CLK) begin
			rd_data <= buffer[rd_addr];
			VGA_BLANK_N <= ~blank;
		end
	end

	// Color output.
	assign {VGA_R, VGA_G, VGA_B} = rd_data ? 24'hFFFFFF : 24'h000000;
endmodule
