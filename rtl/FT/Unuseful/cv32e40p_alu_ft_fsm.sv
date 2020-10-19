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
  input logic       fsm_enable_i,
  input logic       error_detected_i, 
  output logic      en_reg_permanent_fault
);

enum logic [2:0] { RESET_STATE, UP_STATE, IDLE_STATE, FINAL_STATE, DOWN_STATE } State;


State CurrentState, NextState;

logic en_count;
//logic up_dwn; // 0 is up, 1 is down
logic count[6:0];


//----------Seq Logic-----------------------------
always_ff @(posedge clock or negedge rst_n) begin : proc_
  if(rst_n == 1'b0) begin
    CurrentState <= reset_state;
  end else begin
    CurrentState <= NextState;
  end
end // End of Seq logic

//----------Comb Logic----------------------------
always_comb begin :
  case (CurrentState)
    reset_state:
    if (fsm_enable_i) begin
        if (error_detected_i) begin
          NextState = UP_STATE;
      	end
      	else begin 
      		if (count<2) begin
      			NextState = IDLE_STATE;
      		end
      		else begin
      			NextState = DOWN_STATE;
      		end
      	end
    else begin
        NextState = IDLE_STATE;
    end


    UP_STATE:      
    if ( count > 99 ) begin
        NextState = FINAL_STATE;
    end
    else begin
    	if (fsm_enable_i) begin
        	if (error_detected_i) begin
          		NextState = UP_STATE;
      		end
      		else begin 
      			if (count<2) begin
      				NextState = IDLE_STATE;
      			end
      			else begin
      				NextState = DOWN_STATE;
      			end
      		end
    else begin
        NextState = IDLE_STATE;
    end 
	end

    IDLE_STATE: 
    if (fsm_enable_i) begin
        if (error_detected_i) begin
          NextState = UP_STATE;
      	end
      	else begin 
      		if (count<2) begin
      			NextState = IDLE_STATE;
      		end
      		else begin
      			NextState = DOWN_STATE;
      		end
      	end
    else begin
        NextState = IDLE_STATE;
    end

    DOWN_STATE:
    if (fsm_enable_i) begin
        if (error_detected_i) begin
          NextState = UP_STATE;
      	end
      	else begin 
      		if (count<2) begin
      			NextState = IDLE_STATE;
      		end
      		else begin
      			NextState = DOWN_STATE;
      		end
      	end
    else begin
        NextState = IDLE_STATE;
    end

    FINAL_STATE:
    	NextState = reset_state;




    default : NextState = reset_state;
  endcase
end // End of Comb logic



//----------Output Logic-----------------------------
always_comb 
begin: Output_process
	case(CurrentState)
	    
	    reset_state : begin
	      en_count <= 1'b0;
	      en_reg_permanent_fault <= 1'b0;
	      count <= 0;
	    end
	    
	    UP_STATE : begin
	      en_count <= 1'b1;
	      en_reg_permanent_fault <= 1'b0;
	      count <= count+1;;
	    end
	    
	    DOWN_STATE : begin
	      en_count <= 1'b1;
	      en_reg_permanent_fault <= 1'b0;
	      count <= count-2;
	    end

	    IDLE_STATE: begin
	      en_count <= 1'b0;
	      en_reg_permanent_fault <= 1'b0;
	      count <= count;
	    end

	    FINAL_STATE: begin
	    en_count <= 1'b0;
	      en_reg_permanent_fault <= 1'b1;
	      count <= count;
	    end

	    default : begin
	      en_count <= 1'b0;
	      en_reg_permanent_fault <= 1'b0;
	      count <= count;
	    end
	  endcase
end // End of Output_process

/*

//----------Counter----------------------------------

always_ff @(posedge clock) begin : proc_
  if(rst_n == 1'b0) begin
    count <= 'b0;
  end else begin
    if (up_dwn == 1'b0) begin
       count <= count+1;
    end
    else
    	count <= count-2;
  end
end  // End of Counter

*/

endmodule