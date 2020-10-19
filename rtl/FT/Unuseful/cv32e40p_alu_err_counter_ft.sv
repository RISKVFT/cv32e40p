// Copyright 2020 Politecnico di Torino.


////////////////////////////////////////////////////////////////////////////////
// Engineer:       Luca Fiore - luca.fiore@studenti.polito.it                 //
//                                                                            //
// Additional contributions by:                                               //
//                 Marcello Neri - s257090@studenti.polito.it                 //
//                 Elia Ribaldone - s265613@studenti.polito.it                //
//                                                                            //
// Design Name:    cv32e40p_alu_err_counter_ft                                //
// Project Name:   cv32e40p Fault tolernat                                    //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    performance counters to know if an alu is permanently      //
//                 demaged                                                    //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////  


//-----------------------------------------------------
module cv32e40p_alu_err_counter_ft import cv32e40p_pkg::*; import cv32e40p_apu_core_pkg::*;
#(
)
(
  input  logic            clk,
  input  logic            rst_n,
  input  logic            alu_enable_i,
  input  logic            alu_operator_i,
  input  logic [3:0]      error_detected_i, 
  output logic [3:0][8:0] permanent_faulty_alu;  // one for each fsm: 4 ALU and 9 subpart of ALU
);


logic [3:0][8:0] fsm_enable;  // one for each fsm



// Instantiate 4*9 fsm (36 counter to detect permanent errors in the 4 ALUs)
cv32e40p_alu_ft_fsm fsm_array[3:0][8:0]
(
  .clock                    (clk),
  .rst_n                    (rst_n),
  .fsm_enable_i             (fsm_enable),
  .error_detected_i         (error_detected_i), 
  .en_reg_permanent_fault   (permanent_faulty_alu)
);

genvar i;
generate
    for (i=0; i < 4; i++) begin
      
      always_comb begin

        fsm_enable[i][8:0] <= 9'b0; //default

        if (~rst_n) begin
          permanent_faulty_alu[i]   = 9'b0;
        end 
        else if (alu_enable_i) begin
          case (alu_operator_i)

            // shift
            ALU_ADD, ALU_SUB, ALU_ADDU, ALU_SUBU, ALU_ADDR, ALU_SUBR, ALU_ADDUR, ALU_SUBUR, ALU_SRA, ALU_SRL, ALU_ROR, ALU_SLL:  
            fsm_enable[i][0] <= 1;


            // Logic
            ALU_XOR, ALU_OR, ALU_AND :  
            fsm_enable[i][1] <= 1;
       

            // Bit manipulation
            ALU_BEXT, ALU_BEXTU, ALU_BINS, ALU_BCLR, ALU_BSET, ALU_BREV :  
            fsm_enable[i][2] <= 1;


            // Bit counting
            ALU_FF1, ALU_FL1, ALU_CNT, ALU_CLB:  
            fsm_enable[i][3] <= 1;


            // Shuffle
            ALU_EXTS, ALU_EXT, ALU_SHUF, ALU_SHUF2, ALU_PCKLO, ALU_PCKHI, ALU_INS:  
            fsm_enable[i][4] <= 1;


            // Comparisons
            ALU_LTS, ALU_LTU, ALU_LES, ALU_LEU, ALU_GTS, ALU_GTU, ALU_GES, ALU_GEU, ALU_EQ, ALU_NE, ALU_SLTS, ALU_SLTU, ALU_SLETS, ALU_SLETU :  
            fsm_enable[i][5] <= 1;


            // Absolute value
            ALU_ABS, ALU_CLIP, ALU_CLIPU:  
            fsm_enable[i][6] <= 1;


            // min/max
            ALU_MIN, ALU_MINU, ALU_MAX, ALU_MAXU:  
            fsm_enable[i][7] <= 1;


            // div/rem
            ALU_DIVU, ALU_DIV, ALU_REMU, ALU_REM:  
            fsm_enable[i][8] <= 1;


            default:          
            fsm_enable[i][8:0] <= 9'b0;

          endcase; // case (alu_operator)
        end
    end
endgenerate




always_ff @(posedge clk) begin : perm_error_threshold
  if (~rst_n) begin
    permanent_faulty_alu     <= 9'b0;
  end 
  else begin
    if (permanent_faulty_alu[0] != 1'b1) begin
      if (count_logic>100) begin
         
      end
    end

    if (count_shift>100) begin
      /* code */
    end

end

endmodule