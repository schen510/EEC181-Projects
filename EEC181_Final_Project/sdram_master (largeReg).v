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
wire signed [15:0] topaccStore;
wire signed [15:0] tophl2accStore;

// Registers required for calculation of Layer 1
reg [31:0] count, count2, count3, readAddr, readtestDataCounter;
reg [31:0] testDataCounter;
reg signed [15:0] accumulator;
reg [3199:0] accStore;
reg [3199:0] accStoreCopy;
reg [12543:0] testDataArray;
reg [12543:0] testDataArrayCopy;

// Registers required for calculations of Layer 2
reg [31:0] hl2count;
reg [15:0] hl2TotalCount, hl2Counter;
reg signed [15:0] hl2Accumulator;
reg [3199:0] hl2accStore;
reg [3199:0] hl2accStoreCopy;

// Registers required to calculate Output Layer
reg [15:0] outputCounter;
reg signed [15:0] outputAccumulator, max;
reg [15:0] outputNodeID, index;

// Registers related to WriteBack Operations
reg [11:0] writeCounter;
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
assign topaccStore = accStore[3199:3184];
assign tophl2accStore = hl2accStore[3199:3184];

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
			readAddr <= 162200;
			
			// Write Related Variables
			writeCounter <= 12'd0;
			writeAddr <= 220000;
			
			// On Chip Addressing
			addressOnChip <= 32'h04000000;
			chipselectOnChip <= 1'b1;
			write <= 1'b0;
			byteenableOnChip <= 2'b11;
			
			//Calculation Related Variables for Layer 1
			accStore <= 0;
			testDataArrayCopy <= 0;
			count2 <= 0;
			count3 <= 0;
			accumulator <= 0;
			
			//Hidden Layer 2 Related Variables
			hl2count <= 0;
			hl2accStoreCopy <= 0;
			
			//state change
			state <= (startSig == 1) ? state1 : state0;
		end
		/*
			State 1: send out 784 addresses corresponding to 784 data per pixel from the image
			Once all 784 addresses have been successfully sent out, we transition to state 2 and wait until all 
			data has been retrieved
		*/
		state1: begin
			write_n <= 1'b1;
			read_n <= (readtestDataCounter < 784) ? 1'b0 : 1'b1;
			chipselect <= 1'b1;
			byteenable <= 2'b11;
			address <= (waitrequest == 0) ? readtestDataCounter : address;
			readtestDataCounter <= (readtestDataCounter < 784 && waitrequest == 0) ? readtestDataCounter + 1'b1 : readtestDataCounter;
			state <= (readtestDataCounter < 784) ? state1 : state2;
		end
		/*
			State2: Wait State that waits until all test Data value has been retrieved
		*/
		state2: begin
			write_n <= 1'b1;
			read_n <= 1'b1;
			chipselect <= 1'b1;
			byteenable <= 2'b11;
			address <= readAddr;
			testDataArrayCopy <= testDataArray;
			state <= (testDataCounter < 784) ? state2 : state3;
		end
		/*
			State 3: send out 157584 addresses -- 784 for the input data and 784 weight per node 
			since we have 200 nodes, we will send out 784*200 additional addresses. In the C code,
			we will make sure we are dealing with 16 bit values STRICTLY. This will allow us to avoid
			any addressing issues
		*/
		state3: begin
			write <= 1'b0;
			chipselectOnChip <= (count < 157000) ? 1'b1 : 1'b0;
			byteenableOnChip <= 2'b11;
			addressOnChip <= addressOnChip + 1'b1;
			//readAddrOnChip <= readAddrOnChip + 1'b1; maybe need?
			count <= (count < 157000) ? count + 1 : count;
			state <= (count < 157000) ? state3 : state4;

			if(count >= 1)begin
				if(count2 < 156800) begin
					count2 <= (count2 + 1'b1);
					if ((count3 % 784) == 783) begin
						if(testDataArrayCopy[12543:12528] == 16'd1) begin
							accStore <= {accStore[3183:0], (accumulator + readDataOnChip)};
						end
						else begin
							accStore <= {accStore[3183:0],accumulator[15:0]};
						end
						count3 <= 16'd0;
						accumulator <= 16'd0;
						testDataArrayCopy <= testDataArray;
					end
					else if (testDataArrayCopy[12543:12528] == 16'd0)begin
						accumulator <= accumulator;
						testDataArrayCopy <= testDataArrayCopy << 16;
						count3 <= (count3 + 1'b1);
					end
					else if(testDataArrayCopy[12543:12528] == 16'd1) begin
						accumulator <= accumulator + readDataOnChip;
						testDataArrayCopy <= testDataArrayCopy << 16;
						count3 <= (count3 + 1'b1);
					end
				end
				else if(count2 < 157000) begin
					count2 <= (count2 + 1'b1);
					accStore <= ((topaccStore + readDataOnChip) < 0) ? {accStore[3183:0],16'd0} : {accStore[3183:0],16'd1};
				end
			end
		end
		/*
			State2: Send out 40000 addresses corresponding to all the weights of layer 2
			As the data comes in, the calculations will be done in the secondary always loop.
		*/
		state4: begin
			write_n <= 1'b1;
			read_n <= (hl2count < 42200) ? 1'b0 : 1'b1;
			chipselect <= 1'b1;
			byteenable <= 2'b11;
			address <= (waitrequest == 0) ? readAddr : address;
			readAddr <= (hl2count < 42200 && waitrequest == 0) ? readAddr + 1'b1 : readAddr;
			hl2count <= (hl2count < 42200 && waitrequest == 0) ? hl2count + 1'b1 : hl2count;
			
			if (hl2TotalCount == 40199) begin
				hl2accStoreCopy <= hl2accStore;
				//hl2accStoreCopy <= ((hl2accStore[3199:3184] + readdata) < 0) ? {hl2accStore[3183:0], 16'd0} : {hl2accStore[3183:0], 16'd1};
			end
			
			state <= (hl2count < 42200) ? state4 : state5;
		end
		
		state5: begin
			write_n <= 1'b1;
			read_n <= 1'b1;
			chipselect <= 1'b1;
			byteenable <= 2'b11;
			chipselectOnChip <= 1'b0;
			address <= writeAddr;
			
			if (hl2TotalCount == 40199) begin
				hl2accStoreCopy <= hl2accStore;
				//hl2accStoreCopy <= ((tophl2accStore + readdata) < 0) ? (hl2accStore<<16) : {hl2accStore[3183:0],16'd1};
			end
			
			state <= (hl2TotalCount < 42200) ? state5 : state6;
		end
		
		state6: begin
			write_n <= (writeCounter < 200) ? 1'b0 : 1'b1;
			read_n <= 1'b1;
			chipselect <= 1'b1;
			byteenable <= 2'b11;
			address <= (waitrequest == 0) ? writeAddr : address;
			writedata <= hl2accStoreCopy[3199:3184];
			writeAddr <= (waitrequest == 0) ? writeAddr + 1 : writeAddr;
			hl2accStoreCopy <=(writeCounter < 200 && waitrequest == 0) ? hl2accStoreCopy << 16 : hl2accStoreCopy;
			writeCounter <= (writeCounter < 200 && waitrequest == 0) ? writeCounter+1 : writeCounter;
			state <= (writeCounter < 200) ? state6 : state7;
			
			/*)
			write_n <= 1'b0;
			read_n <= 1'b1;
			chipselect <= 1'b1;
			byteenable <= 2'b11;
			address <= writeAddr;
			writedata <= index;*/
			
			state <= (waitrequest == 0) ? state7 : state6;

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

always @ (posedge clk) begin
	if (state == state0 || state == state7) begin
		// Reset Test Data Counter
		testDataCounter <= 32'd0;
		testDataArray <= 0;
		
		//Reset Layer 2 Counters + Accumulators
		hl2accStore <= 0;
		hl2Accumulator <= 0;
		hl2TotalCount <= 0;
		hl2Counter <= 0;
		accStoreCopy <= 0;
		
		// Reset Outut Layers Counters and Accumulators
		outputAccumulator <= 16'd0;
		outputCounter <= 0;
		outputNodeID <= 0;
		max <= 0;
		index <= 0;
	end
	else if (state == state3) begin
		if (count == 157000) begin
			accStoreCopy <= ((topaccStore + readDataOnChip) < 0) ? {accStore[3183:0],16'd0} : {accStore[3183:0],16'd1};
		end
	end
	else if ((readdatavalid == 1'b1) && (testDataCounter < 784)) begin
		testDataCounter <= testDataCounter + 1'b1;
		testDataArray <= (testDataArray << 16) + readdata;
	end
	else if ((readdatavalid == 1'b1) && (testDataCounter >= 784)) begin
		hl2TotalCount <= hl2TotalCount + 1'b1;
		if (hl2TotalCount < 40000) begin
			if ((hl2Counter % 200) == 199) begin
				if(accStoreCopy[3199:3184] == 16'd1) begin
					hl2accStore <= {hl2accStore[3183:0],(hl2Accumulator + readdata)};
				end
				else begin
					hl2accStore <= {hl2accStore[3183:0], hl2Accumulator[15:0]};
				end
				hl2Counter <= 16'd0;
				hl2Accumulator <= 16'd0;
				accStoreCopy <= accStore;
			end
			else if (accStoreCopy[3199:3184] == 16'd0)begin
				hl2Accumulator <= hl2Accumulator;
				accStoreCopy <= accStoreCopy << 16;
				hl2Counter <= hl2Counter + 1'b1;
			end
			else if(accStoreCopy[3199:3184] == 16'd1) begin
				hl2Accumulator <= hl2Accumulator + readdata;
				accStoreCopy <= accStoreCopy << 16;
				hl2Counter <= hl2Counter + 1'b1;
			end
		end
		else if (hl2TotalCount < 40200) begin
			//hl2accStore <= ((tophl2accStore + readdata) < 0) ? {hl2accStore[3183:0], 16'd0} : {hl2accStore[3183:0], 16'd1};
		end
		else if (hl2TotalCount < 42200) begin
			if ((outputCounter % 200) == 199) begin
				outputNodeID <= outputNodeID + 1'b1;
				if(hl2accStore[3199:3184] == 16'd1) begin
					if ((outputAccumulator + readdata) > max) begin
						max <= outputAccumulator + readdata;
						index <= outputNodeID;
					end
				end
				else begin
					if (outputAccumulator > max) begin
						max <= outputAccumulator;
						index <= outputNodeID;
					end
				end
				outputCounter <= 16'd0;
				outputAccumulator <= 0;
				hl2accStore <= hl2accStoreCopy;
			end
			else if (hl2accStore[3199:3184] == 16'd0) begin
				outputAccumulator <= outputAccumulator;
				hl2accStore <= hl2accStore << 16;
				outputCounter <= outputCounter + 1'b1;
			end
			else if (hl2accStore[3199:3184] == 16'd1) begin
				outputAccumulator <= outputAccumulator + readdata;
				hl2accStore <= hl2accStore << 16;
				outputCounter <= outputCounter + 1'b1;
			end
		end
	end
end
endmodule