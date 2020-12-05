// Copyright 2020 Politecnico di Torino.


////////////////////////////////////////////////////////////////////////////////
// Engineer:       Luca Fiore - luca.fiore@studenti.polito.it                 //
//                                                                            //
// Additional contributions by:                                               //
//                 Marcello Neri - s257090@studenti.polito.it                 //
//                 Elia Ribaldone - s265613@studenti.polito.it                //
//                                                                            //
// Design Name:    cv32e40p_dispatcher_ft                                     //
// Project Name:   cv32e40p Fault tolernat                                    //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Decodet to choose the correct set of 3 ALU among the 4     //
//   			   available                                                  //
//                                                                            //
//////////////////////////////////////////////////////////////////////////////// 


module cv32e40p_dispatcher_ft(
  input  logic 			  rst_n,
  input  logic 			  alu_used,
  input  logic            mult_used,
  input  logic [3:0] 	  permanent_faulty_alu_i,  // one for each ALU
  input  logic [2:0] 	  permanent_faulty_mult_i,  // one for each MULT
  output logic [3:0]      clock_gate_pipe_replica_o,
  output logic [2:0]	  sel_mux_ex_o,
  output logic [1:0]	  sel_bypass_alu_o,
  output logic [1:0]	  sel_bypass_mult_o,
  output logic 			  alu_totally_defective_o, // set to '1' if all the ALUs are permanently faulty for that operation
  output logic 			  mult_totally_defective_o // set to '1' if all the MULTs are permanently faulty for that operation
);

// If one of the 4 bits became 1 I should not use the corresponding ALU so I should have the corresponding clock gating bit to 0.
// If there are more than one bit to 1 it means that more than one ALU are permanent faulty for that set of operations. 
// In this case I replace the most significant ALU that means if I have that ALU 0 and 1 are faulty I replace the 1 becasue. 
// When just one ALU is available, I will get its output without TMR and voting mechanism because TMR doesn't make sense with just one good ALU.
// If there are no available ALUs for that operation a signal will be triggered to report the bad situation to the OS for example


