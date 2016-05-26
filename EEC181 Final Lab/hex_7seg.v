module hex_7seg(
   input [3:0] hex,
   output reg [0:6] seg
);

//		012_3456 (segments are active low)
parameter ZERO = 7'b0000001;
parameter ONE = 7'b1001111;
parameter TWO = 7'b0010010;
parameter THREE = 7'b0000110;
parameter FOUR = 7'b1001100;
parameter FIVE = 7'b0100100;
parameter SIX = 7'b0100000;
parameter SEVEN = 7'b0001111;
parameter EIGHT = 7'b0000000;
parameter NINE = 7'b0001100;
parameter A = 7'b0001000;
parameter B = 7'b0000000;
parameter C = 7'b0110001;
parameter D = 7'b0000001;
parameter E = 7'b0110000;
parameter F = 7'b0111000;

always @(hex) begin
	case(hex)
	0: seg = ZERO;
	1: seg = ONE;
	2: seg = TWO;
	3: seg = THREE;
	4: seg = FOUR;
	5: seg = FIVE;
	6: seg = SIX;
	7: seg = SEVEN;
	8: seg = EIGHT;
	9: seg = NINE;
	10: seg = A;
	11: seg = B;
	12: seg = C;
	13: seg = D;
	14: seg = E;
	15: seg = F;
	endcase
end
endmodule

