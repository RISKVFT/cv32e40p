// Copyright 2020 Politecnico di Torino.

////////////////////////////////////////////////////////////////////////////////
// Engineer:       Luca Fiore - luca.fiore@studenti.polito.it                 //
//                                                                            //
//                                                                            //
// Design Name:    cv32e40p_ff_one                                            //
// Project Name:   cv32e40p Fault tolernat                                    //
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
  localparam N_OUT =2; //Number of outputs

  // definition of input and output signals of the three replicas;
  // they are just 3 legth arrays of input and output signals of one replica
  logic [N-1:0][LEN-1:0] in_i_ft;
  logic [N-1:0][$clog2(LEN)-1:0] first_one_o_ft;
  logic [N-1:0] no_ones_o_ft;
  logic [N_OUT-1:0] error_correct_o_ft;
  logic [N_OUT-1:0] error_detected_o_ft;

  //assign to each replica its set of inputs and outputs
  generate
    genvar k;
    for(k = 0; k < N; k++)
    begin
      assign in_i_ft[k] = in_i;
      assign first_one_o_ft[k] = first_one_o;
      assign no_ones_o_ft[k] = no_ones_o;

      // dfine array of three cv32e40p_ff_one replicas
      cv32e40p_ff_one ff_one_i[k]
      (
        .in_i        ( in_i_ft[k] ),
        .first_one_o ( first_one_o_ft[k] ),
        .no_ones_o   ( no_ones_o_ft[k] )
      );

    end
  endgenerate

  
  // instatiation of the the two voters, one for each output
  cv32e40p_generic_3voter #(LEN,N_OUT) voter
  (
    .in_1_i        ( {first_one_o_ft[0], no_ones_o_ft[0]} ),
    .in_2_i        ( {first_one_o_ft[1], no_ones_o_ft[1]} ),
    .in_3_i        ( {first_one_o_ft[2], no_ones_o_ft[2]} ),
    .voted_o       ( {first_one_o, no_ones_o} ),
    .error_correct_o (error_correct_o_ft[0]),
    .error_detected_o (error_detected_o_ft[0])
  );

    

  /* THIS IF WE WANT TO USE TWO 3voter INSTEAD OF THE GENERIC 3voter
  // instatiation of the the two voters, one for each output
  cv32e40p_3voter voter_first_one_i
  (
    .in_1_i        ( first_one_o_ft[0] ),
    .in_2_i        ( first_one_o_ft[1] ),
    .in_3_i        ( first_one_o_ft[2] ),
    .voted_o       ( first_one_o ),
    .error_correct_o (error_correct_o_ft[0]),
    .error_detected_o (error_detected_o_ft[0])
  );

  cv32e40p_3voter voter_no_one_i
  (
    .in_1_i        ( no_ones_o_ft[0] ),
    .in_2_i        ( no_ones_o_ft[1] ),
    .in_3_i        ( no_ones_o_ft[2] ),
    .voted_o       ( no_ones_o ),
    .error_correct_o (error_correct_o_ft[1]),
    .error_detected_o (error_detected_o_ft[1])
  );
*/

assign error_correct_o = error_correct_o_ft[0] | error_correct_o_ft[1];
assign error_detected_o = error_detected_o_ft[0] | error_detected_o_ft[1];


endmodule
