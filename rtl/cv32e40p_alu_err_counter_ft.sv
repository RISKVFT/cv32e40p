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
  input  logic [3:0][ALU_OP_WIDTH-1:0]      alu_operator_i,
  input  logic [3:0]      error_detected_i,
  input  logic            ready_o_div_count, 
  output logic [3:0][8:0] permanent_faulty_alu_o,             // one for each counter: 4 ALU and 9 subpart of ALU
  output logic [3:0][8:0] permanent_faulty_alu_s,             // one for each counter: 4 ALU and 9 subpart of ALU
  output logic [3:0]      perf_counter_permanent_faulty_alu_o, // decided to use only four performance counters, one for each ALU and increment them only if there is a permanent error (in any of the subset of istructions) into the corresponding ALU.

  // CSR: Performance counters
  input  logic [11:0]         mhpm_addr_ft_i,     // the address of the perf counter to be written
  input  logic                mhpm_re_ft_i,      // read enable 
  output logic [31:0]         mhpm_rdata_ft_o,   // the value of the performance counter we want to read
  input  logic                mhpm_we_ft_i,      // write enable 
  input  logic [31:0]         mhpm_wdata_ft_i    // the we want to write into the perf counter

);

logic [3:0][31:0] count_logic_q;
logic [3:0][31:0] count_shift_q;
logic [3:0][31:0] count_bit_man_q;
logic [3:0][31:0] count_bit_count_q;
logic [3:0][31:0] count_comparison_q;
logic [3:0][31:0] count_abs_q;
logic [3:0][31:0] count_min_max_q;
logic [3:0][31:0] count_div_rem_q;
logic [3:0][31:0] count_shuf_q;

logic [3:0][31:0] count_logic_n;
logic [3:0][31:0] count_shift_n;
logic [3:0][31:0] count_bit_man_n;
logic [3:0][31:0] count_bit_count_n;
logic [3:0][31:0] count_comparison_n;
logic [3:0][31:0] count_abs_n;
logic [3:0][31:0] count_min_max_n;
logic [3:0][31:0] count_div_rem_n;
logic [3:0][31:0] count_shuf_n;

logic [31:0]     threshold;

//logic [3:0][8:0] permanent_faulty_alu_s; // one for each counter: 4 ALU and 9 subpart of ALU

logic [3:0]    clock_gated;
logic [1:0]		 error_increase;
logic [1:0]		 error_decrease;

