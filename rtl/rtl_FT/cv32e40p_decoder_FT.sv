// Copyright 2020 Politecnico di Torino.

////////////////////////////////////////////////////////////////////////////////
// Engineer:       Marcello Neri - s257090@studenti.polito.it                 //
//                                                                            //
//                                                                            //
// Design Name:    decoder_FT										          //
// Project Name:   RI5CY                                                      //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Decoder fault tolerant with TMR		                      //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40p_decoder_ft import cv32e40p_pkg::*; import cv32e40p_apu_core_pkg::*;
#(
  parameter PULP_XPULP        = 1,              // PULP ISA Extension (including PULP specific CSRs and hardware loop, excluding p.elw)
  parameter PULP_CLUSTER      = 0,
  parameter A_EXTENSION       = 0,
  parameter FPU               = 0,
  parameter PULP_SECURE       = 0,
  parameter USE_PMP           = 0,
  parameter WAPUTYPE          = 0,
  parameter APU_WOP_CPU       = 6,
  parameter DEBUG_TRIGGER_EN  = 1
)
(
  // fault tolerant extra signals stating error correction and detection
  output logic		  error_corrected_o,
  output logic		  error_detected_o,
  // singals running to/from controller
  input  logic        deassert_we_i,           // deassert we, we are stalled or not active

  output logic        illegal_insn_o ,          // illegal instruction encountered
  output logic        ebrk_insn_o ,             // trap instruction encountered

  output logic        mret_insn_o ,             // return from exception instruction encountered (M)
  output logic        uret_insn_o ,             // return from exception instruction encountered (S)
  output logic        dret_insn_o ,             // return from debug (M)

  output logic        mret_dec_o ,              // return from exception instruction encountered (M) without deassert
  output logic        uret_dec_o ,              // return from exception instruction encountered (S) without deassert
  output logic        dret_dec_o ,              // return from debug (M) without deassert

  output logic        ecall_insn_o ,            // environment call (syscall) instruction encountered
  output logic        wfi_o       ,            // pipeline flush is requested

  output logic        fencei_insn_o ,           // fence.i instruction

  output logic        rega_used_o ,             // rs1 is used by current instruction
  output logic        regb_used_o ,             // rs2 is used by current instruction
  output logic        regc_used_o ,             // rs3 is used by current instruction

  output logic        reg_fp_a_o ,              // fp reg a is used
  output logic        reg_fp_b_o ,              // fp reg b is used
  output logic        reg_fp_c_o ,              // fp reg c is used
  output logic        reg_fp_d_o ,              // fp reg d is used

  output logic [0:0] bmask_a_mux_o ,           // bit manipulation mask a mux
  output logic [1:0] bmask_b_mux_o ,           // bit manipulation mask b mux
  output logic        alu_bmask_a_mux_sel_o ,   // bit manipulation mask a mux (reg or imm)
  output logic        alu_bmask_b_mux_sel_o ,   // bit manipulation mask b mux (reg or imm)

  // from IF/ID pipeline
  input  logic [31:0] instr_rdata_i,           // instruction read from instr memory/cache
  input  logic        illegal_c_insn_i,        // compressed instruction decode failed

  // ALU signals
  output logic        alu_en_o ,                // ALU enable
  output logic [ALU_OP_WIDTH-1:0] alu_operator_o , // ALU operation selection
  output logic [2:0]  alu_op_a_mux_sel_o ,      // operand a selection: reg value, PC, immediate or zero
  output logic [2:0]  alu_op_b_mux_sel_o ,      // operand b selection: reg value or immediate
  output logic [1:0]  alu_op_c_mux_sel_o ,      // operand c selection: reg value or jump target
  output logic [1:0]  alu_vec_mode_o ,          // selects between 32 bit, 16 bit and 8 bit vectorial modes
  output logic        scalar_replication_o ,    // scalar replication enable
  output logic        scalar_replication_c_o ,  // scalar replication enable for operand C
  output logic [0:0]  imm_a_mux_sel_o ,         // immediate selection for operand a
  output logic [3:0]  imm_b_mux_sel_o ,         // immediate selection for operand b
  output logic [1:0]  regc_mux_o ,              // register c selection: S3, RD or 0
  output logic        is_clpx_o ,               // whether the instruction is complex (pulpv3) or not
  output logic        is_subrot_o ,

  // MUL related control signals
  output logic [2:0]  mult_operator_o ,         // Multiplication operation selection
  output logic        mult_int_en_o ,           // perform integer multiplication
  output logic        mult_dot_en_o ,           // perform dot multiplication
  output logic [0:0]  mult_imm_mux_o ,          // Multiplication immediate mux selector
  output logic        mult_sel_subword_o ,      // Select subwords for 16x16 bit of multiplier
  output logic [1:0]  mult_signed_mode_o ,      // Multiplication in signed mode
  output logic [1:0]  mult_dot_signed_o ,       // Dot product in signed mode

  // FPU
  input  logic [C_RM-1:0]             frm_i,   // Rounding mode from float CSR

  output logic [C_FPNEW_FMTBITS-1:0]  fpu_dst_fmt_o ,   // fpu destination format
  output logic [C_FPNEW_FMTBITS-1:0]  fpu_src_fmt_o ,   // fpu source format
  output logic [C_FPNEW_IFMTBITS-1:0] fpu_int_fmt_o ,   // fpu integer format (for casts)

  // APU
  output logic                apu_en_o ,
  output logic [APU_WOP_CPU-1:0]  apu_op_o ,
  output logic [1:0]          apu_lat_o ,
  output logic [WAPUTYPE-1:0] apu_flags_src_o ,
  output logic [2:0]          fp_rnd_mode_o ,

  // register file related signals
  output logic        regfile_mem_we_o ,        // write enable for regfile
  output logic        regfile_alu_we_o ,        // write enable for 2nd regfile port
  output logic        regfile_alu_we_dec_o ,    // write enable for 2nd regfile port without deassert
  output logic        regfile_alu_waddr_sel_o , // Select register write address for ALU/MUL operations

  // CSR manipulation
  output logic        csr_access_o ,            // access to CSR
  output logic        csr_status_o ,            // access to xstatus CSR
  output logic [1:0]  csr_op_o ,                // operation to perform on CSR
  input  PrivLvl_t    current_priv_lvl_i,      // The current privilege level

  // LD/ST unit signals
  output logic        data_req_o ,              // start transaction to data memory
  output logic        data_we_o ,               // data memory write enable
  output logic        prepost_useincr_o ,       // when not active bypass the alu result for address calculation
  output logic [1:0]  data_type_o ,             // data type on data memory: byte, half word or word
  output logic [1:0]  data_sign_extension_o ,   // sign extension on read data from data memory / NaN boxing
  output logic [1:0]  data_reg_offset_o ,       // offset in byte inside register for stores
  output logic        data_load_event_o ,       // data request is in the special event range

  // Atomic memory access
  output logic [5:0] atop_o ,

  // hwloop signals
  output logic [2:0]  hwlp_we_o ,               // write enable for hwloop regs
  output logic        hwlp_target_mux_sel_o ,   // selects immediate for hwloop target
  output logic        hwlp_start_mux_sel_o ,    // selects hwloop start address input
  output logic        hwlp_cnt_mux_sel_o ,      // selects hwloop counter input

  input  logic        debug_mode_i,            // processor is in debug mode
  input  logic        debug_wfi_no_sleep_i,    // do not let WFI cause sleep

  // jump/branches
  output logic [1:0]  ctrl_transfer_insn_in_dec_o ,  // control transfer instruction without deassert
  output logic [1:0]  ctrl_transfer_insn_in_id_o ,   // control transfer instructio is decoded
  output logic [1:0]  ctrl_transfer_target_mux_sel_o ,        // jump target selection

  // HPM related control signals
  input  logic [31:0] mcounteren_i
);

