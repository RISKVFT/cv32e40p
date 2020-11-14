// Copyright 2020 Politecnico di Torino.

////////////////////////////////////////////////////////////////////////////////
// Engineer:       Marcello Neri - s257090@studenti.polito.it                 //
//                                                                            //
//                                                                            //
// Design Name:    hsiao sec-ded codes for fault tolerant application         //
// Project Name:   RI5CY                                                      //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Hsiao SEC-DED codes decoder.   			                  //
//                 This works with data up to 32 bits.                        //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cv32e40p_hsiao_secded_decoder // current design is for DATA_WIDTH=32
#(
    parameter DATA_WIDTH    = 32,
	parameter R_TMP 		= $ceil($clog2(DATA_WIDTH)), // variable to calculate redundancy bits
	parameter R_BITS		= R_TMP + $floor((DATA_WIDTH + R_TMP)/2**R_TMP) + 1 // variable to assign the final redundancy bits
)
(
 	//Data to and from decoder
    input 	logic [DATA_WIDTH-1+R_BITS:0]  	data_dec_i,
    output 	logic [DATA_WIDTH-1:0]  		data_dec_o,
	output 	logic [2:0]						SECDED // meaning of the 3 bits: 0th -> NOERROR, 1st -> SEC, 2nd -> DED 

); // END ENTITY --------------------------------------------------------------------
	
	// redefine parameter names for simplicity
	localparam    K		= DATA_WIDTH;
	localparam    R		= R_BITS;	
	
	// define Hsiao matrix
	logic [0:R-1][K+R-1:0]			hsiao_matrix;  
	logic [K+R-1:0][0:R-1]			hsiao_matrix_transposed;
	
	// define signals used by encoder
	//logic [K-1:0]					data_decoded; 
	logic [K+R-1:0]					data_in_dec_hw; // codeword
	logic [K+R-1:0]					data_dec_corrected;
	logic							parity_dec;
	logic							error_check, parity_check;
	logic [0:R-1]					syndrome_bits;
	
	

	//-----------------------------------------------------------------------------
	//-- HSIAO MATRIX: initialization
	//-----------------------------------------------------------------------------
	// values taken from the model in Matlab for K=32
	/*assign hsiao_matrix ='{	39'b100000010101001010011001010010100110001,
							39'b010000010100101001100101001010011001010,
							39'b001000010010100110010100101001100100110,
							39'b000100001010101001010010100101010011001,
							39'b000010001010010101001010011010001100101,
							39'b000001001001010100101001100100110010010,
							39'b000000100101010010100110010101001001100};*/

	assign hsiao_matrix ='{	39'b100011001010010100110010100101010000001,
							39'b010100110010100101001100101001010000010,
							39'b011001001100101001010011001010010000100,
							39'b100110010101001010010100101010100001000,
							39'b101001100010110010100101010010100010000,
							39'b010010011001001100101001010100100100000,
							39'b001100100101010011001010010101001000000};

		
	genvar i, j;
	for(i=0; i<R; i++) begin
	    for (j=0; j<K+R; j++) begin
	            assign hsiao_matrix_transposed[j][i] = hsiao_matrix[i][j];
	    end
	end


	/*
	//-----------------------------------------------------------------------------
	//-- ENCODER: data_in k bits, data_out k+r bits
	//-----------------------------------------------------------------------------
	assign data_in_enc_hw = data_enc_i; // input data to the encoder 
	//assign data_in_enc_hw = 32'b10110110011101100101110100011001;



    // loop to set redundancy bits by means of XOR gates according to hsiao matrix
	always_comb
	begin : redundancy_bits

		data_encoded[K+R-1:R] = data_in_enc_hw; // data info copied into the codeword
		for(int i=0; i<R; i++) begin
			parity_enc=0;
			for (int j=R; j<K+R; j++) begin
			    if(hsiao_matrix[i][j] == 1) begin
			        parity_enc = parity_enc ^ data_encoded[j];
				end
			end
			data_encoded[i] = parity_enc; // 1 redundancy bit set at time
		end

	end

    assign data_enc_o = data_encoded; // output from the encoder
	*/


	//-----------------------------------------------------------------------------
	//-- DECODER : data_in k+r bits, data_out k bits
	//-----------------------------------------------------------------------------

    assign data_in_dec_hw = data_dec_i; 

	always @(data_in_dec_hw)
	begin : syndrome_bits_and_correction

		error_check = 1'b0;
		parity_check = 1'b0;
		for(int i=0; i<R; i++) begin
		    parity_dec = data_in_dec_hw[i];
		    for (int j=R; j<K+R; j++) begin
		        if (hsiao_matrix[i][j] == 1) begin
		            parity_dec = parity_dec ^ data_in_dec_hw[j];
				end
		    end
		    syndrome_bits[i] = parity_dec;
		end
		if(syndrome_bits != 0) begin
			error_check = 1'b1;
		end
		for(int x=0; x<K+R; x++) begin
		    if( hsiao_matrix_transposed[x] == syndrome_bits ) begin
		        data_dec_corrected[x] = ~data_in_dec_hw[x];
			end else begin
				data_dec_corrected[x] = data_in_dec_hw[x];
		    end
		end

		for(int y=0; y<R; y++) begin
		    parity_check = parity_check ^ syndrome_bits[y];
		end

    	data_dec_o = data_dec_corrected[K+R-1:R];
	end
  
	// no error
	assign SECDED[0] = ~error_check & ~parity_check;
	// single error detected and corrected
	assign SECDED[1] = error_check & parity_check;
	// double error detected but not corrected
	assign SECDED[2] = error_check & ~parity_check;

endmodule
