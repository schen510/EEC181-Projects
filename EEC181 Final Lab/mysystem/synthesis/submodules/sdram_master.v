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
	reg [31:0] count, count3;
reg [8223:0] sdramdata;
//reg [7:0] sdramdata;
reg signed [10:0] data1x, data1y, data2x, data2y, data1absx, data2absx, data1absy, data2absy; 
reg [10:0] sum1,sum2;
integer i,k,count2;

// Flags
reg readdone;

wire [7:0] p0, p1, p2, p3,p4,p5,p6,p7,p8,p9,p10,p11;

localparam state0 = 4'd0;
localparam state1 = 4'd1;
localparam state2 = 4'd2; 
localparam state3 = 4'd3;
localparam state4 = 4'd4; 
localparam state5 = 4'd5;
localparam state6 = 4'd6;
localparam state7 = 4'd7;
 
assign s = state[3:0];
assign p0 = sdramdata[8223:8216];
assign p1 = sdramdata[8215:8208];
assign p2 = sdramdata[8207:8200];
assign p3 = sdramdata[8199:8192];
assign p4 = sdramdata[4127:4120];
assign p5 = sdramdata[4119:4112];
assign p6 = sdramdata[4111:4104];
assign p7 = sdramdata[4103:4096];
assign p8 = sdramdata[31:24];
assign p9 = sdramdata[23:16];
assign p10 = sdramdata[15:8];
assign p11 = sdramdata[7:0];

initial begin
	state = 4'd0;
	count = 0;
	count2 = 0;
	count3 = 0;
	readdone = 0;
end

always @ (posedge clk) begin

	case(state)
		state0: begin
			doneSig <= 1'b1;
			write_n <= 1'b1;
			read_n <= 1'b1;
			chipselect <= 1'b0;
			byteenable <= 2'b00;
			address <= 0;
			count <= 0;
			count3 <= 0;
			read_n <= 1'b1;
			if(startSig == 0) begin
				state <= state0;
			end
			else begin
				state <= state1;
			end
		end
		
		// send out addresses to fill up the array and once all 514 (2 bytes = 2 8 bit data) addresses
		// have been sent out then go into state2 which is a waiting state for all 1028 values to be stored away
		state1: begin
			write_n <= 1'b1;
			read_n <= (count < 514) ? 0 : 1;
			chipselect <= 1'b1;
			byteenable <= 2'b11;
			address <= (waitrequest == 0) ? count : address;
			count <= (count < 514 && waitrequest == 0) ? count + 1 : count;
			state <= (count < 514) ? state1 : state2;
		end
		/*
			state2: wait until all 1028 values are in and the initialized flag means that
			there are 1028 values in and the next time it will simply read two new values and shift 
			two old values out of the array
		*/
		state2: begin
			write_n <= 1'b1;
			read_n <= 1'b1;
			chipselect <= 1'b1;
			if(count2 < 1027) begin
				state <= state2;
			end
			else begin
				state <= state3;
			end
		end
		
		// wait for computations to be done; doesn't matter if the first couple cycles are garbage
		// allows for parallelism, which will speed up the process
		state3: begin
			data1x <= ((p2-p0)+((p5-p3)<<1)+(p8-p6));   //sobel mask for gradient in horiz. direction 
			data1y <= ((p0-p6)+((p1-p7)<<1)+(p2-p8));   //sobel mask for gradient in vertical direction 
			data2x <= ((p10-p1)+((p11-p4)<<1)+(p9-p7));	//sobel mask for gradient in horiz. direction 
			data2y <= ((p1-p7)+((p2-p8)<<1)+(p10-p9)); 	//sobel mask for gradient in vertical direction 
		
			data1absx <= (data1x[10]) ? (~data1x)+1 : data1x;	// to find the absolute value of data1 x 
			data1absy <= (data1y[10]) ? (~data1y)+1 : data1y;	// to find the absolute value of data1 y 
			data2absx <= (data2x[10]) ? (~data2x)+1 : data2x;	
			data2absy <= (data2y[10]) ? (~data2y)+1 : data2y;
		
			sum1 <= data1absx + data1absy;
			sum2 <= data2absx + data2absy;
			state <= state4;
		end
		
		// writes the values into sdram ( potentially could combine with state 3 to increase parallelism )
		state4: begin
			write_n <= (count3 < 131072) ? 0 : 1;
			read_n <= 1'b1;
			chipselect <= 1'b1;
			byteenable <= 2'b11;
			address <= 131073 + count3;
			count3 <= (count3 < 131072 && waitrequest == 0) ? count3 + 1 : count3;
			writedata[15:8] <= (sum2[10]|sum2[9]) ? sum2[10:3]:sum2[7:0];
			writedata[7:0] <= (sum1[10]|sum1[9]) ? sum1[10:3]:sum1[7:0];
			if(waitrequest == 0) begin
				state <= ( count < 131072 ) ? state5 : state7; 
			end
			else begin
				state <= state4;
			end
		end
		
		// send out addresses of next values to be read into the array
		state5: begin
			write_n <= 1'b1;
			read_n <= (count < 131072) ? 0 : 1;
			chipselect <= 1'b1;
			byteenable <= 2'b11;
			address <= (waitrequest == 0) ? count : address;
			count <= (count < 131072 && waitrequest == 0) ? count + 1 : count;
			if(waitrequest == 0) begin
				state <= state6;
			end
			else begin
				state <= state5;
			end
		end
		
		//Waits in this state until finished reading new values into array to process
		state6: begin
			write_n <= 1'b1;
			read_n <= 1'b1;
			chipselect <= 1'b0;
			if(readdone == 1'b1) begin
				state <= state3;
			end 
			else begin
				state <= state6;
			end
		end
		
		state7: begin
			write_n <= 1'b1;
			read_n <= 1'b1;
			chipselect <= 1'b1;
			doneSig <= 1'b0;
			if(startSig == 1'b0) begin
				state <= state0;
			end
			else begin
				state<= state7;
			end
		end
		
		default: begin
			state <= state0;
			read_n <= 1'b1;
			write_n <= 1'b1;
			chipselect <= 1'b0;
			byteenable <= 2'b00;
			doneSig <= 1'b1;
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
	if ((readdatavalid == 1'b1) && (count2 < 1027)) begin
		sdramdata <= (sdramdata << 16)+readdata;
		count2 <= count2 + 2;
		readdone <= 1'b0;
	end
	else if ((readdatavalid == 1'b1) && (count2 > 1027)) begin
		sdramdata[8223:0]<={sdramdata[8207:0],readdata};
		readdone <= 1'b1;
	end
	else if (count2 < 1027) begin
		count2 <= count2;
	end
	else if (count2 > 1027) begin
		readdone <= 1'b0;
	end
end

endmodule