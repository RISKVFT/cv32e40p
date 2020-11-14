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
// Engineer:       Matthias Baer - baermatt@student.ethz.ch                   //
//                                                                            //
// Additional contributions by:                                               //
//                 Igor Loi - igor.loi@unibo.it                               //
//                 Andreas Traber - atraber@student.ethz.ch                   //
//                 Sven Stucki - svstucki@student.ethz.ch                     //
//                 Michael Gautschi - gautschi@iis.ee.ethz.ch                 //
//                 Davide Schiavone - pschiavo@iis.ee.ethz.ch                 //
//                 Robert Balas - balasr@iis.ee.ethz.ch                       //
//                 Andrea Bettati - andrea.bettati@studenti.unipr.it          //
//                                                                            //
// Design Name:    Main controller                                            //
// Project Name:   RI5CY                                                      //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Main CPU controller of the processor                       //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40p_controller_ft import cv32e40p_pkg::*;
#(
  parameter PULP_CLUSTER = 0,
  parameter PULP_XPULP   = 1
)
(
  // fault tolerant extra signals stating error correction and detection
  output logic		  error_corrected_o,
  output logic		  error_detected_o,

  //start of original entity
  input  logic        clk,                        // Gated clock
  input  logic        clk_ungated_i,              // Ungated clock
  input  logic        rst_n,

  input  logic        fetch_enable_i,             // Start the decoding
  output logic        ctrl_busy_o,                // Core is busy processing instructions
  output logic        is_decoding_o,              // Core is in decoding state
  input  logic        is_fetch_failed_i,

  // decoder related signals
  output logic        deassert_we_o,              // deassert write enable for next instruction

  input  logic        illegal_insn_i,             // decoder encountered an invalid instruction
  input  logic        ecall_insn_i,               // decoder encountered an ecall instruction
  input  logic        mret_insn_i,                // decoder encountered an mret instruction
  input  logic        uret_insn_i,                // decoder encountered an uret instruction

  input  logic        dret_insn_i,                // decoder encountered an dret instruction

  input  logic        mret_dec_i,
  input  logic        uret_dec_i,
  input  logic        dret_dec_i,

  input  logic        wfi_i,                      // decoder wants to execute a WFI
  input  logic        ebrk_insn_i,                // decoder encountered an ebreak instruction
  input  logic        fencei_insn_i,              // decoder encountered an fence.i instruction
  input  logic        csr_status_i,               // decoder encountered an csr status instruction

  output logic        hwlp_mask_o,                // prevent writes on the hwloop instructions in case interrupt are taken

  // from IF/ID pipeline
  input  logic        instr_valid_i,              // instruction coming from IF/ID pipeline is valid

  // from prefetcher
  output logic        instr_req_o,                // Start fetching instructions

  // to prefetcher
  output logic        pc_set_o,                   // jump to address set by pc_mux
  output logic [3:0]  pc_mux_o,                   // Selector in the Fetch stage to select the rigth PC (normal, jump ...)
  output logic [2:0]  exc_pc_mux_o,               // Selects target PC for exception
  output logic [1:0]  trap_addr_mux_o,            // Selects trap address base

  // HWLoop signls
  input  logic [31:0]       pc_id_i,
  input  logic              is_compressed_i,

  // from hwloop_regs
  input  logic [1:0] [31:0] hwlp_start_addr_i,
  input  logic [1:0] [31:0] hwlp_end_addr_i,
  input  logic [1:0] [31:0] hwlp_counter_i,

  // to hwloop_regs
  output logic [1:0]        hwlp_dec_cnt_o,

  output logic              hwlp_jump_o,
  output logic [31:0]       hwlp_targ_addr_o,

  // LSU
  input  logic        data_req_ex_i,              // data memory access is currently performed in EX stage
  input  logic        data_we_ex_i,
  input  logic        data_misaligned_i,
  input  logic        data_load_event_i,
  input  logic        data_err_i,
  output logic        data_err_ack_o,

  // from ALU
  input  logic        mult_multicycle_i,          // multiplier is taken multiple cycles and uses op c as storage

  // APU dependency checks
  input  logic        apu_en_i,
  input  logic        apu_read_dep_i,
  input  logic        apu_write_dep_i,

  output logic        apu_stall_o,

  // jump/branch signals
  input  logic        branch_taken_ex_i,          // branch taken signal from EX ALU
  input  logic [1:0]  ctrl_transfer_insn_in_id_i,               // jump is being calculated in ALU
  input  logic [1:0]  ctrl_transfer_insn_in_dec_i,              // jump is being calculated in ALU

  // Interrupt Controller Signals
  input  logic        irq_req_ctrl_i,
  input  logic        irq_sec_ctrl_i,
  input  logic [4:0]  irq_id_ctrl_i,
  input  logic        irq_wu_ctrl_i,
  input  PrivLvl_t    current_priv_lvl_i,

  output logic        irq_ack_o,
  output logic [4:0]  irq_id_o,

  output logic [4:0]  exc_cause_o,

  // Debug Signal
  output logic         debug_mode_o,
  output logic [2:0]   debug_cause_o,
  output logic         debug_csr_save_o,
  input  logic         debug_req_i,
  input  logic         debug_single_step_i,
  input  logic         debug_ebreakm_i,
  input  logic         debug_ebreaku_i,
  input  logic         trigger_match_i,
  output logic         debug_p_elw_no_sleep_o,
  output logic         debug_wfi_no_sleep_o,

  // Wakeup Signal
  output logic        wake_from_sleep_o,

  output logic        csr_save_if_o,
  output logic        csr_save_id_o,
  output logic        csr_save_ex_o,
  output logic [5:0]  csr_cause_o,
  output logic        csr_irq_sec_o,
  output logic        csr_restore_mret_id_o,
  output logic        csr_restore_uret_id_o,

  output logic        csr_restore_dret_id_o,

  output logic        csr_save_cause_o,


  // Regfile target
  input  logic        regfile_we_id_i,            // currently decoded we enable
  input  logic [5:0]  regfile_alu_waddr_id_i,     // currently decoded target address

  // Forwarding signals from regfile
  input  logic        regfile_we_ex_i,            // FW: write enable from  EX stage
  input  logic [5:0]  regfile_waddr_ex_i,         // FW: write address from EX stage
  input  logic        regfile_we_wb_i,            // FW: write enable from  WB stage
  input  logic        regfile_alu_we_fw_i,        // FW: ALU/MUL write enable from  EX stage

  // forwarding signals
  output logic [1:0]  operand_a_fw_mux_sel_o,     // regfile ra data selector form ID stage
  output logic [1:0]  operand_b_fw_mux_sel_o,     // regfile rb data selector form ID stage
  output logic [1:0]  operand_c_fw_mux_sel_o,     // regfile rc data selector form ID stage

  // forwarding detection signals
  input logic         reg_d_ex_is_reg_a_i,
  input logic         reg_d_ex_is_reg_b_i,
  input logic         reg_d_ex_is_reg_c_i,
  input logic         reg_d_wb_is_reg_a_i,
  input logic         reg_d_wb_is_reg_b_i,
  input logic         reg_d_wb_is_reg_c_i,
  input logic         reg_d_alu_is_reg_a_i,
  input logic         reg_d_alu_is_reg_b_i,
  input logic         reg_d_alu_is_reg_c_i,

  // stall signals
  output logic        halt_if_o,
  output logic        halt_id_o,

  output logic        misaligned_stall_o,
  output logic        jr_stall_o,
  output logic        load_stall_o,

  input  logic        id_ready_i,                 // ID stage is ready
  input  logic        id_valid_i,                 // ID stage is valid

  input  logic        ex_valid_i,                 // EX stage is done

  input  logic        wb_ready_i,                 // WB stage is ready

  // Performance Counters
  output logic        perf_jump_o,                // we are executing a jump instruction   (j, jr, jal, jalr)
  output logic        perf_jr_stall_o,            // stall due to jump-register-hazard
  output logic        perf_ld_stall_o,            // stall due to load-use-hazard
  output logic        perf_pipeline_stall_o       // stall due to elw extra cycles
);

  // FSM state encoding
	ctrl_state_e [0:2] ctrl_fsm_ns_ft;
	ctrl_state_e 	   ctrl_fsm_ns_voted;
	logic		[4:0] ctrl_fsm_ns_voted_tmp;




