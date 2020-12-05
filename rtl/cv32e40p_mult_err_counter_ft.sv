// Copyright 2020 Politecnico di Torino.


////////////////////////////////////////////////////////////////////////////////
// Engineer:       Luca Fiore - luca.fiore@studenti.polito.it                 //
//                                                                            //
// Additional contributions by:                                               //
//                 Marcello Neri - s257090@studenti.polito.it                 //
//                 Elia Ribaldone - s265613@studenti.polito.it                //
//                                                                            //
// Design Name:    cv32e40p_mult_err_counter_ft                               //
// Project Name:   cv32e40p Fault tolernat                                    //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Counters for the 3MULTs to know if an mult is permanently  //
//                 demaged. The performance counters related to the 4 mult    //
//                 are activated here.                                        //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////  


//-----------------------------------------------------
module cv32e40p_mult_err_counter_ft import cv32e40p_pkg::*; import cv32e40p_apu_core_pkg::*;
  (
  input  logic                clk,
  input  logic [2:0]          clock_en,
  input  logic                rst_n,
  input  logic [2:0]          mult_enable_i,
  input  logic [2:0][ALU_OP_WIDTH-1:0]      mult_operator_i,
  input  logic [2:0]          error_detected_i,
  input  logic                ready_o_div_count, 
  output logic [2:0][3:0]     permanent_faulty_mult_o,             // one for each counter: 3 MULT and 4 subpart of MULT
  output logic [2:0][3:0]     permanent_faulty_mult_s,             // one for each counter: 3 MULT and 4 subpart of MULT

  // CSR: Performance counters
  input  logic [11:0]         mhpm_addr_ft_i,    // the address of the perf counter to be written
  input  logic                mhpm_re_ft_i,      // read enable 
  output logic [31:0]         mhpm_rdata_ft_o,   // the value of the performance counter we want to read
  input  logic                mhpm_we_ft_i,      // write enable 
  input  logic [31:0]         mhpm_wdata_ft_i    // the we want to write into the perf counter

);

logic [2:0][31:0] count_long_int_q;
logic [2:0][31:0] count_short_int_q;
logic [2:0][31:0] count_dot8_q;
logic [2:0][31:0] count_dot16_q;

// input to the counter registers if we want to increment them because of fault events
logic [2:0][31:0] count_long_int_n;
logic [2:0][31:0] count_short_int_n;
logic [2:0][31:0] count_dot8_n;
logic [2:0][31:0] count_dot16_n;

// input to the counter registers if we want to write them by write instruction
logic [2:0][31:0] count_long_int_nw;
logic [2:0][31:0] count_short_int_nw;
logic [2:0][31:0] count_dot8_nw;
logic [2:0][31:0] count_dot16_nw;

logic [12:0]      sel; // select one between <counter>_n and <counter>_nw and one between permanent_faulty_mult_s and permanent_faulty_mult_nw

// we need 12 bits to store the information on the permanent faulty MULTs so we use one 32b readonly CSR 
logic [31:0]      mult_faulty_map0;

logic [31:0]      mult_faulty_map0_nw;

logic [2:0][3:0]  permanent_faulty_mult_nw;

// maximum value reachable by the counters
logic [31:0]      threshold;

logic [2:0]       clock_gated;
logic [1:0]		    error_increase;
logic [1:0]		    error_decrease;

