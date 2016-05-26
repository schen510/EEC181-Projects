	mysystem u0 (
		.donesignal_export                   (<connected-to-donesignal_export>),                   //     donesignal.export
		.memory_mem_a                        (<connected-to-memory_mem_a>),                        //         memory.mem_a
		.memory_mem_ba                       (<connected-to-memory_mem_ba>),                       //               .mem_ba
		.memory_mem_ck                       (<connected-to-memory_mem_ck>),                       //               .mem_ck
		.memory_mem_ck_n                     (<connected-to-memory_mem_ck_n>),                     //               .mem_ck_n
		.memory_mem_cke                      (<connected-to-memory_mem_cke>),                      //               .mem_cke
		.memory_mem_cs_n                     (<connected-to-memory_mem_cs_n>),                     //               .mem_cs_n
		.memory_mem_ras_n                    (<connected-to-memory_mem_ras_n>),                    //               .mem_ras_n
		.memory_mem_cas_n                    (<connected-to-memory_mem_cas_n>),                    //               .mem_cas_n
		.memory_mem_we_n                     (<connected-to-memory_mem_we_n>),                     //               .mem_we_n
		.memory_mem_reset_n                  (<connected-to-memory_mem_reset_n>),                  //               .mem_reset_n
		.memory_mem_dq                       (<connected-to-memory_mem_dq>),                       //               .mem_dq
		.memory_mem_dqs                      (<connected-to-memory_mem_dqs>),                      //               .mem_dqs
		.memory_mem_dqs_n                    (<connected-to-memory_mem_dqs_n>),                    //               .mem_dqs_n
		.memory_mem_odt                      (<connected-to-memory_mem_odt>),                      //               .mem_odt
		.memory_mem_dm                       (<connected-to-memory_mem_dm>),                       //               .mem_dm
		.memory_oct_rzqin                    (<connected-to-memory_oct_rzqin>),                    //               .oct_rzqin
		.pushbutton_export                   (<connected-to-pushbutton_export>),                   //     pushbutton.export
		.sdram_clk_clk                       (<connected-to-sdram_clk_clk>),                       //      sdram_clk.clk
		.sdram_wire_addr                     (<connected-to-sdram_wire_addr>),                     //     sdram_wire.addr
		.sdram_wire_ba                       (<connected-to-sdram_wire_ba>),                       //               .ba
		.sdram_wire_cas_n                    (<connected-to-sdram_wire_cas_n>),                    //               .cas_n
		.sdram_wire_cke                      (<connected-to-sdram_wire_cke>),                      //               .cke
		.sdram_wire_cs_n                     (<connected-to-sdram_wire_cs_n>),                     //               .cs_n
		.sdram_wire_dq                       (<connected-to-sdram_wire_dq>),                       //               .dq
		.sdram_wire_dqm                      (<connected-to-sdram_wire_dqm>),                      //               .dqm
		.sdram_wire_ras_n                    (<connected-to-sdram_wire_ras_n>),                    //               .ras_n
		.sdram_wire_we_n                     (<connected-to-sdram_wire_we_n>),                     //               .we_n
		.sdramstartstop_beginbursttransfer   (<connected-to-sdramstartstop_beginbursttransfer>),   // sdramstartstop.beginbursttransfer
		.sdramstartstop_writeresponsevalid_n (<connected-to-sdramstartstop_writeresponsevalid_n>), //               .writeresponsevalid_n
		.startsignal_export                  (<connected-to-startsignal_export>),                  //    startsignal.export
		.sys_ref_clk_clk                     (<connected-to-sys_ref_clk_clk>),                     //    sys_ref_clk.clk
		.sys_ref_reset_reset                 (<connected-to-sys_ref_reset_reset>),                 //  sys_ref_reset.reset
		.to_hex_to_led_readdata              (<connected-to-to_hex_to_led_readdata>)               //  to_hex_to_led.readdata
	);