/////////////////////////// FAULT TOLERANT ///////////////////////////////////////////////

/////// LOGIC SIGNALS TOWARDS MAJORITY VOTER DEFINITION ///////////
// generated automatically by a script
//copy_signal
logic [0:2]       ctrl_busy_ft ;
logic [0:2]       is_decoding_ft ;
logic [0:2]       deassert_we_ft ;
logic [0:2]       hwlp_mask_ft ;
logic [0:2]       instr_req_ft ;
logic [0:2]       pc_set_ft ;
logic [0:2][3:0]  pc_mux_ft ;
logic [0:2][2:0]  exc_pc_mux_ft ;
logic [0:2][1:0]  trap_addr_mux_ft ;
logic [0:2][1:0]        hwlp_dec_cnt_ft ;
logic [0:2]             hwlp_jump_ft ;
logic [0:2][31:0]       hwlp_targ_addr_ft ;
logic [0:2]       data_err_ack_ft ;
logic [0:2]       apu_stall_ft ;
logic [0:2]       irq_ack_ft ;
logic [0:2][4:0]  irq_id_ft ;
logic [0:2][4:0]  exc_cause_ft ;
logic [0:2]        debug_mode_ft ;
logic [0:2][2:0]   debug_cause_ft ;
logic [0:2]        debug_csr_save_ft ;
logic [0:2]        debug_p_elw_no_sleep_ft ;
logic [0:2]        debug_wfi_no_sleep_ft ;
logic [0:2]       wake_from_sleep_ft ;
logic [0:2]       csr_save_if_ft ;
logic [0:2]       csr_save_id_ft ;
logic [0:2]       csr_save_ex_ft ;
logic [0:2][5:0]  csr_cause_ft ;
logic [0:2]       csr_irq_sec_ft ;
logic [0:2]       csr_restore_mret_id_ft ;
logic [0:2]       csr_restore_uret_id_ft ;
logic [0:2]       csr_restore_dret_id_ft ;
logic [0:2]       csr_save_cause_ft ;
logic [0:2][1:0]  operand_a_fw_mux_sel_ft ;
logic [0:2][1:0]  operand_b_fw_mux_sel_ft ;
logic [0:2][1:0]  operand_c_fw_mux_sel_ft ;
logic [0:2]       halt_if_ft ;
logic [0:2]       halt_id_ft ;
logic [0:2]       misaligned_stall_ft ;
logic [0:2]       jr_stall_ft ;
logic [0:2]       load_stall_ft ;
logic [0:2]       perf_jump_ft ;
logic [0:2]       perf_jr_stall_ft ;
logic [0:2]       perf_ld_stall_ft ;
logic [0:2]       perf_pipeline_stall_ft ;
//end_copy_signal
/////// END LOGIC SIGNALS TOWARDS MAJORITY VOTER DEFINITION ///////////


