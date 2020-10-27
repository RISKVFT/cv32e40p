// Copyright 2020 Politecnico di Torino.

////////////////////////////////////////////////////////////////////////////////
// Engineer:       Luca Fiore - luca.fiore@studenti.polito.it                 //
//                                                                            //
//                                                                            //                                                               
// Design Name:    cv32e40p_ID_EX_pipeline                                         //
// Project Name:   cv32e40p Fault tolernat                                    //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    pipeline bwtween ID and EX                                 //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40p_ID_EX_pipeline import cv32e40p_pkg::*; import cv32e40p_apu_core_pkg::*;
#(
  parameter APU_NARGS_CPU     =  3,
  parameter APU_WOP_CPU       =  6,
  parameter APU_NDSFLAGS_CPU  = 15
)
(
  // INPUTS //
  input logic         clk,                  // Gated clock
  input logic 	      rst_n,
  input logic         data_misaligned_i,
  input logic         ex_ready_i,           // EX stage is ready for the next instruction
  input logic         mult_multicycle_i,    // from ALU: when we need multiple cycles in the multiplier and use op c as storage
  input logic         id_valid_o,           // ID stage is done
  input logic         alu_en,               // ALU control  
  input logic         mult_int_en,          // Multiplier control: use integer multiplier
  input logic         mult_dot_en,          // use dot product
  input logic         apu_en,
  input logic         regfile_we_id,        // Register Write Control
  input logic         regfile_alu_we_id,
  input logic         data_req_id,           // Data Memory Control
  input logic [1:0]   ctrl_transfer_insn_in_id,

  input logic [31:0]              operand_a_fw_id,
  input logic [31:0]              operand_c_fw_id,
  input logic [ALU_OP_WIDTH-1:0]  alu_operator,
  input logic [31:0]              alu_operand_a,
  input logic [31:0]              alu_operand_b,
  input logic [31:0]              alu_operand_c,
  input logic [ 4:0]              bmask_a_id,
  input logic [ 4:0]              bmask_b_id,
  input logic [ 1:0]              imm_vec_ext_id,
  input logic [ 1:0]              alu_vec_mode,
  input logic                     is_clpx,
  input logic [31:0]              instr,
  input logic                     is_subrot,
  input logic                     mult_en,
  input logic [ 2:0]              mult_operator,
  input logic                     mult_sel_subword,
  input logic [ 1:0]              mult_signed_mode,
  input logic [ 4:0]              mult_imm_id,
  input logic [ 1:0]              mult_dot_signed,
  input logic [APU_WOP_CPU-1:0]   apu_op,
  input logic [1:0]               apu_lat,
  input logic [APU_NARGS_CPU-1:0][31:0]        apu_operands,
  input logic [APU_NDSFLAGS_CPU-1:0]           apu_flags,
  input logic [5:0]                            apu_waddr,
  input logic [5:0]                            regfile_waddr_id,
  input logic [5:0]                            regfile_alu_waddr_id,
  input logic                     prepost_useincr,
  input logic                     csr_access,
  input logic [1:0]               csr_op,
  input logic                     data_we_id,
  input logic [1:0]               data_type_id,
  input logic [1:0]               data_sign_ext_id,
  input logic [1:0]               data_reg_offset_id,
  input logic                     data_load_event_id,
  input logic [5:0]               atop_id,
  input logic [31:0]              pc_id_i,

  // OUTPUTS //
  // Pipeline ID/EX
  output logic [31:0] pc_ex_o,
  
  output logic [31:0] alu_operand_a_ex_o,
  output logic [31:0] alu_operand_b_ex_o,
  output logic [31:0] alu_operand_c_ex_o,
  output logic [ 4:0] bmask_a_ex_o,
  output logic [ 4:0] bmask_b_ex_o,
  output logic [ 1:0] imm_vec_ext_ex_o,
  output logic [ 1:0] alu_vec_mode_ex_o,

  output logic [5:0]  regfile_waddr_ex_o,
  output logic        regfile_we_ex_o,

  output logic [5:0]  regfile_alu_waddr_ex_o,
  output logic        regfile_alu_we_ex_o,
  output logic        prepost_useincr_ex_o,

  // CSR ID/EX
  output logic        csr_access_ex_o,
  output logic [1:0]  csr_op_ex_o,

  // Interface to load store unit
  output logic        data_req_ex_o,
  output logic        data_we_ex_o,
  output logic [1:0]  data_type_ex_o,
  output logic [1:0]  data_sign_ext_ex_o,
  output logic [1:0]  data_reg_offset_ex_o,
  output logic        data_load_event_ex_o,
  output logic [5:0]  atop_ex_o,

  output logic        data_misaligned_ex_o,

  // ALU    
  output logic        alu_en_ex_o,
  output logic [ALU_OP_WIDTH-1:0] alu_operator_ex_o,
  output logic        alu_is_clpx_ex_o,
  output logic        alu_is_subrot_ex_o,
  output logic [ 1:0] alu_clpx_shift_ex_o,

  // MUL
  output logic [ 2:0] mult_operator_ex_o,
  output logic [31:0] mult_operand_a_ex_o,
  output logic [31:0] mult_operand_b_ex_o,
  output logic [31:0] mult_operand_c_ex_o,
  output logic        mult_en_ex_o,
  output logic        mult_sel_subword_ex_o,
  output logic [ 1:0] mult_signed_mode_ex_o,
  output logic [ 4:0] mult_imm_ex_o,

  output logic [31:0] mult_dot_op_a_ex_o,
  output logic [31:0] mult_dot_op_b_ex_o,
  output logic [31:0] mult_dot_op_c_ex_o,
  output logic [ 1:0] mult_dot_signed_ex_o,
  output logic        mult_is_clpx_ex_o,
  output logic [ 1:0] mult_clpx_shift_ex_o,
  output logic        mult_clpx_img_ex_o,

  // APU
  output logic                        apu_en_ex_o,
  output logic [APU_WOP_CPU-1:0]      apu_op_ex_o,
  output logic [1:0]                  apu_lat_ex_o,
  output logic [APU_NARGS_CPU-1:0][31:0]                 apu_operands_ex_o,
  output logic [APU_NDSFLAGS_CPU-1:0] apu_flags_ex_o,
  output logic [5:0]                  apu_waddr_ex_o,

  // Jumps and branches
  output logic       branch_in_ex_o,

  // Fault Tolerant
  input  logic[2:0]  sel_mux_ex_i,
  output logic[2:0]  sel_mux_ex_o,
  input  logic[3:0]  clock_enable_alu_i, //to clock gate the not used counters
  output logic[3:0]  clock_enable_alu_o

);

