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
reg [31:0] count, count2, count3, writeAddr;
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

assign s = state[3:0];

initial begin
	state = 4'd0;
	count = 0;
	count2 = 0;
	count3 = 0;
	writeCounter = 0;
	NodeID = 0;
end

always @ (posedge clk) begin
	case(state)
		/*
			State 0: Acts as a reset state to reset all the signals that we need to do the calculations
			
		*/
		state0: begin
			doneSig <= 1'b1;
			write_n <= 1'b1;
			read_n <= 1'b1;
			chipselect <= 1'b1;
			byteenable <= 2'b11;
			address <= 0;
			count <= 0;
			writeCounter <= 0;
			writeAddr <= 158000;
			if(startSig == 0) begin
				state <= state0;
			end
			else begin
				state <= state1;
			end
		end
		/*
			State 1: send out 157584 addresses -- 784 for the input data and 784 weight per node 
			since we have 200 nodes, we will send out 784*200 additional addreses. In the C code,
			we will make sure we are dealing with 16 bit values STRICTLY. This will allow us to avoid
			any addressing issues
		*/
		state1: begin
			write_n <= 1'b1;
			read_n <= (count < 157584) ? 0 : 1;
			chipselect <= 1'b1;
			byteenable <= 2'b11;
			address <= (waitrequest == 0) ? count : address;
			count <= (count < 157584 && waitrequest == 0) ? count + 1 : count;
			state <= (count < 157584) ? state1 : state2;
		end
		/*
			State2: Acts as our wait state where we have to wait until the calcuations for every node
			is done. Sets all write and read signals to be high (since they're active low) and waits until 
			all values have been read and calculated
		*/
		state2: begin
			write_n <= 1'b1;
			read_n <= 1'b1;
			chipselect <= 1'b1;
			byteenable <= 2'b11;
			state <= (count2 < 157584) ? state2: state3;
		end
		
		state3: begin
			write_n <= (writeCounter < 200) ? 1'b0 : 1'b1;
			read_n <= 1'b1;
			chipselect <= 1'b1;
			byteenable <= 2'b11;
			address <= (waitrequest == 0) ? writeAddr : address;
			writedata <= accStore[writeCounter];
			writeAddr <= (waitrequest == 0) ? writeAddr + 1 : writeAddr;
			writeCounter <= (writeCounter < 200 && waitrequest == 0) ? writeCounter+1 : writeCounter;
			state <= (writeCounter < 200) ? state3 : state4;
		end
		
		state4: begin
			write_n <= 1'b1;
			read_n <= 1'b1;
			chipselect <= 1'b1;
			byteenable <= 2'b11;
			doneSig <= 1'b0;
			if(startSig == 0) begin
				state <= state0;
			end
			else begin
				state <= state4;
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
		NodeID <= 9'd0;
	end
	else if ((readdatavalid == 1'b1) && (count2 < 784)) begin
		testData[count2] <= readdata;
		count2 <= count2 + 1'b1;
		accumulator <= 0;
	end
	else if ((readdatavalid == 1'b1) && (count2 >= 784)) begin
		count2 <= (count2 + 1'b1);
		count3 <= (count3 + 1'b1);
		if ((count3 % 784) == 0 && (count3 != 0)) begin
			accStore[NodeID] <= accumulator;
			NodeID <= NodeID + 1'b1;
			if(testData[0] == 16'd1) begin
				accumulator <= readdata;
			end
			else begin
				accumulator <= 16'd0;
			end
			count3 <= 16'd1;
		end
		else if (testData[count3] == 16'd0)begin
			accumulator <= accumulator;
		end
		else if(testData[count3] == 16'd1) begin
			accumulator <= accumulator + readdata;
		end
	end
	else if (count2 < 784) begin
		count2 <= count2;
	end
	else if (count2 >= 784) begin
		count3 <= count3;
	end
end
endmodule