// other signals
logic [1:45]  err_corrected ;
logic [1:45]  err_detected ;


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
	.in_1_i           	( ctrl_busy_ft[0] 	 ),
	.in_2_i           	( ctrl_busy_ft[1] 	 ),
	.in_3_i           	( ctrl_busy_ft[2] 	 ),
	.voted_o          	( ctrl_busy_o  		 ),
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
	.in_1_i           	( is_decoding_ft[0] 	 ),
	.in_2_i           	( is_decoding_ft[1] 	 ),
	.in_3_i           	( is_decoding_ft[2] 	 ),
	.voted_o          	( is_decoding_o  		 ),
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
	.in_1_i           	( deassert_we_ft[0] 	 ),
	.in_2_i           	( deassert_we_ft[1] 	 ),
	.in_3_i           	( deassert_we_ft[2] 	 ),
	.voted_o          	( deassert_we_o  		 ),
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
	.in_1_i           	( hwlp_mask_ft[0] 	 ),
	.in_2_i           	( hwlp_mask_ft[1] 	 ),
	.in_3_i           	( hwlp_mask_ft[2] 	 ),
	.voted_o          	( hwlp_mask_o  		 ),
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
	.in_1_i           	( instr_req_ft[0] 	 ),
	.in_2_i           	( instr_req_ft[1] 	 ),
	.in_3_i           	( instr_req_ft[2] 	 ),
	.voted_o          	( instr_req_o  		 ),
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
	.in_1_i           	( pc_set_ft[0] 	 ),
	.in_2_i           	( pc_set_ft[1] 	 ),
	.in_3_i           	( pc_set_ft[2] 	 ),
	.voted_o          	( pc_set_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[6]	),
	.err_detected_o 	( err_detected[6] 	)
);


cv32e40p_3voter 
#(
	.L1			( 3+1	),
	.L2			( 1		)
)
voter_result_7
(
	.in_1_i           	( pc_mux_ft[0] 	 ),
	.in_2_i           	( pc_mux_ft[1] 	 ),
	.in_3_i           	( pc_mux_ft[2] 	 ),
	.voted_o          	( pc_mux_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[7]	),
	.err_detected_o 	( err_detected[7] 	)
);


