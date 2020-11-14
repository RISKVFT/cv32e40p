// Copyright 2020 Politecnico di Torino.

////////////////////////////////////////////////////////////////////////////////
// Engineer:       Marcello Neri - s257090@studenti.polito.it                 //
//                                                                            //
//                                                                            //
// Design Name:    RISC-V register file fault tolerant                        //
// Project Name:   RI5CY                                                      //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Module with the same interface of the register file        //
//                 based on flip-flops designed for the RI5CY.                //
//                 This module apply SEC-DED codes to the regfile (SEU), and  //
//                 provides it with fault tolerance properties against        //
//                 permanent errors.                                          //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40p_register_file_ft_hard
#(
    parameter ADDR_WIDTH    = 6,
    parameter DATA_WIDTH    = 32,
    parameter FPU           = 0,
    parameter PULP_ZFINX    = 0
)
(
    // Clock and Reset
    input  logic         clk,
    input  logic         rst_n,

    input  logic         scan_cg_en_i,

    //Read port R1
    input  logic [ADDR_WIDTH-1:0]  raddr_a_i,
    output logic [DATA_WIDTH-1:0]  rdata_a_o,

    //Read port R2
    input  logic [ADDR_WIDTH-1:0]  raddr_b_i,
    output logic [DATA_WIDTH-1:0]  rdata_b_o,

    //Read port R3
    input  logic [ADDR_WIDTH-1:0]  raddr_c_i,
    output logic [DATA_WIDTH-1:0]  rdata_c_o,

    // Write port W1
    input logic [ADDR_WIDTH-1:0]   waddr_a_i,
    input logic [DATA_WIDTH-1:0]   wdata_a_i,
    input logic                    we_a_i,

    // Write port W2
    input logic [ADDR_WIDTH-1:0]   waddr_b_i,
    input logic [DATA_WIDTH-1:0]   wdata_b_i,
    input logic                    we_b_i,

	// Errors signal: no error, sec, ded
	output logic [2:1]			   errors_vector, // signals to state if an error occurred
	input  logic [31:0]			   regfile_location_valid_i, // input coming from performance counter (?)
	output logic [31:0]			   regfile_location_valid_o, // updated valid locations info to send to the performance counter (?)
	output logic				   write_performance_counter_o // write enable to update performance counter register
); 
//////////////////////////////////////////////// END ENTITY ////////////////////////////////////////////////

	// Signals from the encoder to the regfile
	logic [DATA_WIDTH+7-1:0]		wdata_a_encoded_i, wdata_b_encoded_i; // 39 data width (32 data + 7 redundancy)
	//logic [DATA_WIDTH+7-1:0]		wdata_a_encoded_main, wdata_b_encoded_main;
	//logic [DATA_WIDTH+7-1:0]		wdata_a_encoded_second, wdata_b_encoded_second;
	logic							we_a_main, we_b_main;
	logic							we_a_second, we_b_second;

	// Signals from the regfile to the decoder
	logic [DATA_WIDTH+7-1:0]		rdata_a_encoded_o, rdata_b_encoded_o, rdata_c_encoded_o; // 39 data width (32 data + 7 redundancy)
	logic [DATA_WIDTH+7-1:0]		rdata_a_encoded_main, rdata_b_encoded_main, rdata_c_encoded_main;
	logic [DATA_WIDTH+7-1:0]		rdata_a_encoded_second, rdata_b_encoded_second, rdata_c_encoded_second;
	// Errors signals
	logic [2:0]						secded_a, secded_b, secded_c;

	// Signals for fault counters
	parameter						N_counter=5;
	logic [31:0]					en_cnt_faults;
	logic [31:0][1:0]				sel_en_cnt_faults;
	logic [31:0][N_counter-1:0]		cnt_in;
	logic [31:0][N_counter:0]		cnt_out_tmp; // 1 bit wider to produce the flag 
	logic [31:0]					cnt_flag;
	reg	  [31:0][N_counter-1:0]		cnt_out;
	reg	  [31:0]					location_damaged;

	// Signals towards register files
	logic [ADDR_WIDTH-1:0]  raddr_a_main, raddr_b_main, raddr_c_main;
	logic [ADDR_WIDTH-1:0]  raddr_a_second, raddr_b_second, raddr_c_second;

	

  ////////////////////////////////////////////////////////
  //  _____   ____   ____   							//
  // | ____| / ___| / ___|								//
  // |  _|  | |    | | 									//
  // | |___ | |___ | |___  								//
  // \_____| \____| \____|								//
  //                                                    //
  ////////////////////////////////////////////////////////

	//////////////////////////////////
	// 2 WRITE PORTS --> 2 ENCODERS //
	//////////////////////////////////

	//////////// PORT A ////////////
	cv32e40p_hsiao_secded_encoder // current design is for DATA_WIDTH=32
	#(
	.DATA_WIDTH    		( DATA_WIDTH		)
	)
	encoder_a
	(
	//Data to and from encoder
	.data_enc_i			( wdata_a_i			),
	.data_enc_o			( wdata_a_encoded_i	)
	);

	//////////// PORT B ////////////
	cv32e40p_hsiao_secded_encoder // current design is for DATA_WIDTH=32
	#(
	.DATA_WIDTH    		( DATA_WIDTH		)
	)
	encoder_b
	(
	//Data to and from encoder
	.data_enc_i			( wdata_b_i			),
	.data_enc_o			( wdata_b_encoded_i	)
	);

	/////////////////////////////////
	// 3 READ PORTS --> 3 DECODERS //
	/////////////////////////////////

	//////////// PORT A ////////////
	cv32e40p_hsiao_secded_decoder // current design is for DATA_WIDTH=32
	#(
	.DATA_WIDTH    		( DATA_WIDTH		)
	)
	decoder_a
	(
	//Data to and from decoder
	.data_dec_i			( rdata_a_encoded_o	),
	.data_dec_o			( rdata_a_o			),
	.SECDED				( secded_a			)
	);

	//////////// PORT B ////////////
	cv32e40p_hsiao_secded_decoder // current design is for DATA_WIDTH=32
	#(
	.DATA_WIDTH    		( DATA_WIDTH		)
	)
	decoder_b
	(
	//Data to and from decoder
	.data_dec_i			( rdata_b_encoded_o	),
	.data_dec_o			( rdata_b_o			),
	.SECDED				( secded_b			)
	);

	//////////// PORT C ////////////
	cv32e40p_hsiao_secded_decoder // current design is for DATA_WIDTH=32
	#(
	.DATA_WIDTH    		( DATA_WIDTH		)
	)
	decoder_c
	(
	//Data to and from decoder
	.data_dec_i			( rdata_c_encoded_o	),
	.data_dec_o			( rdata_c_o			),
	.SECDED				( secded_c			)
	);


  /////////////////////////////////////////////////////////
  /////////////// ERRORS VECTOR DEFINITION ////////////////
  /////////////////////////////////////////////////////////

	//assign errors_vector[0] = secded_a[0] & secded_b[0] & secded_c[0]; // NO ERROR IN ANY LOCATION
	assign errors_vector[1] = secded_a[1] | secded_b[1] | secded_c[1]; // AT LEAST ONE SINGLE ERROR CORRECTED
	assign errors_vector[2] = secded_a[2] | secded_b[2] | secded_c[2]; // AT LEAST ONE DOUBLE ERROR DETECTED

  /////////////////////////////////////////////////////////
  //  ____  _____ ____ ___ ____ _____ _____ ____  ____   //
  // |  _ \| ____/ ___|_ _/ ___|_   _| ____|  _ \/ ___|  //
  // | |_) |  _|| |  _ | |\___ \ | | |  _| | |_) \___ \  //
  // |  _ <| |__| |_| || | ___) || | | |___|  _ < ___) | //
  // |_| \_\_____\____|___|____/ |_| |_____|_| \_\____/  //
  //                                                     //
  /////////////////////////////////////////////////////////


	/////// MAIN REGFILE ///////
	cv32e40p_register_file
	#(
	.ADDR_WIDTH         ( 6                  ),
	.DATA_WIDTH         ( DATA_WIDTH + 7     ),
	.FPU                ( FPU                ),
	.PULP_ZFINX         ( PULP_ZFINX         )
	)
	register_file_i_main
	(
	.clk                ( clk                ),
	.rst_n              ( rst_n              ),

	.scan_cg_en_i       ( scan_cg_en_i       ),

	// Read port a
	.raddr_a_i          ( raddr_a_main 		),
	.rdata_a_o          ( rdata_a_encoded_main ),

	// Read port b
	.raddr_b_i          ( raddr_b_main 		),
	.rdata_b_o          ( rdata_b_encoded_main	),

	// Read port c
	.raddr_c_i          ( raddr_c_main 		),
	.rdata_c_o          ( rdata_c_encoded_main ),

	// Write port a
	.waddr_a_i          ( waddr_a_i 		),
	.wdata_a_i          ( wdata_a_encoded_i	),
	.we_a_i             ( we_a_main    		),

	// Write port b
	.waddr_b_i          ( waddr_b_i 		),
	.wdata_b_i          ( wdata_b_encoded_i	),
	.we_b_i             ( we_b_main 	 		)
	);

	/////// SECONDARY REGFILE ///////
	cv32e40p_register_file
	#(
	.ADDR_WIDTH         ( 6                  ),
	.DATA_WIDTH         ( DATA_WIDTH + 7     ),
	.FPU                ( FPU                ),
	.PULP_ZFINX         ( PULP_ZFINX         )
	)
	register_file_i_second
	(
	.clk                ( clk                ),
	.rst_n              ( rst_n              ),

	.scan_cg_en_i       ( scan_cg_en_i       ),

	// Read port a
	.raddr_a_i          ( raddr_a_second 		),
	.rdata_a_o          ( rdata_a_encoded_second ),

	// Read port b
	.raddr_b_i          ( raddr_b_second 		),
	.rdata_b_o          ( rdata_b_encoded_second	),

	// Read port c
	.raddr_c_i          ( raddr_c_second 		),
	.rdata_c_o          ( rdata_c_encoded_second ),

	// Write port a
	.waddr_a_i          ( waddr_a_i 		),
	.wdata_a_i          ( wdata_a_encoded_i	),
	.we_a_i             ( we_a_second    		),

	// Write port b
	.waddr_b_i          ( waddr_b_i 		),
	.wdata_b_i          ( wdata_b_encoded_i	),
	.we_b_i             ( we_b_second 	 		)
	);


