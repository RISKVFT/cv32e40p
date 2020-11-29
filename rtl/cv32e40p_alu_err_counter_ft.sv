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
  input  logic                clk,
  input  logic [3:0]          clock_en,
  input  logic                rst_n,
  input  logic [3:0]          alu_enable_i,
  input  logic [3:0][ALU_OP_WIDTH-1:0]      alu_operator_i,
  input  logic [3:0]          error_detected_i,
  input  logic                ready_o_div_count, 
  output logic [3:0][8:0]     permanent_faulty_alu_o,             // one for each counter: 4 ALU and 9 subpart of ALU
  output logic [3:0][8:0]     permanent_faulty_alu_s,             // one for each counter: 4 ALU and 9 subpart of ALU
  //output logic [3:0]          perf_counter_permanent_faulty_alu_o, // decided to use only four performance counters, one for each ALU and increment them only if there is a permanent error (in any of the subset of istructions) into the corresponding ALU.

  // CSR: Performance counters
  input  logic [11:0]         mhpm_addr_ft_i,    // the address of the perf counter to be written
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

// input to the counter registers if we want to increment them because of fault events
logic [3:0][31:0] count_logic_n;
logic [3:0][31:0] count_shift_n;
logic [3:0][31:0] count_bit_man_n;
logic [3:0][31:0] count_bit_count_n;
logic [3:0][31:0] count_comparison_n;
logic [3:0][31:0] count_abs_n;
logic [3:0][31:0] count_min_max_n;
logic [3:0][31:0] count_div_rem_n;
logic [3:0][31:0] count_shuf_n;

// input to the counter registers if we want to write them by write instruction
logic [3:0][31:0] count_logic_nw;
logic [3:0][31:0] count_shift_nw;
logic [3:0][31:0] count_bit_man_nw;
logic [3:0][31:0] count_bit_count_nw;
logic [3:0][31:0] count_comparison_nw;
logic [3:0][31:0] count_abs_nw;
logic [3:0][31:0] count_min_max_nw;
logic [3:0][31:0] count_div_rem_nw;
logic [3:0][31:0] count_shuf_nw;

logic [37:0]      sel; // select one between <counter>_n and <counter>_nw and one between permanent_faulty_alu_s and permanent_faulty_alu_nw

// we need 36 bits to store the information on the permanent faulty ALUs so we use two 32b readonly CSR 
logic [31:0]      alu_faulty_map0;
logic [31:0]      alu_faulty_map1;

logic [31:0]      alu_faulty_map0_nw;
logic [31:0]      alu_faulty_map1_nw;

logic [3:0][8:0]     permanent_faulty_alu_nw;

// maximum value reachable by the counters
logic [31:0]      threshold;

//logic [3:0][8:0] permanent_faulty_alu_s; // one for each counter: 4 ALU and 9 subpart of ALU

logic [3:0]       clock_gated;
logic [1:0]		    error_increase;
logic [1:0]		    error_decrease;

logic [3:0]       signal;

assign signal = 4'b0011;