cv32e40p_3voter 
#(
	.L1			( 2+1	),
	.L2			( 1		)
)
voter_result_8
(
	.in_1_i           	( exc_pc_mux_ft[0] 	 ),
	.in_2_i           	( exc_pc_mux_ft[1] 	 ),
	.in_3_i           	( exc_pc_mux_ft[2] 	 ),
	.voted_o          	( exc_pc_mux_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[8]	),
	.err_detected_o 	( err_detected[8] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1+1	),
	.L2			( 1		)
)
voter_result_9
(
	.in_1_i           	( trap_addr_mux_ft[0] 	 ),
	.in_2_i           	( trap_addr_mux_ft[1] 	 ),
	.in_3_i           	( trap_addr_mux_ft[2] 	 ),
	.voted_o          	( trap_addr_mux_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[9]	),
	.err_detected_o 	( err_detected[9] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1+1	),
	.L2			( 1		)
)
voter_result_10
(
	.in_1_i           	( hwlp_dec_cnt_ft[0] 	 ),
	.in_2_i           	( hwlp_dec_cnt_ft[1] 	 ),
	.in_3_i           	( hwlp_dec_cnt_ft[2] 	 ),
	.voted_o          	( hwlp_dec_cnt_o  		 ),
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
	.in_1_i           	( hwlp_jump_ft[0] 	 ),
	.in_2_i           	( hwlp_jump_ft[1] 	 ),
	.in_3_i           	( hwlp_jump_ft[2] 	 ),
	.voted_o          	( hwlp_jump_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[11]	),
	.err_detected_o 	( err_detected[11] 	)
);


cv32e40p_3voter 
#(
	.L1			( 31+1	),
	.L2			( 1		)
)
voter_result_12
(
	.in_1_i           	( hwlp_targ_addr_ft[0] 	 ),
	.in_2_i           	( hwlp_targ_addr_ft[1] 	 ),
	.in_3_i           	( hwlp_targ_addr_ft[2] 	 ),
	.voted_o          	( hwlp_targ_addr_o  		 ),
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
	.in_1_i           	( data_err_ack_ft[0] 	 ),
	.in_2_i           	( data_err_ack_ft[1] 	 ),
	.in_3_i           	( data_err_ack_ft[2] 	 ),
	.voted_o          	( data_err_ack_o  		 ),
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
	.in_1_i           	( apu_stall_ft[0] 	 ),
	.in_2_i           	( apu_stall_ft[1] 	 ),
	.in_3_i           	( apu_stall_ft[2] 	 ),
	.voted_o          	( apu_stall_o  		 ),
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
	.in_1_i           	( irq_ack_ft[0] 	 ),
	.in_2_i           	( irq_ack_ft[1] 	 ),
	.in_3_i           	( irq_ack_ft[2] 	 ),
	.voted_o          	( irq_ack_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[15]	),
	.err_detected_o 	( err_detected[15] 	)
);


cv32e40p_3voter 
#(
	.L1			( 4+1	),
	.L2			( 1		)
)
voter_result_16
(
	.in_1_i           	( irq_id_ft[0] 	 ),
	.in_2_i           	( irq_id_ft[1] 	 ),
	.in_3_i           	( irq_id_ft[2] 	 ),
	.voted_o          	( irq_id_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[16]	),
	.err_detected_o 	( err_detected[16] 	)
);


cv32e40p_3voter 
#(
	.L1			( 4+1	),
	.L2			( 1		)
)
voter_result_17
(
	.in_1_i           	( exc_cause_ft[0] 	 ),
	.in_2_i           	( exc_cause_ft[1] 	 ),
	.in_3_i           	( exc_cause_ft[2] 	 ),
	.voted_o          	( exc_cause_o  		 ),
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
	.in_1_i           	( debug_mode_ft[0] 	 ),
	.in_2_i           	( debug_mode_ft[1] 	 ),
	.in_3_i           	( debug_mode_ft[2] 	 ),
	.voted_o          	( debug_mode_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[18]	),
	.err_detected_o 	( err_detected[18] 	)
);


