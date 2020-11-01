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

  input  logic [ 2:0]       enable_i,
  input  logic [ 2:0][ 2:0] operator_i,

  // integer and short multiplier
  input  logic [ 2:0]       short_subword_i,
  input  logic [ 2:0][ 1:0] short_signed_i,

  input  logic [ 2:0][31:0] op_a_i,
  input  logic [ 2:0][31:0] op_b_i,
  input  logic [ 2:0][31:0] op_c_i,

  input  logic [ 2:0][ 4:0] imm_i,

  // dot multiplier
  input  logic [ 2:0][ 1:0] dot_signed_i,
  input  logic [ 2:0][31:0] dot_op_a_i,
  input  logic [ 2:0][31:0] dot_op_b_i,
  input  logic [ 2:0][31:0] dot_op_c_i,
  input  logic [ 2:0]       is_clpx_i,
  input  logic [ 2:0][ 1:0] clpx_shift_i,
  input  logic [ 2:0]       clpx_img_i,

  output logic [31:0] result_o,

  output logic        multicycle_o,
  output logic        ready_o,
  input  logic        ex_ready_i,

  // ft  
  //input  logic [3:0]			   clock_en_i, //enable/disable clock through clock gating on input pipe registers
  output logic                     err_corrected_o,
  output logic                     err_detected_o,
  //output logic [2:0][8:0] 		   permanent_faulty_mult_o,  // set of 4 9bit register for a each ALU 
  output logic [2:0]      		   perf_counter_permanent_faulty_mult_o // trigger the performance counter relative to the specific MULT
  //input  logic [2:0]               sel_mux_ex_i // selector of the three mux to choose three of the four alu

);


	// signal out of the four replicas to voters
	logic [2:0][31:0]         result_o_ft;
	logic [2:0]               multicycle_o_ft;
	logic [2:0]               ready_o_ft;


	/* Questa sezione non serve perchè usosolo 3 mux e non 4 come per la ALU
	// signal out of the three mux going into the voting mechanism
	logic [31:0]              voter_res_1_in;
	logic [31:0]              voter_res_2_in;
	logic [31:0]              voter_res_3_in;

	logic                     voter_multicycle_1_in;
	logic                     voter_multicycle_2_in;
	logic                     voter_multicycle_3_in;

	logic                     voter_ready_1_in;
	logic                     voter_ready_2_in;
	logic                     voter_ready_3_in;
	*/ 

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


	logic [ 2:0]        	  err_detected_mult;

	logic [ 2:0]              counter_mult; // counter for the three MULTs
	logic [ 2:0]              enable_count;

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


	        cv32e40p_mult mult_ft_3_i[2:0] // four identical MULT replicas if FT=1 
	        (
	         .clk                 ( clk         ),
	         .rst_n               ( rst_n       ),
	         .enable_i            ( enable_i    ),
	         .operator_i          ( operator_i  ),
	         .short_subword_i     ( short_subword_i ),
	         .short_signed_i      ( short_signed_i ),

	         .op_a_i         	  ( op_a_i ),
	         .op_b_i              ( op_b_i ),
	         .op_c_i              ( op_c_i ),

			 .imm_i               ( imm_i  ),

			  // dot multiplier
			 .dot_signed_i        ( dot_signed_i ),
			 .dot_op_a_i          ( dot_op_a_i   ),
			 .dot_op_b_i          ( dot_op_b_i   ),
			 .dot_op_c_i          ( dot_op_c_i   ),
			 .is_clpx_i           ( is_clpx_i    ),
			 .clpx_shift_i        ( clpx_shift_i ),
			 .clpx_img_i          ( clpx_img_i   ),

	         .result_o            ( result_o_ft  ),

	         .multicycle_o        ( multicycle_o_ft ),
	         .ready_o             ( ready_o_ft      ),
	         .ex_ready_i          ( ex_ready_i      )
	        );



	        /* Questa sezione non serve perchè usosolo 3 mux e non 4 come per la ALU
	        // MUX

	        // Insantiate 3 mux to select 3 of the 4 units available

	        assign voter_res_1_in = sel_mux_ex_i[0] ? result_o_ft[0] : result_o_ft[3];
	        assign voter_res_2_in = sel_mux_ex_i[1] ? result_o_ft[1] : result_o_ft[3];
	        assign voter_res_3_in = sel_mux_ex_i[2] ? result_o_ft[2] : result_o_ft[3];

	        assign voter_multicycle_1_in = sel_mux_ex_i[0] ? multicycle_o_ft[0] : multicycle_o_ft[3];
	        assign voter_multicycle_2_in = sel_mux_ex_i[1] ? multicycle_o_ft[1] : multicycle_o_ft[3];
	        assign voter_multicycle_3_in = sel_mux_ex_i[2] ? multicycle_o_ft[2] : multicycle_o_ft[3];

	        assign voter_ready_1_in = sel_mux_ex_i[0] ? ready_o_ft[0] : ready_o_ft[3];
	        assign voter_ready_2_in = sel_mux_ex_i[1] ? ready_o_ft[1] : ready_o_ft[3];
	        assign voter_ready_3_in = sel_mux_ex_i[2] ? ready_o_ft[2] : ready_o_ft[3];
			*/

	        // VOTER 


	        // the voter of result_o. 
	        cv32e40p_3voter #(32,1) voter_result
	         (
	          .in_1_i           ( result_o_ft[0] ),
	          .in_2_i           ( result_o_ft[1] ),
	          .in_3_i           ( result_o_ft[2] ),
	          .voted_o          ( result_o  ),
	          .err_detected_1 	( err_detected_res_1 ),
	          .err_detected_2 	( err_detected_res_2 ),
	          .err_detected_3 	( err_detected_res_3 ),
	          .err_corrected_o  ( err_corrected_res  ),
	          .err_detected_o 	( err_detected_res 	 )
	        );

	        // voter of voter_multicycle_o
	        cv32e40p_3voter #(1,1) voter_multicycle
	        (
	         .in_1_i           ( multicycle_o_ft[0] ),
	         .in_2_i           ( multicycle_o_ft[1] ),
	         .in_3_i           ( multicycle_o_ft[2] ),
	         .voted_o          ( multicycle_o ),
	         .err_detected_1   ( err_detected_multicycle_1 ),
	         .err_detected_2   ( err_detected_multicycle_2 ),
	         .err_detected_3   ( err_detected_multicycle_3 ),
	         .err_corrected_o  ( err_corrected_multicycle  ),
	         .err_detected_o   ( err_detected_multicycle   )
	        );

	        //voter of ready_o
	        cv32e40p_3voter #(1,1) voter_ready
	        (
		     .in_1_i           ( ready_o_ft[0] ),
		     .in_2_i           ( ready_o_ft[1] ),
		     .in_3_i           ( ready_o_ft[2] ),
		     .voted_o          ( ready_o      ),
		     .err_detected_1   ( err_detected_ready_1 ),
		     .err_detected_2   ( err_detected_ready_2 ),
		     .err_detected_3   ( err_detected_ready_3 ),
		     .err_corrected_o  ( err_corrected_ready  ),
		     .err_detected_o   ( err_detected_ready   )
	        );


			// assignment of err_detected_alux is the input of the err_counter_result which count errors for each ALU
	        assign err_detected_mult[0] = (err_detected_res_1 || err_detected_multicycle_1 || err_detected_ready_1);
	        assign err_detected_mult[1] = (err_detected_res_1 || err_detected_multicycle_2 || err_detected_ready_2);
	        assign err_detected_mult[2] = (err_detected_res_3 || err_detected_multicycle_3 || err_detected_ready_3);

	        
	        
	        // Counters of errors in the three MULTs
	        

	        /*generate
	        	genvar i;
	        	for (i = 0; i < 3; i++) begin
	        		always_ff @(posedge clk or negedge rst_n) begin : proc_
			        	if(~rst_n) begin
			        		perf_counter_permanent_faulty_mult_o[i] <= 1'b0;
			        		counter_mult[i] <= 8'b0;
			        	end 
			        	else if (enable_i[i] & enable_count) begin //se il moltiplicatore è abilitato e lo è anche il counter perchè non è gia arrivato al massimo 
			        		if (err_detected_mult[i]==1) begin
			        			counter_mult[i] <= counter_mult[i]+1;
			        		end
			        		else if (counter_mult[i]>2) begin
			        			counter_mult[i] <= counter_mult[i]-2;
			        		end
			        		else begin
			        			counter_mult[i] <= 8'b0;
			        		end
			         	end
			         	else if (counter_mult[i] > 100) begin
		        			perf_counter_permanent_faulty_mult_o[i] <= 1'b1;
		        			enable_count[i] <= 'b0;
		        		end
			        end
		        end	        
	        endgenerate*/


	        always_ff @(posedge clk or negedge rst_n) begin : counter_0
	        	if(~rst_n) begin
	        		perf_counter_permanent_faulty_mult_o[0] <= 1'b0;
	        		counter_mult[0] <= 8'b0;
	        		enable_count[0] <= 1'b0;
	        	end 
	        	else if (enable_i[0] & enable_count) begin //se il moltiplicatore è abilitato e lo è anche il counter perchè non è gia arrivato al massimo 
	        		if (err_detected_mult[0]==1) begin
	        			counter_mult[0] <= counter_mult[0]+1;
	        		end
	        		else if (counter_mult[0]>2) begin
	        			counter_mult[0] <= counter_mult[0]-2;
	        		end
	        		else begin
	        			counter_mult[0] <= 8'b0;
	        		end
	         	end
	         	else if (counter_mult[0] > 100) begin
        			perf_counter_permanent_faulty_mult_o[0] <= 1'b1;
        			enable_count[0] <= 'b0;
        		end
	        end

	        always_ff @(posedge clk or negedge rst_n) begin : counter_1
	        	if(~rst_n) begin
	        		perf_counter_permanent_faulty_mult_o[1] <= 1'b0;
	        		counter_mult[1] <= 8'b0;
	        		enable_count[1] <= 1'b0;
	        	end 
	        	else if (enable_i[1] & enable_count) begin //se il moltiplicatore è abilitato e lo è anche il counter perchè non è gia arrivato al massimo 
	        		if (err_detected_mult[1]==1) begin
	        			counter_mult[1] <= counter_mult[1]+1;
	        		end
	        		else if (counter_mult[1]>2) begin
	        			counter_mult[1] <= counter_mult[1]-2;
	        		end
	        		else begin
	        			counter_mult[1] <= 8'b0;
	        		end
	         	end
	         	else if (counter_mult[1] > 100) begin
        			perf_counter_permanent_faulty_mult_o[1] <= 1'b1;
        			enable_count[1] <= 'b0;
        		end
	        end


	        always_ff @(posedge clk or negedge rst_n) begin : counter_2
	        	if(~rst_n) begin
	        		perf_counter_permanent_faulty_mult_o[2] <= 1'b0;
	        		counter_mult[2] <= 8'b0;
	        		enable_count[2] <= 1'b0;
	        	end 
	        	else if (enable_i[2] & enable_count) begin //se il moltiplicatore è abilitato e lo è anche il counter perchè non è gia arrivato al massimo 
	        		if (err_detected_mult[2]==1) begin
	        			counter_mult[2] <= counter_mult[2]+1;
	        		end
	        		else if (counter_mult[2]>2) begin
	        			counter_mult[2] <= counter_mult[2]-2;
	        		end
	        		else begin
	        			counter_mult[2] <= 8'b0;
	        		end
	         	end
	         	else if (counter_mult[2] > 100) begin
        			perf_counter_permanent_faulty_mult_o[2] <= 1'b1;
        			enable_count[2] <= 'b0;
        		end
	        end



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

	         .op_a_i         	  ( op_a_i[0] ),
	         .op_b_i              ( op_b_i[0] ),
	         .op_c_i              ( op_c_i[0] ),

			 .imm_i               ( imm_i[0]  ),

			  // dot multiplier
			 .dot_signed_i        ( dot_signed_i[0] ),
			 .dot_op_a_i          ( dot_op_a_i[0]   ),
			 .dot_op_b_i          ( dot_op_b_i[0]   ),
			 .dot_op_c_i          ( dot_op_c_i[0]   ),
			 .is_clpx_i           ( is_clpx_i[0]    ),
			 .clpx_shift_i        ( clpx_shift_i[0] ),
			 .clpx_img_i          ( clpx_img_i[0]   ),

	         .result_o            ( result_o     ),

	         .multicycle_o        ( multicycle_o ),
	         .ready_o             ( ready_o      ),
	         .ex_ready_i          ( ex_ready_i      )
	        );

			assign err_corrected_o = 1'b0;
	  		assign err_detected_o  = 1'b0;
			assign perf_counter_permanent_faulty_mult_o = 4'b0;
   
         end

   	endgenerate

endmodule : cv32e40p_mult_ft
