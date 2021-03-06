module sdram_master(
input clk,
input startSig,
output reg doneSig = 0, 
output reg read_n = 1,
output reg write_n = 1,
output reg chipselect,
input waitrequest,
output reg [31:0] address = 0,
output reg [1:0] byteenable,
input readdatavalid,
input [15:0] readdata,
output reg [15:0] writedata,
output [3:0] s,
input reset_n
);

reg [3:0] state;
reg [31:0] count;
reg [31:0] count2;
reg [31:0] BASESOBEL = 132000;
reg [7:0] sdramdata [0:1027];
reg signed [10:0] data1x,data1y, data2x, data2y; 
reg [10:0] sum1,sum2;
integer i;

// Flags
reg shiften;
reg readdone;
reg computedone;
reg initialized;
reg absen;
reg absvaldone;

wire [7:0] p0, p1, p2, p3,p4,p5,p6,p7,p8,p9,p10,p11;

localparam state0 = 4'd0;
localparam state1 = 4'd1;
localparam state2 = 4'd2; 
localparam state3 = 4'd3;
localparam state4 = 4'd4; 
localparam state5 = 4'd5;
localparam state6 = 4'd6;
localparam state7 = 4'd7;
localparam state8 = 4'd8;
localparam state9 = 4'd9;
 
assign s = state[3:0];

initial begin
	state = 3'd0;
	count = 0;
	count2 = 0;
	computedone = 0;
	shiften = 0;
	readdone = 0;
	initialized = 0;
end

assign p0 = sdramdata[0];
assign p1 = sdramdata[1];
assign p2 = sdramdata[2];
assign p3 = sdramdata[512];
assign p4 = sdramdata[513];
assign p5 = sdramdata[514];
assign p6 = sdramdata[1024];
assign p7 = sdramdata[1025];
assign p8 = sdramdata[1026];
assign p9 = sdramdata[1027];
assign p10 = sdramdata[3];
assign p11 = sdramdata[515];

