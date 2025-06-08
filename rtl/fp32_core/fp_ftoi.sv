`ifndef FP_FTOI_SV
`define FP_FTOI_SV

module fp_ftoi #(
    import gpu_parameters::*
) (
    input logic clk,
    input logic rst,
    input logic [DATA_WIDTH-1:0] float_in,
    output logic [DATA_WIDTH-1:0] int_result, //resulting signed integer
    output logic result_valid
);

    //asserting the DATA_WIDTH is 32-bit for singls precision
    initial begin 
        if (DATA_WIDTH != 32) begin 
            $fatal(1, "ERROR: DATA_WIDTH must be 32 bits");
        end
    end

    localparam EXP_WIDTH = 8;
    localparam MANT_WIDTH = 23;
    localparam BIAS = 127;

    //Pipelining Stage-1: Field extraction and special case detection
    logic sign_s1;
    logic [EXP_WIDTH-1:0] exp_s1;
    logic [MANT_WIDTH-1:0] mant_s1;

    logic is_zero_s1, is_inf_s1, is_nan_s1;
    logic stage1_valid;

    always_ff begin 
        if (rst) begin 
            stage1_valid <= 1'b0;
            sign_s1 <= 1'b0;
            exp_s1 <= 0;
            mant_s1 <= 0;
            is_zero_s1 <= 1'b0;
            is_inf_s1 <= 1'b0;
            is_nan_s1 <= 1'b0;
        end else begin 
            sign_s1 <= float_in[DATA_WIDTH-1];
            exp_s1 <= float_in[DATA_WIDTH-2:MANT_WIDTH];
            mant_s1 <= float_in[MANT_WIDTH-1:0];

            is_zero_s1 <= (exp_s1 == 0) && (mant_S1 == 0);
            is_inf_s1 <= (exp_s1 == {EXP_WIDTH{1'b1}}) && (mant_s1 == 0);
            is_nan_s1 <= (exp_s1 == {EXP_WIDTH{1'b1}}) && (mant_s1 != 0);
            stage1_valid <= 1'b1;
        end
    end


    //Pipelining Stage-2: Denormalization, truncation and saturation
    logic [DATA_WIDTH-1:0] int_result_s2;
    logic result_valid_s2;

    logic [EXP_WIDTH+MANT_WIDTH:0] denormalized_mantissa; //space for hidden bit and potential shifts
    logic [EXP_WIDTH:0] biased_exponent;
    logic [7:0] shift_amount; //MAX shift is 127 (for exponent 1) or 150 (for denormals)

    always_ff @(posedge clk or posedge rst) begin 
        if (rst) begin 
            result_valid_s2 <= 1'b0;
            int_result_s2 <= 0;
        end else if (stage1_valid) begin 
            if (is_nan_s1) begin
                //NaN:indeterminate integer value, representing by 0
                int_result_s2 <= 0;
            end else if (is_inf_s1) begin 
                //infinity: saturating to max/min integer
                if (sign_s1) begin 
                    //saturate to min
                    int_result_s2 <= {1'b1, {DATA_WIDTH-1{1'b0}}};
                end else begin 
                    // Maximum signed integer (2^31 - 1)
                    int_result_s2 <= {1'b0, {DATA_WIDTH-2{1'b1}}, 1'b1};
                end
            end else if (is_zero_s1) begin 
                int_result_s2 <= 0;
            end else begin 
                //denormal processing
                biased_exponent = exp_s1;
                denormalized_mantissa = (exp_s1 == 0) ? {1'b0, mant_s1} : {1'b1, mant_s1}; // adding hidden bit for normalized //if exponent is zero then it denormalized mantissa
            
                //actual exponent
                integer actual_exponent = biased_exponent - BIAS;

                if (actual_exponent < 0) begin 
                    //i.e., FP value is less than 1.0 like 0.5, 0.23 etc
                    int_result_s2 <= 0;
                end else if (actual_exponent >= DATA_WIDTH-1) begin 
                    //value is too large to fit in 32-bit signed integer
                    //therefore saturating to max/min integer based on sign
                    if (sign_s1) begin 
                        //saturating to min
                        int_result_s2 <= {1'b1, {DATA_WIDTH-1{1'b0}}}; 
                    end else begin
                        //maximum signed integer 
                        int_result_s2 <= {1'b0, {DATA_WIDTH-2{1'b1}}, 1'b1}; 
                    end
                end else begin 
                    //shift to align the integer part
                    //shift amount is actual_exponent
                    shift_amount = actual_exponent;
                    /*
                    * The integer part is the bits from the denormalized mantissa shifted left
                    * extract the integer part (before the implied decimal point)
                    * the hidden bit is at position MANT_WIDTH (23) if normalized
                    * so to get the integer part, we need to shift right by (MANT_WIDTH - actual_exponent
                    */
                    if (shift_amount >= MANT_WIDTH) begin // Integer part is fully within the 24 bits
                        // if E = 30, we need to shift denormalized_mantissa by 30 - 24 = 6 to restore the correct scale.
                        int_result_s2 =  denormalized_mantissa << (shift_amount - MANT_WIDTH);
                    end else begin
                        //EG: 1.101 × 2^1 = 11.01 (binary) = 3.25
                        int_result_s2 = denormalized_mantissa >> (MANT_WIDTH - shift_amount);
                    end

                    //apply sign
                    if (sign_s1)
                        int_result_s2 = -int_result_s2; //2's complement for negative numbers
                end
            end
            result_valid_s2 <= 1'b1;
        end else begin 
            result_valid_s2 <= 1'b0;
        end
    end
    
    assign int_result = int_result_s2;
    assign result_valid = result_valid_s2;
endmodule

`endif