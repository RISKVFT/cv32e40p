// Copyright 2020 Politecnico di Torino.

////////////////////////////////////////////////////////////////////////////////
// Engineer:       Luca Fiore - luca.fiore@studenti.polito.it                 //
//                                                                            //
//                                                                            //                                                               
// Design Name:    cv32e40p_popcnt_ft                                         //
// Project Name:   cv32e40p Fault tolernat                                    //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    FAULT TOLERANT VERSION OF cv32e40p_popcnt                  //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40p_popcnt_ft
  #(
  parameter LEN = 32
)
(
  input  logic [LEN-1:0]  in_i,
  output logic [5:0]      result_o,
  output logic            error_correct_o,
  output logic            error_detected_o
);

  localparam N = 3;
  localparam N_OUT =1; //Number of outputs 

  // definition of input and output signals of the three replicas;
  // they are just 3 legth arrays of input and output signals of one replica
  logic [LEN-1:0][N-1:0] in_i_ft;
  logic [5:0][N-1:0] result_o_ft;

  //assign to each replica its set of inputs and outputs
  generate
    genvar k;
    for(k = 0; k < N; k++)
    begin
      assign in_i_ft[LEN-1:0][k] = in_i[LEN-1:0];
      //assign result_ft_o[5:0][k] = result_o[5:0];
    end
  endgenerate

  // dfine array of three cv32e40p_ff_one replicas
  cv32e40p_popcnt cv32e40p_popcnt_i[N-1:0]
  (
    .in_i        ( in_i_ft[N-1:0] ),
    .result_o    ( result_o_ft[5:0][N-1:0] )
  );  


  // instatiation of the the voter
  cv32e40p_generic_3voter #(6,N_OUT) voter_popcnt_i
  (
    .in_1_i        ( result_o_ft[0] ),
    .in_2_i        ( result_o_ft[1] ),
    .in_3_i        ( result_o_ft[2] ),
    .voted_o       ( result_o ),
    .error_correct_o (error_correct_o),
    .error_detected_o (error_detected_o)
  );

  /* THIS IF WE WANT TO USE TWO 3voter INSTEAD OF THE GENERIC 3voter
  // instatiation of the the voter
  cv32e40p__3voter #(6) voter_popcnt_i
  (
    .in_1_i        ( result_o_ft[0] ),
    .in_2_i        ( result_o_ft[1] ),
    .in_3_i        ( result_o_ft[2] ),
    .voted_o       ( result_o ),
    .error_correct_o (error_correct_o),
    .error_detected_o (error_detected_o)
  );
  */

endmodule