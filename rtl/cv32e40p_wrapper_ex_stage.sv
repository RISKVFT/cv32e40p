// Copyright 2020 Politecnico di Torino.


////////////////////////////////////////////////////////////////////////////////
// Engineer:       Luca Fiore - luca.fiore@studenti.polito.it                 //
//                                                                            //
// Additional contributions by:                                               //
//                 Marcello Neri - s257090@studenti.polito.it                 //
//                 Elia Ribaldone - s265613@studenti.polito.it                //
//                                                                            //
// Design Name:    cv32e40p_wrapper_ex_stage                                  //
// Project Name:   cv32e40p Fault tolerant                                    //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Wrapper of the ex stage to exploit the tcl scripts         //
//      		       written to apply the fault injection  .                    //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////   


module cv32e40p_wrapper_ex_stage import cv32e40p_pkg::*; import cv32e40p_apu_core_pkg::*;
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
  input  logic [4*ALU_OP_WIDTH-1:0] alu_operator_i,
  input  logic [127:0] alu_operand_a_i,
  input  logic [127:0] alu_operand_b_i,
  input  logic [127:0] alu_operand_c_i,
  input  logic [  3:0] alu_en_i,
  input  logic [ 19:0] bmask_a_i,
  input  logic [ 19:0] bmask_b_i,
  input  logic [  7:0] imm_vec_ext_i,
  input  logic [  7:0] alu_vec_mode_i,
  input  logic [  3:0] alu_is_clpx_i,
  input  logic [  3:0] alu_is_subrot_i,
  input  logic [  7:0] alu_clpx_shift_i,

  // Multiplier signals
  input  logic [ 11:0] mult_operator_i,
  input  logic [127:0] mult_operand_a_i,
  input  logic [127:0] mult_operand_b_i,
  input  logic [127:0] mult_operand_c_i,
  input  logic [  3:0] mult_en_i,
  input  logic [  3:0] mult_sel_subword_i,
  input  logic [  7:0] mult_signed_mode_i,
  input  logic [ 19:0] mult_imm_i,

  input  logic [127:0] mult_dot_op_a_i,
  input  logic [127:0] mult_dot_op_b_i,
  input  logic [127:0] mult_dot_op_c_i,
  input  logic [  7:0] mult_dot_signed_i,
  input  logic [  3:0] mult_is_clpx_i,
  input  logic [  7:0] mult_clpx_shift_i,
  input  logic [  3:0] mult_clpx_img_i,

  output logic         mult_multicycle_o,

  // FPU signals
  input  logic [C_PC-1:0]             fpu_prec_i,
  output logic                        fpu_fflags_we_o,

  // APU signals
  input  logic [3:0]                       apu_en_i,
  input  logic [4*APU_WOP_CPU-1:0]         apu_op_i,
  input  logic [  7:0]                     apu_lat_i,
  input  logic [128*APU_NARGS_CPU-1:0]     apu_operands_i,
  input  logic [ 23:0]                     apu_waddr_i,
  input  logic [4*APU_NDSFLAGS_CPU-1:0]    apu_flags_i,

  input  logic [17:0]                 apu_read_regs_i,
  input  logic [2:0]                  apu_read_regs_valid_i,
  output logic                        apu_read_dep_o,
  input  logic [11:0]                 apu_write_regs_i,
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
  output logic [APU_WOP_CPU-1:0]         apu_master_op_o,
  // response channel
  input  logic                        apu_master_valid_i,
  input  logic [31:0]                 apu_master_result_i,

  input  logic [3:0]       lsu_en_i,
  input  logic [31:0]	     lsu_rdata_i,

  // input from ID stage
  input  logic [ 3:0]       branch_in_ex_i,
  input  logic [23:0]       regfile_alu_waddr_i,
  input  logic [ 3:0]       regfile_alu_we_i,

  // directly passed through to WB stage, not used in EX
  input  logic [ 3:0]       regfile_we_i,
  input  logic [23:0]       regfile_waddr_i,

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
  input logic [32*APU_NARGS_CPU-1:0]         apu_operands_ex_voted_i,
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


  // unflattened signals, we need to convert from the flattened in/out ports 

  logic [3:0][ALU_OP_WIDTH-1:0] alu_operator_unflatten;      //[3:0][ALU_OP_WIDTH-1:0]
  logic [3:0][31:0] alu_operand_a_unflatten;                 //[3:0][31:0]
  logic [3:0][31:0] alu_operand_b_unflatten;                 //[3:0][31:0]
  logic [3:0][31:0] alu_operand_c_unflatten;                 //[3:0][31:0]
  logic [3:0][ 4:0] bmask_a_unflatten;                       //[3:0][ 4:0]
  logic [3:0][ 4:0] bmask_b_unflatten;                       //[3:0][ 4:0]
  logic [3:0][ 1:0] imm_vec_ext_unflatten;                   //[3:0][ 1:0]
  logic [3:0][ 1:0] alu_vec_mode_unflatten;                  //[3:0][ 1:0]
  logic [3:0][ 1:0] alu_clpx_shift_unflatten;                //[3:0][ 1:0]

  logic [3:0][ 2:0] mult_operator_unflatten;                 //[3:0][ 2:0]
  logic [3:0][31:0] mult_operand_a_unflatten;                //[3:0][31:0]
  logic [3:0][31:0] mult_operand_b_unflatten;                //[3:0][31:0]
  logic [3:0][31:0] mult_operand_c_unflatten;                //[3:0][31:0]
  logic [3:0][ 1:0] mult_signed_mode_unflatten;              //[3:0][ 1:0]
  logic [3:0][ 4:0] mult_imm_unflatten;                      //[3:0][ 4:0]

  logic [3:0][31:0] mult_dot_op_a_unflatten;                 //[3:0][31:0]
  logic [3:0][31:0] mult_dot_op_b_unflatten;                 //[3:0][31:0]
  logic [3:0][31:0] mult_dot_op_c_unflatten;                 //[3:0][31:0]
  logic [3:0][ 1:0] mult_dot_signed_unflatten;               //[3:0][ 1:0]
  logic [3:0][ 1:0] mult_clpx_shift_unflatten;               //[3:0][ 1:0]
  
  logic [3:0][APU_WOP_CPU-1:0]          apu_op_unflatten;       //[3:0][APU_WOP_CPU-1:0]
  logic [3:0][1:0]                      apu_lat_unflatten;      //[3:0][1:0]
  logic [3:0][APU_NARGS_CPU-1:0][31:0]  apu_operands_unflatten; //[3:0][APU_NARGS_CPU-1:0][31:0]
  logic [3:0][5:0]                      apu_waddr_unflatten;    //[3:0][5:0]
  logic [3:0][APU_NDSFLAGS_CPU-1:0]     apu_flags_unflatten;    //[3:0][APU_NDSFLAGS_CPU-1:0]

  logic [2:0][5:0]  apu_read_regs_unflatten;                    //[2:0][5:0]
  logic [1:0][5:0]  apu_write_regs_unflatten;                   //[1:0][5:0]

  logic [3:0][5:0]  regfile_alu_waddr_unflatten;             //[3:0][5:0]
  logic [3:0][5:0]  regfile_waddr_unflatten;                 //[3:0][5:0]

  logic [APU_NARGS_CPU-1:0][31:0]      apu_operands_ex_voted_unflatten; // [APU_NARGS_CPU-1:0][31:0]


