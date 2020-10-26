// Copyright 2020 Politecnico di Torino.


////////////////////////////////////////////////////////////////////////////////
// Engineer:       Luca Fiore - luca.fiore@studenti.polito.it                 //
//                                                                            //
// Additional contributions by:                                               //
//                 Marcello Neri - s257090@studenti.polito.it                 //
//                 Elia Ribaldone - s265613@studenti.polito.it                //
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
  parameter L1 = 32,
  parameter L2 = 1
)
(
  input  logic [L1-1:0][L2-1:0]   	in_1_i,
  input  logic [L1-1:0][L2-1:0]   	in_2_i,
  input  logic [L1-1:0][L2-1:0]   	in_3_i,

  output logic [L1-1:0][L2-1:0]		voted_o,
  output logic						err_detected_1,
  output logic						err_detected_2,
  output logic						err_detected_3,
  output logic                  	err_corrected_o,
  output logic						err_detected_o
);

//structural description of majority voter of 3

always_comb
begin	
	if (in_1_i!=in_2_i && in_1_i!=in_3_i && in_2_i!=in_3_i) begin // the 3 outputs are all different
		err_detected_1 = 1'b1;
		err_detected_2 = 1'b1;
		err_detected_3 = 1'b1;
		err_corrected_o = 1'b0;
		voted_o = in_1_i; //default output if the outputs are all different
	end
	else begin
		if (in_2_i!=in_3_i) begin
			err_corrected_o = 1'b1;
			voted_o = in_1_i;
			if (in_2_i==in_1_i) begin
				err_detected_1 = 1'b0;
				err_detected_2 = 1'b0;
				err_detected_3 = 1'b1;			
			end
			else begin
				err_detected_1 = 1'b0;
				err_detected_2 = 1'b1;
				err_detected_3 = 1'b0;
			end
		end 
		else begin
			voted_o=in_2_i;
			if (in_2_i!=in_1_i) begin
				err_detected_1 = 1'b1;
				err_detected_2 = 1'b0;
				err_detected_3 = 1'b0;
				err_corrected_o = 1'b1;
			end
			else begin// the 3 outputs are all equal
				err_detected_1 = 1'b0;
				err_detected_2 = 1'b0;
				err_detected_3 = 1'b0;
				err_corrected_o = 1'b0;
			end
		end
	end
end

assign err_detected_o = err_detected_1 || err_detected_2 || err_detected_3;

endmodule
