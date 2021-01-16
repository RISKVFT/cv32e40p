// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

////////////////////////////////////////////////////////////////////////////////
// Engineer:       Renzo Andri - andrire@student.ethz.ch                      //
//                 Luca Fiore - luca.fiore@studenti.polito.it                 //
//                                                                            //
// Additional contributions by:                                               //
//                 Igor Loi - igor.loi@unibo.it                               //
//                 Sven Stucki - svstucki@student.ethz.ch                     //
//                 Andreas Traber - atraber@iis.ee.ethz.ch                    //
//                 Michael Gautschi - gautschi@iis.ee.ethz.ch                 //
//                 Davide Schiavone - pschiavo@iis.ee.ethz.ch                 //
//                                                                            //
// Design Name:    Execute stage FT                                           //
// Project Name:   cv32e40p Fault tolerant                                    //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Execution stage: Hosts ALU and MAC unit                    //
//                 ALU: computes additions/subtractions/comparisons           //
//                 MULT: computes normal multiplications                      //
//                 APU_DISP: offloads instructions to the shared unit.        //
//                 Fault tolerant version.                                    //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40p_ex_stage import cv32e40p_pkg::*; import cv32e40p_apu_core_pkg::*;
#(
  parameter FPU              =  0,
  parameter APU_NARGS_CPU    =  3,
  parameter APU_WOP_CPU      =  6,
  parameter APU_NDSFLAGS_CPU = 15,
  parameter APU_NUSFLAGS_CPU =  5,
  parameter FT 		           =  0
)
(
  input  logic        clk,
  input  logic        rst_n,

  // ALU signals from ID stage
  input  logic [3:0][ALU_OP_WIDTH-1:0] alu_operator_i,
  input  logic [3:0][31:0] alu_operand_a_i,
  input  logic [3:0][31:0] alu_operand_b_i,
  input  logic [3:0][31:0] alu_operand_c_i,
  input  logic [3:0]       alu_en_i,
  input  logic [3:0][ 4:0] bmask_a_i,
  input  logic [3:0][ 4:0] bmask_b_i,
  input  logic [3:0][ 1:0] imm_vec_ext_i,
  input  logic [3:0][ 1:0] alu_vec_mode_i,
  input  logic [3:0]       alu_is_clpx_i,
  input  logic [3:0]       alu_is_subrot_i,
  input  logic [3:0][ 1:0] alu_clpx_shift_i,

  // Multiplier signals
  input  logic [3:0][ 2:0] mult_operator_i,
  input  logic [3:0][31:0] mult_operand_a_i,
  input  logic [3:0][31:0] mult_operand_b_i,
  input  logic [3:0][31:0] mult_operand_c_i,
  input  logic [3:0]       mult_en_i,
  input  logic [3:0]       mult_sel_subword_i,
  input  logic [3:0][ 1:0] mult_signed_mode_i,
  input  logic [3:0][ 4:0] mult_imm_i,

  input  logic [3:0][31:0] mult_dot_op_a_i,
  input  logic [3:0][31:0] mult_dot_op_b_i,
  input  logic [3:0][31:0] mult_dot_op_c_i,
  input  logic [3:0][ 1:0] mult_dot_signed_i,
  input  logic [3:0]       mult_is_clpx_i,
  input  logic [3:0][ 1:0] mult_clpx_shift_i,
  input  logic [3:0]       mult_clpx_img_i,

  output logic             mult_multicycle_o,

  // FPU signals
  input  logic [C_PC-1:0]             fpu_prec_i,
  output logic                        fpu_fflags_we_o,

  // APU signals
  input  logic [3:0]                       apu_en_i,
  input  logic [3:0][APU_WOP_CPU-1:0]      apu_op_i,
  input  logic [3:0][1:0]                  apu_lat_i,
  input  logic [3:0][APU_NARGS_CPU-1:0][31:0] apu_operands_i,
  input  logic [3:0][5:0]                  apu_waddr_i,
  input  logic [3:0][APU_NDSFLAGS_CPU-1:0] apu_flags_i,

  input  logic [2:0][5:0]             apu_read_regs_i,
  input  logic [2:0]                  apu_read_regs_valid_i,
  output logic                        apu_read_dep_o,
  input  logic [1:0][5:0]             apu_write_regs_i,
  input  logic [1:0]                  apu_write_regs_valid_i,
  output logic                        apu_write_dep_o,

  output logic                        apu_perf_type_o,
  output logic                        apu_perf_cont_o,
  output logic                        apu_perf_wb_o,

  output logic                        apu_busy_o,
  output logic                        apu_ready_wb_o,

  // apu-interconnect
  // handshake signals
  output logic                       apu_master_req_o,
  output logic                       apu_master_ready_o,
  input  logic                       apu_master_gnt_i,
  // request channel
  output logic [APU_NARGS_CPU-1:0][31:0] apu_master_operands_o,
  output logic [APU_WOP_CPU-1:0]     apu_master_op_o,
  // response channel
  input logic                        apu_master_valid_i,
  input logic [31:0]                 apu_master_result_i,

  input  logic [3:0]       lsu_en_i,
  input  logic [31:0]	     lsu_rdata_i,

  // input from ID stage
  input  logic [3:0]       branch_in_ex_i,
  input  logic [3:0][5:0]  regfile_alu_waddr_i,
  input  logic [3:0]       regfile_alu_we_i,

  // directly passed through to WB stage, not used in EX
  input  logic [3:0]       regfile_we_i,
  input  logic [3:0][5:0]  regfile_waddr_i,

  // CSR access
  input  logic [3:0]       csr_access_i,
  input  logic [31:0]      csr_rdata_i,

  // Output of EX stage pipeline
  output logic [5:0]  regfile_waddr_wb_o,
  output logic        regfile_we_wb_o,
  output logic [31:0] regfile_wdata_wb_o,

  // Forwarding ports : to ID stage
  output logic  [5:0] regfile_alu_waddr_fw_o,
  output logic        regfile_alu_we_fw_o,
  output logic [31:0] regfile_alu_wdata_fw_o,    // forward to RF and ID/EX pipe, ALU & MUL

  // To IF: Jump and branch target and decision
  output logic [31:0] jump_target_o,
  output logic        branch_decision_o,

  // Stall Control
  input logic         is_decoding_i, // Used to mask data Dependency inside the APU dispatcher in case of an istruction non valid
  input logic         lsu_ready_ex_i, // EX part of LSU is done
  input logic         lsu_err_i,

  output logic        ex_ready_o, // EX stage ready for new data
  output logic        ex_valid_o, // EX stage gets new data
  input  logic        wb_ready_i,  // WB stage ready for new data

  // ft
  input  logic [2:0]       sel_mux_ex_i, // selector of the three mux to choose three of the four alu
  output logic [3:0][8:0]  permanent_faulty_alu_ft_o,  // set of 4 9bit register for a each ALU
  output logic [3:0][8:0]  permanent_faulty_alu_s_ft_o,
  output logic [2:0][3:0]  permanent_faulty_mult_ft_o,  // set of 4 9bit register for a each ALU
  output logic [2:0][3:0]  permanent_faulty_mult_s_ft_o,  
  input  logic [3:0]       clock_enable_i,

  // addictional inputs coming from the id_stage pipeline after a voting mechanism
  input logic                 alu_en_ex_voted_i,

  input logic [APU_WOP_CPU-1:0]              apu_op_ex_voted_i,
  input logic [APU_NARGS_CPU-1:0][31:0]      apu_operands_ex_voted_i,
  input logic [ 5:0]          apu_waddr_ex_voted_i,
  input logic [ 5:0]          regfile_alu_waddr_ex_voted_i,
  input logic                 regfile_alu_we_ex_voted_i,
  input logic                 apu_en_ex_voted_i,
  input logic [1:0]           apu_lat_ex_voted_i,
  input logic                 branch_in_ex_voted_i,
  input logic [5:0]           regfile_waddr_ex_voted_i,
  input logic                 regfile_we_ex_voted_i,
  input logic                 csr_access_ex_voted_i,
  input logic 		            lsu_en_voted_i,

  // Performance counters
  input  logic [11:0]         mhpm_addr_ft_i,    // the address of the perf counter to be written
  input  logic                mhpm_re_ft_i,      // read enable 
  output logic [31:0]         mhpm_rdata_ft_o,   // the value of the performance_counter/csr we want to read
  input  logic                mhpm_we_ft_i,      // write enable 
  input  logic [31:0]         mhpm_wdata_ft_i,   // the we want to write into the perf counter

  // set if only two ALU/MULT are not permanent faulty
  input  logic                only_two_alu_i,
  input  logic                only_two_mult_i,
  input  logic [1:0]          sel_mux_only_two_alu_i,
  input  logic [1:0]          sel_mux_only_two_mult_i,

  // bypass if more than 2 ALU/MULT are permanent faulty
  input  logic [1:0]          sel_bypass_alu_ex_i,
  input  logic [1:0]          sel_bypass_mult_ex_i,

  // output signals to summarize the faults detection and correction of EX stage
  output logic [ 1:0]    vector_err_detected_ft_o,
  output logic [ 1:0]    vector_err_corrected_ft_o

);

  logic [31:0]    alu_result;
  logic [31:0]    mult_result;
  logic           alu_cmp_result;

  logic           regfile_we_lsu;
  logic [5:0]     regfile_waddr_lsu;

  logic           wb_contention;
  logic           wb_contention_lsu;

  logic           alu_ready;
  logic           mult_ready;

  // APU signals
  logic           apu_valid;
  logic [ 5:0]    apu_waddr;
  logic [31:0]    apu_result;
  logic           apu_stall;
  logic           apu_active;
  logic           apu_singlecycle;
  logic           apu_multicycle;
  logic           apu_req;
  logic           apu_ready;
  logic           apu_gnt;

  logic [ 3:0]    clk_gated_alu_ft;
  logic           mult_en_ex_voted;

  logic [31:0]    mhpm_rdata_ft_alu;    // the value of the performance_counter/csr we want to read from alu
  logic [31:0]    mhpm_rdata_ft_mult;   // the value of the performance_counter/csr we want to read from mult 

  logic           err_corrected_alu;
  logic           err_detected_alu;
  logic           err_corrected_mult;
  logic           err_detected_mult;   
 
  if (FT) begin // mult_en is used inside the mult and inside the ex_stage so we have to vote it to reduce it to a single signal
    cv32e40p_3voter #(1,1) voter_mult_en_ex
    (
      .in_1_i           ( mult_en_i[0] ),
      .in_2_i           ( mult_en_i[1] ),
      .in_3_i           ( mult_en_i[2] ),
      .only_two_i       ( 1'b0 ),
      .voted_o          ( mult_en_ex_voted ),
      .err_detected_1_o (  ),
      .err_detected_2_o (  ),
      .err_detected_3_o (  ),
      .err_corrected_o  (  ),
      .err_detected_o   (  )
    ); 
  end else begin
    assign mult_en_ex_voted = mult_en_i;
  end


  // ALU write port mux
  always_comb
  begin
    regfile_alu_wdata_fw_o = '0;
    regfile_alu_waddr_fw_o = '0;
    regfile_alu_we_fw_o    = '0;
    wb_contention          = 1'b0;

    // APU single cycle operations, and multicycle operations (>2cycles) are written back on ALU port
    if (apu_valid & (apu_singlecycle | apu_multicycle)) begin
      regfile_alu_we_fw_o    = 1'b1;
      regfile_alu_waddr_fw_o = apu_waddr;
      regfile_alu_wdata_fw_o = apu_result;

      if(regfile_alu_we_ex_voted_i & ~apu_en_ex_voted_i) begin
        wb_contention = 1'b1;
      end
    end else begin
      regfile_alu_we_fw_o      = regfile_alu_we_ex_voted_i & ~apu_en_ex_voted_i; // private fpu incomplete?
      regfile_alu_waddr_fw_o   = regfile_alu_waddr_ex_voted_i;
      if (alu_en_ex_voted_i)
        regfile_alu_wdata_fw_o = alu_result;
      if (mult_en_ex_voted)
        regfile_alu_wdata_fw_o = mult_result;
      if (csr_access_ex_voted_i)
        regfile_alu_wdata_fw_o = csr_rdata_i;
    end
  end

  // LSU write port mux
  always_comb
  begin
    regfile_we_wb_o    = 1'b0;
    regfile_waddr_wb_o = regfile_waddr_lsu;
    regfile_wdata_wb_o = lsu_rdata_i;
    wb_contention_lsu  = 1'b0;

    if (regfile_we_lsu) begin
      regfile_we_wb_o = 1'b1;
      if (apu_valid & (!apu_singlecycle & !apu_multicycle)) begin
         wb_contention_lsu = 1'b1;
      end
    // APU two-cycle operations are written back on LSU port
    end else if (apu_valid & (!apu_singlecycle & !apu_multicycle)) begin
      regfile_we_wb_o    = 1'b1;
      regfile_waddr_wb_o = apu_waddr;
      regfile_wdata_wb_o = apu_result;
    end
  end

  // branch handling
  assign branch_decision_o = alu_cmp_result;
  assign jump_target_o     = alu_operand_c_i;





  cv32e40p_clock_gate clk_gate_alu_4[3:0]
  (
   .clk_i        ( clk ),
   .en_i         ( clock_enable_i ),
   .scan_cg_en_i ( 1'b0 ), // not used here
   .clk_o        ( clk_gated_alu_ft   )
  );



  ////////////////////////////
  //     _    _    _   _    //
  //    / \  | |  | | | |   //
  //   / _ \ | |  | | | |   //
  //  / ___ \| |__| |_| |   //
  // /_/   \_\_____\___/    //
  //                        //
  ////////////////////////////

  cv32e40p_alu_ft 
  #(
    .FT (FT)
   )
   alu_ft_i
  (
    .clk                 ( clk              ),
    .clk_g               ( clk_gated_alu_ft ),
    .rst_n               ( rst_n            ),
    .enable_i            ( alu_en_i         ),
    .operator_i          ( alu_operator_i   ),
    .operand_a_i         ( alu_operand_a_i  ),
    .operand_b_i         ( alu_operand_b_i  ),
    .operand_c_i         ( alu_operand_c_i  ),

    .vector_mode_i       ( alu_vec_mode_i   ),
    .bmask_a_i           ( bmask_a_i        ),
    .bmask_b_i           ( bmask_b_i        ),
    .imm_vec_ext_i       ( imm_vec_ext_i    ),

    .is_clpx_i           ( alu_is_clpx_i    ),
    .clpx_shift_i        ( alu_clpx_shift_i ),
    .is_subrot_i         ( alu_is_subrot_i  ),

    .result_o            ( alu_result       ),
    .comparison_result_o ( alu_cmp_result   ),

    .ready_o             ( alu_ready        ),
    .ex_ready_i          ( ex_ready_o       ),

    .clock_en_i               ( clock_enable_i           ),
    .err_corrected_o          ( err_corrected_alu_o      ),
    .err_detected_o           ( err_detected_alu_o       ),
    .permanent_faulty_alu_o   ( permanent_faulty_alu_ft_o   ),
    .permanent_faulty_alu_s_o ( permanent_faulty_alu_s_ft_o ), 
    //.perf_counter_permanent_faulty_alu_ft_o    (perf_counter_permanent_faulty_alu_ft_o),
    .sel_mux_ex_i        ( sel_mux_ex_i      ),
    .mhpm_addr_ft_i      ( mhpm_addr_ft_i    ),   // the address of the perf counter to be written
    .mhpm_re_ft_i        ( mhpm_re_ft_i      ),   // read enable 
    .mhpm_rdata_ft_o     ( mhpm_rdata_ft_alu ),   // the value of the performance counter we want to read
    .mhpm_we_ft_i        ( mhpm_we_ft_i      ),   // write enable 
    .mhpm_wdata_ft_i     ( mhpm_wdata_ft_i   ),

    .only_two_alu_i         ( only_two_alu_i         ),
    .sel_mux_only_two_alu_i ( sel_mux_only_two_alu_i ),
    .sel_bypass_alu_i       ( sel_bypass_alu_ex_i    )

  );




  ////////////////////////////////////////////////////////////////
  //  __  __ _   _ _   _____ ___ ____  _     ___ _____ ____     //
  // |  \/  | | | | | |_   _|_ _|  _ \| |   |_ _| ____|  _ \    //
  // | |\/| | | | | |   | |  | || |_) | |    | ||  _| | |_) |   //
  // | |  | | |_| | |___| |  | ||  __/| |___ | || |___|  _ <    //
  // |_|  |_|\___/|_____|_| |___|_|   |_____|___|_____|_| \_\   //
  //                                                            //
  ////////////////////////////////////////////////////////////////

  cv32e40p_mult_ft 
  #(
    .FT (FT)
  )
  mult_i
  (
    .clk             ( clk                  ),
    .rst_n           ( rst_n                ),

    .enable_i        ( mult_en_i            ),
    .operator_i      ( mult_operator_i      ),

    .short_subword_i ( mult_sel_subword_i   ),
    .short_signed_i  ( mult_signed_mode_i   ),

    .op_a_i          ( mult_operand_a_i     ),
    .op_b_i          ( mult_operand_b_i     ),
    .op_c_i          ( mult_operand_c_i     ),
    .imm_i           ( mult_imm_i           ),

    .dot_op_a_i      ( mult_dot_op_a_i      ),
    .dot_op_b_i      ( mult_dot_op_b_i      ),
    .dot_op_c_i      ( mult_dot_op_c_i      ),
    .dot_signed_i    ( mult_dot_signed_i    ),
    .is_clpx_i       ( mult_is_clpx_i       ),
    .clpx_shift_i    ( mult_clpx_shift_i    ),
    .clpx_img_i      ( mult_clpx_img_i      ),

    .result_o        ( mult_result          ),

    .multicycle_o    ( mult_multicycle_o    ),
    .ready_o         ( mult_ready           ),
    .ex_ready_i      ( ex_ready_o           ),

    .clock_en_i      ( clock_enable_i   ),
    .err_corrected_o ( err_corrected_mult_o ),
    .err_detected_o  ( err_detected_mult_o  ),

    .permanent_faulty_mult_o   ( permanent_faulty_mult_ft_o   ),
    .permanent_faulty_mult_s_o ( permanent_faulty_mult_s_ft_o ),
    
    .sel_mux_ex_i        ( sel_mux_ex_i       ),

    .mhpm_addr_ft_i      ( mhpm_addr_ft_i     ),   // the address of the perf counter to be written
    .mhpm_re_ft_i        ( mhpm_re_ft_i       ),   // read enable 
    .mhpm_rdata_ft_o     ( mhpm_rdata_ft_mult ),   // the value of the performance counter we want to read
    .mhpm_we_ft_i        ( mhpm_we_ft_i       ),   // write enable 
    .mhpm_wdata_ft_i     ( mhpm_wdata_ft_i    ),

    .only_two_mult_i         ( only_two_mult_i         ),
    .sel_mux_only_two_mult_i ( sel_mux_only_two_mult_i ),
    .sel_bypass_mult_i       ( sel_bypass_mult_ex_i    )
  );

  always_comb  begin
    // default
    mhpm_rdata_ft_o = 'b0;

    case (mhpm_addr_ft_i) // override default when appropriate
      //ALU
      CSR_PERM_FAULTY_ALUL_FT, CSR_PERM_FAULTY_ALUH_FT,
      CSR_MHPMCOUNTER0_FT,  CSR_MHPMCOUNTER1_FT,  CSR_MHPMCOUNTER2_FT,  CSR_MHPMCOUNTER3_FT,
      CSR_MHPMCOUNTER4_FT,  CSR_MHPMCOUNTER5_FT,  CSR_MHPMCOUNTER6_FT,  CSR_MHPMCOUNTER7_FT,
      CSR_MHPMCOUNTER8_FT,  CSR_MHPMCOUNTER9_FT,  CSR_MHPMCOUNTER10_FT, CSR_MHPMCOUNTER11_FT,
      CSR_MHPMCOUNTER12_FT, CSR_MHPMCOUNTER13_FT, CSR_MHPMCOUNTER14_FT, CSR_MHPMCOUNTER15_FT,
      CSR_MHPMCOUNTER16_FT, CSR_MHPMCOUNTER17_FT, CSR_MHPMCOUNTER18_FT, CSR_MHPMCOUNTER19_FT,
      CSR_MHPMCOUNTER20_FT, CSR_MHPMCOUNTER21_FT, CSR_MHPMCOUNTER22_FT, CSR_MHPMCOUNTER23_FT,
      CSR_MHPMCOUNTER24_FT, CSR_MHPMCOUNTER25_FT, CSR_MHPMCOUNTER26_FT, CSR_MHPMCOUNTER27_FT,
      CSR_MHPMCOUNTER28_FT, CSR_MHPMCOUNTER29_FT, CSR_MHPMCOUNTER30_FT, CSR_MHPMCOUNTER31_FT,
      CSR_MHPMCOUNTER32_FT, CSR_MHPMCOUNTER33_FT, CSR_MHPMCOUNTER34_FT, CSR_MHPMCOUNTER35_FT: begin
        mhpm_rdata_ft_o = mhpm_rdata_ft_alu;
      end

      //MULT
      CSR_PERM_FAULTY_MULT_FT,
      CSR_MHPMCOUNTERM0_FT, CSR_MHPMCOUNTERM1_FT, CSR_MHPMCOUNTERM2_FT, CSR_MHPMCOUNTERM3_FT,
      CSR_MHPMCOUNTERM4_FT, CSR_MHPMCOUNTERM5_FT, CSR_MHPMCOUNTERM6_FT, CSR_MHPMCOUNTERM7_FT,
      CSR_MHPMCOUNTERM8_FT, CSR_MHPMCOUNTERM9_FT, CSR_MHPMCOUNTERM10_FT, CSR_MHPMCOUNTERM11_FT: begin
        mhpm_rdata_ft_o = mhpm_rdata_ft_mult;
      end

    endcase // mhpm_addr_ft_i
  end


   generate
      if (FPU == 1) begin
         ////////////////////////////////////////////////////
         //     _    ____  _   _   ____ ___ ____  ____     //
         //    / \  |  _ \| | | | |  _ \_ _/ ___||  _ \    //
         //   / _ \ | |_) | | | | | | | | |\___ \| |_) |   //
         //  / ___ \|  __/| |_| | | |_| | | ___) |  __/    //
         // /_/   \_\_|    \___/  |____/___|____/|_|       //
         //                                                //
         ////////////////////////////////////////////////////

         cv32e40p_apu_disp apu_disp_i
         (
         .clk_i              ( clk                            ),
         .rst_ni             ( rst_n                          ),

         .enable_i           ( apu_en_ex_voted_i                ),
         .apu_lat_i          ( apu_lat_ex_voted_i               ),
         .apu_waddr_i        ( apu_waddr_ex_voted_i           ),

         .apu_waddr_o        ( apu_waddr                      ),
         .apu_multicycle_o   ( apu_multicycle                 ),
         .apu_singlecycle_o  ( apu_singlecycle                ),

         .active_o           ( apu_active                     ),
         .stall_o            ( apu_stall                      ),

         .is_decoding_i      ( is_decoding_i                  ),
         .read_regs_i        ( apu_read_regs_i                ),
         .read_regs_valid_i  ( apu_read_regs_valid_i          ),
         .read_dep_o         ( apu_read_dep_o                 ),
         .write_regs_i       ( apu_write_regs_i               ),
         .write_regs_valid_i ( apu_write_regs_valid_i         ),
         .write_dep_o        ( apu_write_dep_o                ),

         .perf_type_o        ( apu_perf_type_o                ),
         .perf_cont_o        ( apu_perf_cont_o                ),

         // apu-interconnect
         // handshake signals
         .apu_master_req_o   ( apu_req                        ),
         .apu_master_ready_o ( apu_ready                      ),
         .apu_master_gnt_i   ( apu_gnt                        ),
         // response channel
         .apu_master_valid_i ( apu_valid                      )
         );

         assign apu_perf_wb_o  = wb_contention | wb_contention_lsu;
         assign apu_ready_wb_o = ~(apu_active | apu_en_ex_voted_i | apu_stall) | apu_valid;

         assign apu_master_req_o      = apu_req;
         assign apu_master_ready_o    = apu_ready;
         assign apu_gnt               = apu_master_gnt_i;
         assign apu_valid             = apu_master_valid_i;
         assign apu_master_operands_o = apu_operands_ex_voted_i;
         assign apu_master_op_o       = apu_op_ex_voted_i;
         assign apu_result            = apu_master_result_i;
         assign fpu_fflags_we_o       = apu_valid;
      end
      else begin
         // default assignements for the case when no FPU/APU is attached.
         assign apu_master_req_o         = '0;
         assign apu_master_ready_o       = 1'b1;
         assign apu_master_operands_o[0] = '0;
         assign apu_master_operands_o[1] = '0;
         assign apu_master_operands_o[2] = '0;
         assign apu_master_op_o          = '0;
         assign apu_req                  = 1'b0;
         assign apu_gnt                  = 1'b0;
         assign apu_ready                = 1'b0;
         assign apu_result               = 32'b0;
         assign apu_valid       = 1'b0;
         assign apu_waddr       = 6'b0;
         assign apu_stall       = 1'b0;
         assign apu_active      = 1'b0;
         assign apu_ready_wb_o  = 1'b1;
         assign apu_perf_wb_o   = 1'b0;
         assign apu_perf_cont_o = 1'b0;
         assign apu_perf_type_o = 1'b0;
         assign apu_singlecycle = 1'b0;
         assign apu_multicycle  = 1'b0;
         assign apu_read_dep_o  = 1'b0;
         assign apu_write_dep_o = 1'b0;
         assign fpu_fflags_we_o = 1'b0;

      end
   endgenerate

   assign apu_busy_o = apu_active;

  ///////////////////////////////////////
  // EX/WB Pipeline Register           //
  ///////////////////////////////////////
  always_ff @(posedge clk, negedge rst_n)
  begin : EX_WB_Pipeline_Register
    if (~rst_n)
    begin
      regfile_waddr_lsu   <= '0;
      regfile_we_lsu      <= 1'b0;
    end
    else
    begin
      if (ex_valid_o) // wb_ready_i is implied
      begin
        regfile_we_lsu    <= regfile_we_ex_voted_i & ~lsu_err_i;
        if (regfile_we_ex_voted_i & ~lsu_err_i ) begin
          regfile_waddr_lsu <= regfile_waddr_ex_voted_i;
        end
      end else if (wb_ready_i) begin
        // we are ready for a new instruction, but there is none available,
        // so we just flush the current one out of the pipe
        regfile_we_lsu    <= 1'b0;
      end
    end
  end

  // As valid always goes to the right and ready to the left, and we are able
  // to finish branches without going to the WB stage, ex_valid does not
  // depend on ex_ready.
  assign ex_ready_o = (~apu_stall & alu_ready & mult_ready & lsu_ready_ex_i
                       & wb_ready_i & ~wb_contention) | (branch_in_ex_voted_i);
  assign ex_valid_o = (apu_valid | alu_en_ex_voted_i | mult_en_ex_voted | csr_access_ex_voted_i | lsu_en_voted_i)
                       & (alu_ready & mult_ready & lsu_ready_ex_i & wb_ready_i);

  // output signals to summarize the faults detection and correction of EX stage
  assign vector_err_detected_ft_o = {err_detected_alu, err_detected_mult};
  assign vector_err_corrected_ft_o = {err_corrected_alu, err_corrected_mult};

endmodule
