// Copyright 2020 Politecnico di Torino.


////////////////////////////////////////////////////////////////////////////////
// Engineer:       Luca Fiore - luca.fiore@studenti.polito.it                 //
//                                                                            //
// Additional contributions by:                                               //
//                 Marcello Neri - s257090@studenti.polito.it                 //
//                 Elia Ribaldone - s265613@studenti.polito.it                //
//                                                                            //
// Design Name:    cv32e40p_mult_ft                                           //
// Project Name:   cv32e40p Fault tolerant                                    //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Fault tolerant version of cv32e40p mult.                   //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////   


module cv32e40p_mult_ft import cv32e40p_pkg::*;
#(
  parameter FT = 0
)
(
  input  logic        clk,
  input  logic        rst_n,

  input  logic [ 3:0]       enable_i,
  input  logic [ 3:0][ 2:0] operator_i,

  // integer and short multiplier
  input  logic [ 3:0]       short_subword_i,
  input  logic [ 3:0][ 1:0] short_signed_i,

  input  logic [ 3:0][31:0] op_a_i,
  input  logic [ 3:0][31:0] op_b_i,
  input  logic [ 3:0][31:0] op_c_i,

  input  logic [ 3:0][ 4:0] imm_i,

  // dot multiplier
  input  logic [ 3:0][ 1:0] dot_signed_i,
  input  logic [ 3:0][31:0] dot_op_a_i,
  input  logic [ 3:0][31:0] dot_op_b_i,
  input  logic [ 3:0][31:0] dot_op_c_i,
  input  logic [ 3:0]       is_clpx_i,
  input  logic [ 3:0][ 1:0] clpx_shift_i,
  input  logic [ 3:0]       clpx_img_i,

  output logic [31:0] result_o,

  output logic        multicycle_o,
  output logic        ready_o,
  input  logic        ex_ready_i,

  // ft  
  input  logic [3:0]		  clock_en_i, //enable/disable clock through clock gating on input pipe registers
  output logic                err_corrected_o,
  output logic                err_detected_o,
  output logic [2:0][3:0]     permanent_faulty_mult_o,             // one for each counter: 3 MULT and 4 subpart of MULT
  output logic [2:0][3:0]     permanent_faulty_mult_s,             // one for each counter: 3 MULT and 4 subpart of MULT
  input  logic [2:0]          sel_mux_ex_i, // selector of the three mux to choose three of the four alu

  // CSR: Performance counters
  input  logic [11:0]         mhpm_addr_ft_i,    // the address of the perf counter to be written
  input  logic                mhpm_re_ft_i,      // read enable 
  output logic [31:0]         mhpm_rdata_ft_o,   // the value of the performance counter we want to read
  input  logic                mhpm_we_ft_i,      // write enable 
  input  logic [31:0]         mhpm_wdata_ft_i,    // the we want to write into the perf counter

  // set if only two MULT are not permanent faulty
  input  logic    			  only_two_mult_i,
  input  logic [1:0]          sel_mux_only_two_mult_i,

  // bypass if more than 2 MUlt are faulty
  input  logic [1:0]		  sel_bypass_mult_i

);


	// signal out of the four replicas to "only_two" mechanism
	logic [2:0][31:0]         result_o_ft;
	logic [2:0]               multicycle_o_ft;
	logic [2:0]               ready_o_ft;

	// signal out of the "only_two" muxs going into the voting mechanism
    logic [31:0]              voter_res_1_in;
	logic [31:0]              voter_res_2_in;
	logic [31:0]              voter_res_3_in;

	logic                     voter_multicycle_1_in;
	logic                     voter_multicycle_2_in;
	logic                     voter_multicycle_3_in;

	logic                     voter_ready_1_in;
	logic                     voter_ready_2_in;
	logic                     voter_ready_3_in;

	// signals out from the voter

	//logic [31:0]              voter_res_out;
	logic                     err_detected_res_1;
	logic                     err_detected_res_2;
	logic                     err_detected_res_3;
	logic                     err_corrected_res;
	logic                     err_detected_res; 

	//logic                     voter_comp_out;
	logic                     err_detected_multicycle_1;
	logic                     err_detected_multicycle_2;
	logic                     err_detected_multicycle_3;
	logic                     err_corrected_multicycle;
	logic                     err_detected_multicycle; 

	//logic                     voter_ready_out;
	logic                     err_detected_ready_1;
	logic                     err_detected_ready_2;
	logic                     err_detected_ready_3;
	logic                     err_corrected_ready;
	logic                     err_detected_ready; 

	// output of the voters, input to bypass mux
	logic [31:0]              result_voter;
	logic                     multicycle_voter;
	logic                     ready_voter;

	logic [ 2:0]        	  err_detected_mult;

	/*
	logic					  err_detected_res_mult0;
	logic					  err_detected_res_mult1;
	logic					  err_detected_res_mult2;

	logic 					  err_detected_multicycle_mult0;
	logic 					  err_detected_multicycle_mult1;
	logic 					  err_detected_multicycle_mult2;

	logic 					  err_detected_ready_mult0;
	logic 					  err_detected_ready_mult1;
	logic 					  err_detected_ready_mult2;
	*/

	// to select 3 of the four inputs coming from the four pipes
	logic [2:0]				enable_in;
	logic [2:0][ 2:0]		operator_in;
	logic [2:0]				clock_en_in;
	logic [2:0]				short_subword_in;
	logic [2:0][ 1:0]		short_signed_in;
	logic [2:0][31:0]		op_a_in;
	logic [2:0][31:0]       op_b_in;
	logic [2:0][31:0]		op_c_in;
	logic [2:0][ 4:0]		imm_in;
	logic [2:0][ 1:0]		dot_signed_in;
	logic [2:0][31:0]		dot_op_a_in;
	logic [2:0][31:0]		dot_op_b_in;
	logic [2:0][31:0]		dot_op_c_in;
	logic [2:0]				is_clpx_in;
	logic [2:0][ 1:0]		clpx_shift_in;
	logic [2:0]				clpx_img_in;

	generate

    	if (FT == 1) begin

			////////////////////////////////////////////////////////////////////////////////////
			//  __  __ _   _ _   _____ ___ ____  _     ___ _____ ____           ____ ______   //
			// |  \/  | | | | | |_   _|_ _|  _ \| |   |_ _| ____|  _ \     	   |  __|__  __|  //
			// | |\/| | | | | |   | |  | || |_) | |    | ||  _| | |_) |    __  | |__   | |	  //
			// | |  | | |_| | |___| |  | ||  __/| |___ | || |___|  _ <    /__/ |  __|  | |	  //
			// |_|  |_|\___/|_____|_| |___|_|   |_____|___|_____|_| \_\    	   |_|	   |_|	  //
			//                                                            					  //
			////////////////////////////////////////////////////////////////////////////////////


	        
			// MUXs of inputs, to redirect three of the four inputs coming from the four pipelines to the right three MULTs
			assign enable_in[0] = sel_mux_ex_i[0] ? enable_i[3] : enable_i[0];
	        assign enable_in[1] = sel_mux_ex_i[1] ? enable_i[3] : enable_i[1];
	        assign enable_in[2] = sel_mux_ex_i[2] ? enable_i[3] : enable_i[2];

	        assign operator_in[0] = sel_mux_ex_i[0] ? operator_i[3] : operator_i[0];
	        assign operator_in[1] = sel_mux_ex_i[1] ? operator_i[3] : operator_i[1];
	        assign operator_in[2] = sel_mux_ex_i[2] ? operator_i[3] : operator_i[2];

	        assign clock_en_in[0] = sel_mux_ex_i[0] ? clock_en_i[3] : clock_en_i[0];
	        assign clock_en_in[1] = sel_mux_ex_i[1] ? clock_en_i[3] : clock_en_i[1];
	        assign clock_en_in[2] = sel_mux_ex_i[2] ? clock_en_i[3] : clock_en_i[2];

	        assign short_subword_in[0] = sel_mux_ex_i[0] ? short_subword_i[3] : short_subword_i[0];
	        assign short_subword_in[1] = sel_mux_ex_i[1] ? short_subword_i[3] : short_subword_i[1];
	        assign short_subword_in[2] = sel_mux_ex_i[2] ? short_subword_i[3] : short_subword_i[2];

	        assign short_signed_in[0] = sel_mux_ex_i[0] ? short_signed_i[3] : short_signed_i[0];
	        assign short_signed_in[1] = sel_mux_ex_i[1] ? short_signed_i[3] : short_signed_i[1];
	        assign short_signed_in[2] = sel_mux_ex_i[2] ? short_signed_i[3] : short_signed_i[2];

	        assign op_a_in[0] = sel_mux_ex_i[0] ? op_a_i[3] : op_a_i[0];
	        assign op_a_in[1] = sel_mux_ex_i[1] ? op_a_i[3] : op_a_i[1];
	        assign op_a_in[2] = sel_mux_ex_i[2] ? op_a_i[3] : op_a_i[2];

	        assign op_c_in[0] = sel_mux_ex_i[0] ? op_c_i[3] : op_c_i[0];
	        assign op_c_in[1] = sel_mux_ex_i[1] ? op_c_i[3] : op_c_i[1];
	        assign op_c_in[2] = sel_mux_ex_i[2] ? op_c_i[3] : op_c_i[2];

	        assign op_b_in[0] = sel_mux_ex_i[0] ? op_b_i[3] : op_b_i[0];
	        assign op_b_in[1] = sel_mux_ex_i[1] ? op_b_i[3] : op_b_i[1];
	        assign op_b_in[2] = sel_mux_ex_i[2] ? op_b_i[3] : op_b_i[2];

	        assign imm_in[0] = sel_mux_ex_i[0] ? imm_i[3] : imm_i[0];
	        assign imm_in[1] = sel_mux_ex_i[1] ? imm_i[3] : imm_i[1];
	        assign imm_in[2] = sel_mux_ex_i[2] ? imm_i[3] : imm_i[2];

	        assign dot_signed_in[0] = sel_mux_ex_i[0] ? dot_signed_i[3] : dot_signed_i[0];
	        assign dot_signed_in[1] = sel_mux_ex_i[1] ? dot_signed_i[3] : dot_signed_i[1];
	        assign dot_signed_in[2] = sel_mux_ex_i[2] ? dot_signed_i[3] : dot_signed_i[2];

	        assign dot_op_a_in[0] = sel_mux_ex_i[0] ? dot_op_a_i[3] : dot_op_a_i[0];
	        assign dot_op_a_in[1] = sel_mux_ex_i[1] ? dot_op_a_i[3] : dot_op_a_i[1];
	        assign dot_op_a_in[2] = sel_mux_ex_i[2] ? dot_op_a_i[3] : dot_op_a_i[2];

	        assign dot_op_b_in[0] = sel_mux_ex_i[0] ? dot_op_b_i[3] : dot_op_b_i[0];
	        assign dot_op_b_in[1] = sel_mux_ex_i[1] ? dot_op_b_i[3] : dot_op_b_i[1];
	        assign dot_op_b_in[2] = sel_mux_ex_i[2] ? dot_op_b_i[3] : dot_op_b_i[2];

	        assign dot_op_c_in[0] = sel_mux_ex_i[0] ? dot_op_c_i[3] : dot_op_c_i[0];
	        assign dot_op_c_in[1] = sel_mux_ex_i[1] ? dot_op_c_i[3] : dot_op_c_i[1];
	        assign dot_op_c_in[2] = sel_mux_ex_i[2] ? dot_op_c_i[3] : dot_op_c_i[2];

	        assign is_clpx_in[0] = sel_mux_ex_i[0] ? is_clpx_i[3] : is_clpx_i[0];
	        assign is_clpx_in[1] = sel_mux_ex_i[1] ? is_clpx_i[3] : is_clpx_i[1];
	        assign is_clpx_in[2] = sel_mux_ex_i[2] ? is_clpx_i[3] : is_clpx_i[2];

	        assign clpx_shift_in[0] = sel_mux_ex_i[0] ? clpx_shift_i[3] : clpx_shift_i[0];
	        assign clpx_shift_in[1] = sel_mux_ex_i[1] ? clpx_shift_i[3] : clpx_shift_i[1];
	        assign clpx_shift_in[2] = sel_mux_ex_i[2] ? clpx_shift_i[3] : clpx_shift_i[2];

	        assign clpx_img_in[0] = sel_mux_ex_i[0] ? clpx_img_i[3] : clpx_img_i[0];
	        assign clpx_img_in[1] = sel_mux_ex_i[1] ? clpx_img_i[3] : clpx_img_i[1];
	        assign clpx_img_in[2] = sel_mux_ex_i[2] ? clpx_img_i[3] : clpx_img_i[2];



	        cv32e40p_mult mult_ft_3_i[2:0] // four identical MULT replicas if FT=1 
	        ( 
	         .clk                 ( clk          ),
	         .rst_n               ( rst_n        ),
	         .enable_i            ( enable_in    ),
	         .operator_i          ( operator_in  ),
	         .short_subword_i     ( short_subword_in ),
	         .short_signed_i      ( short_signed_in  ),

	         .op_a_i         	  ( op_a_in ),
	         .op_b_i              ( op_b_in ),
	         .op_c_i              ( op_c_in ),

			 .imm_i               ( imm_in  ),

			  // dot multiplier
			 .dot_signed_i        ( dot_signed_in ),
			 .dot_op_a_i          ( dot_op_a_in   ),
			 .dot_op_b_i          ( dot_op_b_in   ),
			 .dot_op_c_i          ( dot_op_c_in   ),
			 .is_clpx_i           ( is_clpx_in    ),
			 .clpx_shift_i        ( clpx_shift_in ),
			 .clpx_img_i          ( clpx_img_in   ),

	         .result_o            ( result_o_ft  ),

	         .multicycle_o        ( multicycle_o_ft ),
	         .ready_o             ( ready_o_ft      ),
	         .ex_ready_i          ( ex_ready_i      )
	        );



	        // Insantiate 2 mux to select 2 of the 3 availabel results if "only_two"
	        assign voter_res_1_in = sel_mux_only_two_mult_i[0] ? result_o_ft[2] : result_o_ft[0];
	        assign voter_res_2_in = sel_mux_only_two_mult_i[1] ? result_o_ft[2] : result_o_ft[1];
	        assign voter_res_3_in = result_o_ft[2];

	        assign voter_multicycle_1_in = sel_mux_only_two_mult_i[0] ? multicycle_o_ft[2] : multicycle_o_ft[0];
	        assign voter_multicycle_2_in = sel_mux_only_two_mult_i[1] ? multicycle_o_ft[2] : multicycle_o_ft[1];
	        assign voter_multicycle_3_in = multicycle_o_ft[2];

	        assign voter_ready_1_in = sel_mux_only_two_mult_i[0] ? ready_o_ft[2] : ready_o_ft[0];
	        assign voter_ready_2_in = sel_mux_only_two_mult_i[1] ? ready_o_ft[2] : ready_o_ft[1];
	        assign voter_ready_3_in = ready_o_ft[2];


	        // VOTER 

	        // the voter of result_o. 
	        cv32e40p_3voter #(32,1) voter_result
	         (
	          .in_1_i           ( voter_res_1_in     ),
	          .in_2_i           ( voter_res_2_in     ),
	          .in_3_i           ( voter_res_3_in     ),
	          .only_two_i       ( only_two_mult_i    ),
	          .voted_o          ( result_voter       ),
	          .err_detected_1_o ( err_detected_res_1 ),
	          .err_detected_2_o ( err_detected_res_2 ),
	          .err_detected_3_o ( err_detected_res_3 ),
	          .err_corrected_o  ( err_corrected_res  ),
	          .err_detected_o 	( err_detected_res 	 )
	        );

	        // voter of voter_multicycle_o
	        cv32e40p_3voter #(1,1) voter_multicycle
	        (
	         .in_1_i           ( voter_multicycle_1_in     ),
	         .in_2_i           ( voter_multicycle_2_in     ),
	         .in_3_i           ( voter_multicycle_3_in 	   ),
	         .only_two_i       ( only_two_mult_i           ),
	         .voted_o          ( multicycle_voter          ),
	         .err_detected_1_o ( err_detected_multicycle_1 ),
	         .err_detected_2_o ( err_detected_multicycle_2 ),
	         .err_detected_3_o ( err_detected_multicycle_3 ),
	         .err_corrected_o  ( err_corrected_multicycle  ),
	         .err_detected_o   ( err_detected_multicycle   )
	        );

	        //voter of ready_o
	        cv32e40p_3voter #(1,1) voter_ready
	        (
		     .in_1_i           ( voter_ready_1_in 	  ),
		     .in_2_i           ( voter_ready_2_in 	  ),
		     .in_3_i           ( voter_ready_3_in 	  ),
		     .only_two_i       ( only_two_mult_i      ),
		     .voted_o          ( ready_voter          ),
		     .err_detected_1_o ( err_detected_ready_1 ),
		     .err_detected_2_o ( err_detected_ready_2 ),
		     .err_detected_3_o ( err_detected_ready_3 ),
		     .err_corrected_o  ( err_corrected_ready  ),
		     .err_detected_o   ( err_detected_ready   )
	        );


	        assign result_o 	  = sel_bypass_mult_i[1] ? (sel_bypass_mult_i[0] ? result_o_ft[2] 	 : result_o_ft[1]) 	   : (sel_bypass_mult_i[0] ? result_o_ft[0]     : result_voter);
	        assign multicycle_o   = sel_bypass_mult_i[1] ? (sel_bypass_mult_i[0] ? multicycle_o_ft[0] : multicycle_o_ft[1]) : (sel_bypass_mult_i[0] ? multicycle_o_ft[0] : multicycle_voter);
	        assign ready_o 		  = sel_bypass_mult_i[1] ? (sel_bypass_mult_i[0] ? ready_o_ft[2]      : ready_o_ft[1])      : (sel_bypass_mult_i[0] ? ready_o_ft[0]      : ready_voter);


			// assignment of err_detected_multx is the input of the err_counter_result which count errors for each MULT
	        assign err_detected_mult[0] = (err_detected_res_1 || err_detected_multicycle_1 || err_detected_ready_1);
	        assign err_detected_mult[1] = (err_detected_res_2 || err_detected_multicycle_2 || err_detected_ready_2);
	        assign err_detected_mult[2] = (err_detected_res_3 || err_detected_multicycle_3 || err_detected_ready_3);

	        
	        
	        cv32e40p_mult_err_counter_ft err_counter_result
			(
			  .clk 									( clk         ),
	         //.clk                                   ( clk_g       ),
			  .clock_en 							( clock_en_in ),
			  .rst_n								( rst_n       ),
			  .mult_enable_i 						( enable_in   ),
			  .mult_operator_i 						( operator_in ),
			  .error_detected_i						( {err_detected_mult[2], err_detected_mult[1], err_detected_mult[0]} ), 
			  .ready_o_div_count                    ( ready_o     ),
			  .permanent_faulty_mult_o     			( permanent_faulty_mult_o ),
			  .permanent_faulty_mult_s              ( permanent_faulty_mult_s ),  
			  .mhpm_addr_ft_i						( mhpm_addr_ft_i   ),     // the address of the perf counter to be written
			  .mhpm_re_ft_i							( mhpm_re_ft_i     ),     // read enable 
			  .mhpm_rdata_ft_o						( mhpm_rdata_ft_o  ),     // the value of the performance counter we want to read
			  .mhpm_we_ft_i							( mhpm_we_ft_i     ),     // write enable 
			  .mhpm_wdata_ft_i						( mhpm_wdata_ft_i  )
			);



	        assign err_detected_o = (err_detected_res || err_detected_multicycle || err_detected_ready);
	        assign err_corrected_o = (err_corrected_res || err_corrected_multicycle || err_corrected_ready);




        end
        else begin

	        cv32e40p_mult mult_i
	        (
	         .clk                 ( clk               ),
	         .rst_n               ( rst_n             ),
	         .enable_i            ( enable_i[0]       ),
	         .operator_i          ( operator_i[0]     ),
	         .short_subword_i     ( short_subword_i[0]),
	         .short_signed_i      ( short_signed_i[0] ),

	         .op_a_i         	  ( op_a_i[0] 		  ),
	         .op_b_i              ( op_b_i[0] 		  ),
	         .op_c_i              ( op_c_i[0] 		  ),

			 .imm_i               ( imm_i[0]          ),

			  // dot multiplier
			 .dot_signed_i        ( dot_signed_i[0]   ),
			 .dot_op_a_i          ( dot_op_a_i[0]     ),
			 .dot_op_b_i          ( dot_op_b_i[0]     ),
			 .dot_op_c_i          ( dot_op_c_i[0]     ),
			 .is_clpx_i           ( is_clpx_i[0]      ),
			 .clpx_shift_i        ( clpx_shift_i[0]   ),
			 .clpx_img_i          ( clpx_img_i[0]     ),

	         .result_o            ( result_o     	  ),

	         .multicycle_o        ( multicycle_o	  ),
	         .ready_o             ( ready_o      	  ),
	         .ex_ready_i          ( ex_ready_i        )
	        );

			assign err_corrected_o = 1'b0;
	  		assign err_detected_o  = 1'b0;
			assign perf_counter_permanent_faulty_mult_o = 3'b0;
   
         end

   	endgenerate

endmodule : cv32e40p_mult_ft
