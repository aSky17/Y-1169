//addsub unit pipelined into 3 stages
//Stage 1	Field extraction, sign logic, mantissa alignment, special case detection
//Stage 2	Actual add/sub, propagate special flags, generate intermediate result
//Stage 3	Normalize mantissa, apply rounding (GRS), handle overflow/underflow, pack result


/*
1	Compare exponents of both operands
2	Shift the smaller mantissa right by the exponent difference
3	After shifting, both mantissas are in the same exponent domain
4	Now add or subtract mantissas safely
5	Result might need normalization and rounding afterwards
*/

/*
IEEE 754 Single-Precision Floating-Point:
A 32-bit number is represented as:

Sign (S): 1 bit (bit 31). 0 for positive, 1 for negative.
Exponent (E): 8 bits (bits 30-23). Biased by 127. So, the actual exponent is E - 127.
Fraction (F): 23 bits (bits 22-0). This is the fractional part of the mantissa.
*/

`ifndef FP_ADDSUB_SV
`define FP_ADDSUB_SV

module fp_addsub #(
    import parameters::*
) (
    input logic clk,
    input logic rst,
    input logic [DATA_WIDTH-1:0] a,
    input logic [DATA_WIDTH-1:0] b,
    input logic sub, //0 for add, 1 for sub
    output logic [DATA_WIDTH-1:0] result,
    output logic result_valid
);
    

    //asserting that DATA_WIDTH is 32 bit
    initial begin 
        if (DATA_WIDTH != 32) begin
            $fatal(1, "Error: DATA_WIDTH must be 32 bits for this single precision PF unit");
        end
    end

    //IEEE 754 single-precision contants 
    localparam EXP_WIDTH = 8;
    localparam MANT_WIDTH = 23;
    localparam BIAS = 127; //its added to the exponent so the need of a sign bit for exponent could be omitted

    //Pipelining: Stage-1
    //registers to pass data to Stage-2
    logic [EXP_WIDTH-1:0] exp_large_s1, exp_small_s1;

    //1 hidden bit, 1 gaurd bit and 1 sticky bit
    //for normalized number, the most significant bit is always 1, so a hidden bit
    //for eg: if the guard bit is 1 and the sticky bit is 1, the result is rounded up
    //and if the gaurd bit is 0 and the sticky bit is 0, the result is rounded down 
    logic [MANT_WIDTH+2:0] mant_a_s1, mant_b_s1; 
    logic sign_a_s1, sign_b_s1;
    logic sub_eff_s1; // control whether mantissas are added or subtracted
    
    logic [EXP_WIDTH:0] exp_diff_s1; //1 extra bit handling for sspecial case when one one exponent is 0 and the other is 255 
    //defining another mantissa register to perform operations upon
    //keeping the above resgisters intact for other flags 
    logic [MANT_WIDTH+2:0] mant_large_s1, mant_small_s1;
    logic sign_res_s1; //tentative sign of the result
    logic is_a_zero_s1, is_b_zero_s1;
    logic is_a_inf_s1, is_b_inf_s1;
    logic is_a_nan_s1, is_b_nan_s1;
    logic stage1_valid;


    //Internal Combinational Wires for Stage 1
    //These wires hold intermediate results computed within the current clock cycle.
    logic [EXP_WIDTH-1:0] exp_a_comb, exp_b_comb;
    logic [MANT_WIDTH-1:0] raw_mant_a_comb, raw_mant_b_comb; // Raw mantissa from input
    logic [MANT_WIDTH+2:0] mant_a_padded_comb, mant_b_padded_comb; // Mantissa with hidden bit, guard, sticky

    logic is_a_zero_comb, is_b_zero_comb;
    logic is_a_inf_comb, is_b_inf_comb;
    logic is_a_nan_comb, is_b_nan_comb;
    logic sub_eff_comb;

    // These wires hold the result of the comparison/alignment logic *before* being registered.
    logic [EXP_WIDTH-1:0] exp_diff_calc_comb;
    logic [MANT_WIDTH+2:0] mant_large_calc_comb, mant_small_calc_comb;
    logic sign_res_calc_comb;


    // --- Combinational Logic for Stage 1: coz we needed some values before hand and doing everything inside always_ff instroduced wrong output coz of 1 delay cycle
    // This block performs all the computations that happen the current clock cycle.
    always_comb begin
        // Initialize all 'comb' wires to default values to avoid unintended latches.
        exp_a_comb = 0; exp_b_comb = 0;
        raw_mant_a_comb = 0; raw_mant_b_comb = 0;
        mant_a_padded_comb = 0; mant_b_padded_comb = 0;
        is_a_zero_comb = 1'b0; is_b_zero_comb = 1'b0;
        is_a_inf_comb = 1'b0; is_b_inf_comb = 1'b0;
        is_a_nan_comb = 1'b0; is_b_nan_comb = 1'b0;
        sub_eff_comb = 1'b0;
        exp_diff_calc_comb = 0;
        mant_large_calc_comb = 0; mant_small_calc_comb = 0;
        sign_res_calc_comb = 1'b0;


        //Extract fields from current inputs 'a' and 'b'
        exp_a_comb      = a[DATA_WIDTH-2:MANT_WIDTH];
        raw_mant_a_comb = a[MANT_WIDTH-1:0];
        mant_a_padded_comb = (exp_a_comb == 0) ? {1'b0, raw_mant_a_comb, 2'b00} : {1'b1, raw_mant_a_comb, 2'b00};

        exp_b_comb      = b[DATA_WIDTH-2:MANT_WIDTH];
        raw_mant_b_comb = b[MANT_WIDTH-1:0];
        mant_b_padded_comb = (exp_b_comb == 0) ? {1'b0, raw_mant_b_comb, 2'b00} : {1'b1, raw_mant_b_comb, 2'b00};

        // Determine effective operation: `sub` XORs with `b`'s sign
        sub_eff_comb = a[DATA_WIDTH-1] ^ b[DATA_WIDTH-1] ^ sub;

        // 2. Check for special values (Zero, Inf, NaN) based on raw input fields
        is_a_zero_comb = (exp_a_comb == 0) && (raw_mant_a_comb == 0);
        is_b_zero_comb = (exp_b_comb == 0) && (raw_mant_b_comb == 0);

        is_a_inf_comb = (exp_a_comb == {EXP_WIDTH{1'b1}}) && (raw_mant_a_comb == 0);
        is_b_inf_comb = (exp_b_comb == {EXP_WIDTH{1'b1}}) && (raw_mant_b_comb == 0);

        is_a_nan_comb = (exp_a_comb == {EXP_WIDTH{1'b1}}) && (raw_mant_a_comb != 0);
        is_b_nan_comb = (exp_b_comb == {EXP_WIDTH{1'b1}}) && (raw_mant_b_comb != 0);

        // 3. Logic for Exponent Alignment and Mantissa Ordering
        // The results of these decisions are stored in `_calc_comb` wires.
        if (is_a_nan_comb || is_b_nan_comb) begin
            exp_diff_calc_comb   = 0;
            mant_large_calc_comb = {MANT_WIDTH+3{1'bX}}; // Propagate 'X' for NaN mantissa
            mant_small_calc_comb = {MANT_WIDTH+3{1'bX}};
            sign_res_calc_comb   = 1'b0; // Don't care for NaN result sign
        end else if (is_a_inf_comb || is_b_inf_comb) begin
            exp_diff_calc_comb   = 0;
            mant_large_calc_comb = {MANT_WIDTH+3{1'bX}}; // Placeholder for Inf
            mant_small_calc_comb = {MANT_WIDTH+3{1'bX}};
            sign_res_calc_comb   = 1'b0; // Placeholder for Inf
        end else if (is_a_zero_comb && is_b_zero_comb) begin
            exp_diff_calc_comb   = 0;
            mant_large_calc_comb = {MANT_WIDTH+3{1'b0}}; // Result is zero
            mant_small_calc_comb = {MANT_WIDTH+3{1'b0}};
            sign_res_calc_comb   = 1'b0; // Sign of zero
        end else if (is_a_zero_comb) begin // A is zero, B is non-zero. Result is B.
            exp_diff_calc_comb   = 0; // No shift needed
            mant_large_calc_comb = mant_b_padded_comb;
            mant_small_calc_comb = {MANT_WIDTH+3{1'b0}}; // Smaller mantissa is effectively zero
            sign_res_calc_comb   = b[DATA_WIDTH-1]; // Sign of B
        end else if (is_b_zero_comb) begin // B is zero, A is non-zero. Result is A.
            exp_diff_calc_comb   = 0;
            mant_large_calc_comb = mant_a_padded_comb;
            mant_small_calc_comb = {MANT_WIDTH+3{1'b0}}; // Smaller mantissa is effectively zero
            sign_res_calc_comb   = a[DATA_WIDTH-1]; // Sign of A
        end else if (exp_a_comb > exp_b_comb) begin // Exponent of A > B
            exp_diff_calc_comb   = exp_a_comb - exp_b_comb;
            mant_large_calc_comb = mant_a_padded_comb;
            mant_small_calc_comb = mant_b_padded_comb;
            sign_res_calc_comb   = a[DATA_WIDTH-1]; // Sign of A (larger magnitude)
        end else if (exp_b_comb > exp_a_comb) begin // Exponent of B > A
            exp_diff_calc_comb   = exp_b_comb - exp_a_comb;
            mant_large_calc_comb = mant_b_padded_comb;
            mant_small_calc_comb = mant_a_padded_comb;
            sign_res_calc_comb   = b[DATA_WIDTH-1]; // Sign of B (larger magnitude)
        end else begin // Exponents are equal (exp_a_comb == exp_b_comb)
            exp_diff_calc_comb = 0;
            // For equal exponents, compare mantissas (using raw values for comparison) to determine larger
            if (raw_mant_a_comb >= raw_mant_b_comb) begin
                mant_large_calc_comb = mant_a_padded_comb;
                mant_small_calc_comb = mant_b_padded_comb;
                sign_res_calc_comb = a[DATA_WIDTH-1]; // Sign of A
            end else begin
                mant_large_calc_comb = mant_b_padded_comb;
                mant_small_calc_comb = mant_a_padded_comb;
                sign_res_calc_comb = b[DATA_WIDTH-1]; // Sign of B
            end
        end
    end

    //Sequential Logic for Stage-1
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            // Reset all Stage 1 pipeline registers to a known, safe state
            stage1_valid <= 1'b0;
            sign_a_s1 <= 1'b0;
            exp_large_s1 <= 0;
            mant_a_s1 <= 0;
            sign_b_s1 <= 1'b0;
            exp_small_s1 <= 0;
            mant_b_s1 <= 0;
            is_a_zero_s1 <= 1'b0;
            is_b_zero_s1 <= 1'b0;
            is_a_inf_s1 <= 1'b0;
            is_b_inf_s1 <= 1'b0;
            is_a_nan_s1 <= 1'b0;
            is_b_nan_s1 <= 1'b0;
            sub_eff_s1 <= 1'b0;
            exp_diff_s1 <= 0;
            mant_large_s1 <= 0;
            mant_small_s1 <= 0;
            sign_res_s1 <= 1'b0;
        end else begin
            // Pipeline the combinatorial results from this clock cycle into Stage 1 registers.
            // These _s1 registers will serve as the inputs for Stage 2 on the *next* clock cycle.
            stage1_valid <= 1'b1; // Indicate that valid data is now available for Stage 2

            // Register the extracted fields (original A/B components)
            sign_a_s1    <= a[DATA_WIDTH-1];
            exp_large_s1 <= exp_a_comb; // Register the *current* exp_a_comb
            mant_a_s1    <= mant_a_padded_comb;

            sign_b_s1    <= b[DATA_WIDTH-1];
            exp_small_s1 <= exp_b_comb; // Register the *current* exp_b_comb
            mant_b_s1    <= mant_b_padded_comb;

            // Register the status flags
            is_a_zero_s1 <= is_a_zero_comb;
            is_b_zero_s1 <= is_b_zero_comb;
            is_a_inf_s1  <= is_a_inf_comb;
            is_b_inf_s1  <= is_b_inf_comb;
            is_a_nan_s1  <= is_a_nan_comb;
            is_b_nan_s1  <= is_b_nan_comb;

            // Register the effective operation
            sub_eff_s1 <= sub_eff_comb;

            // Register the results of the exponent alignment and mantissa ordering
            exp_diff_s1   <= exp_diff_calc_comb;
            mant_large_s1 <= mant_large_calc_comb;
            mant_small_s1 <= mant_small_calc_comb;
            sign_res_s1   <= sign_res_calc_comb;
        end
    end

    //Pipelining: Stage-2
    //register to pass data to stage 3
    logic [MANT_WIDTH+3:0] mant_res_s2; //1 hidden, 2 gs, 1 bit extra for 
    logic [EXP_WIDTH-1:0] exp_res_s2;
    logic sign_res_s2;
    logic stage2_valid;
    logic in_a_nan_s2, is_b_nan_s2;
    logic is_a_inf_s2, is_b_inf_s2;
    logic is_a_zero_s2, is_b_zero_s2;
    logic sub_eff_s2;

    always_ff @(posedge clk or posedge rst) begin 
        if (rst) begin 
            stage2_valid <= 1'b0;
        end else if (stage1_valid) begin 
            exp_res_s2 <= exp_large_s1;
            sign_res_s2 <= sign_res_s1;
            sub_eff_s2 <= sub_eff_s1;

            is_a_nan_s2 <= is_a_nan_s1;
            is_b_nan_s2 <= is_b_nan_s1;
            is_a_inf_s2 <= is_a_inf_s1;
            is_b_inf_s2 <= is_b_inf_s1;
            is_a_zero_s2 <= is_a_zero_s1;
            is_b_zero_s2 <= is_b_zero_s1;

            //handling special cases propogates from stage 1
            //using stage-1 inputs as they are for current cycle, as using is_a_nan_s2 introduced one cycle delay 
            //if i would have to use is_a_nan_s2, i should have given 1 always block for computation of currnet cycle thingy
            if (is_a_nan_s1 || is_b_nan_s1) begin 
                mant_res_s2 <= {MANT_WIDTH+4{1'bX}}; //propogate NaN
            end else if (is_a_inf_s1 || is_b_inf_s1) begin 
                if (is_a_inf_s1 && is_b_inf_s1 && sub_eff_s1) begin // Inf - Inf = NaN
                    mant_res_s2 <= {MANT_WIDTH+4{1'bX}}; // Propagate NaN
                end else if (is_a_inf_s1) begin // A is Inf, B is finite or +/-0
                    mant_res_s2 <= {1'b1, {MANT_WIDTH+2{1'b0}}}; // Sign of A determines Inf
                end else begin // B is Inf, A is finite or +/-0
                    mant_res_s2 <= {1'b1, {MANT_WIDTH+2{1'b0}}}; // Sign of B determines Inf
                end
            end else if (is_a_zero_s1 && is_b_zero_s1) begin 
                mant_res_s2 <= {MANT_WIDTH+4{1'b0}}; // Result is zero
            end else if (is_a_zero_s1 || is_b_zero_s1) begin 
                mant_res_s2 <= mant_large_s1;
            end else begin 
                mant_res_s2 <= sub_eff_s1 ? (mant_large_s1 - mant_small_s1) :(mant_large_s1+- mant_small_s1);
            end
            stage2_valid <= 1'b1;
        end else begin 
            stage2_valid <= 1'b0;
        end
    end

    //Pipelining Stage-3
    //registers
    logic [EXP_WIDTH-1:0] exp_final_s3;
    logiic [MANT_WIDTH-1:0] mant_final_s3;
    logic sign_final_s3;
    logic result_is_nan_s3;
    logic result_is_inf_s3;
    logic result_is_zero_s3;

    //internal wires for normalization and rounding 
    logic [MANT_WIDTH+3:0] norm_mant;
    logic [EXP_WIDTH:0] exp_adj; //adjusted exponent (can go negative)
    logic [5:0] leading_zeros; // max leading zeros in 26 bits
    logic ground_bit, round_bit, sticky_bit;
    logic rounded_up;

    //function to count leading zeroes
    function automatic [5:0] count_leading_zeros_func;
        input [MANT_WIDTH+3:0] in; //23 original, 1 hidden, 2grs
        integer i;
        begin 
            count_leading_zeros_func = 0;
            for (i = MANT_WIDTH+3; i>=0; i--) begin //25 to 0
                if (in[i]) begin 
                    count_leading_zeros_func = (MANT_WIDTH+3) - i;
                    disable count_leading_zeros_func;
                end
            end
        end
    endfunction

        always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            result <= {DATA_WIDTH{1'b0}};
            result_valid <= 1'b0;
        end else if (stage2_valid) begin
            sign_final_s3 <= sign_res_s2;

            result_is_nan_s3 = is_a_nan_s2 || is_b_nan_s2 || (is_a_inf_s2 && is_b_inf_s2 && sub_eff_s2);
            result_is_inf_s3 = (is_a_inf_s2 || is_b_inf_s2) && !(is_a_inf_s2 && is_b_inf_s2 && sub_eff_s2);
            result_is_zero_s3 = (is_a_zero_s2 && is_b_zero_s2) || (mant_res_s2 == 0);

            if (result_is_nan_s3) begin
                result <= {sign_final_s3, {EXP_WIDTH{1'b1}}, {1'b1, {MANT_WIDTH-1{1'b0}}}};
            end else if (result_is_inf_s3) begin
                result <= {sign_final_s3, {EXP_WIDTH{1'b1}}, {MANT_WIDTH{1'b0}}};
            end else if (result_is_zero_s3) begin
                result <= {1'b0, {DATA_WIDTH-1{1'b0}}};
            end else begin
                // Normalization
                if (mant_res_s2[MANT_WIDTH+2]) begin //if bit just aove the hidden bit is 1, it means mantissa overflowed
                    norm_mant = mant_res_s2 >> 1; //shift right
                    exp_adj = exp_res_s2 + 1; 
                    guard_bit = mant_res_s2[0]; //grab gaurd bit for rounding
                    round_bit = 0;
                    sticky_bit = 0;
                end else begin //if no overflow, normalizing by left shifting until MSB is 1
                    leading_zeros = count_leading_zeros_func(mant_res_s2);
                    norm_mant = mant_res_s2 << leading_zeros;
                    exp_adj = exp_res_s2 - leading_zeros;

                    guard_bit = norm_mant[1];
                    round_bit = norm_mant[0];
                    sticky_bit = |(mant_res_s2 & ((1 << (leading_zeros - 1)) - 1));n //Sticky is the OR of all bits that were shifted out
                end

                //Implementing Round to Nearest, Ties to Even
                //if gaurd = 1 nad round or sticky is = 1 -> round up
                //OR Guard = 1 and exact halfway (round=0, sticky=0) and mantissa LSB is 1 (tie → round to even)
                logic lsb_before_rounding = norm_mant[MANT_WIDTH+1];

                round_up = (guard_bit && (round_bit || sticky_bit)) || (guard_bit && !round_bit && !sticky_bit && lsb_before_rounding);

                mant_final_s3 = norm_mant[MANT_WIDTH+1:MANT_WIDTH+1-MANT_WIDTH] + round_up;

                if (mant_final_s3[MANT_WIDTH]) begin //if rouding causes mantissa to overflow, shift right and increase exponent
                    exp_adj = exp_adj + 1;
                    mant_final_s3 = {1'b0, mant_final_s3[MANT_WIDTH-1:1]};
                end

                // Exponent saturation and denormal handling
                if (exp_adj >= {EXP_WIDTH{1'b1}}) begin //overflow
                    result <= {sign_final_s3, {EXP_WIDTH{1'b1}}, {MANT_WIDTH{1'b0}}};
                end else if (exp_adj <= 0) begin //underflow
                    result <= {sign_final_s3, {DATA_WIDTH-1{1'b0}}};
                end else begin //if none of the above flow
                    result <= {sign_final_s3, exp_adj, mant_final_s3};
                end
            end
            result_valid <= 1'b1;
        end else begin
            result_valid <= 1'b0;
        end
    end
endmodule

`endif