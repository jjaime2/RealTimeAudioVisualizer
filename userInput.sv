// Jose Jaime
// 3/6/20
// EE 371
// userInput Module
//
// Converts a user input into a one clock cycle pulse to signal that the FFT should be enabled

module userInput(CLK, RST, IN, OUT);
	input logic CLK, RST;
	input logic IN;
	output logic OUT;
	enum {A = 1, B = 0} PS, NS, tempA, tempB; 
	always_comb begin
		case(PS)
			A: begin		case(IN) 
						1'b1:	NS = A;
						default: NS = B;
						endcase
				end
			B: begin		case(IN) 
						1'b1:	NS = A;
						default: NS = B;
						endcase
				end
		endcase
	end
	
	assign OUT = ((tempB && (PS == B)) == 1) && IN;
	
	always_ff @(posedge CLK) begin
		if(RST)
			PS <= B;
		else
			tempA <= NS;
			tempB <= tempA;
			PS <= tempB;
	end
endmodule
