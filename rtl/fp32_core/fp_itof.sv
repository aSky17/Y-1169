`ifndef FP_ITOF_SV
`define FP_ITOF_SV

module fp_itof #(
    import parameters::*
) (
    input logic clk,
    input logic rst,
    input logic [DATA_WIDTH-1:0] int_in,
    output logic [DATA_WIDTH-1:0] float_result,
    output logic result_valid
);

    initial begin 
        if (DATA_WIDTH != 32) begin 
            $fatal(1,"ERROR: DATA_WIDTH must be 32 bits");
        end
    end
    
    localparam EXP_WIDTH = 8;
    localparam MANT_WIDTH = 23;
    localparam BIAS = 127;

    //Pipelining Stage-1: Determining sign, absolute value, and leading bit position
    logic sign_s1;
    logic [DATA_WIDTH-1:0] abs_int_s1;
    logic [5:0] leading_bit_pos_s1; //max position is 31 for 32-bit int
    logic stage1_valid;

    //function to find the position of most significant 1 bit
    function automatic [5:0] find_leading_bit_position;
        input [DATA_WIDTH-1:0] in;
        integer i;
        begin
            find_leading_bit_position = 0;
            for (i = DATA_WIDTH-1; i>=0; i--) begin 
                if (in[i]) begin 
                    find_leading_bit_position = i;
                    break;
                end
            end
        end
    endfunction

    always_ff @(posedge clk or posedge rst) begin 
        if (rst) begin 
            stage1_valid <= 0;
            sign_s1 <= 1'b0;
            abs_int_s1 <= 0;
            leading_bit_pos_s1 <= 0; 
        end else begin 
            sign_s1 <= int_in[DATA_WIDTH-1]; //MSB is signed bit
            abs_int_s1 = (sign_s1) ? -int_in : int_in; //get absolute value
            leading_bit_pos_s1 = find_leading_bit_position(abs_int_s1);
            stage1_valid <= 1'b1;
        end
    end

    //Pipelining Stage-2: Calculate exponent, extract mantissa, and pack result
    logic [DATA_WIDTH-1:0] float_result_s2;
    logic result_valid_s2;

    logic [EXP_WIDTH-1:0] exp_calc;
    logic [MANT_WIDTH-1:0] mant_calc;
    logic is_zero_s2; //to handle int_in == 0 case

    always_ff @(posedge clk or posedge rst) begin 
        if (rst) begin 
            result_valid_s2 <= 1'b0;
            float_result_s2 <= 0;
        end else if (stage1_valid) begin 
            is_zero_s2 = (abs_int_s1 == 0);

            if (is_zero_s2) begin 
                float_result_s2 <= {sign_s1, {DATA_WIDTH-1{1'b0}}}; //signed zero
            end else begin 
                /*
                * Normalized number
                * Exponent = position of MSB + BIAS
                * the leading_bit_pos_s1 is 0-indexed
                * if the leading_bit_pos_s1 is 23 (2^23), the exponent is 23-23 + BIAS = BIAS
                * if the leading_bit_pos_s1 is 0 (2^0), the exponent is (0-23) + BIAS 
                */
                exp_calc = (leading_bit_pos_s1 - MANT_WIDTH) + BIAS;

                /* Mantissa: 23 bits after the hidden bit
                * The hidden bit is at leading_bit_pos_s1, we need the next 23 bits
                * shift the absolute integer left to align the hidden bit at position 23
                * and then take the next 23 bits as the fractional part
                */
                if (leading_bit_pos_s1 >= MANT_WIDTH) begin 
                    mant_calc = abs_int_s1[(leading_bit_pos_s1-1) -: MANT_WIDTH];
                end else begin 
                    //if the number of bits is less than MANT_WIDTH eg 5, pad with zeros
                    mant_calc = {abs_int_s1[leading_bit_pos_s1-1:0], {MANT_WIDTH - leading_bit_pos_s1 {1'b0}}};
                end

                //handles potential exponent overflow 
                if (exp_calc >= {EXP_WIDTH{1'b1}}) begin 
                    float_result_s2 <= {sign_s1, {EXP_WIDTH{1'b1}}, {MANT_WIDTH{1'b0}}}; //infinity
                end else begin 
                    float_result_s2 = {sign_s1, exp_calc, mant_calc};
                end
            end
            result_valid_s2 <= 1'b1;
        end else begin 
            result_valid_s2 <= 1'b0;
        end
    end

    assign float_result = float_result_s2;
    assign result_valid = result_valid_s2;
endmodule

`endif