always @ (posedge clk) begin

	case(state)
		state0: begin
			doneSig <= 1'b1;
			write_n <= 1'b1;
			read_n <= 1'b1;
			chipselect <= 1'b0;
			byteenable <= 2'b00;
			address <= 0;
			read_n <= 1'b1;
			shiften <= 1'b0;
			initialized <= 1'b0;
			absen <= 1'b0;
			if(~startSig) begin
				state <= state0;
			end
			else begin
				state <= state1;
			end
		end
		
		// send out addresses corresponding to the 1028 values that we need originally
		state1: begin
			write_n <= 1'b1;
			read_n <= (count < 514) ? 0 : 1;
			chipselect <= 1'b1;
			byteenable <= 2'b11;
			shiften <= 1'b0;
			address <= (waitrequest == 0) ? count : address;
			count <= (count < 514 && waitrequest == 0) ? count + 1 : count;
			state <= (count < 514) ? state1 : state2;
		end
		
		/*
			state2: wait until all 1028 values are in
		*/
		
		state2: begin
			write_n <= 1'b1;
			read_n <= 1'b1;
			chipselect <= 1'b1;
			if(count2 < 1027) begin
				state <= state2;
				shiften <= 1'b0;
				initialized <= 1'b0;
			end
			else begin
				state <= state3;
				shiften <= 1'b1;
				initialized <= 1'b1;
			end
		end
		
		// wait for computations to be done
		state3: begin
			if(computedone == 1'b1) begin
				shiften <= 1'b0;
				absen <= 1'b1;
				state <= state4;
			end
			else begin
				shiften <= shiften;
				state <= state3;
			end
		end
		
		state4: begin
			if(absvaldone == 1'b1) begin
				shiften <= 1'b0;
				absen <= 1'b0;
				state <= state5;
			end
			else begin
				shiften <= shiften;
				absen <= absen;
				state <= state4;
			end
		end
		
		state5: begin
			sum1 <= data1x + data1y;
			sum2 <= data2x + data2y;
			state <= state6;
		end
		
		state6: begin
			write_n <= 1'b0;
			read_n <= 1'b1;
			chipselect <= 1'b1;
			byteenable <= 2'b11;
			address <= BASESOBEL;
			BASESOBEL <= BASESOBEL + 1'b1;
			writedata[15:8] <= (sum2[10]|sum2[9]) ? sum2[10:3]:sum2[7:0];
			writedata[7:0] <= (sum1[10]|sum1[9]) ? sum1[10:3]:sum1[7:0];
			if (waitrequest == 1'b0) begin
				state <= state7;
			end
			else begin
				state <= state6;
			end
		end
		
		// read in two new values
		state7: begin
			write_n <= 1'b1;
			read_n <= count < 131072 ? 0 : 1;
			chipselect <= 1'b1;
			byteenable <= 2'b11;
			shiften <= 1'b0;
			intialized <= 1'b1;
			address <= (waitrequest == 0) ? count : address;
			count <= (count < 131072 && waitrequest == 0) ? count + 1 : count;
			state <= (count < 131072) ? state8 : state9;
		end
		
		state8: begin
			if(readdone == 1'b1) begin
				shiften <= 1'b1;
				state <= state3;
			end 
			else begin
				shiften <= shiften;
				state <= state8;
			end
		end
		
		state9: begin
			doneSig = 1'b0;
			state<= state9;
		end
		
		default: begin
			state <= state0;
			read_n <= 1'b1;
			write_n <= 1'b1;
			chipselect <= 1'b0;
			byteenable <= 2'b00;
			initialized <= 1'b0;
			address <= 0;
		end
	endcase 

end

/*
	Readdatavalid + waitrequest is independent of one another so there is no reason to clump them together
	This always loop simply keeps watching for the readdatavalid signal to be asserted before using the data
	that is found in readdata. Readdata(s) can come in way after you send all your addresses, thus there is a period of time
	you may have to wait before all your data comes through.
	
	Source: Page 3-10 of https://www.altera.com/en_US/pdfs/literature/manual/mnl_avalon_spec_1_3.pdf
*/

//Initial read in of the 1028 values OR start reading 2 values in

always @ (posedge clk) begin
	if ((readdatavalid == 1'b1) && (initialized == 1'b0)) begin
		sdramdata[count2] <= readdata[7:0];
		sdramdata[count2+1] <= readdata[15:8];
		count2 <= count2 + 2;
	end
	else if ((readdatavalid == 1'b1) && (initialized == 1'b1)) begin
		sdramdata[1027] <= readdata[15:8];
		sdramdata[1026] <= readdata[7:0];
		for(i=0 ; i < 1026 ;i=i+1)
			sdramdata[i] <= sdramdata[i+2];
		readdone <= 1'b1;
	end
	else if (initialized == 1'b0 ) begin
		count2 <= count2;
	end
	else if (initialized == 1'b1) begin
		readdone <= 1'b0;
	end
end

always @ (posedge clk) begin
	if(shiften) begin
		data1x <= ((p2-p0)+((p5-p3)<<1)+(p8-p6));//sobel mask for gradient in horiz. direction 
		data1y <= ((p0-p6)+((p1-p7)<<1)+(p2-p8));//sobel mask for gradient in vertical direction 
		data2x <= ((p10-p1)+((p11-p4)<<1)+(p9-p7));
		data2y <= ((p1-p7)+((p2-p8)<<1)+(p10-p9));
		computedone <= 1'b1;
	end 
	else begin
		computedone <= 1'b0;
	end
	
	if(absen) begin
		data1x <= (data1x[10]) ? ~data1x+1 : data1x;	// to find the absolute value of data1 x 
		data1y <= (data1y[10]) ? ~data1y+1 : data1y;	// to find the absolute value of data1 y 
		data2x <= (data2x[10]) ? ~data2x+1 : data2x;
		data2y <= (data2y[10]) ? ~data2y+1 : data2y;
		absvaldone <= 1'b1;
	end
	else begin
		absvaldone <= 1'b0;
	end
end

endmodule