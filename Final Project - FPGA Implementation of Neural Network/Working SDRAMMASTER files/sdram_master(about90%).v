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

reg [3:0] state;
reg reset_flag = 1'b0;

// Registers required for calculation of Layer 1
reg [31:0] count, count2, count3, countImage, testDataCounter, readAddr, readtestDataCounter, MAXLIMIT_READ, readImageAddr;
reg [31:0] writeAddrOnChip; 
reg signed [15:0] accumulator;
reg [15:0] testData [0:783];
reg signed [15:0] accStore [0:199];
reg [9:0] NodeID, biasCounter;

// Registers required for calculations of Layer 2
reg [31:0] hl2count;
reg [31:0] hl2TotalCount, hl2Counter;
reg signed [15:0] hl2Accumulator;
reg signed [15:0] hl2accStore [0:199];
reg [8:0] hl2NodeID;

// Registers related to WriteBack Operations
reg [31:0] writeCounter;
reg [31:0] writeAddr;

localparam state0 = 4'd0;
localparam state1 = 4'd1;
localparam state2 = 4'd2; 
localparam state3 = 4'd3;
localparam state4 = 4'd4; 
localparam state5 = 4'd5;
localparam state6 = 4'd6;
localparam state7 = 4'd7;
localparam state8 = 4'd8;

assign s = state[3:0];

