// Copyright 2020 Politecnico di Torino.


////////////////////////////////////////////////////////////////////////////////
// Engineer:       Luca Fiore - luca.fiore@studenti.polito.it                 //
//                                                                            //
// Additional contributions by:                                               //
//                 Marcello Neri - s257090@studenti.polito.it                 //
//                 Elia Ribaldone - s265613@studenti.polito.it                //
//                                                                            //
// Design Name:    cv32e40p_generic_voter                                     //
// Project Name:   cv32e40p Fault tolernat                                    //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:   Majority voter of 3 with arbitrary number of 				  //
//				  input triplets                                              //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40p_generic_voter
#(
  parameter LEN = 32;
  parameter N_IN = 1 //Number of inputs triplets
)
(
  input  logic [N_IN-1:0][LEN-1:0]          in_1_i,
  input  logic [N_IN-1:0][LEN-1:0]          in_2_i,
  input  logic [N_IN-1:0][LEN-1:0]          in_3_i,

  output logic [N_IN-1:0][LEN-1:0] 		voted_o,
  output logic [N_IN-1:0]        		error_correct_o,
  output logic [N_IN-1:0]     	 		error_detected_o
);

//structural description of majority voter of 3 with arbitrary number of input triplets


generate
	genvar k;
	for (k = 0; k < N_IN; k++) begin
	//------------------------------------------------------------
		if (in_1_i[k]!=in_2_i[k] && in_1_i[k]!=in_3_i[k] && in_2_i[k]!=in_3_i[k]) begin // the 3 outputs are all different
			assign error_correct_o[k] = 1'b0;
			assign error_detected_o[k] = '1'b1;
			assign voted_o[k] = in_1_i[k]; //default output if the outputs are all different
		else
			if (in_2_i[k]!=in_3_i[k]) begin
				assign voted_o[k] = in_1_i[k] ;
				assign error_correct_o[k] = 1'b1;
				assign error_detected_o[k] = '1'b1;
			else
				assign voted_o[k]=in_2_i[k];
				if (in_2_i[k]!=in_1_i[k]) begin
					assign error_correct_o[k] = 1'b1;
					assign error_detected_o[k] = '1'b1;
				else // the 3 outputs are all equal
					assign error_correct_o[k] = 1'b0;
					assign error_detected_o[k] = '1'b0;
				end
			end
		end
	//------------------------------------------------------------
	end
endgenerate

/* THIS IF WE WANT TO OUTPUT JUST THE OR OF THE "DETECTION" AND "CORRECTION" SIGNALS
assign error_correct_o = error_correct_o.or();
assign error_detected_o = error_detected_o.or();
*/

endmodule