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
//                                                                            //
// Additional contributions by:                                               //
//                 Igor Loi - igor.loi@unibo.it                               //
//                 Andreas Traber - atraber@student.ethz.ch                   //
//                 Sven Stucki - svstucki@student.ethz.ch                     //
//                                                                            //
// Design Name:    Instruction Fetch Stage                                    //
// Project Name:   RI5CY                                                      //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Instruction fetch unit: Selection of the next PC, and      //
//                 buffering (sampling) of the read instruction               //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40p_if_stage
#(
  parameter PULP_XPULP      = 0,                        // PULP ISA Extension (including PULP specific CSRs and hardware loop, excluding p.elw)
  parameter PULP_OBI        = 0,                        // Legacy PULP OBI behavior
  parameter PULP_SECURE     = 0,
  parameter FPU             = 0
)
(
    input  logic        clk,
    input  logic        rst_n,

    // Used to calculate the exception offsets
    input  logic [23:0] m_trap_base_addr_i, // cs_registers_i
    input  logic [23:0] u_trap_base_addr_i, // cs_registers_i
    input  logic  [1:0] trap_addr_mux_i, // id_stage_i
    // Boot address
    input  logic [31:0] boot_addr_i, // core in 
    input  logic [31:0] dm_exception_addr_i, // core in

    // Debug mode halt address
    input  logic [31:0] dm_halt_addr_i, // core in

    // instruction request control
    input  logic        req_i, // id_stage_i

    // instruction cache interface
    output logic                   instr_req_o, 
    output logic            [31:0] instr_addr_o,
    input  logic                   instr_gnt_i, // pmp_unit_i
    input  logic                   instr_rvalid_i,  // core in
    input  logic            [31:0] instr_rdata_i, // core in
    input  logic                   instr_err_i,   // 0 fisso  // External bus error (validity defined by instr_rvalid_i) (not used yet)
    input  logic                   instr_err_pmp_i, // pmp_unit_i // PMP error (validity defined by instr_gnt_i)

    // Output of IF Pipeline stage
    output logic              instr_valid_id_o,      // instruction in IF/ID pipeline is valid
    output logic       [31:0] instr_rdata_id_o,      // read instruction is sampled and sent to ID stage for decoding
    output logic              is_compressed_id_o,    // compressed decoder thinks this is a compressed instruction
    output logic              illegal_c_insn_id_o,   // compressed decoder thinks this is an invalid instruction
    output logic [2:0][31:0] pc_if_o, //PB out 
    output logic       [31:0] pc_id_o,
    output logic              is_fetch_failed_o,

    // Forwarding ports - control signals
    input  logic        clear_instr_valid_i,   // clear instruction valid bit in IF/ID pipe (id_stage_i)
    input  logic        pc_set_i,              // set the program counter to a new value (id_stage_i)
    input  logic [31:0] mepc_i,                // address used to restore PC when the interrupt/exception is served (cs_registers_i)
    input  logic [31:0] uepc_i,                // address used to restore PC when the interrupt/exception is served (cs_registers_i)

    input  logic [31:0] depc_i,                // address used to restore PC when the debug is served (cs_registers_i)

    input  logic  [3:0] pc_mux_i,              // sel for pc multiplexer (id_stage_i)
    input  logic  [2:0] exc_pc_mux_i,          // selects ISR address (id_stage_i)

    input  logic  [4:0] m_exc_vec_pc_mux_i,    // selects ISR address for vectorized interrupt lines (id_stage_i e core)
    input  logic  [4:0] u_exc_vec_pc_mux_i,    // selects ISR address for vectorized interrupt lines (id_stage_i e core)
    output logic        csr_mtvec_init_o,      // tell CS regfile to init mtvec (id_stage_i)

    // jump and branch target and decision
    input  logic [31:0] jump_target_id_i,      // jump target address (id_stage_i)
    input  logic [31:0] jump_target_ex_i,      // jump target address (ex_stage_i)

    // from hwloop controller
    input  logic        hwlp_jump_i, // id_stage_i //PB in
    input  logic [31:0] hwlp_target_i, //id_stage_i  //PB in

    // pipeline stall
    input  logic        halt_if_i, // id_stage_i
    input  logic        id_ready_i, // id_stage_i

    // misc signals
    output logic        if_busy_o,             // is the IF stage busy fetching instructions?
    output logic        perf_imiss_o           // Instruction Fetch Miss
);

  import cv32e40p_pkg::*;

  logic  [2:0]            if_valid, if_ready; //PB in

  // prefetch buffer related signals
  logic              prefetch_busy;
  logic [2:0]             branch_req; //PB in
  logic [2:0]      [31:0] branch_addr_n; // PB in

  logic [2:0]             fetch_valid; //PB in
  logic [2:0]             fetch_ready; //PB 
  logic [2:0]      [31:0] fetch_rdata; //PB in 

  logic       [31:0] exc_pc;

  logic [23:0]       trap_base_addr;
  logic  [4:0]       exc_vec_pc_mux;
  logic              fetch_failed;

  logic [2:0]             aligner_ready; //PB out
  logic [2:0]             instr_valid; //PB out

  logic [2:0]             illegal_c_insn;
  logic [2:0][31:0]       instr_aligned; //PB out
  logic [2:0][31:0]       instr_decompressed;
  logic [2:0]             instr_compressed_int;
  logic [2:0][31:0] 	branch_addr_n_to_vote;


  ///////////////////////////////////////////////////////////////////////////////////////////
  //
  // Exception PC selection mux
  //
  ///////////////////////////////////////////////////////////////////////////////////////////
  genvar i;
  generate
  	for (i=0; i<3; i=i+1) begin
	  always_comb
	  begin : EXC_PC_MUX
	    unique case (trap_addr_mux_i[i])
	      TRAP_MACHINE:  trap_base_addr[i] = m_trap_base_addr_i[i];
	      TRAP_USER:     trap_base_addr[i] = u_trap_base_addr_i[i];
	      default:       trap_base_addr[i] = m_trap_base_addr_i[i];
	    endcase

	    unique case (trap_addr_mux_i[i])
	      TRAP_MACHINE:  exc_vec_pc_mux[i] = m_exc_vec_pc_mux_i[i];
	      TRAP_USER:     exc_vec_pc_mux[i] = u_exc_vec_pc_mux_i[i];
	      default:       exc_vec_pc_mux[i] = m_exc_vec_pc_mux_i[i];
	    endcase

	    unique case (exc_pc_mux_i[i])
	      EXC_PC_EXCEPTION:                        exc_pc[i] = { trap_base_addr[i], 8'h0 }; //1.10 all the exceptions go to base address
	      EXC_PC_IRQ:                              exc_pc[i] = { trap_base_addr[i], 1'b0, exc_vec_pc_mux[i], 2'b0 }; // interrupts are vectored
	      EXC_PC_DBD:                              exc_pc[i] = { dm_halt_addr_i[i][31:2], 2'b0 };
	      EXC_PC_DBE:                              exc_pc[i] = { dm_exception_addr_i[i][31:2], 2'b0 };
	      default:                                 exc_pc[i] = { trap_base_addr[i], 8'h0 };
	    endcase
	  end

	  // fetch address selection
	  always_comb
	  begin
	    // Default assign PC_BOOT (should be overwritten in below case)
	    branch_addr_n[i] = {boot_addr_i[i][31:2], 2'b0};

	    unique case (pc_mux_i[i])
	      PC_BOOT:      branch_addr_n_to_vote[i] = {boot_addr_i[i][31:2], 2'b0};
	      PC_JUMP:      branch_addr_n_to_vote[i] = jump_target_id_i[i];
	      PC_BRANCH:    branch_addr_n_to_vote[i] = jump_target_ex_i[i];
	      PC_EXCEPTION: branch_addr_n_to_vote[i] = exc_pc[i];             // set PC to exception handler
	      PC_MRET:      branch_addr_n_to_vote[i] = mepc_i[i]; // PC is restored when returning from IRQ/exception
	      PC_URET:      branch_addr_n_to_vote[i] = uepc_i[i]; // PC is restored when returning from IRQ/exception
	      PC_DRET:      branch_addr_n_to_vote[i] = depc_i[i]; //
	      PC_FENCEI:    branch_addr_n_to_vote[i] = pc_id_o[i] + 4; // jump to next instr forces prefetch buffer reload
	      PC_HWLOOP:    branch_addr_n_to_vote[i] = hwlp_target_i[i];
	      default:;
	    endcase
	  end
	end
  endgenerate
	cv32e40p_conf_voter
	#(
		.L1(32),
		.TOUT(CDEC_TOUT[0])
	) v_instr_o
	(
		.to_vote_i( branch_addr_n_to_vote ),
		.voted_o( branch_addr_n),
		.block_err_o( branch_addr_n_block_err),
		.broken_block_i(is_broken_o),
		.err_detected_o(err_detected[0]),
		.err_corrected_o(err_corrected[0])
	);



  // tell CS register file to initialize mtvec on boot
  assign csr_mtvec_init_o = (pc_mux_i == PC_BOOT) & pc_set_i;

  assign fetch_failed    = 1'b0; // PMP is not supported in CV32E40P

  // prefetch buffer, caches a fixed number of instructions
  cv32e40p_prefetch_buffer
  #(
    .PULP_OBI          ( PULP_OBI                    ),
    .PULP_XPULP        ( PULP_XPULP                  )
  )
  prefetch_buffer_i
  (
    .clk               ( clk                         ),
    .rst_n             ( rst_n                       ),

    .req_i             ( req_i                       ),

    .branch_i          ( branch_req                  ),
    .branch_addr_i     ( {branch_addr_n[31:1], 1'b0} ),

    .hwlp_jump_i       ( hwlp_jump_i                 ),
    .hwlp_target_i     ( hwlp_target_i               ),

    .fetch_ready_i     ( fetch_ready[0]                 ),
    .fetch_valid_o     ( fetch_valid[0]                 ),
    .fetch_rdata_o     ( fetch_rdata[0]                 ),

    // goes to instruction memory / instruction cache
    .instr_req_o       ( instr_req_o                 ),
    .instr_addr_o      ( instr_addr_o                ),
    .instr_gnt_i       ( instr_gnt_i                 ),
    .instr_rvalid_i    ( instr_rvalid_i              ),
    .instr_err_i       ( instr_err_i                 ),     // Not supported (yet)
    .instr_err_pmp_i   ( instr_err_pmp_i             ),     // Not supported (yet)
    .instr_rdata_i     ( instr_rdata_i               ),

    // Prefetch Buffer Status
    .busy_o            ( prefetch_busy               )
);

  // offset FSM state transition logic
  always_comb
  begin

    fetch_ready[0]   = 1'b0;
    branch_req[0]    = 1'b0;
    // take care of jumps and branches
    if (pc_set_i) begin
      branch_req[0]    = 1'b1;
    end
    else if (fetch_valid[0]) begin
      if (req_i && if_valid[0]) begin
        fetch_ready[0]   = aligner_ready[0];
      end
    end
  end

  assign if_busy_o       = prefetch_busy;
  assign perf_imiss_o    = (~fetch_valid[0]) | branch_req[0];

  // IF-ID pipeline registers, frozen when the ID stage is stalled
  always_ff @(posedge clk, negedge rst_n)
  begin : IF_ID_PIPE_REGISTERS
    if (rst_n == 1'b0)
    begin
      instr_valid_id_o      <= 1'b0;
      instr_rdata_id_o      <= '0;
      is_fetch_failed_o     <= 1'b0;
      pc_id_o               <= '0;
      is_compressed_id_o    <= 1'b0;
      illegal_c_insn_id_o   <= 1'b0;
    end
    else
    begin

      if (if_valid[0] && instr_valid[0])
      begin
        instr_valid_id_o    <= 1'b1;
        instr_rdata_id_o    <= instr_decompressed[0];
        is_compressed_id_o  <= instr_compressed_int[0];
        illegal_c_insn_id_o <= illegal_c_insn[0];
        is_fetch_failed_o   <= 1'b0;
        pc_id_o             <= pc_if_o[0];
      end else if (clear_instr_valid_i) begin
        instr_valid_id_o    <= 1'b0;
        is_fetch_failed_o   <= fetch_failed;
      end
    end
    end

  assign if_ready[0] = fetch_valid[0] & id_ready_i;
  assign if_ready[1] = fetch_valid[1] & id_ready_i;
  assign if_ready[2] = fetch_valid[2] & id_ready_i;
  assign if_valid[0] = (~halt_if_i) & if_ready[0];
  assign if_valid[1] = (~halt_if_i) & if_ready[1];
  assign if_valid[2] = (~halt_if_i) & if_ready[2];

  cv32e40p_aligner_ft aligner_i
  (
    .clk               ( clk                          ),
    .rst_n             ( rst_n                        ),
    .fetch_valid_i     ( fetch_valid                  ),
    .aligner_ready_o   ( aligner_ready                ),
    .if_valid_i        ( if_valid                     ),
    .fetch_rdata_i     ( fetch_rdata                  ),
    .instr_aligned_o   ( instr_aligned                ),
    .instr_valid_o     ( instr_valid                  ),
    .branch_addr_i     ( {{branch_addr_n[2][31:1], 1'b0},{branch_addr_n[1][31:1], 1'b0},{branch_addr_n[0][31:1], 1'b0}}  ),
    .branch_i          ( branch_req                   ),
    .hwlp_addr_i       ( { hwlp_target_i,hwlp_target_i,hwlp_target_i } ),
    .hwlp_update_pc_i  ( { hwlp_jump_i, hwlp_jump_i, hwlp_jump_i} ),
    .pc_o              ( pc_if_o                      ),
    .set_broken_i      ('0),
    .is_broken_o       (),
    .err_detected_o    (),
    .err_corrected_o   ()
  );

  cv32e40p_compressed_decoder_ft
    #(
      .FPU(FPU)
     )
  compressed_decoder_i
  (

	.clk(clk),
	.rst_n(rst_n),
	.instr_i         ( instr_aligned        ),
	.instr_o         ( instr_decompressed   ),
	.is_compressed_o ( instr_compressed_int ),
	.illegal_instr_o ( illegal_c_insn       ),
	.set_broken_i('0),
	.is_broken_o(),
	.err_detected_o(),
	.err_corrected_o()
  );

  //----------------------------------------------------------------------------
  // Assertions
  //----------------------------------------------------------------------------

`ifdef CV32E40P_ASSERT_ON

  generate
  if (!PULP_XPULP) begin

    // Check that PC Mux cannot select Hardware Loop address iF PULP extensions are not included
    property p_pc_mux_0;
       @(posedge clk) disable iff (!rst_n) (1'b1) |-> (pc_mux_i != PC_HWLOOP);
    endproperty

    a_pc_mux_0 : assert property(p_pc_mux_0);

  end
  endgenerate

 generate
  if (!PULP_SECURE) begin

    // Check that PC Mux cannot select URET address if User Mode is not included
    property p_pc_mux_1;
       @(posedge clk) disable iff (!rst_n) (1'b1) |-> (pc_mux_i != PC_URET);
    endproperty

    a_pc_mux_1 : assert property(p_pc_mux_1);

  end
  endgenerate

`endif

endmodule