// read address for main regfile
assign raddr_a_main = raddr_a_i & {6{~location_damaged[raddr_a_i[4:0]]}};
assign raddr_b_main = raddr_b_i & {6{~location_damaged[raddr_b_i[4:0]]}};
assign raddr_c_main = raddr_c_i & {6{~location_damaged[raddr_c_i[4:0]]}};

// read address for secondary regfile
assign raddr_a_second = raddr_a_i & {6{location_damaged[raddr_a_i[4:0]]}};
assign raddr_b_second = raddr_b_i & {6{location_damaged[raddr_b_i[4:0]]}};
assign raddr_c_second = raddr_c_i & {6{location_damaged[raddr_c_i[4:0]]}};

// write en for main regfile
assign we_a_main = we_a_i & {6{~location_damaged[waddr_a_i[4:0]]}};
assign we_b_main = we_b_i & {6{~location_damaged[waddr_b_i[4:0]]}};

// write en for secondary regfile
assign we_a_second = we_a_i & {6{location_damaged[waddr_a_i[4:0]]}};
assign we_b_second = we_b_i & {6{location_damaged[waddr_b_i[4:0]]}};


// data to and from encoder/decoder for ECC
assign rdata_a_encoded_o = location_damaged[raddr_a_i[4:0]] ? rdata_a_encoded_second : rdata_a_encoded_main; // mux 2to1. Forse si può mettere direttamente una porta OR perché dal regfile che non leggo esce '000...000'
assign rdata_b_encoded_o = location_damaged[raddr_b_i[4:0]] ? rdata_b_encoded_second : rdata_b_encoded_main;
assign rdata_c_encoded_o = location_damaged[raddr_c_i[4:0]] ? rdata_c_encoded_second : rdata_c_encoded_main;