always @ (posedge clk) begin
	case(state)
		/*
			State 0: Acts as a reset state to reset all the signals that we need to do the calculations
		*/
		state0: begin
			doneSig <= 1'b1;
			countImage <= 32'd0;
			
			//SDRAM Related Variables
			write_n <= 1'b1;
			read_n <= 1'b1;
			chipselect <= 1'b1;
			byteenable <= 2'b11;
			address <= 32'd400000;
			count <= 32'd0;
			
			// Write Related Variables
			writeCounter <= 32'd0;
			writeAddr <= 32'd300000;
			writeAddrOnChip <= 32'h04000000;
			
			// Read SDRAM Related Variables
			readtestDataCounter <= 32'd0;
			readAddr <= 32'd162200;
			readImageAddr <= 32'd400000;
			MAXLIMIT_READ <= 32'd784;
			
			// On Chip Addressing
			addressOnChip <= 32'h04000000;
			chipselectOnChip <= 1'b1;
			write <= 1'b0;
			byteenableOnChip <= 2'b11;
			
			//Calculation Related Variables
			count2 <= 32'd0;
			count3 <= 32'd0;
			accumulator <= 16'd0;
			NodeID <= 10'd0;
			biasCounter <= 10'd0;
			hl2count <= 0;
			
			//HL2 stuff
			hl2Accumulator <= 16'd0;
			hl2TotalCount <= 32'd0;
			hl2Counter <= 32'd0;
			hl2NodeID <= 9'd0;
			testDataCounter <= 32'd0;
			
			//state change
			state <= (startSig == 1) ? state1 : state0;
		end
		
		state1: begin
			write_n <= 1'b1;
			read_n <= (readtestDataCounter < 784) ? 1'b0 : 1'b1;
			chipselect <= 1'b1;
			byteenable <= 2'b11;
			address <= (waitrequest == 0) ? readImageAddr : address;
			readImageAddr <= ((readtestDataCounter < 784) && waitrequest == 0) ? readImageAddr + 1'b1 : readImageAddr;
			readtestDataCounter <= ((readtestDataCounter < 784) && waitrequest == 0) ? readtestDataCounter + 1'b1 : readtestDataCounter;
		
			if (readdatavalid == 1'b1) begin
				testData[testDataCounter] <= readdata;
				testDataCounter <= testDataCounter + 1'b1;
			end
			else begin
				testDataCounter <= testDataCounter;
			end
		
			state <= (testDataCounter < 784) ? state1 : state2;
		end
		
		/*
			State 1: send out 157584 addresses -- 784 for the input data and 784 weight per node 
			since we have 200 nodes, we will send out 784*200 additional addreses. In the C code,
			we will make sure we are dealing with 16 bit values STRICTLY. This will allow us to avoid
			any addressing issues
		*/
		state2: begin
			write_n <= 1'b1;
			read_n <= 1'b1;
			chipselect <= 1'b1;
			byteenable <= 2'b11;
			address <= (count < 157000) ? address : readAddr;
		
			write <= 1'b0;
			chipselectOnChip <= (count < 157000) ? 1'b1 : 1'b0;
			byteenableOnChip <= 2'b11;
			addressOnChip <= addressOnChip + 1'b1;
			count <= (count < 157000) ? count + 1'b1 : count;
			state <= (count < 157000) ? state2 : state3;

			if(count >= 1)begin
				count2 <= (count2 + 1'b1);
				if(count2 < 156800) begin
					if ((count3 % 784) == 783) begin
						if(testData[783] == 16'd1) begin
							accStore[NodeID] <= accumulator + readDataOnChip;
						end
						else begin
							accStore[NodeID] <= accumulator;
						end
						accumulator <= 16'd0;
						count3 <= 16'd0;
						NodeID <= NodeID + 1'b1;
					end
					else if (testData[count3] == 16'd0)begin
						accumulator <= accumulator;
						count3 <= (count3 + 1'b1);
					end
					else begin
						accumulator <= accumulator + readDataOnChip;
						count3 <= (count3 + 1'b1);
					end
				end
				else begin
					accStore[biasCounter] <= ((accStore[biasCounter] + readDataOnChip) < 0) ? 16'd0 : 16'd1;
					biasCounter <= biasCounter + 1'b1;
				end
			end
		end
		/*
			State2: Send out 40000 addresses corresponding to all the weights of layer 2
			As the data comes in, the calculations will be done in the secondary always loop.
		*/
		state3: begin
			write_n <= 1'b1;
			read_n <= (hl2count < 40000) ? 1'b0 : 1'b1;
			chipselect <= 1'b1;
			byteenable <= 2'b11;
			address <= (waitrequest == 0) ? address + 1'b1 : address;
			//readAddr <= ((hl2count < 40000) && waitrequest == 0) ? readAddr + 1'b1 : readAddr;
			hl2count <= ((hl2count < 40000) && waitrequest == 0) ? hl2count + 1'b1 : hl2count;
			
			if(readdatavalid == 1'b1) begin
				hl2TotalCount <= hl2TotalCount + 1'b1;
				if ((hl2Counter % 200) == 199) begin
					if(accStore[199] == 16'd1) begin
						hl2accStore[hl2NodeID] <= hl2Accumulator + readdata;
					end
					else begin
						hl2accStore[hl2NodeID] <= hl2Accumulator;
					end
					hl2NodeID <= hl2NodeID + 1'b1;
					hl2Counter <= 16'd0;
					hl2Accumulator <= 16'd0;
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
			else begin 
				hl2Accumulator <= hl2Accumulator;
				hl2TotalCount <= hl2TotalCount;
				hl2Counter <= hl2Counter;
				hl2NodeID <= hl2NodeID;
			end
			
			state <= (hl2TotalCount < 40000) ? state3 : state4;
		end
		
		state4: begin
			write_n <= (writeCounter < 200) ? 1'b0 : 1'b1;
			read_n <= 1'b1;
			chipselect <= 1'b1;
			byteenable <= 2'b11;
			address <= (waitrequest == 0) ? writeAddr : address;
			writedata <= (writeCounter < 200) ? accStore[writeCounter] : 16'd0;
			writeAddr <= (writeCounter < 200 && waitrequest == 0) ? writeAddr + 1'b1: writeAddr;
			writeCounter <= (writeCounter < 200 && waitrequest == 0) ? writeCounter + 1'b1 : writeCounter;
			state <= (writeCounter < 200) ? state4 : state5;
		end
		
		// Reset
		state5: begin
			write_n <= 1'b1;
			read_n <= 1'b1;
			chipselect <= 1'b1;
			byteenable <= 2'b11;
			address <= readImageAddr;
			readtestDataCounter <= 32'd0;
			
			// Reset Calculation/Write  Counters
			count <= 32'd0;
			count2 <= 32'd0;
			count3 <= 32'd0;
			accumulator <= 16'd0;
			NodeID <= 10'd0;
			biasCounter <= 10'd0;
			hl2count <= 32'd0;
			
			writeCounter <= 0;
			addressOnChip <= 32'h04000000;
			chipselectOnChip <= 1'b1;
			
			readAddr <= 162200;
			writeAddrOnChip <= 32'h04000000;
			
			// Change UpperLimit
			MAXLIMIT_READ <= MAXLIMIT_READ + 32'd784;
			
			//HL2 Stuff
			hl2Accumulator <= 16'd0;
			hl2TotalCount <= 32'd0;
			hl2Counter <= 32'd0;
			hl2NodeID <= 9'd0;
			testDataCounter <= 32'd0;
			
			//state change
			
			if (countImage < 399) begin
				doneSig <= 1'b1;
				countImage <= countImage + 1'b1;
				state <= state1;
			end
			else begin
				doneSig <= 1'b0;
				countImage <= countImage;
				state <= state5;
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
/*
always @ (posedge clk) begin
	if (reset_flag == 1'b1) begin
		hl2Accumulator <= 16'd0;
		hl2TotalCount <= 32'd0;
		hl2Counter <= 32'd0;
		hl2NodeID <= 9'd0;
		testDataCounter <= 32'd0;
	end
	else if ((readdatavalid == 1'b1) && (testDataCounter < 784)) begin
		testData[testDataCounter] <= readdata;
		testDataCounter <= testDataCounter + 1'b1;
	end
	else if ((readdatavalid == 1'b1) && (testDataCounter >= 784)) begin
		hl2TotalCount <= hl2TotalCount + 1'b1;
		if ((hl2Counter % 200) == 199) begin
			if(accStore[199] == 16'd1) begin
				hl2accStore[hl2NodeID] <= hl2Accumulator + readdata;
			end
			else begin
				hl2accStore[hl2NodeID] <= hl2Accumulator;
			end
			hl2NodeID <= hl2NodeID + 1'b1;
			hl2Counter <= 16'd0;
			hl2Accumulator <= 16'd0;
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
	else begin
		hl2Accumulator <= hl2Accumulator;
		hl2TotalCount <= hl2TotalCount;
		hl2Counter <= hl2Counter;
		hl2NodeID <= hl2NodeID;
		testDataCounter <= testDataCounter;
	end
end*/
endmodule