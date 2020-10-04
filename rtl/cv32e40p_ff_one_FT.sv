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
// Engineer:       Andreas Traber - atraber@student.ethz.ch                   //
//                 Luca Fiore - luca.fiore@studenti.polito.it                 //
//                                                                            //
// Additional contributions by:                                               //
//                 Davide Schiavone - pschiavo@iis.ee.ethz.ch                 //
//                                                                            //
// Design Name:    cv32e40p_ff_one                                            //
// Project Name:   RI5CY                                                      //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    FAULT TOLERANT VERSION OF cv32e40p_ff_one                  //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////



module cv32e40p_ff_one_ft
#(
  parameter LEN = 32
)
(
  input  logic [LEN-1:0]         in_i,

  output logic [$clog2(LEN)-1:0] first_one_o,
  output logic                   no_ones_o,
  output logic                   error_correct_o,
  output logic                   error_detected_o
);

  localparam N = 3;

  // definition of input and output signals of the three replicas;
  // they are just 3 legth arrays of input and output signals of one replica
  logic [LEN-1:0][N-1:0] in_i_ft;
  logic [$clog2(LEN)-1:0][N-1:0] first_one_o_ft;
  logic [N-1:0] no_ones_o_ft;
  logic [1:0] error_correct_o_ft;
  logic [1:0] error_detected_o_ft;

  //assign to each replica its set of inputs and outputs
  generate
    genvar k;
    for(k = 0; k < N; k++)
    begin
      assign in_i_ft[LEN-1:0][k] = in_i[LEN-1:0];
      assign first_one_o_ft[LEN-1:0][k] = first_one_o[LEN-1:0];
      assign no_ones_o_ft[k] = no_ones_o;
    end
  endgenerate

  // dfine array of three cv32e40p_ff_one replicas
  cv32e40p_ff_one ff_one_i[N-1:0]
  (
    .in_i        ( in_i_ft[N-1:0] ),
    .first_one_o ( first_one_o_ft[N-1:0] ),
    .no_ones_o   ( no_ones_o_ft[N-1:0] )
  );  

  // instatiation of the the two voters, one for each output
  cv32e40p_voter voter_first_one_i
  (
    .in_1_i        ( first_one_o_ft[0] ),
    .in_2_i        ( first_one_o_ft[1] ),
    .in_3_i        ( first_one_o_ft[2] ),
    .voted_o       ( first_one_o ),
    .error_correct_o (error_correct_o_ft[0]),
    .error_detected_o (error_detected_o_ft[0])
  );

  cv32e40p_voter voter_no_one_i
  (
    .in_1_i        ( no_ones_o_ft[0] ),
    .in_2_i        ( no_ones_o_ft[1] ),
    .in_3_i        ( no_ones_o_ft[2] ),
    .voted_o       ( no_ones_o ),
    .error_correct_o (error_correct_o_ft[1]),
    .error_detected_o (error_detected_o_ft[1])
  );

assign error_correct_o = error_correct_o_ft[0] | error_correct_o_ft[1];
assign error_detected_o = error_detected_o_ft[0] | error_detected_o_ft[1];

endmodule
