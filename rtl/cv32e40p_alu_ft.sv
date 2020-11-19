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
  output logic [3:0][8:0]          		permanent_faulty_alu_s,  // one for each counter: 4 ALU and 9 subpart of ALU 
  //output logic [3:0]      		   	perf_counter_permanent_faulty_alu_o, // trigger the performance counter relative to the specific ALU
  input  logic [2:0]               		sel_mux_ex_i,            // selector of the three mux to choose three of the four alu

  // CSR: Performance counters
  input  logic [11:0]         			mhpm_addr_ft_i,    // the address of the perf counter to be written
  input  logic                			mhpm_re_ft_i,      // read enable 
  output logic [31:0]         			mhpm_rdata_ft_o,   // the value of the performance counter we want to read
  input  logic                			mhpm_we_ft_i,      // write enable 
  input  logic [31:0]         			mhpm_wdata_ft_i    // the we want to write into the perf counter

  /*// signal for single ALU if FT==0 (remove these if everithing is made selectable by (if FT==1))
  input  logic                     enable_single_i,
  input  logic [ALU_OP_WIDTH-1:0]  operator_single_i,
  input  logic [31:0]              operand_a_single_i,
  input  logic [31:0]              operand_b_single_i,
  input  logic [31:0]              operand_c_single_i,

  input  logic [ 1:0]              vector_mode_single_i,
  input  logic [ 4:0]              bmask_a_single_i,
  input  logic [ 4:0]              bmask_b_single_i,
  input  logic [ 1:0]              imm_vec_ext_single_i,

  input  logic                     is_clpx_single_i,
  input  logic                     is_subrot_single_i,
  input  logic [ 1:0]              clpx_shift_single_i*/
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



	        // MUX

	        // Insantiate 3 mux to select 3 of the 4 units available

	        assign voter_res_1_in = sel_mux_ex_i[0] ? result_o_ft[3] : result_o_ft[0];
	        assign voter_res_2_in = sel_mux_ex_i[1] ? result_o_ft[3] : result_o_ft[1];
	        assign voter_res_3_in = sel_mux_ex_i[2] ? result_o_ft[3] : result_o_ft[2];

	        assign voter_comp_1_in = sel_mux_ex_i[0] ? comparison_result_o_ft[3] : comparison_result_o_ft[0];
	        assign voter_comp_2_in = sel_mux_ex_i[1] ? comparison_result_o_ft[3] : comparison_result_o_ft[1];
	        assign voter_comp_3_in = sel_mux_ex_i[2] ? comparison_result_o_ft[3] : comparison_result_o_ft[2];

	        assign voter_ready_1_in = sel_mux_ex_i[0] ? ready_o_ft[3] : ready_o_ft[0];
	        assign voter_ready_2_in = sel_mux_ex_i[1] ? ready_o_ft[3] : ready_o_ft[1];
	        assign voter_ready_3_in = sel_mux_ex_i[2] ? ready_o_ft[3] : ready_o_ft[2];


	        // VOTER 


	        // the voter of result_o. 
	        cv32e40p_3voter #(32,1) voter_result
	         (
	          .in_1_i           ( voter_res_1_in ),
	          .in_2_i           ( voter_res_2_in ),
	          .in_3_i           ( voter_res_3_in ),
	          .voted_o          ( result_o  ),
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
	         .voted_o          ( comparison_result_o ),
	         .err_detected_1   ( err_detected_comp_1 ),
	         .err_detected_2   ( err_detected_comp_2 ),
	         .err_detected_3   ( err_detected_comp_3 ),
	         .err_corrected_o  ( err_corrected_comp  ),
	         .err_detected_o   ( err_detected_comp 	 )
	        );

	        //voter of ready_o
	        cv32e40p_3voter #(1,1) voter_ready
	        (
		     .in_1_i           ( voter_ready_1_in ),
		     .in_2_i           ( voter_ready_2_in ),
		     .in_3_i           ( voter_ready_3_in ),
		     .voted_o          ( ready_o      ),
		     .err_detected_1   ( err_detected_ready_1 ),
		     .err_detected_2   ( err_detected_ready_2 ),
		     .err_detected_3   ( err_detected_ready_3 ),
		     .err_corrected_o  ( err_corrected_ready  ),
		     .err_detected_o   ( err_detected_ready   )
	        );



	        
			// assign the three err_detected_()_1, err_detected_()_2 and err_detected_()_3 to three of four err_detected_()_alu0, err_detected_()_alu1, err_detected_()_alu2 or err_detected_()_alu3.
			// In this way the counter associated to the standby ALU does not increment. --> This is obtained also with clock gatin but for security we provide also this approach.
			always_comb begin : assign_err_count_to_3_used_alu
				case (clock_en_i)
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

					4'b1110: begin
						err_detected_res_alu0 = 1'b0;
						err_detected_comp_alu0 = 1'b0;
						err_detected_ready_alu0 = 1'b0;

						err_detected_res_alu1 = err_detected_res_2;
						err_detected_comp_alu1 = err_detected_comp_2;
						err_detected_ready_alu1 = err_detected_ready_2;

						err_detected_res_alu2 = err_detected_res_3;
						err_detected_comp_alu2 = err_detected_comp_3;
						err_detected_ready_alu2 = err_detected_ready_3;

						err_detected_res_alu3 = err_detected_res_1;
						err_detected_comp_alu3 = err_detected_comp_1;
						err_detected_ready_alu3 = err_detected_ready_1;
					end

					4'b1101: begin
						err_detected_res_alu0 = err_detected_res_1;
						err_detected_comp_alu0 = err_detected_comp_1;
						err_detected_ready_alu0 = err_detected_ready_1;

						err_detected_res_alu1 = 1'b0;
						err_detected_comp_alu1 = 1'b0;
						err_detected_ready_alu1 = 1'b0;

						err_detected_res_alu2 = err_detected_res_3;
						err_detected_comp_alu2 = err_detected_comp_3;
						err_detected_ready_alu3 = err_detected_ready_3;

						err_detected_res_alu3 = err_detected_res_2;
						err_detected_comp_alu3 = err_detected_comp_2;
						err_detected_ready_alu3 = err_detected_ready_2;
					end

					4'b1011: begin
						err_detected_res_alu0 = err_detected_res_1;
						err_detected_comp_alu0 = err_detected_comp_1;
						err_detected_ready_alu0 = err_detected_ready_1;

						err_detected_res_alu1 = err_detected_res_2;
						err_detected_comp_alu1 = err_detected_comp_2;
						err_detected_ready_alu1 = err_detected_ready_2;

						err_detected_res_alu2 = 1'b0;
						err_detected_comp_alu2 = 1'b0;
						err_detected_ready_alu2 = 1'b0;

						err_detected_res_alu3 = err_detected_res_3;
						err_detected_comp_alu3 = err_detected_comp_3;
						err_detected_ready_alu3 = err_detected_ready_3;
					end

					default: begin 
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
				endcase 
				
			end


					/*assign	err_detected_res_alu0 = 1'b1;
					assign	err_detected_comp_alu0 = 1'b0;
					assign	err_detected_ready_alu0 = 1'b0;

					assign	err_detected_res_alu1 = 1'b0;
					assign	err_detected_comp_alu1 = 1'b0;
					assign	err_detected_ready_alu1 = 1'b0;

					assign	err_detected_res_alu2 = 1'b0;
					assign	err_detected_comp_alu2 = 1'b0;
					assign	err_detected_ready_alu2 = 1'b0;

					assign	err_detected_res_alu3 = 1'b1;
					assign	err_detected_comp_alu3 = 1'b0;
					assign	err_detected_ready_alu3 = 1'b0;*/
			

			// assignment of err_detected_alux is the input of the err_counter_result which count errors for each ALU
	        assign err_detected_alu0 = (err_detected_res_alu0 || err_detected_comp_alu0 || err_detected_ready_alu0);
	        assign err_detected_alu1 = (err_detected_res_alu1 || err_detected_comp_alu1 || err_detected_ready_alu1);
	        assign err_detected_alu2 = (err_detected_res_alu2 || err_detected_comp_alu2 || err_detected_ready_alu2);
	        assign err_detected_alu3 = (err_detected_res_alu3 || err_detected_comp_alu3 || err_detected_ready_alu3);

	        

	        cv32e40p_alu_err_counter_ft err_counter_result
			(
			  .clk 									( clk        ),
	         //.clk                                   ( clk_g       ),
			  .clock_en 							( clock_en_i ),
			  .rst_n								( rst_n      ),
			  .alu_enable_i 						( enable_i   ),
			  .alu_operator_i 						( operator_i ),
			  .error_detected_i						( {err_detected_alu3, err_detected_alu2, err_detected_alu1, err_detected_alu0} ), 
			  .ready_o_div_count                    ( ready_o    ),
			  .permanent_faulty_alu_o     			( permanent_faulty_alu_o   ),
			  .permanent_faulty_alu_s               ( permanent_faulty_alu_s   ),  
			  //.perf_counter_permanent_faulty_alu_o	( perf_counter_permanent_faulty_alu_o ),
			  .mhpm_addr_ft_i						( mhpm_addr_ft_i   ),     // the address of the perf counter to be written
			  .mhpm_re_ft_i							( mhpm_re_ft_i     ),     // read enable 
			  .mhpm_rdata_ft_o						( mhpm_rdata_ft_o  ),     // the value of the performance counter we want to read
			  .mhpm_we_ft_i							( mhpm_we_ft_i     ),     // write enable 
			  .mhpm_wdata_ft_i						( mhpm_wdata_ft_i  )
			);

	        assign err_detected_o = (err_detected_res || err_detected_comp || err_detected_ready);
	        assign err_corrected_o = (err_corrected_res || err_corrected_comp || err_corrected_ready);





	/*cv32e40p_alu alu_x
	        (
	         .clk                 ( clk             ),
	         .rst_n               ( rst_n           ),
	         .enable_i            ( enable_single_i    ),
	         .operator_i          ( operator_single_i  ),
	         .operand_a_i         ( operand_a_single_i ),
	         .operand_b_i         ( operand_b_single_i ),
	         .operand_c_i         ( operand_c_single_i ),

	         .vector_mode_i       ( vector_mode_single_i   ),
	         .bmask_a_i           ( bmask_a_single_i       ),
	         .bmask_b_i           ( bmask_b_single_i       ),
	         .imm_vec_ext_i       ( imm_vec_ext_single_i   ),

	         .is_clpx_i           ( is_clpx_single_i   ),
	         .clpx_shift_i        ( clpx_shift_single_i),
	         .is_subrot_i         ( is_subrot_single_i ),

	         .result_o            ( result_o      ),
	         .comparison_result_o ( comparison_result_o  ),

	         .ready_o             ( ready_o       ),
	         .ex_ready_i          ( ex_ready_i       )
	        );

			assign err_corrected_o = 1'b0;
	  		assign err_detected_o  = 1'b0;
			assign permanent_faulty_alu_o = 36'b0; 
			assign perf_counter_permanent_faulty_alu_o = 4'b0;
		*/

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
			assign permanent_faulty_alu_o = 36'b0; 
			//assign perf_counter_permanent_faulty_alu_o = 4'b0;
			assign mhpm_rdata_ft_o        = 32'b0;
   
         end

   	endgenerate

endmodule : cv32e40p_alu_ft
