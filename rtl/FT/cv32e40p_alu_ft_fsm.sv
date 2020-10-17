// Copyright 2020 Politecnico di Torino.


////////////////////////////////////////////////////////////////////////////////
// Engineer:       Luca Fiore - luca.fiore@studenti.polito.it                 //
//                                                                            //
// Additional contributions by:                                               //
//                 Marcello Neri - s257090@studenti.polito.it                 //
//                 Elia Ribaldone - s265613@studenti.polito.it                //
//                                                                            //
// Design Name:    cv32e40p_alu_ft_fsm                                        //
// Project Name:   cv32e40p Fault tolernat                                    //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:   fsm to search for permanent faults                          //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////  


//-----------------------------------------------------
module cv32e40p_alu_ft_fsm (
  input logic       clock,
  input logic       rst_n,
  input logic       alu_enable_i,
  input logic       error_detected_i, 
  output logic      alu_remove_o
);

typedef enumlogic [2:0] { reset_state, count_state, aluu_remove_state } State;

State CurrentState, NextState;

logic en_count;
logic count[6:0];


//----------Seq Logic-----------------------------
always_ff @(posedge clock or negedge rst_n) begin : proc_
  if(rst_n== 1'b0) begin
    CurrentState <= reset_state;
  end else begin
    CurrentState <= NextState;
  end
end // End of Seq logic

//----------Comb Logic----------------------------
always_comb begin :
  case (CurrentState)
    reset_state:     
      if (alu_enable_i) begin
        if (error_detected_i) begin
          NextState = count_state;
      end 
      else
          NextState = reset_state;
      end

    count_state:      
      if ( count == 100 ) begin
        NextState = alu_remove_state;
      else
        NextState = reset_state;
      end

    alu_remove_state: 
      NextState = reset_state;

    default : NextState = reset_state;
  endcase
end // End of Comb logic



//----------Output Logic-----------------------------
always @ (posedge clock)
begin : OUTPUT_LOGIC
if (rst_n == 1'b0) begin
  en_count <= 1'b0;
  alu_remove_o <= 1'b0;
end
else begin
  case(CurrentState)
    
    reset_state : begin
      en_count <= 1'b0;
      alu_remove_o <= 1'b0;
    end
    
    count_state : begin
      en_count <= 1'b1;
      alu_remove_o <= 1'b0;
    end
    
    alu_remove_state : begin
      en_count <= 1'b0;
      alu_remove_o <= 1'b1;
    end

    default : begin
      en_count <= 1'b0;
      alu_remove_o <= 1'b0;
    end
  endcase
end
end // End Of Block OUTPUT_LOGIC


//----------Counter----------------------------------

always_ff @(posedge clock) begin : proc_
  if(rst_n == 1'b0) begin
    count <= 'b0;
  end else begin
    if (en_count == 1'b1) begin
       count <= count + 1;
     end <= ;
  end
end  // End of Counter

endmodule