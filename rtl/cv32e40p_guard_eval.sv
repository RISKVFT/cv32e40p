// Copyright 2020 Politecnico di Torino.

////////////////////////////////////////////////////////////////////////////////
// Engineer:       Luca Fiore - luca.fiore@studenti.polito.it                 //
//                                                                            //
//                                                                            //                                                               
// Design Name:    cv32e40p_guard_eval                                        //
// Project Name:   cv32e40p Fault tolernat                                    //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    guarded evaluation latch based                             //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40p_guard_eval
(
    input  logic input_i,
    input  logic en_i,
    output logic output_o
  );

  logic out_latch;

  always_latch
  begin
     if (en_i == 1'b0)
       out_latch <= input_i;
  end

  assign output_o = en_i & out_latch;

endmodule // cv32e40p_guard_eval
