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
// Description:    Counters for the 4 ALUs to know if an alu is permanently   //
//                 demaged. The performance counters related to the 4 alu     //
//                 are activated here.                                        //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////  


//ATTENZIONE: BISOGNA ABILITARE I COUNTER SOLO DELLE TRE ALU USATE: POSSO FAR USCIRE IL CLOCK GATING DALL'ID STAGE SENZA PASSARE PER LA PIPE COSÌ COME I SELETTORI DEI MUX POTREBBERO USCIRE DALL'ID STAGE SENZA PASSARE PER LA PIPE

//-----------------------------------------------------
module cv32e40p_alu_err_counter_ft import cv32e40p_pkg::*; import cv32e40p_apu_core_pkg::*;
  (
  input  logic            clk,
  input  logic [3:0]      clock_en,
  input  logic            rst_n,
  input  logic [3:0]      alu_enable_i,
  input  logic [3:0]      alu_operator_i,
  input  logic [3:0]      error_detected_i, 
  output logic [3:0][8:0] permanent_faulty_alu_o,  // one for each fsm: 4 ALU and 9 subpart of ALU
  output logic [3:0]      perf_counter_permanent_faulty_alu_o // decided to use only four performance counters, one for each ALU and increment them only if there is a permanent error (in any of the subset of istructions) into the corresponding ALU.
);

logic [3:0][8:0] count_logic;
logic [3:0][8:0] count_shift;
logic [3:0][8:0] count_bit_man
logic [3:0][8:0] count_bit_count;
logic [3:0][8:0] count_comparison;
logic [3:0][8:0] count_abs;
logic [3:0][8:0] count_min_max;
logic [3:0][8:0] count_div_rem;
logic [3:0][8:0] count_shuf;

logic [3:0][8:0] permanent_faulty;  // one for each fsm: 4 ALU and 9 subpart of ALU

logic [3:0]      clock_gated;