// CLOCK GATING for the counter that have already reached the end.
cv32e40p_clock_gate CG_counter[2:0]
(
 .clk_i        ( clk              ),
 .en_i         ( clock_en[2:0]    ),
 .scan_cg_en_i ( 1'b0             ), // not used
 .clk_o        ( clock_gated[2:0] )
);



// Special purpose registers to store the threshold value and the increase and decrease amounts for the counters 
// They are customizable by editing "ERROR_THRESHOLD", "ERROR_INCREASE" and "ERROR_DECREASE" in cv32e40p_pkg.sv
always_ff @(posedge rst_n or negedge rst_n) begin : proc_threshold_mult
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
  for (i=0; i < 3; i++) begin
    
    // Next value saving
    always_ff @(posedge clock_gated[i] or negedge rst_n) begin : proc_update_counters_mult
      if(~rst_n) begin
        count_long_int_q[i]     <= 32'b0;
        count_short_int_q[i]    <= 32'b0;
        count_dot8_q[i]         <= 32'b0;
        count_dot16_q[i]        <= 32'b0;
      end else begin
        /*if (mult_enable_i[i]) begin*/
          count_long_int_q[i]   <= sel[i]    ? count_long_int_nw[i]   : count_long_int_n[i];
          count_short_int_q[i]  <= sel[i+4]  ? count_short_int_nw[i]  : count_short_int_n[i];
          count_dot8_q[i]       <= sel[i+8]  ? count_dot8_nw[i]       : count_dot8_n[i];
          count_dot16_q[i]      <= sel[i+12] ? count_dot16_nw[i]      : count_dot16_n[i];     
        /*end*/
      end
    end


    always_comb begin
      // default
      count_long_int_n[i]    = count_long_int_q[i];
      count_short_int_n[i]   = count_short_int_q[i];
      count_dot8_n[i]        = count_dot8_q[i];
      count_dot16_n[i]       = count_dot16_q[i];

      //if (mult_enable_i[i]) begin // override default when appropriate
        case (mult_operator_i[i])

          // 32b integer
          MUL_MAC32, MUL_MSU32:  
          if (~permanent_faulty_mult_s[i][0] & ~permanent_faulty_mult_o[i][0]) begin // PROBABILMENTE QUESTO CONTROLLO È SUPERFLUO PERCHÈ NON DOVREBBE ESSERE SELEZIONATA QUESTA ALU SE NON È IN GRADO DI FARE L'OPERAZIONE. 
            if (error_detected_i[i]) begin      // TUTTAVIA SE C'È LO STESSO ERRORE PERMANENTE IN DUE ALU ALLORA NE VERRÀ SCELTA UNA TRA LE DUE CHE NON SAPRÀ FARE L'OPERAZIONE 
              count_short_int_n[i]=count_short_int_q[i]+error_increase;
            end
            else begin
              if (count_short_int_q[i]>2) begin
                count_short_int_n[i]=count_short_int_q[i]-error_decrease;
              end
              else begin
                count_short_int_n[i]=32'b0;
              end
            end
          end else begin
            count_short_int_n[i]=32'b0;

          end


          // short integer
          MUL_I, MUL_IR, MUL_H:  
          if (~permanent_faulty_mult_s[i][1] & ~permanent_faulty_mult_o[i][1]) begin
            if (error_detected_i[i]) begin
              count_long_int_n[i]=count_long_int_n[i]+error_increase;
            end
            else begin
              if (count_long_int_n[i]>2) begin
                count_long_int_n[i]=count_long_int_n[i]-error_decrease;
              end
              else begin
                count_long_int_n[i]=32'b0;
              end
            end
          end else begin
            count_long_int_n[i]=32'b0;
          end
     


          // 8b dot
          MUL_DOT8:  
          if (~permanent_faulty_mult_s[i][2] & ~permanent_faulty_mult_o[i][2]) begin
            if (error_detected_i[i]) begin
              count_dot8_n[i]=count_dot8_q[i]+error_increase;
            end
            else begin
              if (count_dot8_q[i]>2) begin
                count_dot8_n[i]=count_dot8_q[i]-error_decrease;
              end
              else begin
                count_dot8_n[i]=32'b0;
              end
            end 
          end else begin
            count_dot8_n[i]=32'b0;
          end


          // 16b dot
          MUL_DOT16:
          if (~permanent_faulty_mult_s[i][3] & ~permanent_faulty_mult_o[i][3]) begin  
            if (error_detected_i[i]) begin
              count_dot16_n[i]=count_dot16_q[i]+error_increase;
            end
            else begin
              if (count_dot16_q[i]>2) begin
                count_dot16_n[i]=count_dot16_q[i]-error_decrease;
              end
              else begin
                count_dot16_n[i]=32'b0;
              end
            end 
          end else begin
            count_dot16_n[i]=32'b0;
          end


          default: begin          
            count_long_int_n[i]   = count_long_int_q[i];
            count_short_int_n[i]  = count_short_int_q[i];
            count_dot8_n[i]       = count_dot8_q[i];
            count_dot16_n[i]      = count_dot16_q[i];

	        end
        endcase // case (mult_operator)
      /*end else begin
        count_long_int_n[i]     = count_long_int_q[i];
        count_short_int_n[i]    = count_short_int_q[i];
        count_dot8_n[i]         = count_dot8_q[i];
        count_dot16_n[i]        = count_dot16_q[i];
      end*/
    end
  


  always_comb begin : permanent_error_threshold_mult
    if (~rst_n) begin
      permanent_faulty_mult_s[i]     = 4'b0;
    end
    else begin
      case (mult_operator_i[i])

        // 32b integer 
        MUL_MAC32, MUL_MSU32:
        if (~permanent_faulty_mult_o[i][0]) begin
          if (count_short_int_q[i]==threshold) begin
             permanent_faulty_mult_s[i][0] = 1'b1;
          end else begin
             permanent_faulty_mult_s[i] = 4'b0;
		      end
		    end 
        //end else 
        //	 permanent_faulty_mult_s[i] = 4'b0;

        // short integer
        MUL_I, MUL_IR, MUL_H:
        if (~permanent_faulty_mult_o[i][1]) begin
          if (count_long_int_q[i]==threshold) begin
             permanent_faulty_mult_s[i][1] = 1'b1;
          end else begin
             permanent_faulty_mult_s[i] = 4'b0;
          end
        end
          
        // 8b dot
        MUL_DOT8: 
        if (~permanent_faulty_mult_o[i][2]) begin
          if (count_dot8_q[i]==threshold) begin
             permanent_faulty_mult_s[i][2] = 1'b1;
          end else begin
             permanent_faulty_mult_s[i] = 4'b0;
          end
        end

        // 16b dot
        MUL_DOT16:
        if (~permanent_faulty_mult_o[i][3]) begin
          if (count_dot16_q[i]==threshold) begin
             permanent_faulty_mult_s[i][3] = 1'b1;
          end else begin
             permanent_faulty_mult_s[i] = 4'b0;
          end
        end


        default: 
          permanent_faulty_mult_s[i] = 4'b0;

      endcase
    end 
  end



  always_ff @(posedge clock_gated[i] or negedge rst_n) begin : pipe_counter_mult
    if (~rst_n) begin
      permanent_faulty_mult_o[i]     <= 4'b0;
    end 
    else begin

        // shift
        if (~permanent_faulty_mult_o[i][0])
          permanent_faulty_mult_o[i][0] <= sel[12] ? permanent_faulty_mult_nw[i][0] : permanent_faulty_mult_s[i][0];

         // Logic
        if (~permanent_faulty_mult_o[i][1])
          permanent_faulty_mult_o[i][1] <= sel[12] ? permanent_faulty_mult_nw[i][1] : permanent_faulty_mult_s[i][1];
          
        // Bit manipulation
        if (~permanent_faulty_mult_o[i][2])
          permanent_faulty_mult_o[i][2] <= sel[12] ? permanent_faulty_mult_nw[i][2] : permanent_faulty_mult_s[i][2];

        // Bit counting
        if (~permanent_faulty_mult_o[i][3])
          permanent_faulty_mult_o[i][3] <= sel[12] ? permanent_faulty_mult_nw[i][3] : permanent_faulty_mult_s[i][3];

      end
  end

end // for
endgenerate

genvar y;
genvar z;
genvar k;
generate //reorganize permanent_faulty_mult_o in mult_faulty_map0
    for (y=0; y<3; y++) begin
        for (z=0; z<4; z++) begin
            assign mult_faulty_map0[(3*z)+y] = permanent_faulty_mult_o[y][z];
            assign permanent_faulty_mult_nw[y][z] = mult_faulty_map0_nw[(3*z)+y];
        end
    end
endgenerate




// PERFORMANCE COUNTERS: READING-WRITING LOGIC 
always_comb  begin
  // default
  count_long_int_nw    = 'b0;
  count_short_int_nw   = 'b0;
  count_dot8_nw        = 'b0;
  count_dot16_nw       = 'b0;

  mult_faulty_map0_nw  = 'b0;
  mhpm_rdata_ft_o      = 'b0;
  sel                  = 'b0;

  case (mhpm_addr_ft_i) // override default when appropriate

    CSR_MHPMCOUNTER0_FT, CSR_MHPMCOUNTER1_FT,  CSR_MHPMCOUNTER2_FT: begin
      if (mhpm_re_ft_i) 
        mhpm_rdata_ft_o = count_long_int_q[mhpm_addr_ft_i[7:0]-8];
      else if (mhpm_we_ft_i) begin
        count_long_int_nw[mhpm_addr_ft_i[7:0]-44] = mhpm_wdata_ft_i;
        sel[mhpm_addr_ft_i[7:0]-44] = 1'b1;
      end
    end
    CSR_MHPMCOUNTER3_FT, CSR_MHPMCOUNTER4_FT,  CSR_MHPMCOUNTER5_FT: begin
      if (mhpm_re_ft_i) 
        mhpm_rdata_ft_o = count_short_int_q[mhpm_addr_ft_i[7:0]-12];
      else if (mhpm_we_ft_i) begin
        count_short_int_nw[mhpm_addr_ft_i[7:0]-47] = mhpm_wdata_ft_i;
        sel[mhpm_addr_ft_i[7:0]-44] = 1'b1;
      end
    end
    CSR_MHPMCOUNTER6_FT,  CSR_MHPMCOUNTER7_FT, CSR_MHPMCOUNTER8_FT: begin
      if (mhpm_re_ft_i) 
        mhpm_rdata_ft_o = count_dot8_q[mhpm_addr_ft_i[7:0]-16];
      else if (mhpm_we_ft_i) begin
        count_dot8_nw[mhpm_addr_ft_i[7:0]-50] = mhpm_wdata_ft_i;
        sel[mhpm_addr_ft_i[7:0]-44] = 1'b1;
      end
    end
    CSR_MHPMCOUNTER9_FT,  CSR_MHPMCOUNTER10_FT, CSR_MHPMCOUNTER11_FT: begin
      if (mhpm_re_ft_i) 
        mhpm_rdata_ft_o = count_dot8_q[mhpm_addr_ft_i[7:0]-16];
      else if (mhpm_we_ft_i) begin
        count_dot8_nw[mhpm_addr_ft_i[7:0]-53] = mhpm_wdata_ft_i;
        sel[mhpm_addr_ft_i[7:0]-44] = 1'b1;
      end
    end
    
    CSR_PERM_FAULTY_MULT_FT:
      if (mhpm_re_ft_i) 
        mhpm_rdata_ft_o = mult_faulty_map0;
      else if (mhpm_we_ft_i) begin
        mult_faulty_map0_nw = mhpm_wdata_ft_i;
        sel[mhpm_addr_ft_i[3:0]+12] = 1'b1;
      end

    default: begin
      count_long_int_nw    = 'b0;
      count_short_int_nw   = 'b0;
      count_dot8_nw        = 'b0;
      count_dot16_nw       = 'b0;

      mult_faulty_map0_nw  = 'b0;
      mhpm_rdata_ft_o      = 'b0;
      sel                  = 'b0;
    end

  endcase
end



endmodule
