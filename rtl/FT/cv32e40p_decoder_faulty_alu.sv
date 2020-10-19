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
  output logic [3:0]      clock_gate_pipe_replica_o
);

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


endmodule : cv32e40p_decoder_faulty_alu