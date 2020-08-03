module noise_gen (clk, en, rst, out);
	input logic clk, en, rst;
	output logic signed [23:0] out;
	
	logic feedback;
	logic [3:0] LFSR;
	assign feedback = LFSR[3] ~^ LFSR[2];
	
	always_ff @(posedge clk) begin
		if (rst) LFSR <= 4'b0;
		else LFSR <= {LFSR[2:0], feedback};
	end
	
	always_ff @(posedge clk) begin
		if (rst) out <= 24'b0;
		else if (en) out <= {{5{LFSR[3]}}, LFSR[2:0], 16'b0};
	end

endmodule

module noise_gen_testbench();
  logic clk, en, rst;
  logic signed [23:0] out;

  noise_gen dut (.*);

  initial begin
    clk <= 0;
    forever #10 clk <= ~clk;
  end

  initial begin
    en <= 0; rst <= 1;
    repeat (3) @(posedge clk)
    rst <= 0;
    repeat (3) @(posedge clk)
    en <= 1;
    repeat (30) begin
      @(posedge clk);
      $display("%d",out);
    end
    $stop();
  end
endmodule
