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
input reset_n,

input signed [15:0] readDataOnChip,
output reg [31:0] addressOnChip,
output reg chipselectOnChip,
output reg write,
output reg [1:0] byteenableOnChip,
output reg signed [15:0] writeDataOnChip
);
// State Variable used for state transitions
reg [3:0] state;

// Registers required for calculation of Layer 1
reg [31:0] count, count2, count3, readAddr, readAddrOnChip, readtestDataCounter, testDataCounter;
reg signed [15:0] accumulator;
reg [15:0] testData [0:783];
reg signed [15:0] accStore [0:199];
reg [8:0] NodeID, biasCounter;

// Registers required for calculations of Layer 2
reg [31:0] hl2Address, hl2count;
reg [15:0] hl2TotalCount, hl2Counter;
reg signed [15:0] hl2Accumulator;
reg signed [15:0] hl2accStore [0:199];
reg [8:0] hl2NodeID;

// Registers related to WriteBack Operations
reg [8:0] writeCounter;
reg [31:0] writeAddr;

localparam state0 = 4'd0;
localparam state1 = 4'd1;
localparam state2 = 4'd2; 
localparam state3 = 4'd3;
localparam state4 = 4'd4; 
localparam state5 = 4'd5;
localparam state6 = 4'd6; 
localparam state7 = 4'd7;

assign s = state[3:0];

