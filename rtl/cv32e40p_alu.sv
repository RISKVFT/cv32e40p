// Copyright 2020 Politecnico di Torino.


////////////////////////////////////////////////////////////////////////////////
// Engineer:       Luca Fiore - luca.fiore@studenti.polito.it                 //
//                                                                            //
// Additional contributions by:                                               //
//                 Marcello Neri - s257090@studenti.polito.it                 //
//                 Elia Ribaldone - s265613@studenti.polito.it                //
//                                                                            //
// Design Name:    cv32e40p_alu_ft                                            //
// Project Name:   cv32e40p Fault tolernat                                    //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Fault tolerant version of cv32e40p ALU.                    //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////   


module cv32e40p_alu_ft import cv32e40p_pkg::*;
(
  input  logic                     clk,
  input  logic                     rst_n,
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

  output logic [31:0]              result_o,
  output logic                     comparison_result_o,

  output logic                     ready_o,
  input  logic                     ex_ready_i,

  input  logic [3:0]			   clock_en_i, //enable/disable clock through clock gating on input pipe registers
  output logic                     err_corrected_o,
  output logic                     err_detected_o,
  output logic [3:0][8:0] 		   permanent_faulty_alu_o,  // set of 4 9bit register for a each ALU 
  output logic [3:0]      		   perf_counter_permanent_faulty_alu_o, // trigger the performance counter relative to the specif ALU
  input  logic [2:0]               sel_mux_ex_i // selector of the three mux to choose three of the four alu
);


	// signal out of the four replicas to voters
	logic [3:0][31:0]         result_o_ft;
	logic [3:0]               comparison_result_o_ft;
	logic [3:0]               ready_o_ft;


	// signal out of the three mux going into the voting mechanism
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

	logic [31:0]              voter_res_out;
	logic                     err_detected_res_1;
	logic                     err_detected_res_2;
	logic                     err_detected_res_3;
	logic                     err_corrected_res;
	logic                     err_detected_res; 

	logic                     voter_comp_out;
	logic                     err_detected_comp_1;
	logic                     err_detected_comp_2;
	logic                     err_detected_comp_3;
	logic                     err_corrected_comp;
	logic                     err_detected_comp; 

	logic                     voter_ready_out;
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

	logic 					  err_detected_comb_alu0;
	logic 					  err_detected_comb_alu1;
	logic 					  err_detected_comb_alu2;
	logic 					  err_detected_comb_alu3;

	logic 					  err_detected_ready_alu0;
	logic 					  err_detected_ready_alu1;
	logic 					  err_detected_ready_alu2;
	logic 					  err_detected_ready_alu3;



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


	        cv32e40p_alu alu_i[3:0] // four identical ALU replicas if FT=1 
	        (
	         .clk                 ( clk         ),
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



	        // MUX

	        // Insantiate 3 mux to select 3 of the 4 units available
	        

	        assign voter_result_1_in = sel_mux_ex_i[0] ? result_o_ft[0] : result_o_ft[3];
	        assign voter_result_2_in = sel_mux_ex_i[1] ? result_o_ft[1] : result_o_ft[3];
	        assign voter_result_3_in = sel_mux_ex_i[2] ? result_o_ft[2] : result_o_ft[3];

	        assign voter_comparison_1_in = sel_mux_ex_i[0] ? comparison_result_o_ft[0] : comparison_result_o_ft[3];
	        assign voter_comparison_2_in = sel_mux_ex_i[1] ? comparison_result_o_ft[1] : comparison_result_o_ft[3];
	        assign voter_comparison_3_in = sel_mux_ex_i[2] ? comparison_result_o_ft[2] : comparison_result_o_ft[3];

	        assign voter_ready_1_in = sel_mux_ex_i[0] ? ready_o_ft[0] : ready_o_ft[3];
	        assign voter_ready_2_in = sel_mux_ex_i[1] ? ready_o_ft[1] : ready_o_ft[3];
	        assign voter_ready_3_in = sel_mux_ex_i[2] ? ready_o_ft[2] : ready_o_ft[3];


	        // VOTER 


	        // the voter of result_o. 
	        cv32e40p_3voter #(32,1) voter_result
	         (
	          .in_1_i           ( voter_res_1_in ),
	          .in_2_i           ( voter_res_2_in ),
	          .in_3_i           ( voter_res_3_in ),
	          .voted_o          ( voter_res_out  ),
	          .err_detected_1 	( err_detected_res_1 ),
	          .err_detected_2 	( err_detected_res_2 ),
	          .err_detected_3 	( err_detected_res_3 ),
	          .err_corrected_o  ( err_corrected_res  ),
	          .err_detected_o 	( err_detected_res 	 )
	        );

	        // voter of comparison_result_o
	        cv32e40p_3voter #(1,1) voter_comp_res
	        (
	         .in_1_i           ( voter_comp_1_in ),
	         .in_2_i           ( voter_comp_2_in ),
	         .in_3_i           ( voter_comp_3_in ),
	         .voted_o          ( voter_comp_out ),
	         .err_detected_1   ( err_detected_comp_1 ),
	         .err_detected_2   ( err_detected_comp_2 ),
	         .err_detected_3   ( err_detected_comp_3 ),
	         .err_corrected_o  ( err_corrected_comp  ),
	         .err_detected_o   ( err_detected_comp 	 )
	        );

	        //voter of ready_o
	        cv32e40p_3voter #(1,1) voter_comp_ready
	        (
		     .in_1_i           ( voter_ready_1_in ),
		     .in_2_i           ( voter_ready_2_in ),
		     .in_3_i           ( voter_ready_3_in ),
		     .voted_o          ( voter_ready_out      ),
		     .err_detected_1   ( err_detected_ready_1 ),
		     .err_detected_2   ( err_detected_ready_2 ),
		     .err_detected_3   ( err_detected_ready_3 ),
		     .err_corrected_o  ( err_corrected_ready  ),
		     .err_detected_o   ( err_detected_ready   )
	        );


			// assign the three err_detected_()_1, err_detected_()_2 and err_detected_()_3 to three of four err_detected_()_alu0, err_detected_()_alu1, err_detected_()_alu2 or err_detected_()_alu3.
			// In this way the counter associated to the standby ALU does not increment. --> This is obtained also with clock gatin but for security we provide also this approach.
			always_comb begin : assign_err_count_to_3_used_alu
				case (used_alu_i)
					4'b0111: 
						err_detected_res_alu0 = err_detected_res_1;
						err_detected_comb_alu0 = err_detected_comb_1;
						err_detected_ready_alu0 = err_detected_ready_1;

						err_detected_res_alu1 = err_detected_res_2;
						err_detected_comb_alu1 = err_detected_comb_2;
						err_detected_ready_alu1 = err_detected_ready_2;

						err_detected_res_alu2 = err_detected_res_3;
						err_detected_comb_alu2 = err_detected_comb_3;
						err_detected_ready_alu2 = err_detected_ready_3;

						err_detected_res_alu3 = 1'b0;
						err_detected_comb_alu3 = 1'b0;
						err_detected_ready_alu3 = 1'b0;

					4'b1110:
						err_detected_res_alu0 = 1'b0;
						err_detected_comb_alu0 = 1'b0;
						err_detected_ready_alu0 = 1'b0;

						err_detected_res_alu1 = err_detected_res_1;
						err_detected_comb_alu1 = err_detected_comb_1;
						err_detected_ready_alu1 = err_detected_ready_1;

						err_detected_res_alu2 = err_detected_res_2;
						err_detected_comb_alu2 = err_detected_comb_2;
						err_detected_ready_alu2 = err_detected_ready_2;

						err_detected_res_alu3 = err_detected_res_3;
						err_detected_comb_alu3 = err_detected_comb_3;
						err_detected_ready_alu3 = err_detected_ready_3;

					4'b1101:
						err_detected_res_alu0 = err_detected_res_1;
						err_detected_comb_alu0 = err_detected_comb_1;
						err_detected_ready_alu0 = err_detected_ready_1;

						err_detected_res_alu1 = 1'b0;
						err_detected_comb_alu1 = 1'b0;
						err_detected_ready_alu1 = 1'b0;

						err_detected_res_alu2 = err_detected_res_2;
						err_detected_comb_alu2 = err_detected_comb_2;
						err_detected_ready_alu3 = err_detected_ready_2;

						err_detected_res_alu3 = err_detected_res_3;
						err_detected_comb_alu3 = err_detected_comb_3;
						err_detected_ready_alu3 = err_detected_ready_3;

					4'b1011:
						err_detected_res_alu0 = err_detected_res_1;
						err_detected_comb_alu0 = err_detected_comb_1;
						err_detected_ready_alu0 = err_detected_ready_1;

						err_detected_res_alu1 = err_detected_res_2;
						err_detected_comb_alu1 = err_detected_comb_2;
						err_detected_ready_alu1 = err_detected_ready_2;

						err_detected_res_alu2 = 1'b0;
						err_detected_comb_alu2 = 1'b0;
						err_detected_ready_alu2 = 1'b0;

						err_detected_res_alu3 = err_detected_res_3;
						err_detected_comb_alu3 = err_detected_comb_3;
						err_detected_ready_alu = err_detected_ready_3;
				endcase 
				
			end

			

			// assignment of err_detected_alux is the input of the err_counter_result which count errors for each ALU
	        assign err_detected_alu0 = (err_detected_res_alu0 || err_detected_comb_alu0 || err_detected_ready_alu0);
	        assign err_detected_alu1 = (err_detected_res_alu1 || err_detected_comb_alu1 || err_detected_ready_alu1);
	        assign err_detected_alu2 = (err_detected_res_alu2 || err_detected_comb_alu2 || err_detected_ready_alu2);
	        assign err_detected_alu3 = (err_detected_res_alu3 || err_detected_comb_alu3 || err_detected_ready_alu3);


	        cv32e40p_alu_err_counter_ft err_counter_result
			(
			  .clk 									clock,
			  .clock_en 							clock_en_i,
			  .rst_n								rst_n,
			  .alu_enable_i 						enable_i,
			  .alu_operator_i 						operator_i,
			  .error_detected_i						{err_detected_alu3, err_detected_alu2, err_detected_alu1, err_detected_alu0}, 
			  .permanent_faulty_alu_o, 
			  .perf_counter_permanent_faulty_alu_o
			);

	        assign err_detected_o = (err_detected_res || err_detected_comb || err_detected_ready);
	        assign err_corrected_o = (err_corrected_res || err_corrected_comb || err_corrected_ready);


        end
        else begin

	        cv32e40p_alu alu_i
	        (
	         .clk                 ( clk             ),
	         .rst_n               ( rst_n           ),
	         .enable_i            ( alu_en_i        ),
	         .operator_i          ( alu_operator_i  ),
	         .operand_a_i         ( alu_operand_a_i ),
	         .operand_b_i         ( alu_operand_b_i ),
	         .operand_c_i         ( alu_operand_c_i ),

	         .vector_mode_i       ( alu_vec_mode_i  ),
	         .bmask_a_i           ( bmask_a_i       ),
	         .bmask_b_i           ( bmask_b_i       ),
	         .imm_vec_ext_i       ( imm_vec_ext_i   ),

	         .is_clpx_i           ( alu_is_clpx_i   ),
	         .clpx_shift_i        ( alu_clpx_shift_i),
	         .is_subrot_i         ( alu_is_subrot_i ),

	         .result_o            ( alu_result      ),
	         .comparison_result_o ( alu_cmp_result  ),

	         .ready_o             ( alu_ready       ),
	         .ex_ready_i          ( ex_ready_o      )
	        );

			assign err_corrected_o = 1'b0;
	  		assign err_detected_o  = 1'b0;
   
         end

   	endgenerate

endmodule : cv32e40p_alu_ft