// unflattening the signals

genvar y;
genvar z;
genvar a;
genvar b;
genvar c;
genvar d;
genvar e;
genvar f;
genvar g;
genvar h;
genvar i;
genvar j;
genvar k;
genvar l;
genvar m;
genvar n;
genvar o;
generate //transpose the permanent_faulty_alu matrix
    for (y=0; y<4; y++) begin

    	for (m=0; m<ALU_OP_WIDTH; m++) begin
            assign alu_operator_unflatten[y][m] = alu_operator_i[(y*ALU_OP_WIDTH)+m];
        end


        for (z=0; z<32; z++) begin
            assign alu_operand_a_unflatten[y][z] = alu_operand_a_i[(y*32)+z];
            assign alu_operand_b_unflatten[y][z] = alu_operand_b_i[(y*32)+z];
            assign alu_operand_c_unflatten[y][z] = alu_operand_c_i[(y*32)+z];
            assign mult_operand_a_unflatten[y][z] = mult_operand_a_i[(y*32)+z];
            assign mult_operand_b_unflatten[y][z] = mult_operand_b_i[(y*32)+z];
            assign mult_operand_c_unflatten[y][z] = mult_operand_c_i[(y*32)+z];
            assign mult_dot_op_a_unflatten[y][z] = mult_dot_op_a_i[(y*32)+z];
            assign mult_dot_op_b_unflatten[y][z] = mult_dot_op_b_i[(y*32)+z];
            assign mult_dot_op_c_unflatten[y][z] = mult_dot_op_c_i[(y*32)+z];
        end

        for (a=0; a<5; a++) begin
            assign bmask_a_unflatten[y][a] = bmask_a_i[(y*5)+a];
            assign bmask_b_unflatten[y][a] = bmask_b_i[(y*5)+a];
            assign mult_imm_unflatten[y][a] = mult_imm_i[(y*5)+a];
        end

        for (b=0; b<2; b++) begin
            assign imm_vec_ext_unflatten[y][b] = imm_vec_ext_i[(y*2)+b];
            assign alu_vec_mode_unflatten[y][b] = alu_vec_mode_i[(y*2)+b];
            assign alu_clpx_shift_unflatten[y][b] = alu_clpx_shift_i[(y*2)+b];
            assign mult_signed_mode_unflatten[y][b] = mult_signed_mode_i[(y*2)+b];
            assign mult_dot_signed_unflatten[y][b] = mult_dot_signed_i[(y*2)+b];
            assign mult_clpx_shift_unflatten[y][b] = mult_clpx_shift_i[(y*2)+b];
            assign apu_lat_unflatten[y][b] = apu_lat_i[(y*2)+b];
        end

        for (c=0; c<3; c++) begin
            assign mult_operator_unflatten[y][c] = mult_operator_i[(y*3)+c];
        end

        for (d=0; d<6; d++) begin
            assign apu_waddr_unflatten[y][d] = apu_waddr_i[(y*6)+d];
            assign regfile_alu_waddr_unflatten[y][d] = regfile_alu_waddr_i[(y*6)+d];
            assign regfile_waddr_unflatten[y][d] = regfile_waddr_i[(y*6)+d];
        end

        for (e=0; e<APU_WOP_CPU; e++) begin
            assign apu_op_unflatten[y][e] = apu_op_i[(y*APU_WOP_CPU)+e];
        end

        for (f=0; f<APU_NDSFLAGS_CPU; f++) begin
            assign apu_flags_unflatten[y][f] = apu_flags_i[(y*APU_NDSFLAGS_CPU)+f];
        end

        for (g=0; g<APU_NARGS_CPU; g++) begin
            for (k=0; k<32; k++) begin
              assign apu_operands_unflatten[y][g][k] = apu_operands_i[(y*3)+(g*32)+k];
            end
        end
    end

    for (n=0; n<APU_NARGS_CPU; n++) begin
        for (o=0; o<32; o++) begin
          assign apu_operands_ex_voted_unflatten[n][o] = apu_operands_ex_voted_i[(n*32)+o];
        end
    end

    for (h=0; h<3; h++) begin
        for (i=0; i<6; i++) begin
          assign apu_read_regs_unflatten[h][i] = apu_read_regs_i[(h*3)+i];
        end
    end

    for (j=0; j<2; j++) begin
        for (l=0; l<6; l++) begin
          assign apu_write_regs_unflatten[j][l] = apu_write_regs_i[(j*2)+l];
        end
    end