// CLOCK GATING for the counter that have already reached the end.
cv32e40p_clock_gate CG_counter[3:0]
(
 .clk_i        ( clk            ),
 .en_i         ( clock_en[3:0]  ),
 .scan_cg_en_i ( 1'b0           ), // not used
 .clk_o        ( clock_gated[3:0] )
);



// Special purpose registers to store the threshold value and the increase and decrease amounts for the counters 
// They are customizable by editing "ERROR_THRESHOLD", "ERROR_INCREASE" and "ERROR_DECREASE" in cv32e40p_pkg.sv
always_ff @(posedge clk or negedge rst_n) begin : proc_threshold
	if(~rst_n) begin
		threshold 		  <= 32'd0;
		error_increase 	<= 2'b0;
		error_decrease 	<= 2'b0;
	end else begin
		threshold 		  <= ERROR_THRESHOLD;
		error_increase 	<= ERROR_INCREASE;
		error_decrease 	<= ERROR_DECREASE;
	end
end



genvar i;
generate
  for (i=0; i < 4; i++) begin
    always_ff @(posedge clock_gated[i] or negedge rst_n) begin
      if (~rst_n) begin
        count_logic_q       <= 8'b0;
        count_shift_q       <= 8'b0;
        count_bit_man_q     <= 8'b0;
        count_bit_count_q   <= 8'b0;
        count_comparison_q  <= 8'b0;
        count_abs_q         <= 8'b0;
        count_min_max_q     <= 8'b0;
        count_div_rem_q     <= 8'b0;
        count_shuf_q        <= 8'b0;
      end 
      else if (alu_enable_i[i]) begin
        case (alu_operator_i[i])

          // shift
          ALU_ADD, ALU_SUB, ALU_ADDU, ALU_SUBU, ALU_ADDR, ALU_SUBR, ALU_ADDUR, ALU_SUBUR, ALU_SRA, ALU_SRL, ALU_ROR, ALU_SLL:  
          if (~permanent_faulty_alu_s[i][0] & ~permanent_faulty_alu_o[i][0]) begin // PROBABILMENTE QUESTO CONTROLLO È SUPERFLUO PERCHÈ NON DOVREBBE ESSERE SELEZIONATA QUESTA ALU SE NON È IN GRADO DI FARE L'OPERAZIONE. 
            if (error_detected_i[i]) begin      // TUTTAVIA SE C'È LO STESSO ERRORE PERMANENTE IN DUE ALU ALLORA NE VERRÀ SCELTA UNA TRA LE DUE CHE NON SAPRÀ FARE L'OPERAZIONE 
              count_shift_q[i]<=count_shift_q[i]+error_increase;
            end
            else begin
              if (count_shift_q[i]>2) begin
                count_shift_q[i]<=count_shift_q[i]-error_decrease;
              end
              else begin
                count_shift_q[i]<=8'b0;
              end
            end
          end else begin
            count_shift_q[i]<=8'b0;

          end


          // Logic
          ALU_XOR, ALU_OR, ALU_AND:  
          if (~permanent_faulty_alu_s[i][1] & ~permanent_faulty_alu_o[i][1]) begin
            if (error_detected_i[i]) begin
              count_logic_q[i]<=count_logic_q[i]+error_increase;
            end
            else begin
              if (count_logic_q[i]>2) begin
                count_logic_q[i]<=count_logic_q[i]-error_decrease;
              end
              else begin
                count_logic_q[i]<=8'b0;
              end
            end
          end else begin
            count_logic_q[i]<=8'b0;
          end
     


          // Bit manipulation
          ALU_BEXT, ALU_BEXTU, ALU_BINS, ALU_BCLR, ALU_BSET, ALU_BREV:  
          if (~permanent_faulty_alu_s[i][2] & ~permanent_faulty_alu_o[i][2]) begin
            if (error_detected_i[i]) begin
              count_bit_man_q[i]<=count_bit_man_q[i]+error_increase;
            end
            else begin
              if (count_bit_man_q[i]>2) begin
                count_bit_man_q[i]<=count_bit_man_q[i]-error_decrease;
              end
              else begin
                count_bit_man_q[i]<=8'b0;
              end
            end 
          end else begin
            count_bit_man_q[i]<=8'b0;
          end


          // Bit counting
          ALU_FF1, ALU_FL1, ALU_CNT, ALU_CLB:
          if (~permanent_faulty_alu_s[i][3] & ~permanent_faulty_alu_o[i][3]) begin  
            if (error_detected_i[i]) begin
              count_bit_count_q[i]<=count_bit_count_q[i]+error_increase;
            end
            else begin
              if (count_bit_count_q[i]>2) begin
                count_bit_count_q[i]<=count_bit_count_q[i]-error_decrease;
              end
              else begin
                count_bit_count_q[i]<=8'b0;
              end
            end 
          end else begin
            count_bit_count_q[i]<=8'b0;
          end


          // Shuffle
          ALU_EXTS, ALU_EXT, ALU_SHUF, ALU_SHUF2, ALU_PCKLO, ALU_PCKHI, ALU_INS:  
          if (~permanent_faulty_alu_s[i][4] & ~permanent_faulty_alu_o[i][4]) begin
            if (error_detected_i[i]) begin
              count_shuf_q[i]<=count_shuf_q[i]+error_increase;
            end
            else begin
              if (count_shuf_q[i]>2) begin
                count_shuf_q[i]<=count_shuf_q[i]-error_decrease;
              end
              else begin
                count_shuf_q[i]<=8'b0;
              end
            end
          end else begin
            count_shuf_q[i]<=8'b0;
          end


          // Comparisons
          ALU_LTS, ALU_LTU, ALU_LES, ALU_LEU, ALU_GTS, ALU_GTU, ALU_GES, ALU_GEU, ALU_EQ, ALU_NE, ALU_SLTS, ALU_SLTU, ALU_SLETS, ALU_SLETU:  
          if (~permanent_faulty_alu_s[i][5] & ~permanent_faulty_alu_o[i][5]) begin
            if (error_detected_i[i]) begin
              count_comparison_q[i]<=count_comparison_q[i]+error_increase;
            end
            else begin
              if (count_comparison_q[i]>2) begin
                count_comparison_q[i]<=count_comparison_q[i]-error_decrease;
              end
              else begin
                count_comparison_q[i]<=8'b0;
              end
            end
          end else begin
            count_comparison_q[i]<=8'b0;
          end

          // Absolute value
          ALU_ABS, ALU_CLIP, ALU_CLIPU: 
          if (~permanent_faulty_alu_s[i][6] & ~permanent_faulty_alu_o[i][6]) begin 
            if (error_detected_i[i]) begin
              count_abs_q[i]<=count_abs_q[i]+error_increase;
            end
            else begin
              if (count_abs_q[i]>2) begin
                count_abs_q[i]<=count_abs_q[i]-error_decrease;
              end
              else begin
                count_abs_q[i]<=8'b0;
              end
            end
          end else begin
            count_abs_q[i]<=8'b0;
          end


          // min/max
          ALU_MIN, ALU_MINU, ALU_MAX, ALU_MAXU:  
          if (~permanent_faulty_alu_s[i][7] & ~permanent_faulty_alu_o[i][7]) begin
            if (error_detected_i[i]) begin
              count_min_max_q[i]<=count_min_max_q[i]+error_increase;
            end
            else begin
              if (count_min_max_q[i]>2) begin
                count_min_max_q[i]<=count_min_max_q[i]-error_decrease;
              end
              else begin
                count_min_max_q[i]<=8'b0;
              end
            end
          end else begin
            count_min_max_q[i]<=8'b0;
          end

          // div/rem
          ALU_DIVU, ALU_DIV, ALU_REMU, ALU_REM:  
          if (~permanent_faulty_alu_s[i][8] & ~permanent_faulty_alu_o[i][8]) begin
          	if (ready_o_div_count) begin // the counter can increment or decrement only if the divider has finished the computation that may require more than one cycle
	            if (error_detected_i[i]) begin
	              count_div_rem_q[i]<=count_div_rem_q[i]+error_increase;
	            end
	            else begin
	              if (count_div_rem_q[i]>2) begin
	                count_div_rem_q[i]<=count_div_rem_q[i]-error_decrease;
	              end
	              else begin
	                count_div_rem_q[i]<=8'b0;
	              end
	            end
	        end
          end else begin
            count_div_rem_q[i]<=8'b0;
          end


          default: begin          
            count_logic[i]         <= 8'b0;
            count_shift_q[i]       <= 8'b0;
            count_bit_man_q[i]     <= 8'b0;
            count_bit_count_q[i]   <= 8'b0;
            count_comparison_q[i]  <= 8'b0;
            count_abs_q[i]         <= 8'b0;
            count_min_max_q[i]     <= 8'b0;
            count_div_rem_q[i]     <= 8'b0;
            count_shuf_q[i]        <= 8'b0;
	        end
        endcase; // case (alu_operator)
      end
    end
  


  always_comb begin : permanent_error_threshold
    if (~rst_n) begin
      permanent_faulty_alu_s[i]     = 9'b0;
    end
    else begin
      case (alu_operator_i[i])

        // shift
        ALU_ADD, ALU_SUB, ALU_ADDU, ALU_SUBU, ALU_ADDR, ALU_SUBR, ALU_ADDUR, ALU_SUBUR, ALU_SRA, ALU_SRL, ALU_ROR, ALU_SLL:
        if (~permanent_faulty_alu_o[i][0]) begin
          if (count_shift_q[i]==threshold) begin
             permanent_faulty_alu_s[i][0] = 1'b1;
          end else begin
             permanent_faulty_alu_s[i] = 9'b0;
		  end
		end 
        //end else 
        //	 permanent_faulty_alu_s[i] = 9'b0;

        // Logic
        ALU_XOR, ALU_OR, ALU_AND:
        if (~permanent_faulty_alu_o[i][1]) begin
          if (count_logic_q[i]==threshold) begin
             permanent_faulty_alu_s[i][1] = 1'b1;
          end else begin
             permanent_faulty_alu_s[i] = 9'b0;
          end
        end
          
        // Bit manipulation
        ALU_BEXT, ALU_BEXTU, ALU_BINS, ALU_BCLR, ALU_BSET, ALU_BREV: 
        if (~permanent_faulty_alu_o[i][2]) begin
          if (count_bit_man_q[i]==threshold) begin
             permanent_faulty_alu_s[i][2] = 1'b1;
          end else begin
             permanent_faulty_alu_s[i] = 9'b0;
          end
        end

        // Bit counting
        ALU_FF1, ALU_FL1, ALU_CNT, ALU_CLB:
        if (~permanent_faulty_alu_o[i][3]) begin
          if (count_bit_count_q[i]==threshold) begin
             permanent_faulty_alu_s[i][3] = 1'b1;
          end else begin
             permanent_faulty_alu_s[i] = 9'b0;
          end
        end

        // Shuffle
        ALU_EXTS, ALU_EXT, ALU_SHUF, ALU_SHUF2, ALU_PCKLO, ALU_PCKHI, ALU_INS:
        if (~permanent_faulty_alu_o[i][4]) begin
          if (count_shuf_q[i]==threshold) begin
             permanent_faulty_alu_s[i][4] = 1'b1;
          end else begin
             permanent_faulty_alu_s[i] = 9'b0;
          end
        end


        // Comparisons
        ALU_LTS, ALU_LTU, ALU_LES, ALU_LEU, ALU_GTS, ALU_GTU, ALU_GES, ALU_GEU, ALU_EQ, ALU_NE, ALU_SLTS, ALU_SLTU, ALU_SLETS, ALU_SLETU:
        if (~permanent_faulty_alu_o[i][5]) begin
          if (count_comparison_q[i]==threshold) begin
             permanent_faulty_alu_s[i][5] = 1'b1;
          end else begin
             permanent_faulty_alu_s[i] = 9'b0;
          end
        end

        // Absolute value
        ALU_ABS, ALU_CLIP, ALU_CLIPU:
        if (~permanent_faulty_alu_o[i][6]) begin
          if (count_abs_q[i]==threshold) begin
             permanent_faulty_alu_s[i][6] = 1'b1;
          end else begin
             permanent_faulty_alu_s[i] = 9'b0;
          end
        end

        // min/max
        ALU_MIN, ALU_MINU, ALU_MAX, ALU_MAXU:
        if (~permanent_faulty_alu_o[i][7]) begin
          if (count_min_max_q[i]==threshold) begin
             permanent_faulty_alu_s[i][7] = 1'b1;
          end else begin
             permanent_faulty_alu_s[i] = 9'b0;
          end
        end

        // div/rem
        ALU_DIVU, ALU_DIV, ALU_REMU, ALU_REM: 
        if (~permanent_faulty_alu_o[i][8]) begin
          if (count_div_rem_q[i]==threshold) begin
             permanent_faulty_alu_s[i][8] = 1'b1;
          end else begin
             permanent_faulty_alu_s[i] = 9'b0;
          end
        end

        default: 
          permanent_faulty_alu_s[i] = 9'b0;

      endcase
    end 
  end

  always_ff @(posedge clock_gated[i] or negedge rst_n) begin : pipe_counter
    if (~rst_n) begin
      permanent_faulty_alu_o[i]     <= 9'b0;
    end 
    else begin
      case (alu_operator_i[i])

        // shift
        ALU_ADD, ALU_SUB, ALU_ADDU, ALU_SUBU, ALU_ADDR, ALU_SUBR, ALU_ADDUR, ALU_SUBUR, ALU_SRA, ALU_SRL, ALU_ROR, ALU_SLL:
        if (~permanent_faulty_alu_o[i][0])
          permanent_faulty_alu_o[i][0] <= permanent_faulty_alu_s[i][0];

         // Logic
        ALU_XOR, ALU_OR, ALU_AND:
        if (~permanent_faulty_alu_o[i][1])
          permanent_faulty_alu_o[i][1] <= permanent_faulty_alu_s[i][1];
          
        // Bit manipulation
        ALU_BEXT, ALU_BEXTU, ALU_BINS, ALU_BCLR, ALU_BSET, ALU_BREV: 
        if (~permanent_faulty_alu_o[i][2])
          permanent_faulty_alu_o[i][2] <= permanent_faulty_alu_s[i][2];

        // Bit counting
        ALU_FF1, ALU_FL1, ALU_CNT, ALU_CLB:
        if (~permanent_faulty_alu_o[i][3])
          permanent_faulty_alu_o[i][3] <= permanent_faulty_alu_s[i][3];

        // Shuffle
        ALU_EXTS, ALU_EXT, ALU_SHUF, ALU_SHUF2, ALU_PCKLO, ALU_PCKHI, ALU_INS:
        if (~permanent_faulty_alu_o[i][4])
          permanent_faulty_alu_o[i][4] <= permanent_faulty_alu_s[i][4];

        // Comparisons
        ALU_LTS, ALU_LTU, ALU_LES, ALU_LEU, ALU_GTS, ALU_GTU, ALU_GES, ALU_GEU, ALU_EQ, ALU_NE, ALU_SLTS, ALU_SLTU, ALU_SLETS, ALU_SLETU:
        if (~permanent_faulty_alu_o[i][5])
          permanent_faulty_alu_o[i][5] <= permanent_faulty_alu_s[i][5];

        // Absolute value
        ALU_ABS, ALU_CLIP, ALU_CLIPU:
        if (~permanent_faulty_alu_o[i][6])
          permanent_faulty_alu_o[i][6] <= permanent_faulty_alu_s[i][6];

        // min/max
        ALU_MIN, ALU_MINU, ALU_MAX, ALU_MAXU:
        if (~permanent_faulty_alu_o[i][7])
          permanent_faulty_alu_o[i][7] <= permanent_faulty_alu_s[i][7];

        // div/rem
        ALU_DIVU, ALU_DIV, ALU_REMU, ALU_REM: 
        if (~permanent_faulty_alu_o[i][8])
          permanent_faulty_alu_o[i][8] <= permanent_faulty_alu_s[i][8];
      endcase
    end
  end

end // for
endgenerate


  /*
  assign permanent_faulty_alu_o[0] = permanent_faulty[0];
  assign permanent_faulty_alu_o[1] = permanent_faulty[1];
  assign permanent_faulty_alu_o[2] = permanent_faulty[2];
  assign permanent_faulty_alu_o[3] = permanent_faulty[3];
  */


  // These signals trigger the performance counters related to the 4 alu. Each of this signals is anabled if the respective ALU encounter a serious (permanent) error in one of the 9 sub-units it has been divided in.
  // Because this output signals are combinatorially obtained from the output of the registers of the internal counters, the performance caunter will be incremented one clock cycle after the internal counter increment. 
  // To CS-Registers
  assign perf_counter_permanent_faulty_alu_o[0] = | permanent_faulty_alu_s[0];
  assign perf_counter_permanent_faulty_alu_o[1] = | permanent_faulty_alu_s[1];
  assign perf_counter_permanent_faulty_alu_o[2] = | permanent_faulty_alu_s[2];
  assign perf_counter_permanent_faulty_alu_o[3] = | permanent_faulty_alu_s[3];


  // PERFORMANCE COUNTERS: READING-WRITING LOGIC 
  always_comb  begin
    case (mhpm_addr_ft_i)

      CSR_MHPMCOUNTER0_FT, CSR_MHPMCOUNTER1_FT,  CSR_MHPMCOUNTE2_FT, CSR_MHPMCOUNTER3_FT: begin
        if (mhpm_re_ft_i) 
          mhpm_rdata_ft_o = count_logic_q[mhpm_addr_ft_i[7:0]-8];
        else if (mhpm_we_ft_i) 
          count_logic_n[mhpm_addr_ft_i[7:0]-8] = mhpm_wdata_ft_i;
      end
      CSR_MHPMCOUNTER4_FT,  CSR_MHPMCOUNTER5_FT,  CSR_MHPMCOUNTER6_FT,  CSR_MHPMCOUNTER7_FT: begin
        if (mhpm_re_ft_i) 
          mhpm_rdata_ft_o = count_shift_q[mhpm_addr_ft_i[7:0]-12];
        else if (mhpm_we_ft_i) 
          count_shift_n[mhpm_addr_ft_i[7:0]-12] = mhpm_wdata_ft_i;
      end
      CSR_MHPMCOUNTER8_FT,  CSR_MHPMCOUNTER9_FT,  CSR_MHPMCOUNTER10_FT, CSR_MHPMCOUNTER11_FT: begin
        if (mhpm_re_ft_i) 
          mhpm_rdata_ft_o = count_bit_man_q[mhpm_addr_ft_i[7:0]-16];
        else if (mhpm_we_ft_i) 
          count_bit_man_n[mhpm_addr_ft_i[7:0]-16] = mhpm_wdata_ft_i;
      end
      CSR_MHPMCOUNTER12_FT, CSR_MHPMCOUNTER13_FT, CSR_MHPMCOUNTER14_FT, CSR_MHPMCOUNTER15_FT: begin
        if (mhpm_re_ft_i) 
          mhpm_rdata_ft_o = count_bit_count_q[mhpm_addr_ft_i[7:0]-20];
        else if (mhpm_we_ft_i) 
          count_bit_count_n[mhpm_addr_ft_i[7:0]-20] = mhpm_wdata_ft_i;
      end
      CSR_MHPMCOUNTER16_FT, CSR_MHPMCOUNTER17_FT, CSR_MHPMCOUNTER18_FT, CSR_MHPMCOUNTER19_FT: begin
        if (mhpm_re_ft_i) 
          mhpm_rdata_ft_o = count_comparison_q[mhpm_addr_ft_i[7:0]-24];
        else if (mhpm_we_ft_i) 
          count_comparison_n[mhpm_addr_ft_i[7:0]-24] = mhpm_wdata_ft_i;
      end
      CSR_MHPMCOUNTER20_FT, CSR_MHPMCOUNTER21_FT, CSR_MHPMCOUNTER22_FT, CSR_MHPMCOUNTER23_FT: begin
        if (mhpm_re_ft_i) 
          mhpm_rdata_ft_o = count_abs_q[mhpm_addr_ft_i[7:0]-28];
        else if (mhpm_we_ft_i) 
          count_abs_n[mhpm_addr_ft_i[7:0]-28] = mhpm_wdata_ft_i;
      end
      CSR_MHPMCOUNTER24_FT, CSR_MHPMCOUNTER25_FT, CSR_MHPMCOUNTER26_FT, CSR_MHPMCOUNTER27_FT: begin
        if (mhpm_re_ft_i) 
          mhpm_rdata_ft_o = count_min_max_q[mhpm_addr_ft_i[7:0]32];
        else if (mhpm_we_ft_i) 
          count_min_max_n[mhpm_addr_ft_i[7:0]-32] = mhpm_wdata_ft_i;
      end     
      CSR_MHPMCOUNTER28_FT, CSR_MHPMCOUNTER29_FT, CSR_MHPMCOUNTER30_FT, CSR_MHPMCOUNTER31_FT: begin
        if (mhpm_re_ft_i) 
          mhpm_rdata_ft_o = count_div_rem_q[mhpm_addr_ft_i[7:0]-36];
        else if (mhpm_we_ft_i) 
          count_div_rem_n[mhpm_addr_ft_i[7:0]-36] = mhpm_wdata_ft_i;
      end
      CSR_MHPMCOUNTER32_FT, CSR_MHPMCOUNTER33_FT, CSR_MHPMCOUNTER34_FT, CSR_MHPMCOUNTER35_FT: begin
        if (mhpm_re_ft_i) 
          mhpm_rdata_ft_o = count_shuf_q[mhpm_addr_ft_i[7:0]-40];
        else if (mhpm_we_ft_i) 
          count_shuf_n[mhpm_addr_ft_i[7:0]-40] = mhpm_wdata_ft_i;
      end

      default: begin
        count_logic_n       = count_logic_q;
        count_shift_n       = count_shift_n;
        count_bit_man_n     = count_bit_man_n;
        count_bit_count_n   = count_bit_count_n;
        count_comparison_n  = count_comparison_n;
        count_abs_n         = count_abs_n;
        count_min_max_n     = count_min_max_n;
        count_div_rem_n     = count_div_rem_n;
        count_shuf_n        = count_shuf_n;

        mhpm_rdata_ft_o     = 'b0;
      end

    endcase
  end

endmodule
