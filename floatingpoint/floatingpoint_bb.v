
module floatingpoint (
	clk,
	clk_en,
	dataa,
	datab,
	n,
	reset,
	reset_req,
	start,
	done,
	result);	

	input		clk;
	input		clk_en;
	input	[31:0]	dataa;
	input	[31:0]	datab;
	input	[2:0]	n;
	input		reset;
	input		reset_req;
	input		start;
	output		done;
	output	[31:0]	result;
endmodule