endgenerate



// instantiate the component

cv32e40p_ex_stage
  #(
   .FPU              ( FPU                ),
   .APU_NARGS_CPU    ( APU_NARGS_CPU      ),
   .APU_WOP_CPU      ( APU_WOP_CPU        ),
   .APU_NDSFLAGS_CPU ( APU_NDSFLAGS_CPU   ),
   .APU_NUSFLAGS_CPU ( APU_NUSFLAGS_CPU   ),
   .FT               ( FT )
  )
  ex_stage_i
  (
    // Global signals: Clock and active low asynchronous reset
    .clk                        ( clk                        ),
    .rst_n                      ( rst_n                      ),

    // Alu signals from ID stage
    .alu_en_i                   ( alu_en_i                   ),
    .alu_operator_i             ( alu_operator_unflatten     ), // from ID/EX pipe registers
    .alu_operand_a_i            ( alu_operand_a_unflatten    ), // from ID/EX pipe registers
    .alu_operand_b_i            ( alu_operand_b_unflatten    ), // from ID/EX pipe registers
    .alu_operand_c_i            ( alu_operand_c_unflatten    ), // from ID/EX pipe registers
    .bmask_a_i                  ( bmask_a_unflatten          ), // from ID/EX pipe registers
    .bmask_b_i                  ( bmask_b_unflatten          ), // from ID/EX pipe registers
    .imm_vec_ext_i              ( imm_vec_ext_unflatten      ), // from ID/EX pipe registers
    .alu_vec_mode_i             ( alu_vec_mode_unflatten     ), // from ID/EX pipe registers
    .alu_is_clpx_i              ( alu_is_clpx_i              ), // from ID/EX pipe registers
    .alu_is_subrot_i            ( alu_is_subrot_i            ), // from ID/Ex pipe registers
    .alu_clpx_shift_i           ( alu_clpx_shift_unflatten   ), // from ID/EX pipe registers

    // Multipler
    .mult_operator_i            ( mult_operator_unflatten    ), // from ID/EX pipe registers
    .mult_operand_a_i           ( mult_operand_a_unflatten   ), // from ID/EX pipe registers
    .mult_operand_b_i           ( mult_operand_b_unflatten   ), // from ID/EX pipe registers
    .mult_operand_c_i           ( mult_operand_c_unflatten   ), // from ID/EX pipe registers
    .mult_en_i                  ( mult_en_i                  ), // from ID/EX pipe registers
    .mult_sel_subword_i         ( mult_sel_subword_i         ), // from ID/EX pipe registers
    .mult_signed_mode_i         ( mult_signed_mode_unflatten ), // from ID/EX pipe registers
    .mult_imm_i                 ( mult_imm_unflatten         ), // from ID/EX pipe registers
    .mult_dot_op_a_i            ( mult_dot_op_a_unflatten    ), // from ID/EX pipe registers
    .mult_dot_op_b_i            ( mult_dot_op_b_unflatten    ), // from ID/EX pipe registers
    .mult_dot_op_c_i            ( mult_dot_op_c_unflatten    ), // from ID/EX pipe registers
    .mult_dot_signed_i          ( mult_dot_signed_unflatten  ), // from ID/EX pipe registers
    .mult_is_clpx_i             ( mult_is_clpx_i             ), // from ID/EX pipe registers
    .mult_clpx_shift_i          ( mult_clpx_shift_unflatten  ), // from ID/EX pipe registers
    .mult_clpx_img_i            ( mult_clpx_img_i            ), // from ID/EX pipe registers

    .mult_multicycle_o          ( mult_multicycle_o          ), // to ID/EX pipe registers

    // FPU
    .fpu_prec_i                 ( fpu_prec_i                 ),
    .fpu_fflags_we_o            ( fpu_fflags_we_o            ),

    // APU
    .apu_en_i                   ( apu_en_i                   ),
    .apu_op_i                   ( apu_op_unflatten           ),
    .apu_lat_i                  ( apu_lat_unflatten          ),
    .apu_operands_i             ( apu_operands_unflatten     ),
    .apu_waddr_i                ( apu_waddr_unflatten        ),
    .apu_flags_i                ( apu_flags_unflatten        ),

    .apu_read_regs_i            ( apu_read_regs_unflatten    ),
    .apu_read_regs_valid_i      ( apu_read_regs_valid_i      ),
    .apu_read_dep_o             ( apu_read_dep_o             ),
    .apu_write_regs_i           ( apu_write_regs_unflatten   ),
    .apu_write_regs_valid_i     ( apu_write_regs_valid_i     ),

    .apu_write_dep_o            ( apu_write_dep_o            ), 
    .apu_perf_type_o            ( apu_perf_type_o            ),
    .apu_perf_cont_o            ( apu_perf_cont_o            ),
    .apu_perf_wb_o              ( apu_perf_wb_o              ),
    .apu_ready_wb_o             ( apu_ready_wb_o             ),
    .apu_busy_o                 ( apu_busy_o                 ),

    // apu-interconnect
    // handshake signals
    .apu_master_req_o           ( apu_master_req_o           ),
    .apu_master_ready_o         ( apu_master_ready_o         ),
    .apu_master_gnt_i           ( apu_master_gnt_i           ),
    // request channel
    .apu_master_operands_o      ( apu_master_operands_o      ),
    .apu_master_op_o            ( apu_master_op_o            ),
    // response channel
    .apu_master_valid_i         ( apu_master_valid_i         ),
    .apu_master_result_i        ( apu_master_result_i        ),

    .lsu_en_i                   ( lsu_en_i                   ),
    .lsu_rdata_i                ( lsu_rdata_i                ),

    // interface with CSRs
    .csr_access_i               ( csr_access_i               ),
    .csr_rdata_i                ( csr_rdata_i                ),

    // From ID Stage: Regfile control signals
    .branch_in_ex_i             ( branch_in_ex_i               ),
    .regfile_alu_waddr_i        ( regfile_alu_waddr_unflatten  ),
    .regfile_alu_we_i           ( regfile_alu_we_i             ),

    .regfile_waddr_i            ( regfile_waddr_unflatten    ),
    .regfile_we_i               ( regfile_we_i               ),

    // Output of ex stage pipeline
    .regfile_waddr_wb_o         ( regfile_waddr_wb_o         ),
    .regfile_we_wb_o            ( regfile_we_wb_o            ),
    .regfile_wdata_wb_o         ( regfile_wdata_wb_o         ),

    // To IF: Jump and branch target and decision
    .jump_target_o              ( jump_target_o              ),
    .branch_decision_o          ( branch_decision_o          ),

    // To ID stage: Forwarding signals
    .regfile_alu_waddr_fw_o     ( regfile_alu_waddr_fw_o   	 ),
    .regfile_alu_we_fw_o        ( regfile_alu_we_fw_o        ),
    .regfile_alu_wdata_fw_o     ( regfile_alu_wdata_fw_o     ),

    // stall control
    .is_decoding_i              ( is_decoding_i         	   ),
    .lsu_ready_ex_i             ( lsu_ready_ex_i        	   ),
    .lsu_err_i                  ( lsu_err_i           	       ),

    .ex_ready_o                 ( ex_ready_o             	   ),
    .ex_valid_o                 ( ex_valid_o             	   ),
    .wb_ready_i                 ( wb_ready_i            	   ),

    // FT
    .sel_mux_ex_i                 ( sel_mux_ex_i                 ),  // selector of the three mux to choose three of the four alu
    .permanent_faulty_alu_ft_o    ( permanent_faulty_alu_ft_o    ),  // set of 4 9bit register for a each ALU 
    .permanent_faulty_alu_s_ft_o  ( permanent_faulty_alu_s_ft_o  ),  // set of 4 9bit register for a each ALU 
    .permanent_faulty_mult_ft_o   ( permanent_faulty_mult_ft_o   ),
    .permanent_faulty_mult_s_ft_o ( permanent_faulty_mult_s_ft_o ),
    .clock_enable_i               ( clock_enable_i               ),
    .alu_en_ex_voted_i            ( alu_en_ex_voted_i            ),

      
    .apu_op_ex_voted_i            ( apu_op_ex_voted_i 			    ),
    .apu_operands_ex_voted_i      ( apu_operands_ex_voted_unflatten ),
    .apu_waddr_ex_voted_i         ( apu_waddr_ex_voted_i 		    ),
    .regfile_alu_waddr_ex_voted_i ( regfile_alu_waddr_ex_voted_i    ),
    .regfile_alu_we_ex_voted_i    ( regfile_alu_we_ex_voted_i       ),
    .apu_en_ex_voted_i            ( apu_en_ex_voted_i 			    ),
    .apu_lat_ex_voted_i           ( apu_lat_ex_voted_i 		        ),
    .branch_in_ex_voted_i         ( branch_in_ex_voted_i 		    ),
    .regfile_waddr_ex_voted_i     ( regfile_waddr_ex_voted_i 	    ),
    .regfile_we_ex_voted_i        ( regfile_we_ex_voted_i 		    ),
    .csr_access_ex_voted_i        ( csr_access_ex_voted_i		    ),
    .lsu_en_voted_i		          ( lsu_en_voted_i 		            ),


    // Performance counters
    .mhpm_addr_ft_i          ( mhpm_addr_ft_i  ),    // the address of the perf counter to be written
    .mhpm_re_ft_i            ( mhpm_re_ft_i    ),    // read enable 
    .mhpm_rdata_ft_o         ( mhpm_rdata_ft_o ),    // the value of the performance counter we want to read
    .mhpm_we_ft_i            ( mhpm_we_ft_i    ),    // write enable 
    .mhpm_wdata_ft_i         ( mhpm_wdata_ft_i ),     // the we want to write into the perf counter

    .only_two_alu_i          ( only_two_alu_i            ),
    .only_two_mult_i         ( only_two_mult_i           ),
    .sel_mux_only_two_alu_i  ( sel_mux_only_two_alu_i    ),
    .sel_mux_only_two_mult_i ( sel_mux_only_two_mult_i   ),
    
    .sel_bypass_alu_ex_i       ( sel_bypass_alu_ex_i       ),
    .sel_bypass_mult_ex_i      ( sel_bypass_mult_ex_i      ),
    .vector_err_detected_ft_o  ( vector_err_detected_ft_o  ), 
    .vector_err_corrected_ft_o ( vector_err_corrected_ft_o )

  );

endmodule