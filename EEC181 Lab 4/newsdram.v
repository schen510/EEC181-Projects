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

reg [15:0] READDATA_SDRAM;
reg [15:0] READDATA_ONCHIP;
reg[15:0] accumulator;
reg [3:0] state;
reg [31:0] ADDR_SDRAM;
reg [31:0] ADDR_ONCHIP;
reg [31:0] pixelcounter;
reg SDRAMFLAG;
reg ONCHIPFLAG;
reg READSDRAMFLAG;
reg READONCHIPFLAG;

// Flags
reg readdone;

localparam state0 = 4'd0;
localparam state1 = 4'd1;
localparam state2 = 4'd2; 
localparam state3 = 4'd3;
localparam state4 = 4'd4; 
localparam state5 = 4'd5;
localparam state6 = 4'd6;
localparam state7 = 4'd7;

assign s = state[3:0];

initial begin
	state = 4'd0;
	count = 0;
	count2 = 0;
	SDRAMFLAG = 0;
	ONCHIPFLAG = 0;
	READSDRAMFLAG = 0;
	READONCHIPFLAG = 0;
	accumulator = 0;
	pixelcounter = 0;
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
			count <= 32'h0400_0000;
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
			read_n <= 1'b0;
			chipselect <= 1'b1;
			byteenable <= 2'b11;
			address <= (waitrequest == 0) ? ADDR_SDRAM : address;
			ADDR_SDRAM <= (waitrequest == 0) ? ADDR_SDRAM+1 : ADDR_SDRAM;
			SDRAMFLAG <= (waitrequest == 0) ? 1'b1 : 1'b0;
			state <= (waitrequest == 0) ? state2 : state1;
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
			if(READSDRAMFLAG) begin
				SDRAMFLAG <= 1'b0;
				state <= state3;
			end
			else begin
				state <= state2;
			end
		end
		
		// wait for computations to be done; doesn't matter if the first couple cycles are garbage
		// allows for parallelism, which will speed up the process
		state3: begin
			if(READDATA_SDRAM == 0) begin
				ADDR_ONCHIP <= ADDR_ONCHIP + 1'b1; 
				if pixelcounter == 783 begin
					pixelcounter <= 16'd0;
					state <= state7;
				end
				else
					pixelcounter <= pixelcounter + 1'b1;
					state <= state1;
			end
			else begin
				pixelcounter <= pixelcounter + 1'b1;
				state <= state4;
			end
		end
		
		// writes the values into sdram ( potentially could combine with state 3 to increase parallelism )
		state4: begin
			write_n <= 1'b1;
			read_n <= 1'b0;
			chipselect <= 1'b1;
			byteenable <= 2'b11;
			address <= (waitrequest == 0) ? ADDR_ONCHIP : address;
			ADDR_SDRAM <= (waitrequest == 0) ? ADDR_ONCHIP+1 : ADDR_ONCHIP;
			ONCHIPFLAG <= (waitrequest == 0) ? 1'b1 : 1'b0;
			state <= (waitrequest == 0) ? state5 : state4;
		end
		
		// send out addresses of next values to be read into the array
		state5: begin
			write_n <= 1'b1;
			read_n <= 1'b1;
			chipselect <= 1'b1;
			if(READONCHIPFLAG) begin
				ONCHIPFLAG <= 1'b0;
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
			chipselect <= 1'b1;
			
			accumulator <= accumulator + READDATA_ONCHIP;
			if (pixelcounter < 784) begin
				state <= state1;
			else
				state <= state7;
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
	if ((readdatavalid == 1'b1) && SDRAMFLAG == 1'b1) begin
		READDATA_SDRAM <= readdata;
		READSDRAMFLAG <= 1'b1;
	end
	if ((readatavalid == 1'b1) && ONCHIPFLAG == 1'b1) begin
		READDATA_ONCHIP <= readdata;
		READONCHIPFLAG <= 1'b1;
	end
	else begin
		READSDRAMFLAG <= 1'b0;
		READONCHIPFLAG <= 1'b0;
	end
end

endmodule