always_comb begin : proc_decoder_faulty_alu

	if (~rst_n) begin
		clock_gate_pipe_replica_o = 4'b0111;
		sel_mux_ex_o = 3'b000;
		sel_bypass_alu_o = 2'b00;
		alu_totally_defective_o = 1'b0;
		sel_bypass_mult_o = 2'b00;
		mult_totally_defective_o = 1'b0;

	end else if (alu_used) begin  //only if alu has to be used we have to provide this decoding becasue it is relative to the choice of three of the four ALUs
		unique case (permanent_faulty_alu_i)
			4'b0000: begin
				clock_gate_pipe_replica_o = 4'b0111;
				sel_mux_ex_o = 3'b000;
				sel_bypass_alu_o = 2'b00;
				alu_totally_defective_o = 1'b0;
			end
			4'b0001: begin
				clock_gate_pipe_replica_o = ~permanent_faulty_alu_i;
				sel_mux_ex_o = 3'b001;
				sel_bypass_alu_o = 2'b00;
				alu_totally_defective_o = 1'b0;
			end
			4'b0010, 4'b0011: begin
				clock_gate_pipe_replica_o = ~permanent_faulty_alu_i;
				sel_mux_ex_o = 3'b010;
				sel_bypass_alu_o = 2'b00;
				alu_totally_defective_o = 1'b0;
			end
			4'b0100, 4'b0101: begin
				clock_gate_pipe_replica_o = ~permanent_faulty_alu_i;
				sel_mux_ex_o = 3'b100;
				sel_bypass_alu_o = 2'b00;
				alu_totally_defective_o = 1'b0;
			end
			4'b0110: begin
				clock_gate_pipe_replica_o = ~permanent_faulty_alu_i;
				sel_mux_ex_o = 3'b100;
				sel_bypass_alu_o = 2'b00;
				alu_totally_defective_o = 1'b0;
			end
			4'b0111: begin
				clock_gate_pipe_replica_o = ~permanent_faulty_alu_i;
				sel_mux_ex_o = 3'b100;
				sel_bypass_alu_o = 2'b11;
				alu_totally_defective_o = 1'b0;
			end
			4'b1000, 4'b1001, 4'b1010, 4'b1011, 4'b1100, 4'b1101, 4'b1110 : begin
				clock_gate_pipe_replica_o = ~permanent_faulty_alu_i;
				sel_mux_ex_o = 3'b000;
				sel_bypass_alu_o[1] = permanent_faulty_alu_i[0] && (permanent_faulty_alu_i[2]^permanent_faulty_alu_i[1]);
				sel_bypass_alu_o[0] = permanent_faulty_alu_i[1] && (permanent_faulty_alu_i[2]^permanent_faulty_alu_i[0]);
				alu_totally_defective_o = 1'b0;
			end
			4'b1111: begin // all the ALUs are permanently faulty for that operation
				clock_gate_pipe_replica_o = ~permanent_faulty_alu_i;
				sel_mux_ex_o = 3'b000;
				sel_bypass_alu_o = 2'b00;
				alu_totally_defective_o = 1'b1;
			end
			default : begin
				clock_gate_pipe_replica_o = 4'b0111;
				sel_mux_ex_o = 3'b000;
				sel_bypass_alu_o = 2'b00;
				alu_totally_defective_o = 1'b0;
				
			end
		endcase

	end else if (mult_used) begin
		unique case (permanent_faulty_mult_i)
			4'b000: begin
				clock_gate_pipe_replica_o = 4'b0111;
				sel_mux_ex_o = 3'b000;
				sel_bypass_mult_o = 2'b00;
				mult_totally_defective_o = 1'b0;
			end
			4'b001: begin
				clock_gate_pipe_replica_o = ~permanent_faulty_mult_i;
				sel_mux_ex_o = 3'b001;
				sel_bypass_mult_o = 2'b00;
				mult_totally_defective_o = 1'b0;
			end
			4'b010: begin
				clock_gate_pipe_replica_o = ~permanent_faulty_mult_i;
				sel_mux_ex_o = 3'b010;
				sel_bypass_mult_o = 2'b00;
				mult_totally_defective_o = 1'b0;
			end
			4'b011: begin
				clock_gate_pipe_replica_o = ~permanent_faulty_mult_i;
				sel_mux_ex_o = 3'b010;
				sel_bypass_mult_o = 2'b11;
				mult_totally_defective_o = 1'b0;
			end
			4'b100: begin
				clock_gate_pipe_replica_o = ~permanent_faulty_mult_i;
				sel_mux_ex_o = 3'b100;
				sel_bypass_mult_o = 2'b00;
				mult_totally_defective_o = 1'b0;
			end
			4'b101: begin
				clock_gate_pipe_replica_o = ~permanent_faulty_mult_i;
			    sel_mux_ex_o = 3'b100;
				sel_bypass_mult_o = 2'b10;
				mult_totally_defective_o = 1'b0;
			end
			4'b110: begin
				clock_gate_pipe_replica_o = ~permanent_faulty_mult_i;
				sel_mux_ex_o = 3'b100;
				sel_bypass_mult_o = 2'b01;
				mult_totally_defective_o = 1'b0;
			end
			4'b111: begin
				clock_gate_pipe_replica_o = ~permanent_faulty_mult_i;
				sel_mux_ex_o = 3'b100;
				sel_bypass_mult_o = 2'b00;
				mult_totally_defective_o = 1'b1; // In this case it is activated the mechanism to compute the multiplication as sequence of sums and shifts
			end
			default : begin
				clock_gate_pipe_replica_o = 4'b0111;
				sel_mux_ex_o = 3'b000;
				sel_bypass_mult_o = 2'b00;
				mult_totally_defective_o = 1'b0;
			end
		endcase
	end

end

endmodule : cv32e40p_dispatcher_ft
