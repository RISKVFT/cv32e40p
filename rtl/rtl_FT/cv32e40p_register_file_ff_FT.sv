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

module cv32e40p_register_file_ft
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

	// Errors signal: ded, sec
	output logic [2:1]			   errors_vector
); 
//////////////////////////////////////////////// END ENTITY ////////////////////////////////////////////////

	// Signals from the encoder to the regfile
	logic [DATA_WIDTH+7-1:0]		wdata_a_encoded_i, wdata_b_encoded_i; // 39 data width (32 data + 7 redundancy)
	// Signals from the regfile to the decoder
	logic [DATA_WIDTH+7-1:0]		rdata_a_encoded_o, rdata_b_encoded_o, rdata_c_encoded_o; // 39 data width (32 data + 7 redundancy)
	// Errors signals
	logic [2:0]						secded_a, secded_b, secded_c;


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

	cv32e40p_register_file
	#(
	.ADDR_WIDTH         ( 6                  ),
	.DATA_WIDTH         ( DATA_WIDTH + 7     ),
	.FPU                ( FPU                ),
	.PULP_ZFINX         ( PULP_ZFINX         )
	)
	register_file_i
	(
	.clk                ( clk                ),
	.rst_n              ( rst_n              ),

	.scan_cg_en_i       ( scan_cg_en_i       ),

	// Read port a
	.raddr_a_i          ( raddr_a_i 		),
	.rdata_a_o          ( rdata_a_encoded_o ),

	// Read port b
	.raddr_b_i          ( raddr_b_i 		),
	.rdata_b_o          ( rdata_b_encoded_o	),

	// Read port c
	.raddr_c_i          ( raddr_c_i 		),
	.rdata_c_o          ( rdata_c_encoded_o ),

	// Write port a
	.waddr_a_i          ( waddr_a_i 		),
	.wdata_a_i          ( wdata_a_encoded_i	),
	.we_a_i             ( we_a_i    		),

	// Write port b
	.waddr_b_i          ( waddr_b_i 		),
	.wdata_b_i          ( wdata_b_encoded_i	),
	.we_b_i             ( we_b_i 	 		)
	);

endmodule
