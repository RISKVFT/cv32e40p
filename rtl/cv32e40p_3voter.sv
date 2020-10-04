// Copyright 2020 Politecnico di Torino.


////////////////////////////////////////////////////////////////////////////////
// Engineer:       Luca Fiore - luca.fiore@studenti.polito.it                 //
//                                                                            //
// Additional contributions by:                                               //
//                 Marcello Neri - s257090@studenti.polito.it                 //
//                 Elia Ribaldone - s257090@studenti.polito.it                //
//                                                                            //
// Design Name:    cv32e40p_voter                                             //
// Project Name:   cv32e40p Fault tolernat                                    //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:   Majority voter of 3                                         //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40p_voter
#(
  parameter LEN = 32
)
(
  input  logic [LEN-1:0]         in_1_i,
  input  logic [LEN-1:0]         in_2_i,
  input  logic [LEN-1:0]         in_3_i,

  output logic [LEN-1:0]		 voted_o,
  output logic                   error_correct_o,
  output logic					 error_detected_o
);

//structural description of majority voter of 3

always_comb
begin	
	if (in_1_i!=in_2_i && in_1_i!=in_3_i && in_2_i!=in_3_i) begin // the 3 outputs are all different
		error_correct_o = 1'b0;
		error_detected_o = '1'b1;
		voted_o = in_1_i; //default output if the outputs are all different
	else
		if (in_2_i!=in_3_i) begin
			voted_o = in_1_i ;
			error_correct_o = 1'b1;
			error_detected_o = '1'b1;
		else
			voted_o=in_2_i;
			if (in_2_i!=in_1_i) begin
				error_correct_o = 1'b1;
				error_detected_o = '1'b1;
			else // the 3 outputs are all equal
				error_correct_o = 1'b0;
				error_detected_o = '1'b0;
			end
		end
	end
end


endmodule
