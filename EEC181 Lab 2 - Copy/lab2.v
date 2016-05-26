module lab2(
CLOCK_50,
DRAM_CLK ,
DRAM_CKE ,
DRAM_ADDR ,
DRAM_BA ,
DRAM_CAS_N ,
DRAM_CS_N,
DRAM_RAS_N ,
DRAM_WE_N,
DRAM_DQ ,
DRAM_UDQM ,
DRAM_LDQM ,

HEX0,
HEX1,
HEX2,
HEX3,
HEX4,
HEX5,

KEY,

LEDR,

SW,

HPS_DDR3_ADDR,
HPS_DDR3_BA,
HPS_DDR3_CAS_N,
HPS_DDR3_CKE,
HPS_DDR3_CK_N,
HPS_DDR3_CK_P,
HPS_DDR3_CS_N,
HPS_DDR3_DM,
HPS_DDR3_DQ,
HPS_DDR3_DQS_N,
HPS_DDR3_DQS_P,
HPS_DDR3_ODT,
HPS_DDR3_RAS_N,
HPS_DDR3_RESET_N,
HPS_DDR3_RZQ,
HPS_DDR3_WE_N,
);

input CLOCK_50; 
output DRAM_CLK;
output [0:6] HEX0,HEX1,HEX2,HEX3,HEX4,HEX5;
input[3:0] KEY;
output[9:0]LEDR;
input[9:0]SW;

output [14:0] HPS_DDR3_ADDR;
output [2:0] HPS_DDR3_BA;
output HPS_DDR3_CAS_N;
output HPS_DDR3_CKE;
output HPS_DDR3_CK_N;
output HPS_DDR3_CK_P;
output HPS_DDR3_CS_N;
output [3:0] HPS_DDR3_DM;
inout [31:0] HPS_DDR3_DQ;
inout [3:0] HPS_DDR3_DQS_N;
inout [3:0] HPS_DDR3_DQS_P;
output HPS_DDR3_ODT;
output HPS_DDR3_RAS_N;
output HPS_DDR3_RESET_N;
input HPS_DDR3_RZQ;
output HPS_DDR3_WE_N;

output DRAM_CKE;
output [12:0] DRAM_ADDR;
output [1:0] DRAM_BA;
output DRAM_CAS_N;
output DRAM_CS_N;
output DRAM_RAS_N;
output DRAM_WE_N;
inout [15:0] DRAM_DQ; 
output DRAM_UDQM;
output DRAM_LDQM;

wire [31:0] hex3_hex0;
wire [0:6] store1;
wire [0:6] store2;
wire [0:6] store3;
wire [0:6] store4;
wire [0:6] store5;
wire [0:6] store6;
wire [0:6] store7;
wire [0:12] storeLED;

assign HEX0 = store1[0:6];
assign HEX1 = store2[0:6];
assign HEX2 = store3[0:6];
assign HEX3 = store4[0:6];
assign HEX4 = store5[0:6];
assign HEX5 = store6[0:6];
assign LEDR = hex3_hex0[31:24];


hex_7seg display1(hex3_hex0[3:0],store1[0:6]);
hex_7seg display2(hex3_hex0[7:4],store2[0:6]);
hex_7seg display3(hex3_hex0[11:8],store3[0:6]);
hex_7seg display4(hex3_hex0[15:12],store4[0:6]);
hex_7seg display5(hex3_hex0[19:16],store5[0:6]);
hex_7seg dfisplay6(hex3_hex0[23:20],store6[0:6]);

    mysystem u0 (
        .memory_mem_a       (HPS_DDR3_ADDR),       //      memory.mem_a
        .memory_mem_ba      (HPS_DDR3_BA),      //            .mem_ba
        .memory_mem_ck      (HPS_DDR3_CK_P),      //            .mem_ck
        .memory_mem_ck_n    (HPS_DDR3_CK_N),    //            .mem_ck_n
        .memory_mem_cke     (HPS_DDR3_CKE),     //            .mem_cke
        .memory_mem_cs_n    (HPS_DDR3_CS_N),    //            .mem_cs_n
        .memory_mem_ras_n   (HPS_DDR3_RAS_N),   //            .mem_ras_n
        .memory_mem_cas_n   (HPS_DDR3_CAS_N),   //            .mem_cas_n
        .memory_mem_we_n    (HPS_DDR3_WE_N),    //            .mem_we_n
        .memory_mem_reset_n (HPS_DDR3_RESET_N), //            .mem_reset_n<connected-to-to_hex_to_led_readdata>
        .memory_mem_dq      (HPS_DDR3_DQ),      //            .mem_dq
        .memory_mem_dqs     (HPS_DDR3_DQS_P),     //            .mem_dqs
        .memory_mem_dqs_n   (HPS_DDR3_DQS_N),   //            .mem_dqs_n
        .memory_mem_odt     (HPS_DDR3_ODT),     //            .mem_odt
        .memory_mem_dm      (HPS_DDR3_DM),      //            .mem_dm
        .memory_oct_rzqin   (HPS_DDR3_RZQ),   //            .oct_rzqin
        .sdram_clk_clk          (DRAM_CLK),          //        sdram_clk.clk
        .sys_ref_clk_clk     (CLOCK_50),     //   system_ref_clk.clk
        .sys_ref_reset_reset (~KEY[0]), // system_ref_reset.reset
        .to_hex_to_led_readdata (hex3_hex0),  //    to_hex_to_led.readdata
		  .pushbutton_export      (~KEY[3:1]),     //       pushbutton.export
		  .sdram_wire_addr        (DRAM_ADDR),        //    sdram_wire.addr
        .sdram_wire_ba          (DRAM_BA),          //              .ba
        .sdram_wire_cas_n       (DRAM_CAS_N),       //              .cas_n
        .sdram_wire_cke         (DRAM_CKE),         //              .cke
        .sdram_wire_cs_n        (DRAM_CS_N),        //              .cs_n
        .sdram_wire_dq          (DRAM_DQ),          //              .dq
        .sdram_wire_dqm         ({DRAM_UDQM,DRAM_LDQM}),         //              .dqm
        .sdram_wire_ras_n       (DRAM_RAS_N),       //              .ras_n
        .sdram_wire_we_n        (DRAM_WE_N)         //              .we_n
    );
endmodule




