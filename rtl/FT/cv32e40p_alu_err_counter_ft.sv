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
  input  logic       clock,
  input  logic       rst_n,
  input  logic       alu_enable_i,
  input  logic       alu_operator_i,
  input  logic       error_detected_i, 
  output logic       alu_remove_o
);

logic [12:0][6:0]  count;

always_ff @(posedge clk)
 if (~rst_n) begig
    count_normal      = 'b0;
    count_logic       = 'b0;
    count_shift       = 'b0;
    count_bit_man     = 'b0;
    count_bit_count   = 'b0;
    count_extension   = 'b0;
    count_comparison  = 'b0;
    count_setlowerto  = 'b0;
    count_abs         = 'b0;
    count_ins_ext     = 'b0;
    count_min_max     = 'b0;
    count_div_rem     = 'b0;
    count_shuf        = 'b0;
    count_pck         = 'b0;
  end 
  else if (alu_enable_i) begin
    case (alu_operator_i)

      // arithmetic operations
      ALU_ADD, ALU_SUB, ALU_ADDU, ALU_SUBU, ALU_ADDR, ALU_SUBR, ALU_ADDUR, ALU_SUBUR:  
      if (error_detected_i) begin
        count_normal=count_normal+1;
      end
      else begin
        if (count_normal>2) begin
          count_normal=count_normal-2;
        end
        else begin
          count_normal=0;
        end
      end


      // Logic
      ALU_XOR, ALU_OR, ALU_AND :  
      if (error_detected_i) begin
        count_logic=count_logic+1;
      end
      else begin
        if (count_logic>2) begin
          count_logic=count_logic-2;
        end
        else begin
          count_logic=0;
        end
      end


      // Shifts
      ALU_SRA, ALU_SRL, ALU_ROR, ALU_SLL :  
      if (error_detected_i) begin
        count_shift=count_shift+1;
      end
      else begin
        if (count_shift>2) begin
          count_shift=count_shift-2;
        end
        else begin
          count_shift=0;
        end
      end


      // Bit manipulation
      ALU_BEXT, ALU_BEXTU, ALU_BINS, ALU_BCLR, ALU_BSET, ALU_BREV :  
      if (error_detected_i) begin
        count_bit_man=count_bit_man+1;
      end
      else begin
        if (count_bit_man>2) begin
          count_bit_man=count_bit_man-2;
        end
        else begin
          count_bit_man=0;
        end
      end


      // Bit counting
      ALU_FF1, ALU_FL1, ALU_CNT, ALU_CLB:  
      if (error_detected_i) begin
        count_bit_count=count_bit_count+1;
      end
      else begin
        if (count_bit_count>2) begin
          count_bit_count=count_bit_count-2;
        end
        else begin
          count_bit_count=0;
        end
      end


      // Sign-/zero-extensions
      ALU_EXTS, ALU_EXT:  
      if (error_detected_i) begin
        count_extension=count_extension+1;
      end
      else begin
        if (count_extension>2) begin
          count_extension=count_extension-2;
        end
        else begin
          count_extension=0;
        end
      end


      // Comparisons
      ALU_LTS, ALU_LTU, ALU_LES, ALU_LEU, ALU_GTS, ALU_GTU, ALU_GES, ALU_GEU, ALU_EQ, ALU_NE :  
      if (error_detected_i) begin
        count_comparison=count_comparison+1;
      end
      else begin
        if (count_comparison>2) begin
          count_comparison=count_comparison-2;
        end
        else begin
          count_comparison=0;
        end
      end


      // Set Lower Than operations
      ALU_SLTS, ALU_SLTU, ALU_SLETS, ALU_SLETU:  
      if (error_detected_i) begin
        count_setlowerto=count_setlowerto+1;
      end
      else begin
        if (count_setlowerto>2) begin
          count_setlowerto=count_setlowerto-2;
        end
        else begin
          count_setlowerto=0;
        end
      end

      // Absolute value
      ALU_ABS, ALU_CLIP, ALU_CLIPU:  
      if (error_detected_i) begin
        count_abs=count_abs+1;
      end
      else begin
        if (count_abs>2) begin
          count_abs=count_abs-2;
        end
        else begin
          count_abs=0;
        end
      end

      // Insert/extract
      ALU_INS:  
      if (error_detected_i) begin
        count_ins_ext=count_ins_ext+1;
      end
      else begin
        if (count_ins_ext>2) begin
          count_ins_ext=count_ins_ext-2;
        end
        else begin
          count_ins_ext=0;
        end
      end

      // min/max
      ALU_MIN, ALU_MINU, ALU_MAX, ALU_MAXU:  
      if (error_detected_i) begin
        count_min_max=count_min_max+1;
      end
      else begin
        if (count_min_max>2) begin
          count_min_max=count_min_max-2;
        end
        else begin
          count_min_max=0;
        end
      end

      // div/rem
      ALU_DIVU, ALU_DIV, ALU_REMU, ALU_REM:  
      if (error_detected_i) begin
        count_div_rem=count_div_rem+1;
      end
      else begin
        if (count_div_rem>2) begin
          count_div_rem=count_div_rem-2;
        end
        else begin
          count_div_rem=0;
        end
      end

      // shuffle
      ALU_SHUF, ALU_SHUF2:  
      if (error_detected_i) begin
        count_shuf=count_shuf+1;
      end
      else begin
        if (count_shuf>2) begin
          count_shuf=count_shuf-2;
        end
        else begin
          count_shuf=0;
        end
      end


      // pack
      ALU_PCKLO, ALU_PCKHI:  
      if (error_detected_i) begin
        count_pck=count_pck+1;
      end
      else begin
        if (count_pck>2) begin
          count_pck=count_pck-2;
        end
        else begin
          count_pck=0;
        end
      end

      default:          
        count_normal      = 'b0;
        count_logic       = 'b0;
        count_shift       = 'b0;
        count_bit_man     = 'b0;
        count_bit_count   = 'b0;
        count_extension   = 'b0;
        count_comparison  = 'b0;
        count_setlowerto  = 'b0;
        count_abs         = 'b0;
        count_ins_ext     = 'b0;
        count_min_max     = 'b0;
        count_div_rem     = 'b0;
        count_shuf        = 'b0;
        count_pck         = 'b0;

    endcase; // case (alu_operator)
  end

endmodule