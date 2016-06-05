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
input signed [15:0] readdata,
output reg signed [15:0] writedata,
output [3:0] s,
input reset_n
);

reg [3:0] state;
reg [31:0] count, count2, count3, weightAddr, writeAddr, bound;
reg signed [15:0] accumulator;
reg [15:0] testData [0:783];
reg signed [15:0] accStore [0:199];
reg [8:0] NodeID, writeCounter;

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
localparam state10 = 4'd10;
localparam state11 = 4'd11;

assign s = state[3:0];

initial begin
	state = 4'd0;
	count = 0;
	count2 = 0;
	count3 = 0;
	writeCounter = 0;
end

always @ (posedge clk) begin

	case(state)
		state0: begin
			doneSig <= 1'b1;
			write_n <= 1'b1;
			read_n <= 1'b1;
			chipselect <= 1'b1;
			byteenable <= 2'b11;
			address <= 0;
			count <= 0;
			writeCounter <= 0;
			weightAddr <= 784;
			writeAddr <= 158000;
			bound <= 1568;
			NodeID <= 0;
			if(startSig == 0) begin
				state <= state0;
			end
			else begin
				state <= state1;
			end
		end
		
		// get all 784 input data
		state1: begin
			write_n <= 1'b1;
			read_n <= (count < 784) ? 0 : 1;
			chipselect <= 1'b1;
			byteenable <= 2'b11;
			address <= (waitrequest == 0) ? count : address;
			count <= (count < 784 && waitrequest == 0) ? count + 1 : count;
			state <= (count < 784) ? state1 : state2;
		end
		
		// wait until all image input values are read in
		state2: begin
			write_n <= 1'b1;
			read_n <= 1'b1;
			chipselect <= 1'b1;
			byteenable <= 2'b11;
			state <= (count2 < 784) ? state2 : state3;
		end
		
		// send out 784 addresses corresponding to the weights
		state3: begin
			write_n <= 1'b1;
			read_n <= (weightAddr < bound) ? 0 : 1;
			chipselect <= 1'b1;
			byteenable <= 2'b11;
			address <= (waitrequest == 0) ? weightAddr : address;
			weightAddr <= (weightAddr < bound && waitrequest == 0) ? weightAddr + 1 : weightAddr;
			state <= (weightAddr < bound) ? state3 : state4;
		end
		
		// writes the values into sdram ( potentially could combine with state 3 to increase parallelism )
		state4: begin
			write_n <= 1'b1;
			read_n <= 1'b1;
			chipselect <= 1'b1;
			byteenable <= 2'b11;
			if(count3 < 784) begin
				state <= state4;
			end
			else begin
				accStore[NodeID] <= accumulator;
				NodeID = NodeID + 1'b1;
				state <= state5;
			end
		end
		
		state5: begin
			if( NodeID < 200 ) begin
				bound <= bound + 784;
				state <= state3;
			end
			else begin
				state <= state6;
			end
		end
		
		state6: begin
			write_n <= (writeCounter < 200) ? 1'b0 : 1'b1;
			read_n <= 1'b1;
			chipselect <= 1'b1;
			byteenable <= 2'b11;
			address <= (waitrequest == 0) ? writeAddr : address;
			writedata <= accStore[writeCounter];
			writeAddr <= (waitrequest == 0) ? writeAddr + 1 : writeAddr;
			writeCounter <= (writeCounter < 200 && waitrequest == 0) ? writeCounter+1 : writeCounter;
			state <= (writeCounter < 200) ? state6 : state7;
		end
		
		state7: begin
			write_n <= 1'b1;
			read_n <= 1'b1;
			chipselect <= 1'b1;
			byteenable <= 2'b11;
			doneSig <= 1'b0;
			if(startSig == 0) begin
				state <= state0;
			end
			else begin
				state <= state7;
			end
		end
		
		default: begin
			state <= state0;
			read_n <= 1'b1;
			write_n <= 1'b1;
			chipselect <= 1'b1;
			byteenable <= 2'b11;
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
	if (state == state0) begin
		count2 <= 0;
		count3 <= 0;
		accumulator <= 0;
	end
	else if ((readdatavalid == 1'b1) && (count2 < 784)) begin
		testData[count2] <= readdata;
		count2 <= count2 + 1'b1;
	end
	else if ((readdatavalid == 1'b1) && (count2 >= 784) && count3 < 784) begin
		if (count3 == 0 && testData[count3] == 16'd1) begin
			accumulator <= readdata;
		end
		else if (count3 == 0 && testData[count3] == 16'd0)begin
			accumulator <= 0;
		end
		else if(testData[count3] == 16'd1) begin
			accumulator <= accumulator + readdata;
		end
		count3 <= count3 + 1'b1;
	end
	else if ( count2 >= 784 && count3 == 784) begin
		count3 <= 0;
		accumulator <= 0;
	end
	else if (count2 < 784) begin
		count2 <= count2;
	end
	else if (count2 >= 784) begin
		count3 <= count3;
	end
end

endmodule