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

reg [2:0] state;
reg [3:0] count;
reg [3:0] count2;
 
//The lowest maximum possible is 0 and highest minimum is all 16 bits asserted
reg [15:0] max;
reg [15:0] min;

localparam state0 = 4'd0;
localparam state1 = 4'd1;
localparam state2 = 4'd2; 
localparam state3 = 4'd3;
localparam state4 = 4'd4; 
localparam state5 = 4'd5; 
localparam MINADD = 32'd1;
localparam MAXADD = 32'd2;

assign s = {1'b0, state};

initial begin
	state = 3'd0;
	count = 0;
	max = 16'd0;
	min = 16'hffff;
	count2 = 0;
end


always @ (posedge clk) begin

	case(state)
		/*
			state 0 waits for a start signal -- the c code will put a 1 at the 11th spot
			once we grab that then we can start the check for the minimum and maximum values
			by moving to state 1
		*/
		
		state0: begin
			doneSig <= 1'b1;
			count <= 0;
			write_n <= 1'b1;
			chipselect <= 1'b0;
			byteenable <= 2'b00;
			address <= 0;
			read_n <= 1'b1;
			if(~startSig) begin
				state <= state0;
			end
			else begin
				state <= state1;
			end
		end
		
		/*
			state 1 is the state to determine whether we write or read (the other idea is that you have a read and write state)
			if this doesn't work then scrap it and change state 1 to purely read and as follows
			it sends out the read/write/chipselect stuff and then sends it to state 2 if the count is less than 10 (10 would rep. the 11th value)
			at the 11th value you want to move to writing the min + max values to their corresponding addresses since
			you know the minimum and maximum at this point in time (move to state3)
		*/
		state1: begin
			write_n <= 1'b1;
			read_n <= count < 10 ? 0 : 1;
			chipselect <= 1'b1;
			byteenable <= 2'b11;
			address <= (waitrequest == 0) ? count : address;
			count <= (count < 10 && waitrequest == 0) ? count + 1 : count;
			state <= (count < 10) ? state1 : state2;
			
			/*
			if ((waitrequest == 1'b0)) begin
				address <= count;
				if( count < 10 ) begin
					count <= count + 1;
					state <= state1;
				end
				else begin
					count <= count;
					state <= state3;
				end
			end
			else begin
				address <= address;
			end
			*/
		end
		/*
			Have to wait until all 10 values come in. When all 10 values come in proceed to min and max
			count2 is modified in the next always statement.
		*/
		state2: begin
			write_n <= 1'b1;
			read_n <= 1'b1;
			chipselect <= 1'b1;
			if(count2 < 10) begin
				state <= state2;
			end
			else begin
				state <= state3;
			end
		end
		/*
			state3 writes the minimum value to the MINADD which contains the address of where the minimum value should begin
			if it is successful, then it will transition to writing the maximum value, otherwise it stays in this state
		*/
		state3: begin
			write_n <= 1'b0;
			read_n <= 1'b1;
			chipselect <= 1'b1;
			byteenable <= 2'b11;
			address <= MINADD;
			writedata <= min;
			if (waitrequest == 1'b0) begin
				state <= state4;
			end
			else begin
				state <= state3;
			end
		end
		
		state4: begin
			write_n <= 1'b0;
			read_n <= 1'b1;
			chipselect <= 1'b1;
			byteenable <= 2'b11;
			address <= MAXADD;
			writedata <= max;
			if (waitrequest == 1'b0) begin
				state <= state5;
			end
			else begin
				state <= state4;
			end
		end
		
		state5: begin
			doneSig <= 1'b0;
			state <= state5;
		end
		
		default: begin
			state <= state0;
			read_n <= 1'b1;
			write_n <= 1'b1;
			chipselect <= 1'b0;
			byteenable <= 2'b00;
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
	if ((readdatavalid == 1'b1)) begin
		if(readdata > max) begin
			max <= readdata;
		end
		if(readdata < min) begin
			min <= readdata;
		end
		count2 <= count2 + 1;
	end
	else begin
		count2 <= count2;
		max <= max;
		min <= min;
	end
end

endmodule