//assign rdata_a_encoded_o = rdata_a_encoded_second | rdata_a_encoded_main; // alternativa
//assign rdata_b_encoded_o = rdata_b_encoded_second | rdata_b_encoded_main;
//assign rdata_c_encoded_o = rdata_c_encoded_second | rdata_c_encoded_main;



// combinatorial block to generate the enable for the faults counter (actually it is a mux4to1, with sel and inputs generated with logic gates)
//sel_en_cnt_faults signal could be removed
always @ (raddr_a_i, raddr_b_i, raddr_c_i, secded_a, secded_b, secded_c)
	begin
		for (int i=0; i<32; i++) begin
			//sel_en_cnt_faults[i] = 2'b0;

			case (i)
				raddr_a_i: begin
					sel_en_cnt_faults[i] = 2'b01;
					en_cnt_faults[i] = secded_a[1] | secded_a[2];
				end
				raddr_b_i: begin
					sel_en_cnt_faults[i] = 2'b10;
					en_cnt_faults[i] = secded_b[1] | secded_b[2];
				end
				raddr_c_i: begin
					sel_en_cnt_faults[i] = 2'b11;
					en_cnt_faults[i] = secded_c[1] | secded_c[2];
				end
				default: begin
					sel_en_cnt_faults[i] = 2'b00;
					en_cnt_faults[i] = 1'b0;
				end
			endcase
		end
end

// fault counters generation: if a fault occurs more than 31 times ---> that location is permanently damaged!
genvar i;
generate
	for (i=0;i<32;i++) begin 
		// counter combinatorial part
		always @ (cnt_in[i], en_cnt_faults[i]) begin
			unique case ( en_cnt_faults[i] )
				1'b1 : cnt_out_tmp[i] = cnt_in[i] +1;
				1'b0 : cnt_out_tmp[i] = cnt_in[i];
			endcase
		end
		// counter sequential part
		always_ff @(posedge clk or negedge rst_n) begin
			  if(!rst_n) begin
				cnt_out[i] <= 0;
			  end else begin
				if (cnt_out_tmp[i] == 2**N_counter -1) begin
					cnt_out[i] <= 0;
					cnt_flag[i] = 1'b1;
				end else begin
					cnt_out[i] <= cnt_out_tmp[i];
				end
			  end
		end

		// register where info about damaged locations of regfile is stored
		always_ff @(posedge clk or negedge rst_n) begin
		  if(!rst_n) begin
		    location_damaged[i] <= regfile_location_valid_i[i];
			write_performance_counter_o <= 1'b0;
		  end else begin
				if (cnt_flag[i] == 1) begin
					location_damaged[i] <= 1'b1;
					write_performance_counter_o <= 1'b1;
				end else begin
					location_damaged[i] <= location_damaged[i];
					write_performance_counter_o <= 1'b0;
				end
		  end
		end	
	end

endgenerate

assign regfile_location_valid_o = location_damaged;

endmodule