// CLOCK GATING for the counter that have already reached the end.
cv32e40p_clock_gate CG_counter[3:0]
(
 .clk_i        ( clk              ),
 .en_i         ( clock_en[3:0]    ),
 .scan_cg_en_i ( 1'b0             ), // not used
 .clk_o        ( clock_gated[3:0] )
);



// Special purpose registers to store the threshold value and the increase and decrease amounts for the counters 
// They are customizable by editing "ERROR_THRESHOLD", "ERROR_INCREASE" and "ERROR_DECREASE" in cv32e40p_pkg.sv
always_ff @(posedge rst_n or negedge rst_n) begin : proc_threshold
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
    
    // Next value saving
    always_ff @(posedge clock_gated[i] or negedge rst_n) begin : proc_update_counters
      if(~rst_n) begin
        count_logic_q[i]       <= 32'b0;
        count_shift_q[i]       <= 32'b0;
        count_bit_man_q[i]     <= 32'b0;
        count_bit_count_q[i]   <= 32'b0;
        count_comparison_q[i]  <= 32'b0;
        count_abs_q[i]         <= 32'b0;
        count_min_max_q[i]     <= 32'b0;
        count_div_rem_q[i]     <= 32'b0;
        count_shuf_q[i]        <= 32'b0;
      end else begin
        /*if (alu_enable_i[i]) begin*/
          count_logic_q[i]       <= sel[i]    ? count_logic_nw[i]      : count_logic_n[i];
          count_shift_q[i]       <= sel[i+4]  ? count_shift_nw[i]      : count_shift_n[i];
          count_bit_man_q[i]     <= sel[i+8]  ? count_bit_man_nw[i]    : count_bit_man_n[i];
          count_bit_count_q[i]   <= sel[i+12] ? count_bit_count_nw[i]  : count_bit_count_n[i];
          count_comparison_q[i]  <= sel[i+16] ? count_comparison_nw[i] : count_comparison_n[i];
          count_abs_q[i]         <= sel[i+20] ? count_abs_nw[i]        : count_abs_n[i];
          count_min_max_q[i]     <= sel[i+24] ? count_min_max_nw[i]    : count_min_max_n[i];
          count_div_rem_q[i]     <= sel[i+28] ? count_div_rem_nw[i]    : count_div_rem_n[i];
          count_shuf_q[i]        <= sel[i+32] ? count_shuf_nw[i]       : count_shuf_n[i];      
        /*end*/
      end
    end


    /*always_ff @(posedge clock_gated[i] or negedge rst_n) begin : proc_prova
      if(~rst_n) begin
        count_shift_q[i] <= 'b0;
      end else begin

        if (alu_enable_i[i]) begin // override default when appropriate
          case (alu_operator_i[i])

            ALU_ADD, ALU_SUB, ALU_ADDU, ALU_SUBU, ALU_ADDR, ALU_SUBR, ALU_ADDUR, ALU_SUBUR, ALU_SRA, ALU_SRL, ALU_ROR, ALU_SLL:  
              if (~permanent_faulty_alu_s[i][0] & ~permanent_faulty_alu_o[i][0]) begin // PROBABILMENTE QUESTO CONTROLLO È SUPERFLUO PERCHÈ NON DOVREBBE ESSERE SELEZIONATA QUESTA ALU SE NON È IN GRADO DI FARE L'OPERAZIONE. 
                if (error_detected_i[i]) begin      // TUTTAVIA SE C'È LO STESSO ERRORE PERMANENTE IN DUE ALU ALLORA NE VERRÀ SCELTA UNA TRA LE DUE CHE NON SAPRÀ FARE L'OPERAZIONE 
                  count_shift_q[i]=count_shift_q[i]+error_increase;
                end
                else begin
                  if (count_shift_q[i]>2) begin
                    count_shift_q[i]=count_shift_q[i]-error_decrease;
                  end
                  else begin
                    count_shift_q[i]=32'b0;
                  end
                end
              end else begin
                count_shift_q[i]=32'b0;
            end
          endcase
        end

      end
    end*/

    always_comb begin
      // default
      count_logic_n[i]       = count_logic_q[i];
      count_shift_n[i]       = count_shift_q[i];
      count_bit_man_n[i]     = count_bit_man_q[i];
      count_bit_count_n[i]   = count_bit_count_q[i];
      count_comparison_n[i]  = count_comparison_q[i];
      count_abs_n[i]         = count_abs_q[i];
      count_min_max_n[i]     = count_min_max_q[i];
      count_div_rem_n[i]     = count_div_rem_q[i];
      count_shuf_n[i]        = count_shuf_q[i];

      //if (alu_enable_i[i]) begin // override default when appropriate
        case (alu_operator_i[i])

          // shift
          ALU_ADD, ALU_SUB, ALU_ADDU, ALU_SUBU, ALU_ADDR, ALU_SUBR, ALU_ADDUR, ALU_SUBUR, ALU_SRA, ALU_SRL, ALU_ROR, ALU_SLL:  
          if (~permanent_faulty_alu_s[i][0] & ~permanent_faulty_alu_o[i][0]) begin // PROBABILMENTE QUESTO CONTROLLO È SUPERFLUO PERCHÈ NON DOVREBBE ESSERE SELEZIONATA QUESTA ALU SE NON È IN GRADO DI FARE L'OPERAZIONE. 
            if (error_detected_i[i]) begin      // TUTTAVIA SE C'È LO STESSO ERRORE PERMANENTE IN DUE ALU ALLORA NE VERRÀ SCELTA UNA TRA LE DUE CHE NON SAPRÀ FARE L'OPERAZIONE 
              count_shift_n[i]=count_shift_q[i]+error_increase;
            end
            else begin
              if (count_shift_q[i]>2) begin
                count_shift_n[i]=count_shift_q[i]-error_decrease;
              end
              else begin
                count_shift_n[i]=32'b0;
              end
            end
          end else begin
            count_shift_n[i]=32'b0;

          end


          // Logic
          ALU_XOR, ALU_OR, ALU_AND:  
          if (~permanent_faulty_alu_s[i][1] & ~permanent_faulty_alu_o[i][1]) begin
            if (error_detected_i[i]) begin
              count_logic_n[i]=count_logic_n[i]+error_increase;
            end
            else begin
              if (count_logic_n[i]>2) begin
                count_logic_n[i]=count_logic_n[i]-error_decrease;
              end
              else begin
                count_logic_n[i]=32'b0;
              end
            end
          end else begin
            count_logic_n[i]=32'b0;
          end
     


          // Bit manipulation
          ALU_BEXT, ALU_BEXTU, ALU_BINS, ALU_BCLR, ALU_BSET, ALU_BREV:  
          if (~permanent_faulty_alu_s[i][2] & ~permanent_faulty_alu_o[i][2]) begin
            if (error_detected_i[i]) begin
              count_bit_man_n[i]=count_bit_man_q[i]+error_increase;
            end
            else begin
              if (count_bit_man_q[i]>2) begin
                count_bit_man_n[i]=count_bit_man_q[i]-error_decrease;
              end
              else begin
                count_bit_man_n[i]=32'b0;
              end
            end 
          end else begin
            count_bit_man_n[i]=32'b0;
          end


          // Bit counting
          ALU_FF1, ALU_FL1, ALU_CNT, ALU_CLB:
          if (~permanent_faulty_alu_s[i][3] & ~permanent_faulty_alu_o[i][3]) begin  
            if (error_detected_i[i]) begin
              count_bit_count_n[i]=count_bit_count_q[i]+error_increase;
            end
            else begin
              if (count_bit_count_q[i]>2) begin
                count_bit_count_n[i]=count_bit_count_q[i]-error_decrease;
              end
              else begin
                count_bit_count_n[i]=32'b0;
              end
            end 
          end else begin
            count_bit_count_n[i]=32'b0;
          end


          // Shuffle
          ALU_EXTS, ALU_EXT, ALU_SHUF, ALU_SHUF2, ALU_PCKLO, ALU_PCKHI, ALU_INS:  
          if (~permanent_faulty_alu_s[i][4] & ~permanent_faulty_alu_o[i][4]) begin
            if (error_detected_i[i]) begin
              count_shuf_n[i]=count_shuf_q[i]+error_increase;
            end
            else begin
              if (count_shuf_q[i]>2) begin
                count_shuf_n[i]=count_shuf_q[i]-error_decrease;
              end
              else begin
                count_shuf_n[i]=32'b0;
              end
            end
          end else begin
            count_shuf_n[i]=32'b0;
          end


          // Comparisons
          ALU_LTS, ALU_LTU, ALU_LES, ALU_LEU, ALU_GTS, ALU_GTU, ALU_GES, ALU_GEU, ALU_EQ, ALU_NE, ALU_SLTS, ALU_SLTU, ALU_SLETS, ALU_SLETU:  
          if (~permanent_faulty_alu_s[i][5] & ~permanent_faulty_alu_o[i][5]) begin
            if (error_detected_i[i]) begin
              count_comparison_n[i]=count_comparison_q[i]+error_increase;
            end
            else begin
              if (count_comparison_q[i]>2) begin
                count_comparison_n[i]=count_comparison_q[i]-error_decrease;
              end
              else begin
                count_comparison_n[i]=32'b0;
              end
            end
          end else begin
            count_comparison_n[i]=32'b0;
          end

          // Absolute value
          ALU_ABS, ALU_CLIP, ALU_CLIPU: 
          if (~permanent_faulty_alu_s[i][6] & ~permanent_faulty_alu_o[i][6]) begin 
            if (error_detected_i[i]) begin
              count_abs_n[i]=count_abs_q[i]+error_increase;
            end
            else begin
              if (count_abs_q[i]>2) begin
                count_abs_n[i]=count_abs_q[i]-error_decrease;
              end
              else begin
                count_abs_n[i]=32'b0;
              end
            end
          end else begin
            count_abs_n[i]=32'b0;
          end


          // min/max
          ALU_MIN, ALU_MINU, ALU_MAX, ALU_MAXU:  
          if (~permanent_faulty_alu_s[i][7] & ~permanent_faulty_alu_o[i][7]) begin
            if (error_detected_i[i]) begin
              count_min_max_n[i]=count_min_max_q[i]+error_increase;
            end
            else begin
              if (count_min_max_q[i]>2) begin
                count_min_max_n[i]=count_min_max_q[i]-error_decrease;
              end
              else begin
                count_min_max_n[i]=32'b0;
              end
            end
          end else begin
            count_min_max_n[i]=32'b0;
          end

          // div/rem
          ALU_DIVU, ALU_DIV, ALU_REMU, ALU_REM:  
          if (~permanent_faulty_alu_s[i][8] & ~permanent_faulty_alu_o[i][8]) begin
          	if (ready_o_div_count) begin // the counter can increment or decrement only if the divider has finished the computation that may require more than one cycle
	            if (error_detected_i[i]) begin
	              count_div_rem_n[i]=count_div_rem_q[i]+error_increase;
	            end
	            else begin
	              if (count_div_rem_q[i]>2) begin
	                count_div_rem_n[i]=count_div_rem_q[i]-error_decrease;
	              end
	              else begin
	                count_div_rem_n[i]=32'b0;
	              end
	            end
	        end
          end else begin
            count_div_rem_n[i]=32'b0;
          end


          default: begin          
            count_logic_n[i]       = count_logic_q[i];
            count_shift_n[i]       = count_shift_q[i];
            count_bit_man_n[i]     = count_bit_man_q[i];
            count_bit_count_n[i]   = count_bit_count_q[i];
            count_comparison_n[i]  = count_comparison_q[i];
            count_abs_n[i]         = count_abs_q[i];
            count_min_max_n[i]     = count_min_max_q[i];
            count_div_rem_n[i]     = count_div_rem_q[i];
            count_shuf_n[i]        = count_shuf_q[i];
	        end
        endcase // case (alu_operator)
      /*end else begin
        count_logic_n[i]       = count_logic_q[i];
        count_shift_n[i]       = count_shift_q[i];
        count_bit_man_n[i]     = count_bit_man_q[i];
        count_bit_count_n[i]   = count_bit_count_q[i];
        count_comparison_n[i]  = count_comparison_q[i];
        count_abs_n[i]         = count_abs_q[i];
        count_min_max_n[i]     = count_min_max_q[i];
        count_div_rem_n[i]     = count_div_rem_q[i];
        count_shuf_n[i]        = count_shuf_q[i];
      end*/
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

        // shift
        if (~permanent_faulty_alu_o[i][0])
          permanent_faulty_alu_o[i][0] <= sel[36] ? permanent_faulty_alu_nw[i][0] : permanent_faulty_alu_s[i][0];
          //permanent_faulty_alu_o[i][0] <= signal[i];


         // Logic
        if (~permanent_faulty_alu_o[i][1])
          permanent_faulty_alu_o[i][1] <= sel[36] ? permanent_faulty_alu_nw[i][1] : permanent_faulty_alu_s[i][1];
          
        // Bit manipulation
        if (~permanent_faulty_alu_o[i][2])
          permanent_faulty_alu_o[i][2] <= sel[36] ? permanent_faulty_alu_nw[i][2] : permanent_faulty_alu_s[i][2];

        // Bit counting
        if (~permanent_faulty_alu_o[i][3])
          permanent_faulty_alu_o[i][3] <= sel[36] ? permanent_faulty_alu_nw[i][3] : permanent_faulty_alu_s[i][3];

        // Shuffle
        if (~permanent_faulty_alu_o[i][4])
          permanent_faulty_alu_o[i][4] <= sel[36] ? permanent_faulty_alu_nw[i][4] : permanent_faulty_alu_s[i][4];

        // Comparisons
        if (~permanent_faulty_alu_o[i][5])
          permanent_faulty_alu_o[i][5] <= sel[36] ? permanent_faulty_alu_nw[i][5] : permanent_faulty_alu_s[i][5];

        // Absolute value
        if (~permanent_faulty_alu_o[i][6])
          permanent_faulty_alu_o[i][6] <= sel[36] ? permanent_faulty_alu_nw[i][6] : permanent_faulty_alu_s[i][6];

        // min/max
        if (~permanent_faulty_alu_o[i][7])
          permanent_faulty_alu_o[i][7] <= sel[36] ? permanent_faulty_alu_nw[i][7] : permanent_faulty_alu_s[i][7];

        // div/rem
        if (~permanent_faulty_alu_o[i][8])
          permanent_faulty_alu_o[i][8] <= sel[37] ? permanent_faulty_alu_nw[i][8] : permanent_faulty_alu_s[i][8];
    end
  end

end // for
endgenerate

genvar y;
genvar z;
genvar k;
generate //reorganize permanent_faulty_alu_o in alu_faulty_map0 and alu_faulty_map1
    for (y=0; y<4; y++) begin
        for (z=0; z<8; z++) begin
            assign alu_faulty_map0[(4*z)+y] = permanent_faulty_alu_o[y][z];
            assign permanent_faulty_alu_nw[y][z] = alu_faulty_map0_nw[(4*z)+y];
        end
        assign alu_faulty_map1[y] = permanent_faulty_alu_o[y][8];
        assign permanent_faulty_alu_nw[y][8] = alu_faulty_map1_nw[y];
    end
    for (k=4; k<32; k++) begin
      assign alu_faulty_map1[k] = 1'b0;
    end
endgenerate




/*
assign permanent_faulty_alu_o[0] = permanent_faulty[0];
assign permanent_faulty_alu_o[1] = permanent_faulty[1];
assign permanent_faulty_alu_o[2] = permanent_faulty[2];
assign permanent_faulty_alu_o[3] = permanent_faulty[3];
*/


/*
// These signals trigger the performance counters related to the 4 alu. Each of this signals is anabled if the respective ALU encounter a serious (permanent) error in one of the 9 sub-units it has been divided in.
// Because this output signals are combinatorially obtained from the output of the registers of the internal counters, the performance caunter will be incremented one clock cycle after the internal counter increment. 
// To CS-Registers
assign perf_counter_permanent_faulty_alu_o[0] = | permanent_faulty_alu_s[0];
assign perf_counter_permanent_faulty_alu_o[1] = | permanent_faulty_alu_s[1];
assign perf_counter_permanent_faulty_alu_o[2] = | permanent_faulty_alu_s[2];
assign perf_counter_permanent_faulty_alu_o[3] = | permanent_faulty_alu_s[3];
*/


// PERFORMANCE COUNTERS: READING-WRITING LOGIC 
always_comb  begin
  // default
  count_logic_nw       = 'b0;
  count_shift_nw       = 'b0;
  count_bit_man_nw     = 'b0;
  count_bit_count_nw   = 'b0;
  count_comparison_nw  = 'b0;
  count_abs_nw         = 'b0;
  count_min_max_nw     = 'b0;
  count_div_rem_nw     = 'b0;
  count_shuf_nw        = 'b0;
  alu_faulty_map0_nw   = 'b0;
  alu_faulty_map1_nw   = 'b0;
  mhpm_rdata_ft_o      = 'b0;
  sel                  = 'b0;

  case (mhpm_addr_ft_i) // override default when appropriate

    CSR_MHPMCOUNTER0_FT, CSR_MHPMCOUNTER1_FT,  CSR_MHPMCOUNTER2_FT, CSR_MHPMCOUNTER3_FT: begin
      if (mhpm_re_ft_i) 
        mhpm_rdata_ft_o = count_logic_q[mhpm_addr_ft_i[7:0]-8];
      else if (mhpm_we_ft_i) begin
        count_logic_nw[mhpm_addr_ft_i[7:0]-8] = mhpm_wdata_ft_i;
        sel[mhpm_addr_ft_i[7:0]-8] = 1'b1;
      end
    end
    CSR_MHPMCOUNTER4_FT,  CSR_MHPMCOUNTER5_FT,  CSR_MHPMCOUNTER6_FT,  CSR_MHPMCOUNTER7_FT: begin
      if (mhpm_re_ft_i) 
        mhpm_rdata_ft_o = count_shift_q[mhpm_addr_ft_i[7:0]-12];
      else if (mhpm_we_ft_i) begin
        count_shift_nw[mhpm_addr_ft_i[7:0]-12] = mhpm_wdata_ft_i;
        sel[mhpm_addr_ft_i[7:0]-8] = 1'b1;
      end
    end
    CSR_MHPMCOUNTER8_FT,  CSR_MHPMCOUNTER9_FT,  CSR_MHPMCOUNTER10_FT, CSR_MHPMCOUNTER11_FT: begin
      if (mhpm_re_ft_i) 
        mhpm_rdata_ft_o = count_bit_man_q[mhpm_addr_ft_i[7:0]-16];
      else if (mhpm_we_ft_i) begin
        count_bit_man_nw[mhpm_addr_ft_i[7:0]-16] = mhpm_wdata_ft_i;
        sel[mhpm_addr_ft_i[7:0]-8] = 1'b1;
      end
    end
    CSR_MHPMCOUNTER12_FT, CSR_MHPMCOUNTER13_FT, CSR_MHPMCOUNTER14_FT, CSR_MHPMCOUNTER15_FT: begin
      if (mhpm_re_ft_i) 
        mhpm_rdata_ft_o = count_bit_count_q[mhpm_addr_ft_i[7:0]-20];
      else if (mhpm_we_ft_i) begin
        count_bit_count_nw[mhpm_addr_ft_i[7:0]-20] = mhpm_wdata_ft_i;
        sel[mhpm_addr_ft_i[7:0]-8] = 1'b1;
      end
    end
    CSR_MHPMCOUNTER16_FT, CSR_MHPMCOUNTER17_FT, CSR_MHPMCOUNTER18_FT, CSR_MHPMCOUNTER19_FT: begin
      if (mhpm_re_ft_i) 
        mhpm_rdata_ft_o = count_comparison_q[mhpm_addr_ft_i[7:0]-24];
      else if (mhpm_we_ft_i) begin
        count_comparison_nw[mhpm_addr_ft_i[7:0]-24] = mhpm_wdata_ft_i;
        sel[mhpm_addr_ft_i[7:0]-8] = 1'b1;
      end
    end
    CSR_MHPMCOUNTER20_FT, CSR_MHPMCOUNTER21_FT, CSR_MHPMCOUNTER22_FT, CSR_MHPMCOUNTER23_FT: begin
      if (mhpm_re_ft_i) 
        mhpm_rdata_ft_o = count_abs_q[mhpm_addr_ft_i[7:0]-28];
      else if (mhpm_we_ft_i) 
        count_abs_nw[mhpm_addr_ft_i[7:0]-28] = mhpm_wdata_ft_i;
        sel[mhpm_addr_ft_i[7:0]-8] = 1'b1;
    end
    CSR_MHPMCOUNTER24_FT, CSR_MHPMCOUNTER25_FT, CSR_MHPMCOUNTER26_FT, CSR_MHPMCOUNTER27_FT: begin
      if (mhpm_re_ft_i) 
        mhpm_rdata_ft_o = count_min_max_q[mhpm_addr_ft_i[7:0]-32];
      else if (mhpm_we_ft_i) begin
        count_min_max_nw[mhpm_addr_ft_i[7:0]-32] = mhpm_wdata_ft_i;
        sel[mhpm_addr_ft_i[7:0]-8] = 1'b1;
      end
    end     
    CSR_MHPMCOUNTER28_FT, CSR_MHPMCOUNTER29_FT, CSR_MHPMCOUNTER30_FT, CSR_MHPMCOUNTER31_FT: begin
      if (mhpm_re_ft_i) 
        mhpm_rdata_ft_o = count_div_rem_q[mhpm_addr_ft_i[7:0]-36];
      else if (mhpm_we_ft_i) begin
        count_div_rem_nw[mhpm_addr_ft_i[7:0]-36] = mhpm_wdata_ft_i;
        sel[mhpm_addr_ft_i[7:0]-8] = 1'b1;
      end
    end
    CSR_MHPMCOUNTER32_FT, CSR_MHPMCOUNTER33_FT, CSR_MHPMCOUNTER34_FT, CSR_MHPMCOUNTER35_FT: begin
      if (mhpm_re_ft_i) 
        mhpm_rdata_ft_o = count_shuf_q[mhpm_addr_ft_i[7:0]-40];
      else if (mhpm_we_ft_i) begin
        count_shuf_nw[mhpm_addr_ft_i[7:0]-40] = mhpm_wdata_ft_i;
        sel[mhpm_addr_ft_i[7:0]-8] = 1'b1;
      end
    end

    CSR_PERM_FAULTY_ALUL_FT:
      if (mhpm_re_ft_i) 
        mhpm_rdata_ft_o = alu_faulty_map0;
      else if (mhpm_we_ft_i) begin
        alu_faulty_map0_nw = mhpm_wdata_ft_i;
        sel[mhpm_addr_ft_i[3:0]+36] = 1'b1;
      end

    CSR_PERM_FAULTY_ALUH_FT:
      if (mhpm_re_ft_i) 
        mhpm_rdata_ft_o = alu_faulty_map1;
      else if (mhpm_we_ft_i) begin
        alu_faulty_map1_nw = mhpm_wdata_ft_i;
        sel[mhpm_addr_ft_i[3:0]+36] = 1'b1;
      end

    default: begin
      count_logic_nw       = 'b0;
      count_shift_nw       = 'b0;
      count_bit_man_nw     = 'b0;
      count_bit_count_nw   = 'b0;
      count_comparison_nw  = 'b0;
      count_abs_nw         = 'b0;
      count_min_max_nw     = 'b0;
      count_div_rem_nw     = 'b0;
      count_shuf_nw        = 'b0;
      alu_faulty_map0_nw   = 'b0;
      alu_faulty_map1_nw   = 'b0;

      mhpm_rdata_ft_o      = 'b0;
      sel                  = 'b0;
    end

  endcase
end



endmodule
