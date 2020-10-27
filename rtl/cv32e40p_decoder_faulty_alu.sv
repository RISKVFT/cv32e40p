// Copyright 2020 Politecnico di Torino.


////////////////////////////////////////////////////////////////////////////////
// Engineer:       Luca Fiore - luca.fiore@studenti.polito.it                 //
//                                                                            //
// Additional contributions by:                                               //
//                 Marcello Neri - s257090@studenti.polito.it                 //
//                 Elia Ribaldone - s265613@studenti.polito.it                //
//                                                                            //
// Design Name:    cv32e40p_decoder_faulty_alu                                //
// Project Name:   cv32e40p Fault tolernat                                    //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Decodet to choose the correct set of 3 ALU among the 4     //
//   			   available                                                  //
//                                                                            //
//////////////////////////////////////////////////////////////////////////////// 


module cv32e40p_decoder_faulty_alu(
  input  logic [3:0] 	  permanent_faulty_alu_i,  // one for each ALU
  output logic [3:0]      clock_gate_pipe_replica_o,
  output logic [2:0]	  sel_mux_ex_o
);

// If one of the 4 bits became 1 I should not use the corresponding ALU so I should have the corresponding clock gating bit to 0.
// If there are more than one bit to 1 it means that more than one ALU is permanent faulty for that set of instruction. 
// In this case I leave the most significant ALUs that means if I have that ALU 0 and 1 are faulty I replace only the 1 becasue 
// I want to have always TMR even if one of the three ALU is faulty.

always_comb begin : proc_decoder_faulty_alu
	unique case (permanent_faulty_alu_i)
		4'b0000: begin
			clock_gate_pipe_replica_o = 4'b0111;
			sel_mux_ex_o <= 3'b000;
		end
		4'b0001: begin
			clock_gate_pipe_replica_o = 4'b1110;
			sel_mux_ex_o <= 3'b001;
		end
		4'b0010, 4'b0011: begin
			clock_gate_pipe_replica_o = 4'b1101;
			sel_mux_ex_o <= 3'b010;
		end
		4'b0100, 4'b0101, 4'b0111: begin
			clock_gate_pipe_replica_o = 4'b1011;
			sel_mux_ex_o <= 3'b100;
		end
		4'b1000, 4'b1001, 4'b1010, 4'b1011, 4'b1100, 4'b1101, 4'b1110, 4'b1111 : begin
			clock_gate_pipe_replica_o = 4'b0111;
			sel_mux_ex_o <= 3'b000;
		end


		default : clock_gate_pipe_replica_o = 4'b0111;
	endcase

end


/*
always_comb begin : proc_decoder_faulty_alu
	case (permanent_faulty_alu_i)
		4'b0000: begin
			clock_gate_pipe_replica_o = 4'b0111;
		end
		4'b0001: begin
			clock_gate_pipe_replica_o = 4'b1110;
		end
		4'b0010: begin
			clock_gate_pipe_replica_o = 4'b1101;
		end
		4'b0011: begin
			clock_gate_pipe_replica_o = 4'b1101;
		end
		4'b0100: begin
			clock_gate_pipe_replica_o = 4'b1011;
		end
		4'b0101: begin
			clock_gate_pipe_replica_o = 4'b1011;
		end
		4'b0110: begin
			clock_gate_pipe_replica_o = 4'b1011;
		end
		4'b0111: begin
			clock_gate_pipe_replica_o = 4'b1011; // faulty ALU
		end
		4'b1000: begin
			clock_gate_pipe_replica_o = 4'b0111;
		end
		4'b1001: begin
			clock_gate_pipe_replica_o = 4'b0111;
		end
		4'b1010: begin
			clock_gate_pipe_replica_o = 4'b0111;
		end
		4'b1011: begin
			clock_gate_pipe_replica_o = 4'b0111; // faulty ALU
		end
		4'b1100: begin
			clock_gate_pipe_replica_o = 4'b0111;
		end
		4'b1101: begin
			clock_gate_pipe_replica_o = 4'b0111; // faulty ALU
		end
		4'b1110: begin
			clock_gate_pipe_replica_o = 4'b0111; // faulty ALU
		end
		4'b1111: begin
			clock_gate_pipe_replica_o = 4'b0111; // faulty ALU
		end

	
		default : clock_gate_pipe_replica_o = 4'b0111;
	endcase

end
*/


endmodule : cv32e40p_decoder_faulty_alu