// CLOCK GATING for the counter that have already reached the end.
cv32e40p_clock_gate CG_counter[3:0]
(
 .clk_i        ( clk            ),
 .en_i         ( clock_en[3:0]  ),
 .scan_cg_en_i ( 1'b0           ), // not used
 .clk_o        ( clk_gated[3:0] )
);

genvar i;
generate
  for (i=0; i < 4; i++) begin
    always_ff @(posedge clk_gated[i])
      if (~rst_n) begin
        count_logic       <= 8'b0;
        count_shift       <= 8'b0;
        count_bit_man     <= 8'b0;
        count_bit_count   <= 8'b0;
        count_comparison  <= 8'b0;
        count_abs         <= 8'b0;
        count_min_max     <= 8'b0;
        count_div_rem     <= 8'b0;
        count_shuf        <= 8'b0;
      end 
      else if (alu_enable_i[i]) begin
        case (alu_operator_i[i])

          // shift
          ALU_ADD, ALU_SUB, ALU_ADDU, ALU_SUBU, ALU_ADDR, ALU_SUBR, ALU_ADDUR, ALU_SUBUR, ALU_SRA, ALU_SRL, ALU_ROR, ALU_SLL:  
          if (~permanent_faulty[i][0]) begin // PROBABILMENTE QUESTO CONTROLLO È SUPERFLUO PERCHÈ NON DOVREBBE ESSERE SELEZIONATA QUESTA ALU SE NON È IN GRADO DI FARE L'OPERAZIONE. 
            if (error_detected_i[i]) begin      // TUTTAVIA SE C'È LO STESSO ERRORE PERMANENTE IN DUE ALU ALLORA NE VERRÀ SCELTA UNA TRA LE DUE CHE NON SAPRÀ FARE L'OPERAZIONE 
              count_shift[i]<=count_shift[i]+1;
            end
            else begin
              if (count_shift[i]>2) begin
                count_shift[i]<=count_shift[i]-2;
              end
              else begin
                count_shift[i]<=8'b0;
              end
            end
          end else begin
            count_shift[i]<=8'b0;
          end


          // Logic
          ALU_XOR, ALU_OR, ALU_AND:  
          if (~permanent_faulty[i][1]) begin
            if (error_detected_i[i]) begin
              count_logic[i]<=count_logic[i]+1;
            end
            else begin
              if (count_logic[i]>2) begin
                count_logic[i]<=count_logic[i]-2;
              end
              else begin
                count_logic[i]<=8'b0;
              end
            end
          end else begin
            count_logic[i]<=8'b0;
          end
     


          // Bit manipulation
          ALU_BEXT, ALU_BEXTU, ALU_BINS, ALU_BCLR, ALU_BSET, ALU_BREV:  
          if (~permanent_faulty[i][2]) begin
            if (error_detected_i[i]) begin
              count_bit_man[i]<=count_bit_man[i]+1;
            end
            else begin
              if (count_bit_man[i]>2) begin
                count_bit_man[i]<=count_bit_man[i]-2;
              end
              else begin
                count_bit_man[i]<=8'b0;
              end
            end 
          end else begin
            count_bit_man[i]<=8'b0;
          end


          // Bit counting
          ALU_FF1, ALU_FL1, ALU_CNT, ALU_CLB:
          if (~permanent_faulty[i][3]) begin  
            if (error_detected_i[i]) begin
              count_bit_count[i]<=count_bit_count[i]+1;
            end
            else begin
              if (count_bit_count[i]>2) begin
                count_bit_count[i]<=count_bit_count[i]-2;
              end
              else begin
                count_bit_count[i]<=8'b0;
              end
            end 
          end else begin
            count_bit_count[i]<=8'b0;
          end


          // Shuffle
          ALU_EXTS, ALU_EXT, ALU_SHUF, ALU_SHUF2, ALU_PCKLO, ALU_PCKHI, ALU_INS:  
          if (~permanent_faulty[i][4]) begin
            if (error_detected_i[i]) begin
              count_shuf[i]<=count_shuf[i]+1;
            end
            else begin
              if (count_shuf[i]>2) begin
                count_shuf[i]<=count_shuf[i]-2;
              end
              else begin
                count_shuf[i]<=8'b0;
              end
            end
          end else begin
            count_shuf[i]<=8'b0;
          end


          // Comparisons
          ALU_LTS, ALU_LTU, ALU_LES, ALU_LEU, ALU_GTS, ALU_GTU, ALU_GES, ALU_GEU, ALU_EQ, ALU_NE, ALU_SLTS, ALU_SLTU, ALU_SLETS, ALU_SLETU:  
          if (~permanent_faulty[i][5]) begin
            if (error_detected_i[i]) begin
              count_comparison[i]<=count_comparison[i]+1;
            end
            else begin
              if (count_comparison[i]>2) begin
                count_comparison[i]<=count_comparison[i]-2;
              end
              else begin
                count_comparison[i]<=8'b0;
              end
            end
          end else begin
            count_comparison[i]<=8'b0;
          end

          // Absolute value
          ALU_ABS, ALU_CLIP, ALU_CLIPU: 
          if (~permanent_faulty[i][6]) begin 
            if (error_detected_i[i]) begin
              count_abs[i]<=count_abs[i]+1;
            end
            else begin
              if (count_abs[i]>2) begin
                count_abs[i]<=count_abs[i]-2;
              end
              else begin
                count_abs[i]<=8'b0;
              end
            end
          end else begin
            count_abs[i]<=8'b0;
          end


          // min/max
          ALU_MIN, ALU_MINU, ALU_MAX, ALU_MAXU:  
          if (~permanent_faulty[i][7]) begin
            if (error_detected_i[i]) begin
              count_min_max[i]<=count_min_max[i]+1;
            end
            else begin
              if (count_min_max[i]>2) begin
                count_min_max[i]<=count_min_max[i]-2;
              end
              else begin
                count_min_max[i]<=8'b0;
              end
            end
          end else begin
            count_min_max[i]<=8'b0;
          end

          // div/rem
          ALU_DIVU, ALU_DIV, ALU_REMU, ALU_REM:  
          if (~permanent_faulty[i][8]) begin
            if (error_detected_i[i]) begin
              count_div_rem[i]<=count_div_rem[i]+1;
            end
            else begin
              if (count_div_rem[i]>2) begin
                count_div_rem[i]<=count_div_rem[i]-2;
              end
              else begin
                count_div_rem[i]<=8'b0;
              end
            end
          end else begin
            count_div_rem[i]<=8'b0;
          end


          default:          
            count_logic[i]       <= 8'b0;
            count_shift[i]       <= 8'b0;
            count_bit_man[i]     <= 8'b0;
            count_bit_count[i]   <= 8'b0;
            count_comparison[i]  <= 8'b0;
            count_abs[i]         <= 8'b0;
            count_min_max[i]     <= 8'b0;
            count_div_rem[i]     <= 8'b0;
            count_shuf[i]        <= 8'b0;

        endcase; // case (alu_operator)
      end
    end
  end



  always_ff @(posedge clk) begin : permanent_error_threshold
    if (~rst_n) begin
      permanent_faulty[i]     <= 9'b0;
    end 
    else begin
      case (alu_operator_i[i])

        // shift
         // Logic
        ALU_ADD, ALU_SUB, ALU_ADDU, ALU_SUBU, ALU_ADDR, ALU_SUBR, ALU_ADDUR, ALU_SUBUR, ALU_SRA, ALU_SRL, ALU_ROR, ALU_SLL:
        if (permanent_faulty[0][0] != 1'b1) begin
          if (count_shift[i]>100) begin
             permanent_faulty[0][0] <= 1'b1;
          end
        end

        ALU_XOR, ALU_OR, ALU_AND:
        if (permanent_faulty[0][1] != 1'b1) begin
          if (count_logic[i]>100) begin
             permanent_faulty[0][1] <= 1'b1;
          end
        end
          
        // Bit manipulation
        ALU_BEXT, ALU_BEXTU, ALU_BINS, ALU_BCLR, ALU_BSET, ALU_BREV: 
        if (permanent_faulty[0][2] != 1'b1) begin
          if (count_bit_man[i]>100) begin
             permanent_faulty[0][2] <= 1'b1;
          end
        end

        // Bit counting
        ALU_FF1, ALU_FL1, ALU_CNT, ALU_CLB:
        if (permanent_faulty[0][3] != 1'b1) begin
          if (count_bit_count[i]>100) begin
             permanent_faulty[0][3] <= 1'b1;
          end
        end

        // Shuffle
        ALU_EXTS, ALU_EXT, ALU_SHUF, ALU_SHUF2, ALU_PCKLO, ALU_PCKHI, ALU_INS:
        if (permanent_faulty[0][4] != 1'b1) begin
          if (count_shuf[i]>100) begin
             permanent_faulty[0][4] <= 1'b1;
          end
        end


        // Comparisons
        ALU_LTS, ALU_LTU, ALU_LES, ALU_LEU, ALU_GTS, ALU_GTU, ALU_GES, ALU_GEU, ALU_EQ, ALU_NE, ALU_SLTS, ALU_SLTU, ALU_SLETS, ALU_SLETU:
        if (permanent_faulty[0][5] != 1'b1) begin
          if (count_comparison[i]>100) begin
             permanent_faulty[0][5] <= 1'b1;
          end
        end

        // Absolute value
        ALU_ABS, ALU_CLIP, ALU_CLIPU:
        if (permanent_faulty[0][6] != 1'b1) begin
          if (count_abs[i]>100) begin
             permanent_faulty[0][6] <= 1'b1;
          end
        end

        // min/max
        ALU_MIN, ALU_MINU, ALU_MAX, ALU_MAXU:
        if (permanent_faulty[0][7] != 1'b1) begin
          if (count_min_max[i]>100) begin
             permanent_faulty[0][7] <= 1'b1;
          end
        end

        // div/rem
        ALU_DIVU, ALU_DIV, ALU_REMU, ALU_REM: 
        if (permanent_faulty[0][8] != 1'b1) begin
          if (count_div_rem[i]>100) begin
             permanent_faulty[0][8] <= 1'b1;
          end
        end
      endcase
    end
  end


  assign permanent_faulty_alu_o[0][8:0] = permanent_faulty[0][8:0];
  assign permanent_faulty_alu_o[1][8:0] = permanent_faulty[1][8:0];
  assign permanent_faulty_alu_o[2][8:0] = permanent_faulty[2][8:0];
  assign permanent_faulty_alu_o[3][8:0] = permanent_faulty[3][8:0];


  // These signals trigger the performance counters related to the 4 alu. Each of this signals is anabled if the respective ALU encounter a serious (permanent) error in one of the 9 sub-units it has been divided in.
  // Because this output signals are combinatorially obtained from the output of the registers of the internal counters, the performance caunter will be incremented one clock cycle after the internal counter increment. 
  // To CS-Registers
  assign perf_counter_permanent_faulty_alu_o[0] = | permanent_faulty_alu_o[0];
  assign perf_counter_permanent_faulty_alu_o[1] = | permanent_faulty_alu_o[0];
  assign perf_counter_permanent_faulty_alu_o[2] = | permanent_faulty_alu_o[0];
  assign perf_counter_permanent_faulty_alu_o[3] = | permanent_faulty_alu_o[0];


endgenerate

endmodule