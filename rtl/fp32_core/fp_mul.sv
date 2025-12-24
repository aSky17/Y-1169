`ifndef FP_MUL_SV
`define FP_MUL_SV

module fp_mul #(
    import parameters::*
) (
    input logic clk,
    input logic rst,
    input logic [DATA_WIDTH-1:0] a,
    input logic [DATA_WIDTH-1:0] b,
    output logic [DATA_WIDTH-1:0] result,
    output logic result_valid
);
    
    //asserting that DATA_WIDTH is 32-bit
    initial begin 
        if (DATA_WIDTH != 32) begin
            $fatal(1, "Error: DATA_WIDTH must be 32 bits for this single precision PF unit");
        end
    end

    //IEEE 754 single-precision constants
    localparam EXP_WIDTH = 8;
    localparam MANT_WIDTH = 23;
    localparam BIAS = 127;

    //Pipelining Stage-1
    //Field extraction, special case detection, mantissa setup
    //register to pass data to stage 2
    logic [EXP_WIDTH-1:0] exp_a_s1, exp_b_s1;
    logic [MANT_WIDTH:0] mant_a_s1, mant_b_s1; // mantissa with 1 hidden bit
    logic sign_a_s1, sign_b_s1;

    logic is_a_zero_s1, is_b_zero_s1;
    logic is_a_inf_s1, is_b_inf_s1;
    logic is_a_nan_s1, is_b_nan_s1;

    logic sign_res_s1; //tentative sign of the result
    logic stage1_valid;

    //internal wires for stage 1
    logic [EXP_WIDTH-1:0] exp_a_comb, exp_b_comb;
    logic [MANT_WIDTH-1:0] raw_mant_a_comb, raw_mant_b_comb;
    logic [MANT_WIDTH:0] mant_a_padded_comb, mant_b_padded_comb;

    logic is_a_zero_comb, is_b_zero_comb;
    logic is_a_inf_comb, is_b_inf_comb;
    logic is_a_nan_comb, is_b_nan_comb;
    logic sign_res_calc_comb;

    always_comb begin
        exp_a_comb = 0;
        exp_b_comb = 0;
        raw_mant_a_comb = 0; 
        raw_mant_b_comb = 0;
        mant_a_padded_comb = 0; 
        mant_b_padded_comb = 0;
        is_a_zero_comb = 1'b0; 
        is_b_zero_comb = 1'b0;
        is_a_inf_comb = 1'b0; 
        is_b_inf_comb = 1'b0;
        is_a_nan_comb = 1'b0; 
        is_b_nan_comb = 1'b0;
        sign_res_calc_comb = 1'b0;

        //field extraction
        //sign is XOR of sign bits of both operand
        sign_res_calc_comb = a[DATA_WIDTH-1] ^ a[DATA_WIDTH-1];
        
        //extracting exponent and raw mantissa for a
        exp_a_comb = a[DATA_WIDTH-2:MANT_WIDTH];
        raw_mant_a_comb = a[MANT_WIDTH-1:0];
        //padding mantissa with a hidden bit: 1 for normalized, 0 for denormal
        mant_a_padded_comb = (exp_a_comb == 0) ? {1'b0, raw_mant_a_comb} : {1'b1, raw_mant_a_comb};

        //for b
        exp_b_comb = b[DATA_WIDTH-2:MANT_WIDTH];
        raw_mant_b_comb = b[MANT_WIDTH-1:0];
        mant_b_padded_comb = (exp_b_comb == 0) ? {1'b0, raw_mant_b_comb} : {1'b1, raw_mant_b_comb};

        //checking for special cases: nan, inf, zero
        //for zero: exponent is 0 and mantissa is zero
        is_a_zero_comb = (exp_a_comb == 0) && (raw_mant_a_comb == 0);
        is_b_zero_comb = (exp_b_comb == 0) && (raw_mant_b_comb == 0);

        //for infinty: exponent is all 1s and mantissa is 0
        is_a_inf_comb = (exp_a_comb == {EXP_WIDTH{1'b1}}) && (raw_mant_a_comb == 0);
        is_b_inf_comb = (exp_b_comb) == {EXP_WIDTH{1'b1}} && (raw_mant_b_comb == 0);

        //for nan: exponent is all 1s and mantissa is non zero
        is_a_nan_comb = (exp_a_comb == {EXP_WIDTH{1'b1}}) && (raw_mant_a_comb != 0);
        is_b_nan_comb = (exp_b_comb == {EXP_WIDTH{1'b1}}) && (raw_mant_b_comb != 0);

    end

    always_ff @(posedge clk or posedge rst) begin 

        if (rst) begin 
            stage1_valid <= 1'b0;
            sign_a_s1 <= 1'b0;
            exp_a_s1 <= 0;
            mant_a_s1 <= 0;
            sign_b_s1 <= 1'b0;
            exp_b_s1 <= 0;
            mant_b_s1 <= 0;
            is_a_zero_s1 <= 1'b0;
            is_b_zero_s1 <= 1'b0;
            is_a_inf_s1 <= 1'b0;
            is_b_inf_s1 <= 1'b0;
            is_a_nan_s1 <= 1'b0;
            is_b_nan_s1 <= 1'b0;
            sign_res_s1 <= 1'b0;
        end else begin
            stage1_valid <= 1'b1;

            sign_a_s1 <= a[DATA_WIDTH-1];
            exp_a_s1 <= exp_a_comb;
            mant_a_s1 <= mant_a_padded_comb;

            sign_b_s1 <= b[DATA_WIDTH-1];
            exp_b_s1 <= exp_b_comb;
            mant_b_s1 <= mant_b_padded_comb;

            //Register the status flags for special cases
            is_a_zero_s1 <= is_a_zero_comb;
            is_b_zero_s1 <= is_b_zero_comb;
            is_a_inf_s1 <= is_a_inf_comb;
            is_b_inf_s1 <= is_b_inf_comb;
            is_a_nan_s1 <= is_a_nan_comb;
            is_b_nan_s1 <= is_b_nan_comb;

            //register the calculated sign bit
            sign_res_s1 <= sign_res_calc_comb;
        end
    end

    //Pipelining Stage-2
    //Mantissa multiplication, initial exponent sum
    //Registers to pass due to stage 3
    logic [MANT_WIDTH*2:0] mant_prod_s2; //(MANT_WIDTH+1)*(MANT_WIDTH+1)
    logic [EXP_WIDTH:0]  exp_sum_s2; //8+8, so 9 bits needed
    logic sign_res_s2;

    logic is_a_zero_s2, is_b_zero_s2;
    logic is_a_inf_s2, is_b_inf_s2;
    logic is_a_nan_s2, is_b_nan_s2;
    logic stage2_valid;

    always_ff @(posedge clk or posedge rst) begin 
        if (rst) begin 
            stage2_valid <= 1'b0;
            mant_prod_s2 <= 0;
            exp_sum_s2 <= 0;
            sign_res_s2 <= 1'b0;
            is_a_zero_s2 <= 1'b0;
            is_b_zero_s2 <= 1'b0;
            is_a_inf_s2 <= 1'b0;
            is_b_inf_s2 <= 1'b0;
            is_a_nan_s2 <= 1'b0;
            is_b_nan_s2 <= 1'b0;
        end else if (stage1_valid) begin 
            sign_res_s2 <= sign_res_s1;
            is_a_zero_s2 <= is_a_zero_s1;
            is_b_zero_s2 <= is_b_zero_s1;
            is_a_inf_s2 <= is_a_inf_s1;
            is_b_inf_s2 <= is_b_inf_s1;
            is_a_nan_s2 <= is_a_nan_s1;
            is_b_nan_s2 <= is_b_nan_s1;

            //handling special cases based on flags from stage 1
            if (is_a_nan_s1 || is_b_nan_s1) begin 
                mant_prod_s2 <= {2*MANT_WIDTH+1{1'bX}};
                exp_sum_s2 <= {EXP_WIDTH+1{1'bX}};
            end else if (is_a_inf_s1 || is_b_inf_s1) begin 
                //if either of the operand is infinity
                if ((is_a_zero_s1 && is_b_inf_s1) || (is_a_inf_s1 && is_b_zero_s1)) begin
                    // Special case: 0 * Inf results in NaN
                    mant_prod_s2 <= {2*MANT_WIDTH+1{1'bX}}; // Propagate NaN
                    exp_sum_s2 <= {EXP_WIDTH+1{1'bX}};      // Placeholder for NaN exponent
                end else begin
                    // Inf * X = Inf (where X is not 0)
                    mant_prod_s2 <= {1'b1, {2*MANT_WIDTH{1'b0}}}; // Mantissa for infinity (1.0 implied)
                    exp_sum_s2 <= {EXP_WIDTH+1{1'b1}};           // Exponent for infinity (all 1s)
                end
            end else if (is_a_zero_s1 || is_b_zero_s1) begin 
                // If either operand is Zero (and not 0 * Inf case)
                mant_prod_s2 <= {2*MANT_WIDTH+1{1'b0}}; // Mantissa for zero
                exp_sum_s2 <= 0;                         // Exponent for zero
            end else begin 
                //normal multiplication
                mant_prod_s2 <= mant_a_s1 * mant_b_s1;
                exp_sum_s2 <= exp_a_s1 + exp_b_s1;
            end
            stage2_valid <= 1'b1;
        end else begin

        end stage2_valid <= 1'b0;
    end

    //Pipelining Stage:3
    //Normalization, Rounding, Exponent adjustment, Packing result
    logic [EXP_WIDTH-1:0] exp_final_s3;
    logic [MANT_WIDTH-1:0] mant_final_s3;
    logic sign_final_s3;
    logic result_is_nan_s3;
    logic result_is_inf_s3;
    logic result_is_zero_s3;

    //internal wires for rounding and normalization
    logic [MANT_WIDTH*2:0] norm_mant_shifted; //mantissa after normalization
    logic [EXP_WIDTH+1:0] exp_adj; //adjusted exponent, can be negative as well
    logic [5:0] leading_bit_pos; //position of leading 1 in the prod mantissa

    logic guard_bit, round_bit, sticy_bit;
    logic round_up;

    //function to find the position of the most significant 1 bit
    function automatic [5:0] find_leading_bit_position;
        input [2*MANT_WIDTH:0] in;
        integer i;
        begin 
            find_leading_bit_position = 0;
            for (i = 2*MANT_WIDTH; i >= 0; i--) begin
                if (int[i]) begin 
                    find_leading_bit_position = i;
                    break;
                end
            end 
        end
    endfunction

    //Normalization, rounding,a and final result packing
    always_ff @(posedge clk or posedge rst) begin 
        if (rst) begin 
            result <= {DATA_WIDTH{1'b0}};
            result_valid <= 1'b0;
        end else if (stage2_valid) begin 
            sign_final_s3 <= sign_res_s2;

            // Propagate special flags from Stage 2 to determine final result type
            result_is_nan_s3 = is_a_nan_s2 || is_b_nan_s2 || ((is_a_inf_s2 && is_b_zero_s2) || (is_a_zero_s2 && is_b_inf_s2));
            result_is_inf_s3 = (is_a_inf_s2 || is_b_inf_s2) && !(is_a_zero_s2 || is_b_zero_s2); // Inf * 0 is NaN
            result_is_zero_s3 = is_a_zero_s2 || is_b_zero_s2;

            if (result_is_nan_s3) begin 
                // NaN result: sign (can be anything, typically 0), all 1s exponent, non-zero mantissa (quiet NaN)
                result <= {1'b0, {EXP_WIDTH{1'b1}}, {1'b1, {MANT_WIDTH-1{1'b0}}}};
            end else if (result_is_inf_s3) begin 
                // Infinity result: sign from operation, all 1s exponent, all 0s mantissa
                result <= {sign_final_s3, {EXP_WIDTH{1'b1}}, {MANT_WIDTH{1'b0}}};
            end else if (result_is_zero_s3) begin 
                // Zero result: sign from operation, all 0s exponent, all 0s mantissa
                result <= {sign_final_s3, {DATA_WIDTH-1{1'b0}}};
            end else begin

                //normalization and rounding for finite, non-zero result

                //calulating the position of leading 1 in the product mantissa
                leading_bit_pos = find_leading_bit_position(mant_prod_s2);
                
                integer normalization_shift;
                if (leading_bit_pos == 2*MANT_WIDTH) begin  //mantissa is of form 1X.XXX...
                    normalization_shift = 1;
                    norm_mant_shifted = mant_prod_s2 >> 1;
                end else begin
                    normalization_shift = 0;
                    norm_mant_shifted = mant_prod_s2; //no shift needed
                end

                //calculating adjusted exponent(exp_a+exp_b-2*BIAS)+normalization_shift_compensation
                exp_adj = exp_sum_s2 - (2*BIAS) + normalization_shift;

                //Extract G, R, S bits for rounding (Round to Nearest, Ties to Even)
                //The norm_mant_shifted now has the hidden bit at position 23
                //Gaurd bit is at index 22
                //Round bit is at index 21
                //Sticky bit is the OR of all the bits below R(MANT_WIDTH-3:0)
                guard_bit = norm_mant_shifted[MANT_WIDTH-1];
                round_bit = norm_mant_shifted[MANT_WIDTH-2];
                sticky_bit = |norm_mant_shifted[MANT_WIDTH-3:0];

                //determining if the rounding up is required
                //i.e. round up is (G and (R or S)) or ((G and not R and NOT S) and LSB is 1)
                /*
                Bits	Meaning	Action
                G R S = 1 x x	More than halfway	Round up
                G R S = 1 0 0, LSB = 1	Exactly halfway and LSB is 1	Round up (to even)
                G R S = 1 0 0, LSB = 0	Exactly halfway and LSB is 0	Round down (already even)
                */
                logic lsb_before_rounding = norm_mant_shifted[MANT_WIDTH]; //this is the LSB of the final 24-bit mantissa (hidden bit + 23 fraction bits)
                round_up = (guard_bit && (round_bit || sticky_bit)) || (guard_bit && !round_bit && !sticky_bit && lsb_before_rounding);

                //extract the 23 bit fraction and apply rounding
                //the hidden bit is at norm_mant_shifted[MANT_WIDTh]
                mant_final_s3 = norm_mant_shifted[MANT_WIDTH-1:0];
                if (round_up) begin 
                    mant_final_s3 = mant_final_s3 + 1;
                end

                //handling potential mantissa overflow after rounding
                //if rounding causes the 23-bit mantissa to become all 1s and then rounds up, it effectively becomes 1.00000....
                //this means the exponent needs to be incremented and the mantissa becomes 0
                if (mant_final_s3[MANT_WIDTH]) begin //if overflow
                    exp_adj = exp_adj + 1;
                    mant_final_s3 = {MANT_WIDTH{1'b0}}; //mantissa becomes all zero i.e. 1.0 coz of the hidden bit as it is in normzalized form
                end

                //exponent saturation and denormal handling
                if (exp_adj >= {EXP_WIDTH{1'b1}}) begin //exponent overflow: result is infinity
                    result <= {sign_final_s3, {EXP_WIDTH{1'b1}}, {MANT_WIDTH{1'b0}}};
                end else if (exp_adj <= 0) begin //exponent underflow: result is zero or denormal
                    //flusing to zero for underflow
                    result <= {sign_final_s3, {DATA_WIDTH-1{1'b0}}};
                end else begin //normal finite, non-zero result 
                    exp_final_s3 = exp_adj[EXP_WIDTH-1:0];
                    result <= {sign_final_s3, exp_final_s3, mant_final_s3};
                end
            end
            result_valid <= 1'b1;
        end else begin 
            result_valid <= 1'b0;
        end
    end

endmodule

`endif