////////////////////////////////////////////////////////////////////////////////////////////

/////// LOGIC SIGNALS TOWARDS MAJORITY VOTER DEFINITION ///////////
// generated automatically by a script
//copy_signal
logic [0:2]       illegal_insn_ft ;
logic [0:2]       ebrk_insn_ft ;
logic [0:2]       mret_insn_ft ;
logic [0:2]       uret_insn_ft ;
logic [0:2]       dret_insn_ft ;
logic [0:2]       mret_dec_ft ;
logic [0:2]       uret_dec_ft ;
logic [0:2]       dret_dec_ft ;
logic [0:2]       ecall_insn_ft ;
logic [0:2]       wfi_ft ;
logic [0:2]       fencei_insn_ft ;
logic [0:2]       rega_used_ft ;
logic [0:2]       regb_used_ft ;
logic [0:2]       regc_used_ft ;
logic [0:2]       reg_fp_a_ft ;
logic [0:2]       reg_fp_b_ft ;
logic [0:2]       reg_fp_c_ft ;
logic [0:2]       reg_fp_d_ft ;
logic [0:2][0:0] bmask_a_mux_ft ;
logic [0:2][1:0] bmask_b_mux_ft ;
logic [0:2]       alu_bmask_a_mux_sel_ft ;
logic [0:2]       alu_bmask_b_mux_sel_ft ;
logic [0:2]       alu_en_ft ;
logic [0:2][ALU_OP_WIDTH-1:0] alu_operator_ft ;
logic [0:2][2:0]  alu_op_a_mux_sel_ft ;
logic [0:2][2:0]  alu_op_b_mux_sel_ft ;
logic [0:2][1:0]  alu_op_c_mux_sel_ft ;
logic [0:2][1:0]  alu_vec_mode_ft ;
logic [0:2]       scalar_replication_ft ;
logic [0:2]       scalar_replication_c_ft ;
logic [0:2][0:0]  imm_a_mux_sel_ft ;
logic [0:2][3:0]  imm_b_mux_sel_ft ;
logic [0:2][1:0]  regc_mux_ft ;
logic [0:2]       is_clpx_ft ;
logic [0:2]       is_subrot_ft ;
logic [0:2][2:0]  mult_operator_ft ;
logic [0:2]       mult_int_en_ft ;
logic [0:2]       mult_dot_en_ft ;
logic [0:2][0:0]  mult_imm_mux_ft ;
logic [0:2]       mult_sel_subword_ft ;
logic [0:2][1:0]  mult_signed_mode_ft ;
logic [0:2][1:0]  mult_dot_signed_ft ;
logic [0:2][C_FPNEW_FMTBITS-1:0]  fpu_dst_fmt_ft ;
logic [0:2][C_FPNEW_FMTBITS-1:0]  fpu_src_fmt_ft ;
logic [0:2][C_FPNEW_IFMTBITS-1:0] fpu_int_fmt_ft ;
logic [0:2]               apu_en_ft ;
logic [0:2][APU_WOP_CPU-1:0]  apu_op_ft ;
logic [0:2][1:0]          apu_lat_ft ;
logic [0:2][WAPUTYPE-1:0] apu_flags_src_ft ;
logic [0:2][2:0]          fp_rnd_mode_ft ;
logic [0:2]       regfile_mem_we_ft ;
logic [0:2]       regfile_alu_we_ft ;
logic [0:2]       regfile_alu_we_dec_ft ;
logic [0:2]       regfile_alu_waddr_sel_ft ;
logic [0:2]       csr_access_ft ;
logic [0:2]       csr_status_ft ;
logic [0:2][1:0]  csr_op_ft ;
logic [0:2]       data_req_ft ;
logic [0:2]       data_we_ft ;
logic [0:2]       prepost_useincr_ft ;
logic [0:2][1:0]  data_type_ft ;
logic [0:2][1:0]  data_sign_extension_ft ;
logic [0:2][1:0]  data_reg_offset_ft ;
logic [0:2]       data_load_event_ft ;
logic [0:2][5:0] atop_ft ;
logic [0:2][2:0]  hwlp_we_ft ;
logic [0:2]       hwlp_target_mux_sel_ft ;
logic [0:2]       hwlp_start_mux_sel_ft ;
logic [0:2]       hwlp_cnt_mux_sel_ft ;
logic [0:2][1:0]  ctrl_transfer_insn_in_dec_ft ;
logic [0:2][1:0]  ctrl_transfer_insn_in_id_ft ;
logic [0:2][1:0]  ctrl_transfer_target_mux_sel_ft ;
//end_copy_signal
/////// END LOGIC SIGNALS TOWARDS MAJORITY VOTER DEFINITION ///////////


