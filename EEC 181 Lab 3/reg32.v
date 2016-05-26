module reg32 (D,clock,reset,q,byteenable);
  input [31:0]D; 
  input [3:0]byteenable;
  input clock, reset; 
  output [31:0]q;
  reg [31:0]q;
  

always @ ( posedge clock) begin
	if (~reset) begin
		 q <= 8'h0000;
	end  
	else begin
		 q <= D;
	end
	
	if (byteenable == 4'b1111) begin
		q <= D;
	end
	else if (byteenable == 4'b0011) begin
		q[15:0] <= D[15:0];
	end
	else if (byteenable == 4'b1100) begin
		q[31:16] <= D[31:16];
	end
	else if (byteenable == 4'b0001) begin		
		q[7:0] <= D[7:0];
	end
	else if (byteenable == 4'b0010) begin		
		q[15:8] <= D[15:8];
	end
	else if (byteenable == 4'b0100) begin
		q[23:16] <= D[23:16];
	end
	else if (byteenable == 4'b1000) begin
		q[31:24] <= D[31:24];
	end
	else begin
		$display("Wrong Byteenable");
	end
end

endmodule