/////////////////////////////////////////////////////////////////////////////////
  //   ___ ____        _______  __  ____ ___ ____  _____ _     ___ _   _ _____   //
  //  |_ _|  _ \      | ____\ \/ / |  _ \_ _|  _ \| ____| |   |_ _| \ | | ____|  //
  //   | || | | |_____|  _|  \  /  | |_) | || |_) |  _| | |    | ||  \| |  _|    //
  //   | || |_| |_____| |___ /  \  |  __/| ||  __/| |___| |___ | || |\  | |___   //
  //  |___|____/      |_____/_/\_\ |_|  |___|_|   |_____|_____|___|_| \_|_____|  //
  //                                                                             //
  /////////////////////////////////////////////////////////////////////////////////

  always_ff @(posedge clk, negedge rst_n)
  begin : ID_EX_PIPE_REGISTERS

    if (rst_n == 1'b0)
    begin
      alu_en_ex_o                 <= '0;
      alu_operator_ex_o           <= ALU_SLTU;
      alu_operand_a_ex_o          <= '0;
      alu_operand_b_ex_o          <= '0;
      alu_operand_c_ex_o          <= '0;
      bmask_a_ex_o                <= '0;
      bmask_b_ex_o                <= '0;
      imm_vec_ext_ex_o            <= '0;
      alu_vec_mode_ex_o           <= '0;
      alu_clpx_shift_ex_o         <= 2'b0;
      alu_is_clpx_ex_o            <= 1'b0;
      alu_is_subrot_ex_o          <= 1'b0;

      mult_operator_ex_o          <= '0;
      mult_operand_a_ex_o         <= '0;
      mult_operand_b_ex_o         <= '0;
      mult_operand_c_ex_o         <= '0;
      mult_en_ex_o                <= 1'b0;
      mult_sel_subword_ex_o       <= 1'b0;
      mult_signed_mode_ex_o       <= 2'b00;
      mult_imm_ex_o               <= '0;

      mult_dot_op_a_ex_o          <= '0;
      mult_dot_op_b_ex_o          <= '0;
      mult_dot_op_c_ex_o          <= '0;
      mult_dot_signed_ex_o        <= '0;
      mult_is_clpx_ex_o           <= 1'b0;
      mult_clpx_shift_ex_o        <= 2'b0;
      mult_clpx_img_ex_o          <= 1'b0;

      apu_en_ex_o                 <= '0;
      apu_op_ex_o                 <= '0;
      apu_lat_ex_o                <= '0;
      apu_operands_ex_o[0]        <= '0;
      apu_operands_ex_o[1]        <= '0;
      apu_operands_ex_o[2]        <= '0;
      apu_flags_ex_o              <= '0;
      apu_waddr_ex_o              <= '0;


      regfile_waddr_ex_o          <= 6'b0;
      regfile_we_ex_o             <= 1'b0;

      regfile_alu_waddr_ex_o      <= 6'b0;
      regfile_alu_we_ex_o         <= 1'b0;
      prepost_useincr_ex_o        <= 1'b0;

      csr_access_ex_o             <= 1'b0;
      csr_op_ex_o                 <= CSR_OP_READ;

      data_we_ex_o                <= 1'b0;
      data_type_ex_o              <= 2'b0;
      data_sign_ext_ex_o          <= 2'b0;
      data_reg_offset_ex_o        <= 2'b0;
      data_req_ex_o               <= 1'b0;
      data_load_event_ex_o        <= 1'b0;
      atop_ex_o                   <= 5'b0;

      data_misaligned_ex_o        <= 1'b0;

      pc_ex_o                     <= '0;

      branch_in_ex_o              <= 1'b0;

      sel_mux_ex_o                <= 3'b0;
      clock_enable_alu_o          <= 3'b0;

    end
    else if (data_misaligned_i) begin

      // misaligned data access case
      clock_enable_alu_o           <= clock_enable_alu_i;
      sel_mux_ex_o                <= sel_mux_ex_i;

      if (ex_ready_i)
      begin // misaligned access case, only unstall alu operands

        // if we are using post increments, then we have to use the
        // original value of the register for the second memory access
        // => keep it stalled
        if (prepost_useincr_ex_o == 1'b1)
        begin
          alu_operand_a_ex_o        <= operand_a_fw_id;
        end

        alu_operand_b_ex_o          <= 32'h4;
        regfile_alu_we_ex_o         <= 1'b0;
        prepost_useincr_ex_o        <= 1'b1;

        data_misaligned_ex_o        <= 1'b1;
      end
    end else if (mult_multicycle_i) begin
      clock_enable_alu_o           <= clock_enable_alu_i;
      sel_mux_ex_o                <= sel_mux_ex_i;

      mult_operand_c_ex_o <= operand_c_fw_id;
    end
    else begin
      // normal pipeline unstall case
      clock_enable_alu_o           <= clock_enable_alu_i;
      sel_mux_ex_o                <= sel_mux_ex_i;

      if (id_valid_o)
      begin // unstall the whole pipeline
        alu_en_ex_o                 <= alu_en;
        if (alu_en)
        begin
          alu_operator_ex_o         <= alu_operator;
          alu_operand_a_ex_o        <= alu_operand_a;
          alu_operand_b_ex_o        <= alu_operand_b;
          alu_operand_c_ex_o        <= alu_operand_c;
          bmask_a_ex_o              <= bmask_a_id;
          bmask_b_ex_o              <= bmask_b_id;
          imm_vec_ext_ex_o          <= imm_vec_ext_id;
          alu_vec_mode_ex_o         <= alu_vec_mode;
          alu_is_clpx_ex_o          <= is_clpx;
          alu_clpx_shift_ex_o       <= instr[14:13];
          alu_is_subrot_ex_o        <= is_subrot;
        end

        mult_en_ex_o                <= mult_en;
        if (mult_int_en) begin
          mult_operator_ex_o        <= mult_operator;
          mult_sel_subword_ex_o     <= mult_sel_subword;
          mult_signed_mode_ex_o     <= mult_signed_mode;
          mult_operand_a_ex_o       <= alu_operand_a;
          mult_operand_b_ex_o       <= alu_operand_b;
          mult_operand_c_ex_o       <= alu_operand_c;
          mult_imm_ex_o             <= mult_imm_id;
        end
        if (mult_dot_en) begin
          mult_operator_ex_o        <= mult_operator;
          mult_dot_signed_ex_o      <= mult_dot_signed;
          mult_dot_op_a_ex_o        <= alu_operand_a;
          mult_dot_op_b_ex_o        <= alu_operand_b;
          mult_dot_op_c_ex_o        <= alu_operand_c;
          mult_is_clpx_ex_o         <= is_clpx;
          mult_clpx_shift_ex_o      <= instr[14:13];
          mult_clpx_img_ex_o        <= instr[25];
        end

        // APU pipeline
        apu_en_ex_o                 <= apu_en;
        if (apu_en) begin
          apu_op_ex_o               <= apu_op;
          apu_lat_ex_o              <= apu_lat;
          apu_operands_ex_o         <= apu_operands;
          apu_flags_ex_o            <= apu_flags;
          apu_waddr_ex_o            <= apu_waddr;
        end

        regfile_we_ex_o             <= regfile_we_id;
        if (regfile_we_id) begin
          regfile_waddr_ex_o        <= regfile_waddr_id;
        end

        regfile_alu_we_ex_o         <= regfile_alu_we_id;
        if (regfile_alu_we_id) begin
          regfile_alu_waddr_ex_o    <= regfile_alu_waddr_id;
        end

        prepost_useincr_ex_o        <= prepost_useincr;

        csr_access_ex_o             <= csr_access;
        csr_op_ex_o                 <= csr_op;

        data_req_ex_o               <= data_req_id;
        if (data_req_id)
        begin // only needed for LSU when there is an active request
          data_we_ex_o              <= data_we_id;
          data_type_ex_o            <= data_type_id;
          data_sign_ext_ex_o        <= data_sign_ext_id;
          data_reg_offset_ex_o      <= data_reg_offset_id;
          data_load_event_ex_o      <= data_load_event_id;
          atop_ex_o                 <= atop_id;
        end else begin
          data_load_event_ex_o      <= 1'b0;
        end

        data_misaligned_ex_o        <= 1'b0;

        if ((ctrl_transfer_insn_in_id == BRANCH_COND) || data_req_id) begin
          pc_ex_o                   <= pc_id_i;
        end

        branch_in_ex_o              <= ctrl_transfer_insn_in_id == BRANCH_COND;
      end else if(ex_ready_i) begin
        // EX stage is ready but we don't have a new instruction for it,
        // so we set all write enables to 0, but unstall the pipe

        regfile_we_ex_o             <= 1'b0;

        regfile_alu_we_ex_o         <= 1'b0;

        csr_op_ex_o                 <= CSR_OP_READ;

        data_req_ex_o               <= 1'b0;

        data_load_event_ex_o        <= 1'b0;

        data_misaligned_ex_o        <= 1'b0;

        branch_in_ex_o              <= 1'b0;

        apu_en_ex_o                 <= 1'b0;

        alu_operator_ex_o           <= ALU_SLTU;

        mult_en_ex_o                <= 1'b0;

        alu_en_ex_o                 <= 1'b1;

      end else if (csr_access_ex_o) begin
       //In the EX stage there was a CSR access, to avoid multiple
       //writes to the RF, disable regfile_alu_we_ex_o.
       //Not doing it can overwrite the RF file with the currennt CSR value rather than the old one
       regfile_alu_we_ex_o         <= 1'b0;
      end
    end
  end

endmodule