cv32e40p_3voter 
#(
	.L1			( 2+1	),
	.L2			( 1		)
)
voter_result_19
(
	.in_1_i           	( debug_cause_ft[0] 	 ),
	.in_2_i           	( debug_cause_ft[1] 	 ),
	.in_3_i           	( debug_cause_ft[2] 	 ),
	.voted_o          	( debug_cause_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[19]	),
	.err_detected_o 	( err_detected[19] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_20
(
	.in_1_i           	( debug_csr_save_ft[0] 	 ),
	.in_2_i           	( debug_csr_save_ft[1] 	 ),
	.in_3_i           	( debug_csr_save_ft[2] 	 ),
	.voted_o          	( debug_csr_save_o  		 ),
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
	.in_1_i           	( debug_p_elw_no_sleep_ft[0] 	 ),
	.in_2_i           	( debug_p_elw_no_sleep_ft[1] 	 ),
	.in_3_i           	( debug_p_elw_no_sleep_ft[2] 	 ),
	.voted_o          	( debug_p_elw_no_sleep_o  		 ),
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
	.in_1_i           	( debug_wfi_no_sleep_ft[0] 	 ),
	.in_2_i           	( debug_wfi_no_sleep_ft[1] 	 ),
	.in_3_i           	( debug_wfi_no_sleep_ft[2] 	 ),
	.voted_o          	( debug_wfi_no_sleep_o  		 ),
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
	.in_1_i           	( wake_from_sleep_ft[0] 	 ),
	.in_2_i           	( wake_from_sleep_ft[1] 	 ),
	.in_3_i           	( wake_from_sleep_ft[2] 	 ),
	.voted_o          	( wake_from_sleep_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[23]	),
	.err_detected_o 	( err_detected[23] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_24
(
	.in_1_i           	( csr_save_if_ft[0] 	 ),
	.in_2_i           	( csr_save_if_ft[1] 	 ),
	.in_3_i           	( csr_save_if_ft[2] 	 ),
	.voted_o          	( csr_save_if_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[24]	),
	.err_detected_o 	( err_detected[24] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_25
(
	.in_1_i           	( csr_save_id_ft[0] 	 ),
	.in_2_i           	( csr_save_id_ft[1] 	 ),
	.in_3_i           	( csr_save_id_ft[2] 	 ),
	.voted_o          	( csr_save_id_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[25]	),
	.err_detected_o 	( err_detected[25] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_26
(
	.in_1_i           	( csr_save_ex_ft[0] 	 ),
	.in_2_i           	( csr_save_ex_ft[1] 	 ),
	.in_3_i           	( csr_save_ex_ft[2] 	 ),
	.voted_o          	( csr_save_ex_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[26]	),
	.err_detected_o 	( err_detected[26] 	)
);


cv32e40p_3voter 
#(
	.L1			( 5+1	),
	.L2			( 1		)
)
voter_result_27
(
	.in_1_i           	( csr_cause_ft[0] 	 ),
	.in_2_i           	( csr_cause_ft[1] 	 ),
	.in_3_i           	( csr_cause_ft[2] 	 ),
	.voted_o          	( csr_cause_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[27]	),
	.err_detected_o 	( err_detected[27] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_28
(
	.in_1_i           	( csr_irq_sec_ft[0] 	 ),
	.in_2_i           	( csr_irq_sec_ft[1] 	 ),
	.in_3_i           	( csr_irq_sec_ft[2] 	 ),
	.voted_o          	( csr_irq_sec_o  		 ),
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
	.in_1_i           	( csr_restore_mret_id_ft[0] 	 ),
	.in_2_i           	( csr_restore_mret_id_ft[1] 	 ),
	.in_3_i           	( csr_restore_mret_id_ft[2] 	 ),
	.voted_o          	( csr_restore_mret_id_o  		 ),
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
	.in_1_i           	( csr_restore_uret_id_ft[0] 	 ),
	.in_2_i           	( csr_restore_uret_id_ft[1] 	 ),
	.in_3_i           	( csr_restore_uret_id_ft[2] 	 ),
	.voted_o          	( csr_restore_uret_id_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[30]	),
	.err_detected_o 	( err_detected[30] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_31
(
	.in_1_i           	( csr_restore_dret_id_ft[0] 	 ),
	.in_2_i           	( csr_restore_dret_id_ft[1] 	 ),
	.in_3_i           	( csr_restore_dret_id_ft[2] 	 ),
	.voted_o          	( csr_restore_dret_id_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[31]	),
	.err_detected_o 	( err_detected[31] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_32
(
	.in_1_i           	( csr_save_cause_ft[0] 	 ),
	.in_2_i           	( csr_save_cause_ft[1] 	 ),
	.in_3_i           	( csr_save_cause_ft[2] 	 ),
	.voted_o          	( csr_save_cause_o  		 ),
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
	.in_1_i           	( operand_a_fw_mux_sel_ft[0] 	 ),
	.in_2_i           	( operand_a_fw_mux_sel_ft[1] 	 ),
	.in_3_i           	( operand_a_fw_mux_sel_ft[2] 	 ),
	.voted_o          	( operand_a_fw_mux_sel_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[33]	),
	.err_detected_o 	( err_detected[33] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1+1	),
	.L2			( 1		)
)
voter_result_34
(
	.in_1_i           	( operand_b_fw_mux_sel_ft[0] 	 ),
	.in_2_i           	( operand_b_fw_mux_sel_ft[1] 	 ),
	.in_3_i           	( operand_b_fw_mux_sel_ft[2] 	 ),
	.voted_o          	( operand_b_fw_mux_sel_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[34]	),
	.err_detected_o 	( err_detected[34] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1+1	),
	.L2			( 1		)
)
voter_result_35
(
	.in_1_i           	( operand_c_fw_mux_sel_ft[0] 	 ),
	.in_2_i           	( operand_c_fw_mux_sel_ft[1] 	 ),
	.in_3_i           	( operand_c_fw_mux_sel_ft[2] 	 ),
	.voted_o          	( operand_c_fw_mux_sel_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[35]	),
	.err_detected_o 	( err_detected[35] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_36
(
	.in_1_i           	( halt_if_ft[0] 	 ),
	.in_2_i           	( halt_if_ft[1] 	 ),
	.in_3_i           	( halt_if_ft[2] 	 ),
	.voted_o          	( halt_if_o  		 ),
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
	.in_1_i           	( halt_id_ft[0] 	 ),
	.in_2_i           	( halt_id_ft[1] 	 ),
	.in_3_i           	( halt_id_ft[2] 	 ),
	.voted_o          	( halt_id_o  		 ),
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
	.in_1_i           	( misaligned_stall_ft[0] 	 ),
	.in_2_i           	( misaligned_stall_ft[1] 	 ),
	.in_3_i           	( misaligned_stall_ft[2] 	 ),
	.voted_o          	( misaligned_stall_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[38]	),
	.err_detected_o 	( err_detected[38] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_39
(
	.in_1_i           	( jr_stall_ft[0] 	 ),
	.in_2_i           	( jr_stall_ft[1] 	 ),
	.in_3_i           	( jr_stall_ft[2] 	 ),
	.voted_o          	( jr_stall_o  		 ),
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
	.in_1_i           	( load_stall_ft[0] 	 ),
	.in_2_i           	( load_stall_ft[1] 	 ),
	.in_3_i           	( load_stall_ft[2] 	 ),
	.voted_o          	( load_stall_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[40]	),
	.err_detected_o 	( err_detected[40] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_41
(
	.in_1_i           	( perf_jump_ft[0] 	 ),
	.in_2_i           	( perf_jump_ft[1] 	 ),
	.in_3_i           	( perf_jump_ft[2] 	 ),
	.voted_o          	( perf_jump_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[41]	),
	.err_detected_o 	( err_detected[41] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_42
(
	.in_1_i           	( perf_jr_stall_ft[0] 	 ),
	.in_2_i           	( perf_jr_stall_ft[1] 	 ),
	.in_3_i           	( perf_jr_stall_ft[2] 	 ),
	.voted_o          	( perf_jr_stall_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[42]	),
	.err_detected_o 	( err_detected[42] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_43
(
	.in_1_i           	( perf_ld_stall_ft[0] 	 ),
	.in_2_i           	( perf_ld_stall_ft[1] 	 ),
	.in_3_i           	( perf_ld_stall_ft[2] 	 ),
	.voted_o          	( perf_ld_stall_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[43]	),
	.err_detected_o 	( err_detected[43] 	)
);


cv32e40p_3voter 
#(
	.L1			( 1	),
	.L2			( 1		)
)
voter_result_44
(
	.in_1_i           	( perf_pipeline_stall_ft[0] 	 ),
	.in_2_i           	( perf_pipeline_stall_ft[1] 	 ),
	.in_3_i           	( perf_pipeline_stall_ft[2] 	 ),
	.voted_o          	( perf_pipeline_stall_o  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[44]	),
	.err_detected_o 	( err_detected[44] 	)
);
//end_copy_instance
/////// END INSTANCES OF MAJORITY VOTER ///////////

/////////////////////////// END FAULT TOLERANT ///////////////////////////////////////////////

/////////////// TMR //////////////////////

cv32e40p_3voter 
#(
	.L1			( 5	),
	.L2			( 1		)
)
voter_result_45
(
	.in_1_i           	( ctrl_fsm_ns_ft[0] 	 ),
	.in_2_i           	( ctrl_fsm_ns_ft[1] 	 ),
	.in_3_i           	( ctrl_fsm_ns_ft[2] 	 ),
	.voted_o          	( ctrl_fsm_ns_voted_tmp  		 ),
	.err_detected_1 	(  ),
	.err_detected_2 	(  ),
	.err_detected_3 	(  ),
	.err_corrected_o  	( err_corrected[45]	),
	.err_detected_o 	( err_detected[45] 	)
);

assign ctrl_fsm_ns_voted = ctrl_state_e'(ctrl_fsm_ns_voted_tmp);

genvar j;

generate
	for (j = 0; j<3; j++) begin

	cv32e40p_controller_feedback
	  #(
		.PULP_CLUSTER ( PULP_CLUSTER ),
		.PULP_XPULP   ( PULP_XPULP   )
	  )
	  controller_i
	  (
		.clk                            ( clk                    ),         // Gated clock
		.clk_ungated_i                  ( clk_ungated_i          ),         // Ungated clock
		.rst_n                          ( rst_n                  ),

		.fetch_enable_i                 ( fetch_enable_i         ),
		.ctrl_busy_o			( ctrl_busy_ft[j]			),
		.is_decoding_o			( is_decoding_ft[j]			),
		.is_fetch_failed_i              ( is_fetch_failed_i      ),

		// decoder related signals
		.deassert_we_o			( deassert_we_ft[j]			),

		.illegal_insn_i                 ( illegal_insn_i       ),
		.ecall_insn_i                   ( ecall_insn_i         ),
		.mret_insn_i                    ( mret_insn_i          ),
		.uret_insn_i                    ( uret_insn_i          ),

		.dret_insn_i                    ( dret_insn_i          ),

		.mret_dec_i                     ( mret_dec_i               ),
		.uret_dec_i                     ( uret_dec_i               ),
		.dret_dec_i                     ( dret_dec_i               ),


		.wfi_i                          ( wfi_i           ),
		.ebrk_insn_i                    ( ebrk_insn_i              ),
		.fencei_insn_i                  ( fencei_insn_i        ),
		.csr_status_i                   ( csr_status_i             ),

		.hwlp_mask_o			( hwlp_mask_ft[j]			),

		// from IF/ID pipeline
		.instr_valid_i                  ( instr_valid_i          ),

		// from prefetcher
		.instr_req_o			( instr_req_ft[j]			),

		// to prefetcher
		.pc_set_o			( pc_set_ft[j]			),
		.pc_mux_o			( pc_mux_ft[j]			),
		.exc_pc_mux_o			( exc_pc_mux_ft[j]			),
		.exc_cause_o			( exc_cause_ft[j]			),
		.trap_addr_mux_o			( trap_addr_mux_ft[j]			),

		 // HWLoop signls
		.pc_id_i                        ( pc_id_i                ),
		.is_compressed_i                ( is_compressed_i        ),

		.hwlp_start_addr_i              ( hwlp_start_addr_i           ),
		.hwlp_end_addr_i                ( hwlp_end_addr_i             ),
		.hwlp_counter_i                 ( hwlp_counter_i             ),
		.hwlp_dec_cnt_o			( hwlp_dec_cnt_ft[j]			),

		.hwlp_jump_o			( hwlp_jump_ft[j]			),
		.hwlp_targ_addr_o			( hwlp_targ_addr_ft[j]			),

		// LSU
		.data_req_ex_i                  ( data_req_ex_i          ),
		.data_we_ex_i                   ( data_we_ex_i           ),
		.data_misaligned_i              ( data_misaligned_i      ),
		.data_load_event_i              ( data_load_event_i     ),
		.data_err_i                     ( data_err_i             ),
		.data_err_ack_o			( data_err_ack_ft[j]			),

		// ALU
		.mult_multicycle_i              ( mult_multicycle_i      ),

		// APU
		.apu_en_i                       ( apu_en_i                 ),
		.apu_read_dep_i                 ( apu_read_dep_i         ),
		.apu_write_dep_i                ( apu_write_dep_i        ),

		.apu_stall_o			( apu_stall_ft[j]			),

		// jump/branch control
		.branch_taken_ex_i              ( branch_taken_ex_i        ),
		.ctrl_transfer_insn_in_id_i     ( ctrl_transfer_insn_in_id_i  ),
		.ctrl_transfer_insn_in_dec_i    ( ctrl_transfer_insn_in_dec_i ),

		// Interrupt signals
		.irq_wu_ctrl_i                  ( irq_wu_ctrl_i            ),
		.irq_req_ctrl_i                 ( irq_req_ctrl_i           ),
		.irq_sec_ctrl_i                 ( irq_sec_ctrl_i           ),
		.irq_id_ctrl_i                  ( irq_id_ctrl_i            ),
		.current_priv_lvl_i             ( current_priv_lvl_i     ),
		.irq_ack_o			( irq_ack_ft[j]			),
		.irq_id_o			( irq_id_ft[j]			),

		// Debug Signal
		.debug_mode_o			( debug_mode_ft[j]			),
		.debug_cause_o			( debug_cause_ft[j]			),
		.debug_csr_save_o			( debug_csr_save_ft[j]			),
		.debug_req_i                    ( debug_req_i            ),
		.debug_single_step_i            ( debug_single_step_i    ),
		.debug_ebreakm_i                ( debug_ebreakm_i        ),
		.debug_ebreaku_i                ( debug_ebreaku_i        ),
		.trigger_match_i                ( trigger_match_i        ),
		.debug_p_elw_no_sleep_o			( debug_p_elw_no_sleep_ft[j]			),
		.debug_wfi_no_sleep_o			( debug_wfi_no_sleep_ft[j]			),

		// Wakeup Signal
		.wake_from_sleep_o			( wake_from_sleep_ft[j]			),

		// CSR Controller Signals
		.csr_save_cause_o			( csr_save_cause_ft[j]			),
		.csr_cause_o			( csr_cause_ft[j]			),
		.csr_save_if_o			( csr_save_if_ft[j]			),
		.csr_save_id_o			( csr_save_id_ft[j]			),
		.csr_save_ex_o			( csr_save_ex_ft[j]			),
		.csr_restore_mret_id_o			( csr_restore_mret_id_ft[j]			),
		.csr_restore_uret_id_o			( csr_restore_uret_id_ft[j]			),

		.csr_restore_dret_id_o			( csr_restore_dret_id_ft[j]			),

		.csr_irq_sec_o			( csr_irq_sec_ft[j]			),

		// Write targets from ID
		.regfile_we_id_i                ( regfile_we_id_i  ),
		.regfile_alu_waddr_id_i         ( regfile_alu_waddr_id_i   ),

		// Forwarding signals from regfile
		.regfile_we_ex_i                ( regfile_we_ex_i        ),
		.regfile_waddr_ex_i             ( regfile_waddr_ex_i     ),
		.regfile_we_wb_i                ( regfile_we_wb_i        ),

		// regfile port 2
		.regfile_alu_we_fw_i            ( regfile_alu_we_fw_i    ),

		// Forwarding detection signals
		.reg_d_ex_is_reg_a_i            ( reg_d_ex_is_reg_a_i   ),
		.reg_d_ex_is_reg_b_i            ( reg_d_ex_is_reg_b_i   ),
		.reg_d_ex_is_reg_c_i            ( reg_d_ex_is_reg_c_i   ),
		.reg_d_wb_is_reg_a_i            ( reg_d_wb_is_reg_a_i   ),
		.reg_d_wb_is_reg_b_i            ( reg_d_wb_is_reg_b_i   ),
		.reg_d_wb_is_reg_c_i            ( reg_d_wb_is_reg_c_i   ),
		.reg_d_alu_is_reg_a_i           ( reg_d_alu_is_reg_a_i  ),
		.reg_d_alu_is_reg_b_i           ( reg_d_alu_is_reg_b_i  ),
		.reg_d_alu_is_reg_c_i           ( reg_d_alu_is_reg_c_i  ),

		// Forwarding signals
		.operand_a_fw_mux_sel_o			( operand_a_fw_mux_sel_ft[j]			),
		.operand_b_fw_mux_sel_o			( operand_b_fw_mux_sel_ft[j]			),
		.operand_c_fw_mux_sel_o			( operand_c_fw_mux_sel_ft[j]			),

		// Stall signals
		.halt_if_o			( halt_if_ft[j]			),
		.halt_id_o			( halt_id_ft[j]			),

		.misaligned_stall_o			( misaligned_stall_ft[j]			),
		.jr_stall_o					( jr_stall_ft[j]			),
		.load_stall_o			( load_stall_ft[j]			),

		.id_ready_i                     ( id_ready_i             ),
		.id_valid_i                     ( id_valid_i             ),

		.ex_valid_i                     ( ex_valid_i             ),

		.wb_ready_i                     ( wb_ready_i             ),

		// Performance Counters
		.perf_jump_o			( perf_jump_ft[j]			),
		.perf_jr_stall_o			( perf_jr_stall_ft[j]			),
		.perf_ld_stall_o			( perf_ld_stall_ft[j]			),
		.perf_pipeline_stall_o			( perf_pipeline_stall_ft[j]			),
		.ctrl_fsm_ns_i					( ctrl_fsm_ns_voted  	 ),
  		.ctrl_fsm_ns_o 					( ctrl_fsm_ns_ft[j] 	 )
	  );

	end

endgenerate;


assign error_corrected_o = |err_corrected;
assign error_detected_o = |err_detected;

endmodule // cv32e40p_controller
