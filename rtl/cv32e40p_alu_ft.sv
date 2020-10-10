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
// Description:   Fault tolerant version of Acv32e40p ALU                     //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////   


module cv32e40p_alu_ft import cv32e40p_pkg::*;
(
  input  logic                     clk,
  input  logic                     rst_n,
  input  logic                     enable_i,
  input  logic [ALU_OP_WIDTH-1:0]  operator_i,
  input  logic [31:0]              operand_a_i,
  input  logic [31:0]              operand_b_i,
  input  logic [31:0]              operand_c_i,

  input  logic [ 1:0]              vector_mode_i,
  input  logic [ 4:0]              bmask_a_i,
  input  logic [ 4:0]              bmask_b_i,
  input  logic [ 1:0]              imm_vec_ext_i,

  input  logic                     is_clpx_i,
  input  logic                     is_subrot_i,
  input  logic [ 1:0]              clpx_shift_i,

  output logic [31:0]              result_o,
  output logic                     comparison_result_o,

  output logic                     ready_o,
  input  logic                     ex_ready_i,

  output logic                     error_correct_o,
  output logic                     error_detected_o
);



   // signals for guarded evaluation; they are array of 4 because one for each replicas
   logic [3:0]                    clk_guard; // in this case we apply clock gating
   logic [3:0]                    rst_n_guard;
   logic [3:0]                    enable_i_guard;
   logic [3:0][ALU_OP_WIDTH-1:0]  operator_i_guard;
   logic [3:0][31:0]              operand_a_i_guard;
   logic [3:0][31:0]              operand_b_i_guard;
   logic [3:0][31:0]              operand_c_i_guard;

   logic [3:0][ 1:0]              vector_mode_i_guard;
   logic [3:0][ 4:0]              bmask_a_i_guard;
   logic [3:0][ 4:0]              bmask_b_i_guard;
   logic [3:0][ 1:0]              imm_vec_ext_i_guard;

   logic [3:0]                    is_clpx_i_guard;
   logic [3:0]                    is_subrot_i_guard;
   logic [3:0][ 1:0]              clpx_shift_i_guard; 
   logic [3:0]                    ex_ready_i_guard;



   // signal out of the four replicas to voters
   logic [3:0][31:0]              result_o_ft;
   logic [3:0]                    comparison_result_o_ft;
   logic [3:0]                    ready_o_ft;


   // signal out of the three mux going into the voting mechanism
   logic [31:0]                   voter_res_1_in;
   logic [31:0]                   voter_res_2_in;
   logic [31:0]                   voter_res_3_in;

   logic                          voter_comp_1_in;
   logic                          voter_comp_2_in;
   logic                          voter_comp_3_in;

   logic                          voter_ready_1_in;
   logic                          voter_ready_2_in;
   logic                          voter_ready_3_in; 

   // signals out from the 3 voter going into the last voter

   logic [2:0][31:0]              voter_res_out;
   logic [2:0]                    voter_comp_out; 
   logic [2:0]                    voter_ready_out;
   
   logic [2:0]                    error_detected_res_1;
   logic [2:0]                    error_detected_res_2;
   logic [2:0]                    error_detected_res_3;
   logic [2:0]                    error_detected_comp_1;
   logic [2:0]                    error_detected_comp_2;
   logic [2:0]                    error_detected_comp_3;
   logic [2:0]                    error_detected_ready_1;
   logic [2:0]                    error_detected_ready_2;
   logic [2:0]                    error_detected_ready_3;

   logic [2:0]                    error_correct_res;
   logic [2:0]                    error_detected_res; 
   logic [2:0]                    error_correct_comp;
   logic [2:0]                    error_detected_comp; 
   logic [2:0]                    error_correct_ready;
   logic [2:0]                    error_detected_ready; 


   // signal out of the last voter
   logic                          error_detected_res_master_1;
   logic                          error_detected_res_master_2;
   logic                          error_detected_res_master_3;

   logic                          error_detected_comp_master_1;
   logic                          error_detected_comp_master_2;
   logic                          error_detected_comp_master_3;

   logic                          error_detected_ready_master_1;
   logic                          error_detected_ready_master_2;
   logic                          error_detected_ready_master_3;

   logic                          err_corrected_res_master
   logic                          err_detected_res_master; 
   logic                          err_correct_comp_master;
   logic                          err_detected_comp_master;
   logic                          err_correct_ready_master;
   logic                          err_detected_ready_master;


   generate

      if (FT == 1) begin

         genvar k;

         for (k=0; k<4; k++) begin

            // GUARDED EVALUATION for all inputs except for clock
            always_latch
              begin: guarded latch
               if (en_guard_latch[k]) begin // capire de deve essere attivo basso alto
                  rst_n_guard[k]          <= rst_n; // capire se bloking o non blocking <= o =
                  enable_i_guard[k]       <= enable_i;
                  operator_i_guard[k]     <= operator_i;
                  operand_a_i_guard[k]    <= operand_a_i;
                  operand_b_i_guard[k]    <= operand_b_i;
                  operand_c_i_guard[k]    <= operand_c_i;
                  vector_mode_i_guard[k]  <= vector_mode_i;
                  bmask_a_i_guard[k]      <= bmask_a_i;
                  bmask_b_i_guard[k]      <= bmask_b_i;
                  imm_vec_ext_i_guard[k]  <= imm_vec_ext_i;
                  is_clpx_i_guard[k]      <= is_clpx_i;
                  is_subrot_i_guard[k]    <= is_subrot_i
                  clpx_shift_i_guard[k]   <= clpx_shift_i; 
                  ex_ready_i_guard[k]     <= ex_ready_i; 
               end
           end

            // CLOCK GATING --> GUARDED EVALUATION FOR CLOCK
            cv32e40p_clock_gate CG_ALU
            (
            .clk_i        ( clk             ),
            .en_i         ( ~enable_i_guard ),
            .scan_cg_en_i ( 1'b0            ), // not used
            .clk_o        ( clk_guard       )
            );

         end

         ////////////////////////////
         //     _    _    _   _    //
         //    / \  | |  | | | |   //
         //   / _ \ | |  | | | |   //
         //  / ___ \| |__| |_| |   //
         // /_/   \_\_____\___/    //
         //                        //
         ////////////////////////////


        cv32e40p_alu alu_i[3:0] // four identical ALU replicas if FT=1 
         (
          .clk                 ( clk_guard         ),
          .rst_n               ( rst_n_guard       ),
          .enable_i            ( enable_i_guard    ),
          .operator_i          ( operator_i_guard  ),
          .operand_a_i         ( operand_a_i_guard ),
          .operand_b_i         ( operand_b_i_guard ),
          .operand_c_i         ( operand_c_i_guard ),

          .vector_mode_i       ( vector_mode_i_guard ),
          .bmask_a_i           ( bmask_a_i_guard     ),
          .bmask_b_i           ( bmask_b_i_guard     ),
          .imm_vec_ext_i       ( imm_vec_ext_i_guard ),

          .is_clpx_i           ( is_clpx_i_guard   ),
          .clpx_shift_i        ( clpx_shift_i_guard),
          .is_subrot_i         ( is_subrot_i_guard ),

          .result_o            ( result_o_ft ),
          .comparison_result_o ( comparison_result_o_ft ),

          .ready_o             ( ready_o_ft ),
          .ex_ready_i          ( ex_ready_i )
         );



         // MUX

         // Insantiate 3 mux to select 3 of the 4 units available
         // sel of mux has to be on 2bit because there are 4 possible combination of 4 elements in 3 position
         // Given A,B,C and D the name of the four result_o_ft[i]:
         // SEL[1:0] --> i,j,k
         //    00    --> A,B,C
         //    01    --> D,B,C
         //    10    --> A,D,C
         //    11    --> A,B,D

         assign voter_result_1_in = sel[1] ? result_o_ft[0] : (sel[0] ? result_o_ft[3] : result_o_ft[0] );
         assign voter_result_2_in = sel[1] ? result_o_ft[1] : (sel[0] ? result_o_ft[3] : result_o_ft[1] );
         assign voter_result_3_in = sel[1] ? result_o_ft[2] : (sel[0] ? result_o_ft[3] : result_o_ft[2] );

         assign voter_comparison_1_in = sel[1] ? comparison_result_o_ft[0] : (sel[0] ? comparison_result_o_ft[3] : comparison_result_o_ft[0] );
         assign voter_comparison_2_in = sel[1] ? comparison_result_o_ft[1] : (sel[0] ? comparison_result_o_ft[3] : comparison_result_o_ft[1] );
         assign voter_comparison_3_in = sel[1] ? comparison_result_o_ft[2] : (sel[0] ? comparison_result_o_ft[3] : comparison_result_o_ft[2] );

         assign voter_ready_1_in = sel[1] ? ready_o_ft[0] : (sel[0] ? ready_o_ft[3] : ready_o_ft[0] );
         assign voter_ready_2_in = sel[1] ? ready_o_ft[1] : (sel[0] ? ready_o_ft[3] : ready_o_ft[1] );
         assign voter_ready_3_in = sel[1] ? ready_o_ft[2] : (sel[0] ? ready_o_ft[3] : ready_o_ft[2] );



         // VOTER MECHANISM

         ///////////////////////
         // ### 1st level ### //
         ///////////////////////

         // the voter of result_o. 
         cv32e40p__3voter #(32) voter_result[2:0]
         (
          .in_1_i           ( voter_res_1_in ),
          .in_2_i           ( voter_res_2_in ),
          .in_3_i           ( voter_res_3_in ),
          .voted_o          ( voter_res_out[2:0] ),
          .error_detected_1 ( error_detected_res_1[2:0] ),
          .error_detected_2 ( error_detected_res_2[2:0] ),
          .error_detected_3 ( error_detected_res_3[2:0] ),
          .error_correct_o  ( error_correct_res[2:0] ),
          .error_detected_o ( error_detected_res[2:0] )
         );

         // voter of comparison_result_o
         cv32e40p__3voter #(32) voter_comp_res[2:0]
         (
          .in_1_i           ( voter_comp_1_in ),
          .in_2_i           ( voter_comp_2_in ),
          .in_3_i           ( voter_comp_3_in ),
          .voted_o          ( voter_comp_out[2:0] ),
          .error_detected_1 ( error_detected_comp_1[2:0] ),
          .error_detected_2 ( error_detected_comp_2[2:0] ),
          .error_detected_3 ( error_detected_comp_3[2:0] ),
          .error_correct_o  ( error_correct_comp[2:0] ),
          .error_detected_o ( error_detected_comp[2:0] )
         );

         //voter of ready_o
         cv32e40p__3voter #(32) voter_comp_ready[2:0]
         (
          .in_1_i           ( voter_ready_1_in ),
          .in_2_i           ( voter_ready_2_in ),
          .in_3_i           ( voter_ready_3_in ),
          .voted_o          ( voter_ready_out[2:0] ),
          .error_detected_1 ( error_detected_ready_1[2:0] ),
          .error_detected_2 ( error_detected_ready_2[2:0] ),
          .error_detected_3 ( error_detected_ready_3[2:0] ),
          .error_correct_o  ( error_correct_ready[2:0] ),
          .error_detected_o ( error_detected_ready[2:0] )
         );


         /*
         cv32e40p_generic_3voter #(1,2) voters_comp_ready[2:0]
         (
           .in_1_i        ( {voter_comparison_1_in, voter_ready_1_in} ),
           .in_2_i        ( {voter_comparison_2_in, voter_ready_2_in} ),
           .in_3_i        ( {voter_comparison_3_in, voter_ready_3_in} ),
           .voted_o       ( {voter_comparison_out[2:0], voter_ready_out[2:0]} ),
           .error_correct_o (error_correct_comp_ready[2:0]),
           .error_detected_o (error_detected_comp_ready[2:0])
         );
         */

         ///////////////////////
         // ### 2nd level ### //
         ///////////////////////

         //voter of the voters of result_o
         cv32e40p__3voter #(32) voter_master_result
         (
          .in_1_i           ( voter_result_out[0] ),
          .in_2_i           ( voter_result_out[1] ),
          .in_3_i           ( voter_result_out[2] ),
          .voted_o          ( result_o ),
          .error_detected_1 ( error_detected_res_master_1 ),
          .error_detected_2 ( error_detected_res_master_2 ),
          .error_detected_3 ( error_detected_res_master_3 ),
          .error_correct_o  ( err_corrected_res_master),
          .error_detected_o ( err_detected_res_master)
         );


         //voter of the voters of comparison_result_o
         cv32e40p__3voter #(32) voter_master_result
         (
          .in_1_i           ( voter_comp_out[0] ),
          .in_2_i           ( voter_comp_out[1] ),
          .in_3_i           ( voter_comp_out[2] ),
          .voted_o          ( comparison_result_o ),
          .error_detected_1 ( error_detected_comp_master_1 ),
          .error_detected_2 ( error_detected_comp_master_2 ),
          .error_detected_3 ( error_detected_comp_master_3 ),
          .error_correct_o  ( err_corrected_comp_master),
          .error_detected_o ( err_detected_comp_master)
         );


         //voter of the voters of ready_o
         cv32e40p__3voter #(32) voter_master_result
         (
          .in_1_i           ( voter_ready_out[0] ),
          .in_2_i           ( voter_ready_out[1] ),
          .in_3_i           ( voter_ready_out[2] ),
          .voted_o          ( ready_o ),
          .error_detected_1 ( error_detected_ready_master_1 ),
          .error_detected_2 ( error_detected_ready_master_2 ),
          .error_detected_3 ( error_detected_ready_master_3 ),
          .error_correct_o  ( err_corrected_ready_master),
          .error_detected_o ( err_detected_ready_master)
         );

         /*
         //voter of the voters of comparison_result_o and ready_o
         cv32e40p_generic_3voter #(1,2) voters_master_comp_ready
         (
           .in_1_i        ( {voter_comparison_out[0], voter_ready_out[0]} ),
           .in_2_i        ( {voter_comparison_out[1], voter_ready_out[1]} ),
           .in_3_i        ( {voter_comparison_out[2], voter_ready_out[2]} ),
           .voted_o       ( {comparison_result_o, ready_o} ),
           .error_correct_o ({err_correct_cr_master[0], err_correct_cr_master[1]}),
           .error_detected_o ({err_detected_cr_master[0], err_correct_cr_master[1]})
         );
         */


         assign error_correct_o = err_corrected_res_master || err_correct_cr_master.or();
         assign error_detected_o = err_detected_res_master || err_detected_cr_master.or();

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

         end
   endgenerate

endmodule : cv32e40p_alu_ft