// other signals
logic [1:72]  err_corrected ;
logic [1:72]  err_detected ;


/////// INSTANCES OF MAJORITY VOTER ///////////
// generated automatically by a script
//copy_instance
cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_1
(
	.in_1_i           	( illegal_insn_ft[0] 	 ),
	.in_2_i           	( illegal_insn_ft[1] 	 ),
	.in_3_i           	( illegal_insn_ft[2] 	 ),
	.voted_o          	( illegal_insn_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[1]	),
	.err_detected_o 	( err_detected[1] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_2
(
	.in_1_i           	( ebrk_insn_ft[0] 	 ),
	.in_2_i           	( ebrk_insn_ft[1] 	 ),
	.in_3_i           	( ebrk_insn_ft[2] 	 ),
	.voted_o          	( ebrk_insn_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[2]	),
	.err_detected_o 	( err_detected[2] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_3
(
	.in_1_i           	( mret_insn_ft[0] 	 ),
	.in_2_i           	( mret_insn_ft[1] 	 ),
	.in_3_i           	( mret_insn_ft[2] 	 ),
	.voted_o          	( mret_insn_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[3]	),
	.err_detected_o 	( err_detected[3] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_4
(
	.in_1_i           	( uret_insn_ft[0] 	 ),
	.in_2_i           	( uret_insn_ft[1] 	 ),
	.in_3_i           	( uret_insn_ft[2] 	 ),
	.voted_o          	( uret_insn_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[4]	),
	.err_detected_o 	( err_detected[4] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_5
(
	.in_1_i           	( dret_insn_ft[0] 	 ),
	.in_2_i           	( dret_insn_ft[1] 	 ),
	.in_3_i           	( dret_insn_ft[2] 	 ),
	.voted_o          	( dret_insn_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[5]	),
	.err_detected_o 	( err_detected[5] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_6
(
	.in_1_i           	( mret_dec_ft[0] 	 ),
	.in_2_i           	( mret_dec_ft[1] 	 ),
	.in_3_i           	( mret_dec_ft[2] 	 ),
	.voted_o          	( mret_dec_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[6]	),
	.err_detected_o 	( err_detected[6] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_7
(
	.in_1_i           	( uret_dec_ft[0] 	 ),
	.in_2_i           	( uret_dec_ft[1] 	 ),
	.in_3_i           	( uret_dec_ft[2] 	 ),
	.voted_o          	( uret_dec_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[7]	),
	.err_detected_o 	( err_detected[7] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_8
(
	.in_1_i           	( dret_dec_ft[0] 	 ),
	.in_2_i           	( dret_dec_ft[1] 	 ),
	.in_3_i           	( dret_dec_ft[2] 	 ),
	.voted_o          	( dret_dec_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[8]	),
	.err_detected_o 	( err_detected[8] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_9
(
	.in_1_i           	( ecall_insn_ft[0] 	 ),
	.in_2_i           	( ecall_insn_ft[1] 	 ),
	.in_3_i           	( ecall_insn_ft[2] 	 ),
	.voted_o          	( ecall_insn_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[9]	),
	.err_detected_o 	( err_detected[9] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_10
(
	.in_1_i           	( wfi_ft[0] 	 ),
	.in_2_i           	( wfi_ft[1] 	 ),
	.in_3_i           	( wfi_ft[2] 	 ),
	.voted_o          	( wfi_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[10]	),
	.err_detected_o 	( err_detected[10] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_11
(
	.in_1_i           	( fencei_insn_ft[0] 	 ),
	.in_2_i           	( fencei_insn_ft[1] 	 ),
	.in_3_i           	( fencei_insn_ft[2] 	 ),
	.voted_o          	( fencei_insn_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[11]	),
	.err_detected_o 	( err_detected[11] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_12
(
	.in_1_i           	( rega_used_ft[0] 	 ),
	.in_2_i           	( rega_used_ft[1] 	 ),
	.in_3_i           	( rega_used_ft[2] 	 ),
	.voted_o          	( rega_used_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[12]	),
	.err_detected_o 	( err_detected[12] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_13
(
	.in_1_i           	( regb_used_ft[0] 	 ),
	.in_2_i           	( regb_used_ft[1] 	 ),
	.in_3_i           	( regb_used_ft[2] 	 ),
	.voted_o          	( regb_used_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[13]	),
	.err_detected_o 	( err_detected[13] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_14
(
	.in_1_i           	( regc_used_ft[0] 	 ),
	.in_2_i           	( regc_used_ft[1] 	 ),
	.in_3_i           	( regc_used_ft[2] 	 ),
	.voted_o          	( regc_used_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[14]	),
	.err_detected_o 	( err_detected[14] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_15
(
	.in_1_i           	( reg_fp_a_ft[0] 	 ),
	.in_2_i           	( reg_fp_a_ft[1] 	 ),
	.in_3_i           	( reg_fp_a_ft[2] 	 ),
	.voted_o          	( reg_fp_a_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[15]	),
	.err_detected_o 	( err_detected[15] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_16
(
	.in_1_i           	( reg_fp_b_ft[0] 	 ),
	.in_2_i           	( reg_fp_b_ft[1] 	 ),
	.in_3_i           	( reg_fp_b_ft[2] 	 ),
	.voted_o          	( reg_fp_b_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[16]	),
	.err_detected_o 	( err_detected[16] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_17
(
	.in_1_i           	( reg_fp_c_ft[0] 	 ),
	.in_2_i           	( reg_fp_c_ft[1] 	 ),
	.in_3_i           	( reg_fp_c_ft[2] 	 ),
	.voted_o          	( reg_fp_c_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[17]	),
	.err_detected_o 	( err_detected[17] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_18
(
	.in_1_i           	( reg_fp_d_ft[0] 	 ),
	.in_2_i           	( reg_fp_d_ft[1] 	 ),
	.in_3_i           	( reg_fp_d_ft[2] 	 ),
	.voted_o          	( reg_fp_d_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[18]	),
	.err_detected_o 	( err_detected[18] 	)
);


cv32e40p_3voter 
#(
	.L1			( 0+1	),
	.L2			( 1		)
)
voter_result_19
(
	.in_1_i           	( bmask_a_mux_ft[0] 	 ),
	.in_2_i           	( bmask_a_mux_ft[1] 	 ),
	.in_3_i           	( bmask_a_mux_ft[2] 	 ),
	.voted_o          	( bmask_a_mux_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[19]	),
	.err_detected_o 	( err_detected[19] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1+1	),
	.L2			( 1		)
)
voter_result_20
(
	.in_1_i           	( bmask_b_mux_ft[0] 	 ),
	.in_2_i           	( bmask_b_mux_ft[1] 	 ),
	.in_3_i           	( bmask_b_mux_ft[2] 	 ),
	.voted_o          	( bmask_b_mux_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[20]	),
	.err_detected_o 	( err_detected[20] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_21
(
	.in_1_i           	( alu_bmask_a_mux_sel_ft[0] 	 ),
	.in_2_i           	( alu_bmask_a_mux_sel_ft[1] 	 ),
	.in_3_i           	( alu_bmask_a_mux_sel_ft[2] 	 ),
	.voted_o          	( alu_bmask_a_mux_sel_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[21]	),
	.err_detected_o 	( err_detected[21] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_22
(
	.in_1_i           	( alu_bmask_b_mux_sel_ft[0] 	 ),
	.in_2_i           	( alu_bmask_b_mux_sel_ft[1] 	 ),
	.in_3_i           	( alu_bmask_b_mux_sel_ft[2] 	 ),
	.voted_o          	( alu_bmask_b_mux_sel_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[22]	),
	.err_detected_o 	( err_detected[22] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_23
(
	.in_1_i           	( alu_en_ft[0] 	 ),
	.in_2_i           	( alu_en_ft[1] 	 ),
	.in_3_i           	( alu_en_ft[2] 	 ),
	.voted_o          	( alu_en_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[23]	),
	.err_detected_o 	( err_detected[23] 	)
);


cv32e40p_3voter 
#(
	.L1			( ALU_OP_WIDTH-1+1	),
	.L2			( 1		)
)
voter_result_24
(
	.in_1_i           	( alu_operator_ft[0] 	 ),
	.in_2_i           	( alu_operator_ft[1] 	 ),
	.in_3_i           	( alu_operator_ft[2] 	 ),
	.voted_o          	( alu_operator_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[24]	),
	.err_detected_o 	( err_detected[24] 	)
);


cv32e40p_3voter 
#(
	.L1			( 2+1	),
	.L2			( 1		)
)
voter_result_25
(
	.in_1_i           	( alu_op_a_mux_sel_ft[0] 	 ),
	.in_2_i           	( alu_op_a_mux_sel_ft[1] 	 ),
	.in_3_i           	( alu_op_a_mux_sel_ft[2] 	 ),
	.voted_o          	( alu_op_a_mux_sel_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[25]	),
	.err_detected_o 	( err_detected[25] 	)
);


cv32e40p_3voter 
#(
	.L1			( 2+1	),
	.L2			( 1		)
)
voter_result_26
(
	.in_1_i           	( alu_op_b_mux_sel_ft[0] 	 ),
	.in_2_i           	( alu_op_b_mux_sel_ft[1] 	 ),
	.in_3_i           	( alu_op_b_mux_sel_ft[2] 	 ),
	.voted_o          	( alu_op_b_mux_sel_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[26]	),
	.err_detected_o 	( err_detected[26] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1+1	),
	.L2			( 1		)
)
voter_result_27
(
	.in_1_i           	( alu_op_c_mux_sel_ft[0] 	 ),
	.in_2_i           	( alu_op_c_mux_sel_ft[1] 	 ),
	.in_3_i           	( alu_op_c_mux_sel_ft[2] 	 ),
	.voted_o          	( alu_op_c_mux_sel_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[27]	),
	.err_detected_o 	( err_detected[27] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1+1	),
	.L2			( 1		)
)
voter_result_28
(
	.in_1_i           	( alu_vec_mode_ft[0] 	 ),
	.in_2_i           	( alu_vec_mode_ft[1] 	 ),
	.in_3_i           	( alu_vec_mode_ft[2] 	 ),
	.voted_o          	( alu_vec_mode_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[28]	),
	.err_detected_o 	( err_detected[28] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_29
(
	.in_1_i           	( scalar_replication_ft[0] 	 ),
	.in_2_i           	( scalar_replication_ft[1] 	 ),
	.in_3_i           	( scalar_replication_ft[2] 	 ),
	.voted_o          	( scalar_replication_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[29]	),
	.err_detected_o 	( err_detected[29] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_30
(
	.in_1_i           	( scalar_replication_c_ft[0] 	 ),
	.in_2_i           	( scalar_replication_c_ft[1] 	 ),
	.in_3_i           	( scalar_replication_c_ft[2] 	 ),
	.voted_o          	( scalar_replication_c_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[30]	),
	.err_detected_o 	( err_detected[30] 	)
);


cv32e40p_3voter 
#(
	.L1			( 0+1	),
	.L2			( 1		)
)
voter_result_31
(
	.in_1_i           	( imm_a_mux_sel_ft[0] 	 ),
	.in_2_i           	( imm_a_mux_sel_ft[1] 	 ),
	.in_3_i           	( imm_a_mux_sel_ft[2] 	 ),
	.voted_o          	( imm_a_mux_sel_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[31]	),
	.err_detected_o 	( err_detected[31] 	)
);


cv32e40p_3voter 
#(
	.L1			( 3+1	),
	.L2			( 1		)
)
voter_result_32
(
	.in_1_i           	( imm_b_mux_sel_ft[0] 	 ),
	.in_2_i           	( imm_b_mux_sel_ft[1] 	 ),
	.in_3_i           	( imm_b_mux_sel_ft[2] 	 ),
	.voted_o          	( imm_b_mux_sel_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[32]	),
	.err_detected_o 	( err_detected[32] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1+1	),
	.L2			( 1		)
)
voter_result_33
(
	.in_1_i           	( regc_mux_ft[0] 	 ),
	.in_2_i           	( regc_mux_ft[1] 	 ),
	.in_3_i           	( regc_mux_ft[2] 	 ),
	.voted_o          	( regc_mux_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[33]	),
	.err_detected_o 	( err_detected[33] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_34
(
	.in_1_i           	( is_clpx_ft[0] 	 ),
	.in_2_i           	( is_clpx_ft[1] 	 ),
	.in_3_i           	( is_clpx_ft[2] 	 ),
	.voted_o          	( is_clpx_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[34]	),
	.err_detected_o 	( err_detected[34] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_35
(
	.in_1_i           	( is_subrot_ft[0] 	 ),
	.in_2_i           	( is_subrot_ft[1] 	 ),
	.in_3_i           	( is_subrot_ft[2] 	 ),
	.voted_o          	( is_subrot_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[35]	),
	.err_detected_o 	( err_detected[35] 	)
);


cv32e40p_3voter 
#(
	.L1			( 2+1	),
	.L2			( 1		)
)
voter_result_36
(
	.in_1_i           	( mult_operator_ft[0] 	 ),
	.in_2_i           	( mult_operator_ft[1] 	 ),
	.in_3_i           	( mult_operator_ft[2] 	 ),
	.voted_o          	( mult_operator_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[36]	),
	.err_detected_o 	( err_detected[36] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_37
(
	.in_1_i           	( mult_int_en_ft[0] 	 ),
	.in_2_i           	( mult_int_en_ft[1] 	 ),
	.in_3_i           	( mult_int_en_ft[2] 	 ),
	.voted_o          	( mult_int_en_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[37]	),
	.err_detected_o 	( err_detected[37] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_38
(
	.in_1_i           	( mult_dot_en_ft[0] 	 ),
	.in_2_i           	( mult_dot_en_ft[1] 	 ),
	.in_3_i           	( mult_dot_en_ft[2] 	 ),
	.voted_o          	( mult_dot_en_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[38]	),
	.err_detected_o 	( err_detected[38] 	)
);


cv32e40p_3voter 
#(
	.L1			( 0+1	),
	.L2			( 1		)
)
voter_result_39
(
	.in_1_i           	( mult_imm_mux_ft[0] 	 ),
	.in_2_i           	( mult_imm_mux_ft[1] 	 ),
	.in_3_i           	( mult_imm_mux_ft[2] 	 ),
	.voted_o          	( mult_imm_mux_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[39]	),
	.err_detected_o 	( err_detected[39] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_40
(
	.in_1_i           	( mult_sel_subword_ft[0] 	 ),
	.in_2_i           	( mult_sel_subword_ft[1] 	 ),
	.in_3_i           	( mult_sel_subword_ft[2] 	 ),
	.voted_o          	( mult_sel_subword_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[40]	),
	.err_detected_o 	( err_detected[40] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1+1	),
	.L2			( 1		)
)
voter_result_41
(
	.in_1_i           	( mult_signed_mode_ft[0] 	 ),
	.in_2_i           	( mult_signed_mode_ft[1] 	 ),
	.in_3_i           	( mult_signed_mode_ft[2] 	 ),
	.voted_o          	( mult_signed_mode_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[41]	),
	.err_detected_o 	( err_detected[41] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1+1	),
	.L2			( 1		)
)
voter_result_42
(
	.in_1_i           	( mult_dot_signed_ft[0] 	 ),
	.in_2_i           	( mult_dot_signed_ft[1] 	 ),
	.in_3_i           	( mult_dot_signed_ft[2] 	 ),
	.voted_o          	( mult_dot_signed_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[42]	),
	.err_detected_o 	( err_detected[42] 	)
);


cv32e40p_3voter 
#(
	.L1			( C_FPNEW_FMTBITS-1+1	),
	.L2			( 1		)
)
voter_result_43
(
	.in_1_i           	( fpu_dst_fmt_ft[0] 	 ),
	.in_2_i           	( fpu_dst_fmt_ft[1] 	 ),
	.in_3_i           	( fpu_dst_fmt_ft[2] 	 ),
	.voted_o          	( fpu_dst_fmt_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[43]	),
	.err_detected_o 	( err_detected[43] 	)
);


cv32e40p_3voter 
#(
	.L1			( C_FPNEW_FMTBITS-1+1	),
	.L2			( 1		)
)
voter_result_44
(
	.in_1_i           	( fpu_src_fmt_ft[0] 	 ),
	.in_2_i           	( fpu_src_fmt_ft[1] 	 ),
	.in_3_i           	( fpu_src_fmt_ft[2] 	 ),
	.voted_o          	( fpu_src_fmt_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[44]	),
	.err_detected_o 	( err_detected[44] 	)
);


cv32e40p_3voter 
#(
	.L1			( C_FPNEW_IFMTBITS-1+1	),
	.L2			( 1		)
)
voter_result_45
(
	.in_1_i           	( fpu_int_fmt_ft[0] 	 ),
	.in_2_i           	( fpu_int_fmt_ft[1] 	 ),
	.in_3_i           	( fpu_int_fmt_ft[2] 	 ),
	.voted_o          	( fpu_int_fmt_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[45]	),
	.err_detected_o 	( err_detected[45] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_46
(
	.in_1_i           	( apu_en_ft[0] 	 ),
	.in_2_i           	( apu_en_ft[1] 	 ),
	.in_3_i           	( apu_en_ft[2] 	 ),
	.voted_o          	( apu_en_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[46]	),
	.err_detected_o 	( err_detected[46] 	)
);


cv32e40p_3voter 
#(
	.L1			( APU_WOP_CPU-1+1	),
	.L2			( 1		)
)
voter_result_47
(
	.in_1_i           	( apu_op_ft[0] 	 ),
	.in_2_i           	( apu_op_ft[1] 	 ),
	.in_3_i           	( apu_op_ft[2] 	 ),
	.voted_o          	( apu_op_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[47]	),
	.err_detected_o 	( err_detected[47] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1+1	),
	.L2			( 1		)
)
voter_result_48
(
	.in_1_i           	( apu_lat_ft[0] 	 ),
	.in_2_i           	( apu_lat_ft[1] 	 ),
	.in_3_i           	( apu_lat_ft[2] 	 ),
	.voted_o          	( apu_lat_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[48]	),
	.err_detected_o 	( err_detected[48] 	)
);


cv32e40p_3voter 
#(
	.L1			( WAPUTYPE-1+1	),
	.L2			( 1		)
)
voter_result_49
(
	.in_1_i           	( apu_flags_src_ft[0] 	 ),
	.in_2_i           	( apu_flags_src_ft[1] 	 ),
	.in_3_i           	( apu_flags_src_ft[2] 	 ),
	.voted_o          	( apu_flags_src_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[49]	),
	.err_detected_o 	( err_detected[49] 	)
);


cv32e40p_3voter 
#(
	.L1			( 2+1	),
	.L2			( 1		)
)
voter_result_50
(
	.in_1_i           	( fp_rnd_mode_ft[0] 	 ),
	.in_2_i           	( fp_rnd_mode_ft[1] 	 ),
	.in_3_i           	( fp_rnd_mode_ft[2] 	 ),
	.voted_o          	( fp_rnd_mode_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[50]	),
	.err_detected_o 	( err_detected[50] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_51
(
	.in_1_i           	( regfile_mem_we_ft[0] 	 ),
	.in_2_i           	( regfile_mem_we_ft[1] 	 ),
	.in_3_i           	( regfile_mem_we_ft[2] 	 ),
	.voted_o          	( regfile_mem_we_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[51]	),
	.err_detected_o 	( err_detected[51] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_52
(
	.in_1_i           	( regfile_alu_we_ft[0] 	 ),
	.in_2_i           	( regfile_alu_we_ft[1] 	 ),
	.in_3_i           	( regfile_alu_we_ft[2] 	 ),
	.voted_o          	( regfile_alu_we_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[52]	),
	.err_detected_o 	( err_detected[52] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_53
(
	.in_1_i           	( regfile_alu_we_dec_ft[0] 	 ),
	.in_2_i           	( regfile_alu_we_dec_ft[1] 	 ),
	.in_3_i           	( regfile_alu_we_dec_ft[2] 	 ),
	.voted_o          	( regfile_alu_we_dec_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[53]	),
	.err_detected_o 	( err_detected[53] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_54
(
	.in_1_i           	( regfile_alu_waddr_sel_ft[0] 	 ),
	.in_2_i           	( regfile_alu_waddr_sel_ft[1] 	 ),
	.in_3_i           	( regfile_alu_waddr_sel_ft[2] 	 ),
	.voted_o          	( regfile_alu_waddr_sel_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[54]	),
	.err_detected_o 	( err_detected[54] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_55
(
	.in_1_i           	( csr_access_ft[0] 	 ),
	.in_2_i           	( csr_access_ft[1] 	 ),
	.in_3_i           	( csr_access_ft[2] 	 ),
	.voted_o          	( csr_access_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[55]	),
	.err_detected_o 	( err_detected[55] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_56
(
	.in_1_i           	( csr_status_ft[0] 	 ),
	.in_2_i           	( csr_status_ft[1] 	 ),
	.in_3_i           	( csr_status_ft[2] 	 ),
	.voted_o          	( csr_status_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[56]	),
	.err_detected_o 	( err_detected[56] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1+1	),
	.L2			( 1		)
)
voter_result_57
(
	.in_1_i           	( csr_op_ft[0] 	 ),
	.in_2_i           	( csr_op_ft[1] 	 ),
	.in_3_i           	( csr_op_ft[2] 	 ),
	.voted_o          	( csr_op_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[57]	),
	.err_detected_o 	( err_detected[57] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_58
(
	.in_1_i           	( data_req_ft[0] 	 ),
	.in_2_i           	( data_req_ft[1] 	 ),
	.in_3_i           	( data_req_ft[2] 	 ),
	.voted_o          	( data_req_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[58]	),
	.err_detected_o 	( err_detected[58] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_59
(
	.in_1_i           	( data_we_ft[0] 	 ),
	.in_2_i           	( data_we_ft[1] 	 ),
	.in_3_i           	( data_we_ft[2] 	 ),
	.voted_o          	( data_we_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[59]	),
	.err_detected_o 	( err_detected[59] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_60
(
	.in_1_i           	( prepost_useincr_ft[0] 	 ),
	.in_2_i           	( prepost_useincr_ft[1] 	 ),
	.in_3_i           	( prepost_useincr_ft[2] 	 ),
	.voted_o          	( prepost_useincr_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[60]	),
	.err_detected_o 	( err_detected[60] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1+1	),
	.L2			( 1		)
)
voter_result_61
(
	.in_1_i           	( data_type_ft[0] 	 ),
	.in_2_i           	( data_type_ft[1] 	 ),
	.in_3_i           	( data_type_ft[2] 	 ),
	.voted_o          	( data_type_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[61]	),
	.err_detected_o 	( err_detected[61] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1+1	),
	.L2			( 1		)
)
voter_result_62
(
	.in_1_i           	( data_sign_extension_ft[0] 	 ),
	.in_2_i           	( data_sign_extension_ft[1] 	 ),
	.in_3_i           	( data_sign_extension_ft[2] 	 ),
	.voted_o          	( data_sign_extension_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[62]	),
	.err_detected_o 	( err_detected[62] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1+1	),
	.L2			( 1		)
)
voter_result_63
(
	.in_1_i           	( data_reg_offset_ft[0] 	 ),
	.in_2_i           	( data_reg_offset_ft[1] 	 ),
	.in_3_i           	( data_reg_offset_ft[2] 	 ),
	.voted_o          	( data_reg_offset_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[63]	),
	.err_detected_o 	( err_detected[63] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_64
(
	.in_1_i           	( data_load_event_ft[0] 	 ),
	.in_2_i           	( data_load_event_ft[1] 	 ),
	.in_3_i           	( data_load_event_ft[2] 	 ),
	.voted_o          	( data_load_event_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[64]	),
	.err_detected_o 	( err_detected[64] 	)
);


cv32e40p_3voter 
#(
	.L1			( 5+1	),
	.L2			( 1		)
)
voter_result_65
(
	.in_1_i           	( atop_ft[0] 	 ),
	.in_2_i           	( atop_ft[1] 	 ),
	.in_3_i           	( atop_ft[2] 	 ),
	.voted_o          	( atop_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[65]	),
	.err_detected_o 	( err_detected[65] 	)
);


cv32e40p_3voter 
#(
	.L1			( 2+1	),
	.L2			( 1		)
)
voter_result_66
(
	.in_1_i           	( hwlp_we_ft[0] 	 ),
	.in_2_i           	( hwlp_we_ft[1] 	 ),
	.in_3_i           	( hwlp_we_ft[2] 	 ),
	.voted_o          	( hwlp_we_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[66]	),
	.err_detected_o 	( err_detected[66] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_67
(
	.in_1_i           	( hwlp_target_mux_sel_ft[0] 	 ),
	.in_2_i           	( hwlp_target_mux_sel_ft[1] 	 ),
	.in_3_i           	( hwlp_target_mux_sel_ft[2] 	 ),
	.voted_o          	( hwlp_target_mux_sel_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[67]	),
	.err_detected_o 	( err_detected[67] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_68
(
	.in_1_i           	( hwlp_start_mux_sel_ft[0] 	 ),
	.in_2_i           	( hwlp_start_mux_sel_ft[1] 	 ),
	.in_3_i           	( hwlp_start_mux_sel_ft[2] 	 ),
	.voted_o          	( hwlp_start_mux_sel_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[68]	),
	.err_detected_o 	( err_detected[68] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_69
(
	.in_1_i           	( hwlp_cnt_mux_sel_ft[0] 	 ),
	.in_2_i           	( hwlp_cnt_mux_sel_ft[1] 	 ),
	.in_3_i           	( hwlp_cnt_mux_sel_ft[2] 	 ),
	.voted_o          	( hwlp_cnt_mux_sel_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[69]	),
	.err_detected_o 	( err_detected[69] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1+1	),
	.L2			( 1		)
)
voter_result_70
(
	.in_1_i           	( ctrl_transfer_insn_in_dec_ft[0] 	 ),
	.in_2_i           	( ctrl_transfer_insn_in_dec_ft[1] 	 ),
	.in_3_i           	( ctrl_transfer_insn_in_dec_ft[2] 	 ),
	.voted_o          	( ctrl_transfer_insn_in_dec_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[70]	),
	.err_detected_o 	( err_detected[70] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1+1	),
	.L2			( 1		)
)
voter_result_71
(
	.in_1_i           	( ctrl_transfer_insn_in_id_ft[0] 	 ),
	.in_2_i           	( ctrl_transfer_insn_in_id_ft[1] 	 ),
	.in_3_i           	( ctrl_transfer_insn_in_id_ft[2] 	 ),
	.voted_o          	( ctrl_transfer_insn_in_id_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[71]	),
	.err_detected_o 	( err_detected[71] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1+1	),
	.L2			( 1		)
)
voter_result_72
(
	.in_1_i           	( ctrl_transfer_target_mux_sel_ft[0] 	 ),
	.in_2_i           	( ctrl_transfer_target_mux_sel_ft[1] 	 ),
	.in_3_i           	( ctrl_transfer_target_mux_sel_ft[2] 	 ),
	.voted_o          	( ctrl_transfer_target_mux_sel_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[72]	),
	.err_detected_o 	( err_detected[72] 	)
);
//end_copy_instance
/////// END INSTANCES OF MAJORITY VOTER ///////////



  //////////////////////////////////////////////////
  //  ____  _____ ____ ___  ____  _____ ____      //
  // |  _ \| ____/ ___/ _ \|  _ \| ____|  _ \     //
  // | | | |  _|| |  | | | | | | |  _| | |_) |    //
  // | |_| | |__| |__| |_| | |_| | |___|  _ <     //
  // |____/|_____\____\___/|____/|_____|_| \_\    //
  //                                              //
  //////////////////////////////////////////////////



genvar j;

generate
	for (j = 0; j<3; j++) begin

		  cv32e40p_decoder
			#(
			  .PULP_XPULP          ( PULP_XPULP           ),
			  .PULP_CLUSTER        ( PULP_CLUSTER         ),
			  .A_EXTENSION         ( A_EXTENSION          ),
			  .FPU                 ( FPU                  ),
			  .PULP_SECURE         ( PULP_SECURE          ),
			  .USE_PMP             ( USE_PMP              ),
			  .WAPUTYPE            ( WAPUTYPE             ),
			  .APU_WOP_CPU         ( APU_WOP_CPU          ),
			  .DEBUG_TRIGGER_EN    ( DEBUG_TRIGGER_EN     )
			  )
		  decoder_i_replica
		  (
			// controller related signals
			.deassert_we_i                   ( deassert_we_i               ),

			.illegal_insn_o                  ( illegal_insn_ft[j]          ),
			.ebrk_insn_o                     ( ebrk_insn_ft[j]                 ),

			.mret_insn_o                     ( mret_insn_ft[j]             ),
			.uret_insn_o                     ( uret_insn_ft[j]             ),
			.dret_insn_o                     ( dret_insn_ft[j]             ),

			.mret_dec_o                      ( mret_dec_ft[j]                  ),
			.uret_dec_o                      ( uret_dec_ft[j]                  ),
			.dret_dec_o                      ( dret_dec_ft[j]                  ),

			.ecall_insn_o                    ( ecall_insn_ft[j]            ),
			.wfi_o                           ( wfi_ft[j]              ),

			.fencei_insn_o                   ( fencei_insn_ft[j]           ),

			.rega_used_o                     ( rega_used_ft[j]             ),
			.regb_used_o                     ( regb_used_ft[j]             ),
			.regc_used_o                     ( regc_used_ft[j]             ),

			.reg_fp_a_o                      ( reg_fp_a_ft[j]              ),
			.reg_fp_b_o                      ( reg_fp_b_ft[j]              ),
			.reg_fp_c_o                      ( reg_fp_c_ft[j]              ),
			.reg_fp_d_o                      ( reg_fp_d_ft[j]              ),

			.bmask_a_mux_o                   ( bmask_a_mux_ft[j]               ),
			.bmask_b_mux_o                   ( bmask_b_mux_ft[j]               ),
			.alu_bmask_a_mux_sel_o           ( alu_bmask_a_mux_sel_ft[j]       ),
			.alu_bmask_b_mux_sel_o           ( alu_bmask_b_mux_sel_ft[j]       ),

			// from IF/ID pipeline
			.instr_rdata_i                   ( instr_rdata_i                     ),
			.illegal_c_insn_i                ( illegal_c_insn_i          ),

			// ALU signals
			.alu_en_o                        ( alu_en_ft[j]                    ),
			.alu_operator_o                  ( alu_operator_ft[j]              ),
			.alu_op_a_mux_sel_o              ( alu_op_a_mux_sel_ft[j]          ),
			.alu_op_b_mux_sel_o              ( alu_op_b_mux_sel_ft[j]          ),
			.alu_op_c_mux_sel_o              ( alu_op_c_mux_sel_ft[j]          ),
			.alu_vec_mode_o                  ( alu_vec_mode_ft[j]              ),
			.scalar_replication_o            ( scalar_replication_ft[j]        ),
			.scalar_replication_c_o          ( scalar_replication_c_ft[j]     ),
			.imm_a_mux_sel_o                 ( imm_a_mux_sel_ft[j]             ),
			.imm_b_mux_sel_o                 ( imm_b_mux_sel_ft[j]             ),
			.regc_mux_o                      ( regc_mux_ft[j]                  ),
			.is_clpx_o                       ( is_clpx_ft[j]                   ),
			.is_subrot_o                     ( is_subrot_ft[j]                 ),

			// MUL signals
			.mult_operator_o                 ( mult_operator_ft[j]             ),
			.mult_int_en_o                   ( mult_int_en_ft[j]               ),
			.mult_sel_subword_o              ( mult_sel_subword_ft[j]          ),
			.mult_signed_mode_o              ( mult_signed_mode_ft[j]          ),
			.mult_imm_mux_o                  ( mult_imm_mux_ft[j]              ),
			.mult_dot_en_o                   ( mult_dot_en_ft[j]               ),
			.mult_dot_signed_o               ( mult_dot_signed_ft[j]           ),

			// FPU / APU signals
			.frm_i                           ( frm_i                     ),
			.fpu_src_fmt_o                   ( fpu_src_fmt_ft[j]               ),
			.fpu_dst_fmt_o                   ( fpu_dst_fmt_ft[j]              ),
			.fpu_int_fmt_o                   ( fpu_int_fmt_ft[j]               ),
			.apu_en_o                        ( apu_en_ft[j]                    ),
			.apu_op_o                        ( apu_op_ft[j]                    ),
			.apu_lat_o                       ( apu_lat_ft[j]                   ),
			.apu_flags_src_o                 ( apu_flags_src_ft[j]             ),
			.fp_rnd_mode_o                   ( fp_rnd_mode_ft[j]               ),

			// Register file control signals
			.regfile_mem_we_o                ( regfile_mem_we_ft[j]             ),
			.regfile_alu_we_o                ( regfile_alu_we_ft[j]         ),
			.regfile_alu_we_dec_o            ( regfile_alu_we_dec_ft[j]     ),
			.regfile_alu_waddr_sel_o         ( regfile_alu_waddr_sel_ft[j] ),

			// CSR control signals
			.csr_access_o                    ( csr_access_ft[j]                ),
			.csr_status_o                    ( csr_status_ft[j]                ),
			.csr_op_o                        ( csr_op_ft[j]                    ),
			.current_priv_lvl_i              ( current_priv_lvl_i        ),

			// Data bus interface
			.data_req_o                      ( data_req_ft[j]               ),
			.data_we_o                       ( data_we_ft[j]                ),
			.prepost_useincr_o               ( prepost_useincr_ft[j]           ),
			.data_type_o                     ( data_type_ft[j]              ),
			.data_sign_extension_o           ( data_sign_extension_ft[j]          ),
			.data_reg_offset_o               ( data_reg_offset_ft[j]        ),
			.data_load_event_o               ( data_load_event_ft[j]        ),

			// Atomic memory access
			.atop_o                          ( atop_ft[j]                   ),

			// hwloop signals
			.hwlp_we_o                       ( hwlp_we_ft[j]               ),
			.hwlp_target_mux_sel_o           ( hwlp_target_mux_sel_ft[j]       ),
			.hwlp_start_mux_sel_o            ( hwlp_start_mux_sel_ft[j]        ),
			.hwlp_cnt_mux_sel_o              ( hwlp_cnt_mux_sel_ft[j]          ),

			// debug mode
			.debug_mode_i                    ( debug_mode_i              ),
			.debug_wfi_no_sleep_i            ( debug_wfi_no_sleep_i        ),

			// jump/branches
			.ctrl_transfer_insn_in_dec_o     ( ctrl_transfer_insn_in_dec_ft[j]    ),
			.ctrl_transfer_insn_in_id_o      ( ctrl_transfer_insn_in_id_ft[j]     ),
			.ctrl_transfer_target_mux_sel_o  ( ctrl_transfer_target_mux_sel_ft[j] ),

			// HPM related control signals
			.mcounteren_i                    ( mcounteren_i              )

		  );
	end
endgenerate;

assign error_corrected_o = |err_corrected;
assign error_detected_o = |err_detected;
 

endmodule // cv32e40p_decoder_ft