always @ (posedge clk) begin
	case(state)
		/*
			State 0: Acts as a reset state to reset all the signals that we need to do the calculations
		*/
		state0: begin
			doneSig <= 1'b1;
			
			//SDRAM Related Variables
			write_n <= 1'b1;
			read_n <= 1'b1;
			chipselect <= 1'b1;
			byteenable <= 2'b11;
			address <= 0;
			count <= 0;
			readtestDataCounter <= 0;
			
			// Write Related Variables
			writeCounter <= 0;
			writeAddr <= 205000;
			
			// On Chip Addressing
			addressOnChip <= 32'h04000000;
			chipselectOnChip <= 1'b1;
			write <= 1'b0;
			byteenableOnChip <= 2'b11;
			
			//Calculation Related Variables for Layer 1
			count2 <= 0;
			count3 <= 0;
			accumulator <= 0;
			NodeID <= 9'd0;
			biasCounter <= 9'd0;
			hl2count <= 0;
			
			//state change
			state <= (startSig == 1) ? state1 : state0;
		end
		/*
			State 1: send out 157584 addresses -- 784 for the input data and 784 weight per node 
			since we have 200 nodes, we will send out 784*200 additional addreses. In the C code,
			we will make sure we are dealing with 16 bit values STRICTLY. This will allow us to avoid
			any addressing issues
		*/
		state1: begin
			write_n <= 1'b1;
			read_n <= (readtestDataCounter < 784) ? 0 : 1;
			chipselect <= 1'b1;
			byteenable <= 2'b11;
			address <= (waitrequest == 0) ? readtestDataCounter : address;
			readtestDataCounter <= (readtestDataCounter < 784 && waitrequest == 0) ? readtestDataCounter + 1'b1 : readtestDataCounter;
			state <= (readtestDataCounter < 784) ? state1 : state2;
		end
		
		state2: begin
			write_n <= 1'b1;
			read_n <= 1'b1;
			chipselect <= 1'b1;
			byteenable <= 2'b11;
			address <= 162200;
			state <= (testDataCounter < 784) ? state2 : state3;
		end
		/*
			State 3: send out 157584 addresses -- 784 for the input data and 784 weight per node 
			since we have 200 nodes, we will send out 784*200 additional addreses. In the C code,
			we will make sure we are dealing with 16 bit values STRICTLY. This will allow us to avoid
			any addressing issues
		*/
		state3: begin
			write <= 1'b0;
			chipselectOnChip <= (count < 157000) ? 1'b1 : 1'b0;
			byteenableOnChip <= 2'b11;
			addressOnChip <= addressOnChip + 1'b1;
			count <= (count < 157000) ? count + 1 : count;
			state <= (count < 157000) ? state3 : state4;

			if(count >= 1)begin
				if(count2 < 156800) begin
					count2 <= (count2 + 1'b1);
					if ((count3 % 784) == 0 && (count3 != 0)) begin
						accStore[NodeID] <= accumulator;
						NodeID <= NodeID + 1'b1;
						if(testData[0] == 16'd1) begin
							accumulator <= readDataOnChip;
						end
						else begin
							accumulator <= 16'd0;
						end
						count3 <= 16'd1;
					end
					else if (testData[count3] == 16'd0)begin
						accumulator <= accumulator;
						count3 <= (count3 + 1'b1);
					end
					else if(testData[count3] == 16'd1) begin
						accumulator <= accumulator + readDataOnChip;
						count3 <= (count3 + 1'b1);
					end
				end
				else if(count2 < 157000) begin
					count2 <= (count2 + 1'b1);
					accStore[biasCounter] <= ((accStore[biasCounter] + readDataOnChip) < 0) ? 16'd0 : 16'd1;
					biasCounter <= biasCounter + 1'b1;
				end
			end
		end
		/*
			State2: Send out 40000 addresses corresponding to all the weights of layer 2
			As the data comes in, the calculations will be done in the secondary always loop.
		*/
		state4: begin
			write_n <= 1'b1;
			read_n <= (hl2count < 40000) ? 0 : 1;
			chipselect <= 1'b1;
			byteenable <= 2'b11;
			address <= (waitrequest == 0) ? address + 1'b1 : address;
			hl2count <= (hl2count < 40000 && waitrequest == 0) ? hl2count + 1'b1 : hl2count;
			state <= (hl2count < 40000) ? state4 : state5;
		end
		
		state5: begin
			write_n <= 1'b1;
			read_n <= 1'b1;
			chipselect <= 1'b1;
			byteenable <= 2'b11;
			chipselectOnChip = 1'b1;
			state <= (hl2TotalCount < 40000) ? state5 : state6;
		end
		
		state6: begin
			write_n <= (writeCounter < 200) ? 1'b0 : 1'b1;
			read_n <= 1'b1;
			chipselect <= 1'b1;
			byteenable <= 2'b11;
			address <= (waitrequest == 0) ? writeAddr : address;
			writedata <= hl2accStore[writeCounter];
			writeAddr <= (waitrequest == 0) ? writeAddr + 1 : writeAddr;
			writeCounter <= (writeCounter < 200 && waitrequest == 0) ? writeCounter+1 : writeCounter;
			state <= (writeCounter < 200) ? state6 : state7;
		end
		
		state7: begin
			// SDRAM Signals
			write_n <= 1'b1;
			read_n <= 1'b1;
			chipselect <= 1'b1;
			byteenable <= 2'b11;
			
			write <= 1'b0;
			byteenableOnChip <= 2'b11;
			chipselectOnChip <= 1'b0;
			
			doneSig <= 1'b0;
			state <= (startSig == 0) ? state0 : state7;
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

always @ (posedge clk) begin
	if (state == state0 || state == state7) begin
		testDataCounter <= 0;
		hl2Accumulator <= 0;
		hl2TotalCount <= 0;
		hl2Counter <= 0;
		hl2NodeID <= 0;
		hl2biasCounter <= 0;
	end
	else if ((readdatavalid == 1'b1) && (testDataCounter < 784)) begin
		testData[testDataCounter] <= readdata;
		testDataCounter <= testDataCounter + 1'b1;
	end
	else if ((readdatavalid == 1'b1) && (testDataCounter >= 784)) begin
		hl2TotalCount <= hl2TotalCount + 1'b1;
		if (hl2TotalCount < 40000) begin
			if ((hl2Counter % 200) == 0 && (hl2Counter != 0)) begin
				hl2accStore[hl2NodeID] <= hl2Accumulator;
				hl2NodeID <= hl2NodeID + 1'b1;
				if(accStore[0] == 16'd1) begin
					hl2Accumulator <= readdata;
				end
				else begin
					hl2Accumulator <= 16'd0;
				end
				hl2Counter <= 16'd1;
			end
			else if (accStore[hl2Counter] == 16'd0)begin
				hl2Accumulator <= hl2Accumulator;
				hl2Counter <= hl2Counter + 1'b1;
			end
			else if(accStore[hl2Counter] == 16'd1) begin
				hl2Accumulator <= hl2Accumulator + readdata;
				hl2Counter <= hl2Counter + 1'b1;
			end
		end
		else if (hl2TotalCount < 40200) begin
			hl2accStore[biasCounter] <= ((hl2accStore[hl2biasCounter] + readdata) < 0) ? 16'd0 : 16'd1;
			hl2biasCounter <= hl2biasCounter + 1'b1;
			accumulator <= 0;
			hl2counter <= 0;
		end
		else if (hl2TotalCount < 42200) begin
			if ((hl2Counter) % 200) == 0) && (hl2)
			
		
		
		
		end
	end
end
endmodule