// Copyright 2020 Politecnico di Torino.


////////////////////////////////////////////////////////////////////////////////
// Engineer:       Luca Fiore - luca.fiore@studenti.polito.it                 //
//                                                                            //
// Additional contributions by:                                               //
//                 Marcello Neri - s257090@studenti.polito.it                 //
//                 Elia Ribaldone - s265613@studenti.polito.it                //
//                                                                            //
// Design Name:    cv32e40p_alu_ft                                            //
// Project Name:   cv32e40p Fault tolerant                                    //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Fault tolerant version of cv32e40p ALU.                    //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////   


module cv32e40p_alu_ft import cv32e40p_pkg::*;
#(
  parameter FT = 0
)
(
  input  logic                     		clk,
  input  logic [3:0]               		clk_g,
  input  logic                     		rst_n,
  input  logic [3:0]                    enable_i,
  input  logic [3:0][ALU_OP_WIDTH-1:0]  operator_i,
  input  logic [3:0][31:0]              operand_a_i,
  input  logic [3:0][31:0]              operand_b_i,
  input  logic [3:0][31:0]              operand_c_i,

  input  logic [3:0][ 1:0]              vector_mode_i,
  input  logic [3:0][ 4:0]              bmask_a_i,
  input  logic [3:0][ 4:0]              bmask_b_i,
  input  logic [3:0][ 1:0]              imm_vec_ext_i,

  input  logic [3:0]                    is_clpx_i,
  input  logic [3:0]                    is_subrot_i,
  input  logic [3:0][ 1:0]              clpx_shift_i,

  output logic [31:0]              		result_o,
  output logic                     		comparison_result_o,

  output logic                     		ready_o,
  input  logic                     		ex_ready_i,

  // ft  
  input  logic [3:0]			   		clock_en_i,              //enable/disable clock through clock gating on input pipe registers
  output logic                     		err_corrected_o,
  output logic                     		err_detected_o,
  output logic [3:0][8:0] 		   		permanent_faulty_alu_o,  // set of 4 9bit register for a each ALU
  output logic [3:0][8:0]          		permanent_faulty_alu_s_o,  // one for each counter: 4 ALU and 9 subpart of ALU 
  //output logic [3:0]      		   	perf_counter_permanent_faulty_alu_o, // trigger the performance counter relative to the specific ALU
  input  logic [2:0]               		sel_mux_ex_i,            // selector of the three mux to choose three of the four alu

  // CSR: Performance counters
  input  logic [11:0]         			mhpm_addr_ft_i,    // the address of the perf counter to be written
  input  logic                			mhpm_re_ft_i,      // read enable 
  output logic [31:0]         			mhpm_rdata_ft_o,   // the value of the performance counter we want to read
  input  logic                			mhpm_we_ft_i,      // write enable 
  input  logic [31:0]         			mhpm_wdata_ft_i,    // the we want to write into the perf counter

  // set if only two ALU are not permanent faulty
  input  logic    						only_two_alu_i,
  input  logic [1:0]                    sel_mux_only_two_alu_i,

  // bypass if more than 2 ALU are faulty
  input  logic [1:0]					sel_bypass_alu_i

);


	// signal out of the four replicas to voters
	logic [3:0][31:0]         result_o_ft;
	logic [3:0]               comparison_result_o_ft;
	logic [3:0]               ready_o_ft;


	// signal out of the three mux going into the "only_two" mux mechanism
	logic [31:0]              voter_res_1_only_two_in;
	logic [31:0]              voter_res_2_only_two_in;
	logic [31:0]              voter_res_3_only_two_in;

	logic                     voter_comp_1_only_two_in;
	logic                     voter_comp_2_only_two_in;
	logic                     voter_comp_3_only_two_in;

	logic                     voter_ready_1_only_two_in;
	logic                     voter_ready_2_only_two_in;
	logic                     voter_ready_3_only_two_in;

    // signal out of the "only_two" muxs going into the voting mechanism
    logic [31:0]              voter_res_1_in;
	logic [31:0]              voter_res_2_in;
	logic [31:0]              voter_res_3_in;

	logic                     voter_comp_1_in;
	logic                     voter_comp_2_in;
	logic                     voter_comp_3_in;

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
	logic                     err_detected_comp_1;
	logic                     err_detected_comp_2;
	logic                     err_detected_comp_3;
	logic                     err_corrected_comp;
	logic                     err_detected_comp; 

	//logic                     voter_ready_out;
	logic                     err_detected_ready_1;
	logic                     err_detected_ready_2;
	logic                     err_detected_ready_3;
	logic                     err_corrected_ready;
	logic                     err_detected_ready; 


	logic 					  err_detected_alu0;
	logic 					  err_detected_alu1;
	logic 					  err_detected_alu2;
	logic 					  err_detected_alu3;

	logic					  err_detected_res_alu0;
	logic					  err_detected_res_alu1;
	logic					  err_detected_res_alu2;
	logic					  err_detected_res_alu3;

	logic 					  err_detected_comp_alu0;
	logic 					  err_detected_comp_alu1;
	logic 					  err_detected_comp_alu2;
	logic 					  err_detected_comp_alu3;

	logic 					  err_detected_ready_alu0;
	logic 					  err_detected_ready_alu1;
	logic 					  err_detected_ready_alu2;
	logic 					  err_detected_ready_alu3;

	// output of the voters, input to bypass mux
	logic [31:0]              result_voter;
	logic                     comparison_result_voter;
	logic                     ready_voter;




	generate

    	if (FT == 1) begin

	        //////////////////////////////////////////////
	        //     _    _    _   _    	  ____ ______   //
	        //    / \  | |  | | | |   	 |	__|__  __| 	//
	        //   / _ \ | |  | | | |  __  | |__	 | |	//
	        //  / ___ \| |__| |_| | /__/ | 	__|	 | |	//
	        // /_/   \_\_____\___/    	 |_|	 |_|	//
	        //                        					//
	        //////////////////////////////////////////////


	        cv32e40p_alu alu_ft_4_i[3:0] // four identical ALU replicas if FT=1 
	        (
	         //.clk                 ( clk         ),
	         .clk                 ( clk_g       ),
	         .rst_n               ( rst_n       ),
	         .enable_i            ( enable_i    ),
	         .operator_i          ( operator_i  ),
	         .operand_a_i         ( operand_a_i ),
	         .operand_b_i         ( operand_b_i ),
	         .operand_c_i         ( operand_c_i ),

	         .vector_mode_i       ( vector_mode_i ),
	         .bmask_a_i           ( bmask_a_i     ),
	         .bmask_b_i           ( bmask_b_i     ),
	         .imm_vec_ext_i       ( imm_vec_ext_i ),

	         .is_clpx_i           ( is_clpx_i   ),
	         .clpx_shift_i        ( clpx_shift_i),
	         .is_subrot_i         ( is_subrot_i ),

	         .result_o            ( result_o_ft ),
	         .comparison_result_o ( comparison_result_o_ft ),

	         .ready_o             ( ready_o_ft ),
	         .ex_ready_i          ( ex_ready_i )
	        );



	        /// MUXS ///
	        
	        // Insantiate 3 muxs to select 3 of the 4 units available
	        assign voter_res_1_only_two_in = sel_mux_ex_i[0] ? result_o_ft[3] : result_o_ft[0];
	        assign voter_res_2_only_two_in = sel_mux_ex_i[1] ? result_o_ft[3] : result_o_ft[1];
	        assign voter_res_3_only_two_in = sel_mux_ex_i[2] ? result_o_ft[3] : result_o_ft[2];

	        assign voter_comp_1_only_two_in = sel_mux_ex_i[0] ? comparison_result_o_ft[3] : comparison_result_o_ft[0];
	        assign voter_comp_2_only_two_in = sel_mux_ex_i[1] ? comparison_result_o_ft[3] : comparison_result_o_ft[1];
	        assign voter_comp_3_only_two_in = sel_mux_ex_i[2] ? comparison_result_o_ft[3] : comparison_result_o_ft[2];

	        assign voter_ready_1_only_two_in = sel_mux_ex_i[0] ? ready_o_ft[3] : ready_o_ft[0];
	        assign voter_ready_2_only_two_in = sel_mux_ex_i[1] ? ready_o_ft[3] : ready_o_ft[1];
	        assign voter_ready_3_only_two_in = sel_mux_ex_i[2] ? ready_o_ft[3] : ready_o_ft[2];

	        // Insantiate 2 mux to select 2 of the 3 availabel results if "only_two"
	        assign voter_res_1_in = sel_mux_only_two_alu_i[0] ? voter_res_3_only_two_in : voter_res_1_only_two_in;
	        assign voter_res_2_in = sel_mux_only_two_alu_i[1] ? voter_res_3_only_two_in : voter_res_2_only_two_in;
	        assign voter_res_3_in = voter_res_3_only_two_in;

	        assign voter_comp_1_in = sel_mux_only_two_alu_i[0] ? voter_comp_3_only_two_in : voter_comp_1_only_two_in;
	        assign voter_comp_2_in = sel_mux_only_two_alu_i[1] ? voter_comp_3_only_two_in : voter_comp_2_only_two_in;
	        assign voter_comp_3_in = voter_comp_3_only_two_in;

	        assign voter_ready_1_in = sel_mux_only_two_alu_i[0] ? voter_ready_3_only_two_in : voter_ready_1_only_two_in;
	        assign voter_ready_2_in = sel_mux_only_two_alu_i[1] ? voter_ready_3_only_two_in : voter_ready_2_only_two_in;
	        assign voter_ready_3_in = voter_ready_3_only_two_in;
			


	        /// VOTERS ///

	        // voter of result_o. 
	        cv32e40p_3voter #(32,1) voter_result
	         (
	          .in_1_i           ( voter_res_1_in 	 ),
	          .in_2_i           ( voter_res_2_in     ),
	          .in_3_i           ( voter_res_3_in     ),
	          .only_two_i       ( only_two_alu_i     ),
	          .voted_o          ( result_voter       ),
	          .err_detected_1_o ( err_detected_res_1 ),
	          .err_detected_2_o ( err_detected_res_2 ),
	          .err_detected_3_o ( err_detected_res_3 ),
	          .err_corrected_o  ( err_corrected_res  ),
	          .err_detected_o 	( err_detected_res 	 )
	        );

	        // voter of comparison_result_o
	        cv32e40p_3voter #(1,1) voter_comp_res
	        (	
	         .in_1_i           ( voter_comp_1_in 		  ),
	         .in_2_i           ( voter_comp_2_in 		  ),
	         .in_3_i           ( voter_comp_3_in 		  ),
	         .only_two_i       ( only_two_alu_i           ),
	         .voted_o          ( comparison_result_voter  ),
	         .err_detected_1_o ( err_detected_comp_1      ),
	         .err_detected_2_o ( err_detected_comp_2      ),
	         .err_detected_3_o ( err_detected_comp_3      ),
	         .err_corrected_o  ( err_corrected_comp       ),
	         .err_detected_o   ( err_detected_comp 	      )
	        );

	        // voter of ready_o
	        cv32e40p_3voter #(1,1) voter_ready
	        (
		     .in_1_i           ( voter_ready_1_in     ),
		     .in_2_i           ( voter_ready_2_in     ),
		     .in_3_i           ( voter_ready_3_in     ),
		     .only_two_i       ( only_two_alu_i       ),
		     .voted_o          ( ready_voter          ),
		     .err_detected_1_o ( err_detected_ready_1 ),
		     .err_detected_2_o ( err_detected_ready_2 ),
		     .err_detected_3_o ( err_detected_ready_3 ),
		     .err_corrected_o  ( err_corrected_ready  ),
		     .err_detected_o   ( err_detected_ready   )
	        );


	        assign result_o 			= sel_bypass_alu_i[1] ? (sel_bypass_alu_i[0] ? voter_res_3_in 	: voter_res_2_in) 	: (sel_bypass_alu_i[0] ? voter_res_1_in   : result_voter);
	        assign comparison_result_o  = sel_bypass_alu_i[1] ? (sel_bypass_alu_i[0] ? voter_comp_3_in 	: voter_comp_2_in) 	: (sel_bypass_alu_i[0] ? voter_comp_1_in  : comparison_result_voter);
	        assign ready_o 				= sel_bypass_alu_i[1] ? (sel_bypass_alu_i[0] ? voter_ready_3_in : voter_ready_2_in) : (sel_bypass_alu_i[0] ? voter_ready_1_in : ready_voter);

	        
			// assign the three err_detected_()_1, err_detected_()_2 and err_detected_()_3 to three of four err_detected_()_alu0, err_detected_()_alu1, err_detected_()_alu2 or err_detected_()_alu3.
			// In this way the counter associated to the standby ALU does not increment. --> This is obtained also with clock gatin but for security we provide also this approach.
			always_comb begin : assign_err_count_to_3_used_alu
				case (clock_en_i)
					//4'b0000: // default

					//4'b0001: // default

					//4'b0010: // default

					4'b0011: begin // this assignment is consequence of only-two managing
						err_detected_res_alu0   = err_detected_res_1;
						err_detected_comp_alu0  = err_detected_comp_1;
						err_detected_ready_alu0 = err_detected_ready_1;

						err_detected_res_alu1   = err_detected_res_2;
						err_detected_comp_alu1  = err_detected_comp_2;
						err_detected_ready_alu1 = err_detected_ready_2;

						err_detected_res_alu2   = 1'b0;
						err_detected_comp_alu2  = 1'b0;
						err_detected_ready_alu2 = 1'b0;

						err_detected_res_alu3   = 1'b0;
						err_detected_comp_alu3  = 1'b0;
						err_detected_ready_alu3 = 1'b0;
					end

					//4'b0100: // default

					4'b0101: begin
						err_detected_res_alu0   = err_detected_res_1;
						err_detected_comp_alu0  = err_detected_comp_1;
						err_detected_ready_alu0 = err_detected_ready_1;

						err_detected_res_alu1   = 1'b0;
						err_detected_comp_alu1  = 1'b0;
						err_detected_ready_alu1 = 1'b0;

						err_detected_res_alu2   = err_detected_res_2;
						err_detected_comp_alu2  = err_detected_comp_2;
						err_detected_ready_alu2 = err_detected_ready_2;

						err_detected_res_alu3   = 1'b0;
						err_detected_comp_alu3  = 1'b0;
						err_detected_ready_alu3 = 1'b0;
					end

					4'b0110: begin // this assignment is consequence of only-two managing
						err_detected_res_alu0   = 1'b0;
						err_detected_comp_alu0  = 1'b0;
						err_detected_ready_alu0 = 1'b0;

						err_detected_res_alu1   = err_detected_res_2;
						err_detected_comp_alu1  = err_detected_comp_2;
						err_detected_ready_alu1 = err_detected_ready_2;

						err_detected_res_alu2   = err_detected_res_1;
						err_detected_comp_alu2  = err_detected_comp_1;
						err_detected_ready_alu2 = err_detected_ready_1;

						err_detected_res_alu3   = 1'b0;
						err_detected_comp_alu3  = 1'b0;
						err_detected_ready_alu3 = 1'b0;
					end

					4'b0111: begin
						err_detected_res_alu0 = err_detected_res_1;
						err_detected_comp_alu0 = err_detected_comp_1;
						err_detected_ready_alu0 = err_detected_ready_1;

						err_detected_res_alu1 = err_detected_res_2;
						err_detected_comp_alu1 = err_detected_comp_2;
						err_detected_ready_alu1 = err_detected_ready_2;

						err_detected_res_alu2 = err_detected_res_3;
						err_detected_comp_alu2 = err_detected_comp_3;
						err_detected_ready_alu2 = err_detected_ready_3;

						err_detected_res_alu3 = 1'b0;
						err_detected_comp_alu3 = 1'b0;
						err_detected_ready_alu3 = 1'b0;
					end

					//4'b1000: // default

					4'b1001: begin // this assignment is consequence of only-two managing
						err_detected_res_alu0 = err_detected_res_1;
						err_detected_comp_alu0 = err_detected_comp_1;
						err_detected_ready_alu0 = err_detected_ready_1;

						err_detected_res_alu1 = 1'b0;
						err_detected_comp_alu1 = 1'b0;
						err_detected_ready_alu1 = 1'b0;

						err_detected_res_alu2 = 1'b0;
						err_detected_comp_alu2 = 1'b0;
						err_detected_ready_alu2 = 1'b0;

						err_detected_res_alu3 = err_detected_res_2;
						err_detected_comp_alu3 = err_detected_comp_2;
						err_detected_ready_alu3 = err_detected_ready_2;
					end

					4'b1010: begin // this assignment is consequence of only-two managing
						err_detected_res_alu0   = 1'b0;
						err_detected_comp_alu0  = 1'b0;
						err_detected_ready_alu0 = 1'b0;

						err_detected_res_alu1   = err_detected_res_2;
						err_detected_comp_alu1  = err_detected_comp_2;
						err_detected_ready_alu1 = err_detected_ready_2;

						err_detected_res_alu2   = 1'b0;
						err_detected_comp_alu2  = 1'b0;
						err_detected_ready_alu2 = 1'b0;

						err_detected_res_alu3   = err_detected_res_1;
						err_detected_comp_alu3  = err_detected_comp_1;
						err_detected_ready_alu3 = err_detected_ready_1;
					end

					4'b1011: begin
						err_detected_res_alu0   = err_detected_res_1;
						err_detected_comp_alu0  = err_detected_comp_1;
						err_detected_ready_alu0 = err_detected_ready_1;

						err_detected_res_alu1   = err_detected_res_2;
						err_detected_comp_alu1  = err_detected_comp_2;
						err_detected_ready_alu1 = err_detected_ready_2;

						err_detected_res_alu2   = 1'b0;
						err_detected_comp_alu2  = 1'b0;
						err_detected_ready_alu2 = 1'b0;

						err_detected_res_alu3   = err_detected_res_3;
						err_detected_comp_alu3  = err_detected_comp_3;
						err_detected_ready_alu3 = err_detected_ready_3;
					end

					4'b1100: begin // this assignment is consequence of "only-two" managing
						err_detected_res_alu0   = 1'b0;
						err_detected_comp_alu0  = 1'b0;
						err_detected_ready_alu0 = 1'b0;

						err_detected_res_alu1   = 1'b0;
						err_detected_comp_alu1  = 1'b0;
						err_detected_ready_alu1 = 1'b0;

						err_detected_res_alu2   = err_detected_res_1;
						err_detected_comp_alu2  = err_detected_comp_1;
						err_detected_ready_alu2 = err_detected_ready_1;

						err_detected_res_alu3   = err_detected_res_2;
						err_detected_comp_alu3  = err_detected_comp_2;
						err_detected_ready_alu3 = err_detected_ready_2;
					end

					4'b1101: begin
						err_detected_res_alu0   = err_detected_res_1;
						err_detected_comp_alu0  = err_detected_comp_1;
						err_detected_ready_alu0 = err_detected_ready_1;

						err_detected_res_alu1   = 1'b0;
						err_detected_comp_alu1  = 1'b0;
						err_detected_ready_alu1 = 1'b0;

						err_detected_res_alu2   = err_detected_res_3;
						err_detected_comp_alu2  = err_detected_comp_3;
						err_detected_ready_alu2 = err_detected_ready_3;

						err_detected_res_alu3   = err_detected_res_2;
						err_detected_comp_alu3  = err_detected_comp_2;
						err_detected_ready_alu3 = err_detected_ready_2;
					end

					4'b1110: begin
						err_detected_res_alu0   = 1'b0;
						err_detected_comp_alu0  = 1'b0;
						err_detected_ready_alu0 = 1'b0;

						err_detected_res_alu1   = err_detected_res_2;
						err_detected_comp_alu1  = err_detected_comp_2;
						err_detected_ready_alu1 = err_detected_ready_2;

						err_detected_res_alu2   = err_detected_res_3;
						err_detected_comp_alu2  = err_detected_comp_3;
						err_detected_ready_alu2 = err_detected_ready_3;

						err_detected_res_alu3   = err_detected_res_1;
						err_detected_comp_alu3  = err_detected_comp_1;
						err_detected_ready_alu3 = err_detected_ready_1;
					end


					4'b1111: begin
						err_detected_res_alu0   = err_detected_res_1;
						err_detected_comp_alu0  = err_detected_comp_1;
						err_detected_ready_alu0 = err_detected_ready_1;

						err_detected_res_alu1   = err_detected_res_2;
						err_detected_comp_alu1  = err_detected_comp_2;
						err_detected_ready_alu1 = err_detected_ready_2;

						err_detected_res_alu2   = err_detected_res_3;
						err_detected_comp_alu2  = err_detected_comp_3;
						err_detected_ready_alu2 = err_detected_ready_3;

						err_detected_res_alu3   = 1'b0;
						err_detected_comp_alu3  = 1'b0;
						err_detected_ready_alu3 = 1'b0;
					end


					default: begin // (0111, 1111)
						err_detected_res_alu0   = 1'b0;
						err_detected_comp_alu0  = 1'b0;
						err_detected_ready_alu0 = 1'b0;

						err_detected_res_alu1   = 1'b0;
						err_detected_comp_alu1  = 1'b0;
						err_detected_ready_alu1 = 1'b0;

						err_detected_res_alu2   = 1'b0;
						err_detected_comp_alu2  = 1'b0;
						err_detected_ready_alu2 = 1'b0;

						err_detected_res_alu3   = 1'b0;
						err_detected_comp_alu3  = 1'b0;
						err_detected_ready_alu3 = 1'b0;
					end
				endcase 
				
			end
		

			// assignment of err_detected_alux is the input of the err_counter_result which count errors for each ALU
	        assign err_detected_alu0 = (err_detected_res_alu0 || err_detected_comp_alu0 || err_detected_ready_alu0);
	        assign err_detected_alu1 = (err_detected_res_alu1 || err_detected_comp_alu1 || err_detected_ready_alu1);
	        assign err_detected_alu2 = (err_detected_res_alu2 || err_detected_comp_alu2 || err_detected_ready_alu2);
	        assign err_detected_alu3 = (err_detected_res_alu3 || err_detected_comp_alu3 || err_detected_ready_alu3);

	        

	        cv32e40p_alu_err_counter_ft err_counter_result
			(
	          .clock_gated                          ( clk_g      ),
			  .rst_n								( rst_n      ),
			  .alu_enable_i 						( enable_i   ),
			  .alu_operator_i 						( operator_i ),
			  .error_detected_i						( {err_detected_alu3, err_detected_alu2, err_detected_alu1, err_detected_alu0} ), 
			  .ready_o_div_count                    ( ready_o    ),
			  .permanent_faulty_alu_o     			( permanent_faulty_alu_o   ),
			  .permanent_faulty_alu_s_o             ( permanent_faulty_alu_s_o ),  
			  .mhpm_addr_ft_i						( mhpm_addr_ft_i   ),     // the address of the perf counter to be written
			  .mhpm_re_ft_i							( mhpm_re_ft_i     ),     // read enable 
			  .mhpm_rdata_ft_o						( mhpm_rdata_ft_o  ),     // the value of the performance counter we want to read
			  .mhpm_we_ft_i							( mhpm_we_ft_i     ),     // write enable 
			  .mhpm_wdata_ft_i						( mhpm_wdata_ft_i  )
			);

	        assign err_detected_o = (err_detected_res || err_detected_comp || err_detected_ready);
	        assign err_corrected_o = (err_corrected_res || err_corrected_comp || err_corrected_ready);





        end
        else begin

	        cv32e40p_alu alu_i
	        (
	         .clk                 ( clk            		),
	         .rst_n               ( rst_n          		),
	         .enable_i            ( enable_i[0]    		),
	         .operator_i          ( operator_i[0]  		),
	         .operand_a_i         ( operand_a_i[0] 		),
	         .operand_b_i         ( operand_b_i[0] 		),
	         .operand_c_i         ( operand_c_i[0] 		),

	         .vector_mode_i       ( vector_mode_i[0]  	),
	         .bmask_a_i           ( bmask_a_i[0]      	),
	         .bmask_b_i           ( bmask_b_i[0]      	),
	         .imm_vec_ext_i       ( imm_vec_ext_i[0]   	),

	         .is_clpx_i           ( is_clpx_i[0]   		),
	         .clpx_shift_i        ( clpx_shift_i[0]		),
	         .is_subrot_i         ( is_subrot_i[0]      ),

	         .result_o            ( result_o            ),
	         .comparison_result_o ( comparison_result_o ),

	         .ready_o             ( ready_o          	),
	         .ex_ready_i          ( ex_ready_i       	)
	        );

			assign err_corrected_o 		  = 1'b0;
	  		assign err_detected_o  		  = 1'b0;

	  		genvar y;
			for (y=0; y<4; y++) begin
  				assign permanent_faulty_alu_o[y] = 9'b0;
  				assign permanent_faulty_alu_s_o[y] = 9'b0;
  			end

			assign mhpm_rdata_ft_o        = 32'b0;
   
         end

   	endgenerate

endmodule : cv32e40p_alu_ft
