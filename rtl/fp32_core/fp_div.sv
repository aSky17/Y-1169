//5-Stage Pipelined Division(FDIV) unit

//Stage-1: Operand field extraction and special cases detection
//Stage-2: Mantissa multiplication and initial exponent sum
//Stage-3: Mantissa alignment and Addition/Subtraction
//Stage-4: Normalization and Rounding 
//Stage-5: Final result packing and output handling

`ifndef FP_DIV_SV
`define FP_DIV_SV

module fp_div #(
    import gpu_parameters::*
) (
    input logic clk,
    input logic rst,
    input logic [DATA_WIDTH-1:0] operand_a,
    input logic [DATA_WIDTH-1:0] operand_b,

    output logic result_valid,
    output logic [DATA_WIDTH-1:0] result
);

    initial begin
        if (DATA_WIDTH != 32) begin 
            fatal(1,"DATA_WIDTH must be 32 bits");
        end
    end

    localparam EXP_WIDTH = 8;
    localparam MANT_WIDTH = 23;
    localparam BIAS = 127;

    //Pipelining stage-1: Operand field extraction and special cases detection
    //Stage-1 registers 
    logic stage1_valid_q;
    logic sign_a_s1_q, sign_b_s1_q;
    logic [EXP_WIDTH-1:0] exp_a_s1_q, exp_b_s1_q;
    logic [MANT_WIDTH:0] mant_a_s1_q, mant_b_s1_q; //24 bits
    logic is_a_zero_s1_q, is_b_zero_s1_q;
    logic is_a_inf_s1_q, is_b_inf_s1_q;
    logic is_a_nan_s1_q, is_b_nan_s1_q;

    //combinational wires for stage-1
    logic [EXP_WIDTH-1:0] exp_a_s1_comb, exp_b_s1_comb;
    logic [MANT_WIDTH-1:0] raw_mant_a_s1_comb, raw_mant_b_s1_comb;
    logic [MANT_WIDTH:0] mant_a_padded_s1_comb, mant_b_padded_s1_comb;

    logic is_a_zero_s1_comb, is_b_zero_s1_comb;
    logic is_a_inf_s1_comb, is_b_inf_s1_comb;
    logic is_a_nan_s1_comb, is_b_nan_s1_comb; 

    always_comb begin
        exp_a_s1_comb = '0; exp_b_s1_comb = '0;
        raw_mant_a_s1_comb = '0; raw_mant_b_s1_comb = '0;
        mant_a_padded_s1_comb = '0; mant_b_padded_s1_comb '0;
        is_a_zero_s1_comb = 1'b0; is_b_zero_s1_comb = 1'b0;
        is_a_inf_s1_comb = 1'b0; is_b_inf_s1_comb = 1'b0;
        is_a_nan_s1_comb = 1'b0; is_b_nan_s1_comb = 1'b0;

        //process operand_a
        exp_a_s1_comb = a[DATA_WIDTH-2:MANT_WIDTH];
        raw_mant_a_s1_comb = a[MANT_WIDTH-1:0];
        mant_a_padded_s1_comb = (exp_a_s1_comb == 0) ? {1'b0, raw_mant_a_s1_comb} : {1'b1, raw_mant_a_s1_comb};
        is_a_zero_s1_comb = (exp_a_s1_comb == 0) && (raw_mant_a_s1_comb == 0);
        is_a_inf_s1_comb = (exp_a_s1_comb == {EXP_WIDTH{1'b1}}) && (raw_mant_a_s1_comb == 0);
        is_a_nan_s1_comb = (exp_a_s1_comb == {EXP_WIDTH{1'b1}}) && (raw_mant_a_s1_comb != 0);

        //process operand_b
        exp_b_s1_comb = b[DATA_WIDTH-2:MANT_WIDTH];
        raw_mant_b_s1_comb = b[MANT_WIDTH-1:0];
        mant_b_padded_s1_comb = (exp_b_s1_comb == 0) ? {1'b0, raw_mant_b_s1_comb} : {1'b1, raw_mant_b_s1_comb};
        is_b_zero_s1_comb = (exp_b_s1_comb == 0) && (raw_mant_b_s1_comb == 0);
        is_b_inf_s1_comb = (exp_b_s1_comb == {EXP_WIDTH{1'b1}}) && (raw_mant_b_s1_comb == 0);
        is_b_nan_s1_comb = (exp_b_s1_comb == {EXP_WIDTH{1'b1}}) && (raw_mant_b_s1_comb != 0);
    end

    //registering
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin 
            stage1_valid_q <= 1'b0;
            sign_a_s1_q <= 1'b0; sign_b_s1_q <= 1'b0;
            exp_a_s1_q <= '0; exp_b_s1_q <= '0;
            mant_a_s1_q <= '0; mant_b_s1_q <= '0; 
            is_a_zero_s1_q <= 1'b0; is_b_zero_s1_q <= 1'b0;
            is_a_inf_s1_q <= 1'b0; is_b_inf_s1_q <= 1'b0;
            is_a_nan_s1_q <= 1'b0; is_b_nan_s1_q <= 1'b0;
        end else begin
            stage1_valid_q <= 1'b1;
            sign_a_s1_q <= a[DATA_WIDTH-1];
            sign_b_s1_q <= b[DATA_WIDTH-1];
            exp_a_s1_q <= exp_a_s1_comb;
            exp_b_s1_q <= exp_b_s1_comb;
            mant_a_s1_q <= mant_a_padded_s1_comb;
            mant_b_s1_q <= mant_b_padded_s1_comb;
            is_a_zero_s1_q <= is_a_zero_s1_comb;
            is_b_zero_s1_q <= is_b_zero_s1_comb;
            is_a_inf_s1_q <= is_a_inf_s1_comb;
            is_b_inf_s1_q <= is_b_inf_s1_comb;
            is_a_nan_s1_q <= is_a_nan_s1_comb;
            is_b_nan_s1_q <= is_b_nan_s1_comb;
        end
    end

    //Pipelining Stage-2: Exponent subtraction and initial special case resolution
    //Stage-2 registers
    logic stage2_valid_q;
    logic signed [EXP_WIDTH:0] exp_diff_s2_q;
    logic sign_quotient_s2_q;
    logic [MANT_WIDTH:0] mant_a_prep_s2_q; //dividend
    logic [MANT_WIDTH:0] mant_b_prep_s2_q; //divisor
    
    logic is_a_zero_s2_q, is_b_zero_s2_q;
    logic is_a_inf_s2_q, is_b_inf_s2_q;
    logic is_a_nan_s2_q, is_b_nan_s2_q;

    logic is_quotient_zero_s2_q, is_quotient_inf_s2_q, is_quotient_nan_s2_q;

    //combinantional wires for stage-2
    logic signed [EXP_WIDTH:0] exp_diff_s2_comb;
    logic sign_quotient_s2_comb;
    logic [MANT_WIDTH:0] mant_a_prep_s2_comb;
    logic [MANT_WIDTH:0] mant_b_prep_s2_comb;
    logic is_quotient_zero_s2_comb, is_quotient_inf_s2_comb, is_quotient_nan_s2_comb;

    always_comb begin
        exp_diff_s2_comb = '0;
        sign_quotient_s2_comb = 1'b0;
        mant_a_prep_s2_comb = '0;
        mant_b_prep_s2_comb = '0;
        is_quotient_zero_s2_comb = 1'b0;
        is_quotient_inf_s2_comb = 1'b0;
        is_quotient_nan_s2_comb = 1'b0;

        //calculating sign of a/b
        sign_quotient_s2_comb = sign_a_s1_q ^ sign_b_s1_q;

        //handling special cases of a/b
        if (is_a_nan_s1_q || is_b_nan_s1_q) begin 
            is_quotient_nan_s2_comb = 1'b1;
        end else if (is_a_zero_s1_q && is_b_zero_s1_q) begin 
            is_quotient_zero_s2_comb = 1'b1;
        end else if (is_a_inf_s1_q && is_b_inf_s1_q) begin 
            is_quotient_nan_s2_comb = 1'b1;
        end else if (is_a_inf_s1_q) begin 
            is_quotient_inf_s2_comb = 1'b1;
        end else if (is_b_inf_s1_q) begin 
            is_quotient_zero_s2_comb = 1'b1;
        end else if (is_a_zero_s1_q) begin 
            is_quotient_zero_s2_comb = 1'b1;
        end else if (is_b_zero_s1_q) begin 
            is_quotient_inf_s2_comb = 1'b1;
        end else begin 
            //normal division
            //exponent subtraction: Exp_A - Exp_B + BIAS
            exp_diff_s2_comb = exp_a_s1_q - exp_b_s1_q + BIAS;
            mant_a_prep_s2_comb = mant_a_s1_q;
            mant_b_prep_s2_comb = mant_b_s1_q;
        end
    end

    //registering
    always_ff @(posedge clk or posedge rst) begin 
        if (rst) begin 
            stage2_valid_q <= 1'b0;
            exp_diff_s2_q <= '0;
            sign_quotient_s2_q <= 1'b0;
            mant_a_prep_s2_q <= '0;
            mant_b_prep_s2_q <= '0;
            is_a_zero_s2_q <= 1'b0; is_b_zero_s2_q <= 1'b0;
            is_a_inf_s2_q <= 1'b0; is_b_inf_s2_q <= 1'b0;
            is_a_nan_s2_q <= 1'b0; is_b_nan_s2_q <= 1'b0;
            is_quotient_zero_s2_q <= 1'b0; is_quotient_inf_s2_q <= 1'b0; is_quotient_nan_s2_q <= 1'b0;
        end else if (stage1_valid_q) begin 
            stage2_valid_q <= 1'b1;
            exp_diff_s2_q <= exp_diff_s2_comb;
            sign_quotient_s2_q <= sign_quotient_s2_comb;
            mant_a_prep_s2_q <= mant_a_prep_s2_comb;
            mant_b_prep_s2_q <= mant_b_prep_s2_comb;
            
            is_a_zero_s2_q <= is_a_zero_s1_q;
            is_b_zero_s2_q <= is_b_zero_s1_q;
            
            is_a_inf_s2_q <= is_a_inf_s1_q;
            is_b_inf_s2_q <= is_b_inf_s1_q;
            
            is_a_nan_s2_q <= is_a_nan_s1_q;
            is_b_nan_s2_q <= is_b_nan_s1_q;
            
            is_quotient_zero_s2_q <= is_quotient_zero_s2_comb;
            is_quotient_inf_s2_q <= is_quotient_inf_s2_comb;
            is_quotient_nan_s2_q <= is_quotient_nan_s2_comb;
        end else begin 
            stage2_valid_q <= 1'b0;
        end
    end 


    //Stage-3: Mantissa division
    //Stage-3 Regsisters
    localparam QUOTIENT_MANT_WIDTH = MANT_WIDTH + 1;
    localparam REM_WIDTH = MANT_WIDTH + 1;

    logic stage3_valid_q;
    logic [QUOTIENT_MANT_WIDTH-1:0] quotient_partial_s3_q;
    logic [REM_WIDTH-1:0] remainder_partial_s3_q;
    logic [EXP_WIDTH:0] exp_quotient_s3_q;
    logic sign_quotient_s3_q;

    logic is_quotient_zero_s3_q, is_quotient_inf_s3_q, is_quotient_nan_s3_q;

    //combinational wires for stage-3
    localparam PARTIAL_Q_BITS = QUOTIENT_MANT_WIDTH / 2;

    logic [QUOTIENT_MANT_WIDTH-1:0] quotient_partial_s3_comb;
    logic [REM_WIDTH-1:0] remainder_partial_s3_comb;
    logic signed [EXP_WIDTH:0] exp_quotient_s3_comb;
    logic sign_quotient_s3_comb;
    logic is_quotient_zero_s3_comb, is_quotient_inf_s3_comb, is_quotient_nan_s3_comb;

    always_comb begin
        quotient_partial_s3_comb = '0;
        remainder_partial_s3_comb = '0;
        exp_quotient_s3_comb = '0;
        sign_quotient_s3_comb = 1'b0;
        is_quotient_zero_s3_comb = 1'b0;
        is_quotient_inf_s3_comb = 1'b0;
        is_quotient_nan_s3_comb = 1'b0;

        //propogate quotient flags from the previous stage
        is_quotient_zero_s3_comb = is_quotient_zero_s2_q;
        is_quotient_inf_s3_comb = is_quotient_inf_s2_q;
        is_quotient_nan_s3_comb = is_quotient_nan_s2_q;

        //in a special case no division is performed
        if (is_quotient_zero_s2_q || is_quotient_inf_s2_q || is_quotient_nan_s2_q) begin 
            //will hanlde in the final packing stage
            quotient_partial_s3_comb = '0;
            remainder_partial_s3_comb = '0;
            exp_quotient_s3_comb = exp_diff_s2_comb;
            sign_quotient_s3_comb = sign_quotient_s3_q;
        end else begin 
            //simplified iterative division
            //Extend dividend by MANT_WIDTH+1 bits for precision
            logic [2*MANT_WIDTH+2:0] dividend_extended;
            logic [MANT_WIDTH:0] divisor_normalized = mant_b_prep_s2_q;

            // Initial normalization: Ensure dividend is larger than divisor for a 1.xx result
            // If dividend is 1.xxxx and divisor is 1.xxxx, the quotient is 0.xxxx.
            // We want 1.xxxx for normalized result. So if dividend < divisor, we shift dividend left once
            // and decrement exponent.
            exp_quotient_s3_comb = exp_diff_s2_q;
            if (mant_a_prep_s2_q < mant_b_prep_s2_q) begin 
                dividend_extended = {mant_a_prep_s2_q, {MANT_WIDTH+2{1'b0}}} << 1; //shift dividend left
                exp_quotient_s3_comb = exp_quotient_s3_comb - 1; //decrement exponent for normalization
            end else begin 
                dividend_extended = {mant_a_prep_s2_q, {MANT_WIDTH+2{1'b0}}}; //no shift
            end

            quotient_partial_s3_comb = dividend_extended[2*MANT_WIDTH+1:MANT_WIDTH+2] / divisor_normalized;
            remainder_partial_s3_comb = dividend_extended[MANT_WIDTH+1:0] % divisor_normalized;

            sign_quotient_s3_comb = sign_quotient_s2_q;
        end
    end

    //registering stage-3
    always_ff @(posedge clk or posedge rst) begin 
        if (rst) begin 
            stage3_valid_q <= 1'b0;
            quotient_partial_s3_q <= '0;
            remainder_partial_s3_q <= '0;
            exp_quotient_s3_q <= '0;
            sign_quotient_s3_q <= 1'b0;
            is_quotient_zero_s3_q <= 1'b0;
            is_quotient_inf_s3_q <= 1'b0;
            is_quotient_nan_s3_q <= 1'b0;
        end else if (stage2_valid_q) begin 
            stage3_valid_q <= 1'b1;
            quotient_partial_s3_q <= quotient_partial_s3_comb;
            remainder_partial_s3_q <-= remainder_partial_s3_comb;
            exp_quotient_s3_q <= exp_quotient_s3_comb;
            sign_quotient_s3_q <= sign_quotient_s3_comb;
            is_quotient_zero_s3_q <= is_quotient_zero_s3_comb;
            is_quotient_inf_s3_q <= is_quotient_inf_s3_comb;
            is_quotient_nan_s3_q <= is_quotient_nan_s3_comb;
        end else begin 
            stage3_valid_q <= 1'b0;
        end
    end

    //Stage-4: Mantissa division and pre-normalization
    //Stage-4 registers
    localparam ROUNDING_MANT_WIDTH = QUOTIENT_MANT_WIDTH + 3; // 24 + 3 = 27 bits (for G, R, S)
    logic stage4_valid_q;
    logic [ROUNDING_MANT_WIDTH-1:0] mant_quotient_full_s4_q;
    logic [EXP_WIDTH:0] exp_quotient_s4_q;
    logic sign_quotient_s4_q;

    // Final special case flags derived from all preceding stages
    logic is_final_result_zero_s4_q;
    logic is_final_result_inf_s4_q;
    logic is_final_result_nan_s4_q;

    //combinational wires for stage-4
    logic [ROUNDING_MANT_WIDTH-1:0] mant_quotient_full_s4_comb;
    logic [EXP_WIDTH:0] exp_quotient_s4_comb;
    logic sign_quotient_s4_comb;
    logic is_final_result_zero_s4_comb;
    logic is_final_result_inf_s4_comb;
    logic is_final_result_nan_s4_comb;

    // Local parameters for bit positions within mant_quotient_full_s4_comb
    localparam IMPLIED_ONE_POS_S4 = QUOTIENT_MANT_WIDTH - 1; // 23 (for 24-bit quotient)
    localparam FRACTION_MSB_POS_S4 = IMPLIED_ONE_POS_S4 - 1; // 22 (Start of 23-bit fraction part)
    localparam FRACTION_LSB_POS_S4 = 0; // The actual 23-bit mantissa will be 22:0
    localparam G_BIT_POS_S4 = -1; 
    localparam R_BIT_POS_S4 = -2;
    localparam S_BITS_LSB_POS_S4 = -3; 

    // For a 27-bit full quotient [26:0]
    // Hidden bit at 26. Fraction 25:3. G:2, R:1, S:0.
    localparam FULL_Q_HIDDEN_BIT_S4 = ROUNDING_MANT_WIDTH - 1; // 26
    localparam FULL_Q_FRACTION_MSB_S4 = FULL_Q_HIDDEN_BIT_S4 - 1; // 25
    localparam FULL_Q_FRACTION_LSB_S4 = FULL_Q_HIDDEN_BIT_S4 - MANT_WIDTH; // 26-23=3
    localparam FULL_Q_G_BIT_S4 = FULL_Q_FRACTION_LSB_S4 - 1; // 2
    localparam FULL_Q_R_BIT_S4 = FULL_Q_G_BIT_S4 - 1; // 1
    localparam FULL_Q_S_BIT_S4 = FULL_Q_R_BIT_S4 - 1; // 0

    always_comb begin 
        mant_quotient_full_s4_comb = '0;
        exp_quotient_s4_comb = '0;
        sign_quotient_s4_comb = '0;
        is_final_result_zero_s4_comb = 1'b0;
        is_final_result_inf_s4_comb = 1'b0;
        is_final_result_nan_s4_comb = 1'b0;

        is_final_result_zero_s4_comb = is_quotient_zero_s3_q;
        is_final_result_inf_s4_comb = is_quotient_inf_s3_q;
        is_final_result_nan_s4_comb = is_quotient_nan_s3_q;

        if (is_quotient_zero_s3_q || is_quotient_inf_s3_q || is_quotient_nan_s3_q) begin 
            mant_quotient_full_s4_comb = '0;
            exp_quotient_s4_comb = exp_quotient_s3_q;
            sign_quotient_s4_comb = sign_quotient_s3_q;
        end else begin 
            mant_quotient_full_s4_comb = {quotient_partial_s3_q, remainder_partial_s3_q[10:0], 3'b000}; // Just a placeholder for GRS

            integer lead_one_index;
            integer shift_amount = 0;
            lead_one_index = FULL_Q_HIDDEN_BIT_S4;
            for (int i = FULL_Q_HIDDEN_BIT_S4;; i>=0;i--) begin 
                if (mant_quotient_full_s4_comb[i]) begin 
                    lead_one_index = i;
                    break;
                end
            end
            shift_amount = FULL_Q_HIDDEN_BIT_S4 - lead_one_index;

            if (shift_amount > 0) begin 
                mant_quotient_full_s4_comb = mant_quotient_full_s4_comb << shift_amount;
                exp_quotient_s4_comb = exp_quotient_s3_q - shift_amount;
            end else begin 
                exp_quotient_s4_comb = exp_quotient_s3_q;
            end

            sign_quotient_s4_comb = sign_quotient_s3_q;
        end
    end

    //registering stage-4
    always_ff @(posedge clk or posedge rst) begin 
        if (rst) begin 
            stage4_valid_q <= 1'b0;
            mant_quotient_full_s4_q <= '0;
            exp_quotient_s4_q <= '0;
            sign_quotient_s4_q <= 1'b0;
            is_final_result_zero_s4_q <= 1'b0;
            is_final_result_inf_s4_q <= 1'b0;
            is_final_result_nan_s4_q <= 1'b0;
        end else if (stage3_valid_q) begin 
            stage4_valid_q <= 1'b1;
            mant_quotient_full_s4_q <= mant_quotient_full_s4_comb;
            exp_quotient_s4_q <= exp_quotient_s4_comb;
            sign_quotient_s4_q <= sign_quotient_s4_comb;
            is_final_result_zero_s4_q <= is_final_result_zero_s4_comb;
            is_final_result_inf_s4_q <= is_final_result_inf_s4_comb;
            is_final_result_nan_s4_q <= is_final_result_nan_s4_comb;
        end else begin 
            stage4_valid_q <= 1'b0;
        end
    end

    //Pipelininng Stage-5: Rouding and  final result packing
    //combinational wires for stage-5
    logic [MANT_WIDTH-1:0] mant_final_s5_comb;
    logic [EXP_WIDTH-1:0] exp_final_s5_comb;
    logic sign_final_s5_comb;

    logic g_bit_s5_comb, r_bit_s5_comb, s_bit_s5_comb;
    logic round_up_s5_comb;
    logic rounding_overflow_occured_s5_comb;

    logic is_exp_overflow_s5_comb;
    logic is_exp_underflow_s5_comb;
    logic is_result_denormal_s5_comb;

    logic [DATA_WIDTH-1:0] packed_result_s5_comb;

    always_comb begin 
        mant_final_s5_comb = '0;
        exp_final_s5_comb = '0;
        sign_final_s5_comb = 1'b0;
        g_bit_s5_comb = 1'b0;
        r_bit_s5_comb = 1'b0;
        s_bit_s5_comb = 1'b0;
        round_up_s5_comb = 1'b0;
        rounding_overflow_occured_s5_comb = 1'b0;
        is_exp_overflow_s5_comb = 1'b0;
        is_exp_underflow_s5_comb = 1'b0;
        is_result_denormal_s5_comb = 1'b0;
        packed_result_s5_comb = '0;

        sign_final_s5_comb = sign_quotient_s4_q;

        if (is_final_result_nan_s4_q) begin
            packed_result_s5_comb = {1'b0, {EXP_WIDTH{1'b1}}, {1'b1, {MANT_WIDTH-1{1'b0}}}}; //QNaN
        end else if (is_final_result_inf_s4_q) begin 
            packed_result_s5_comb = {sign_quotient_s4_q, {EXP_WIDTH{1'b1}}, {MANT_WIDTH{1'b0}}}; //INF
        end else if (is_final_result_zero_s4_q) begin 
            packed_result_s5_comb = {sign_quotient_s4_q, {EXP_WIDTH{1'b0}}, {MANT_WIDTH{1'b0}}}; //zero
        end else begin 
            //Rounding: round to nearest, ties to even
            mant_final_s5_comb = mant_quotient_full_s4_q[FULL_Q_FRACTION_MSB_S4 : FULL_Q_FRACTION_LSB_S4];
            g_bit_s5_comb = mant_quotient_full_s4_q[FULL_Q_G_BIT_S4];
            r_bit_s5_comb = mant_quotient_full_s4_q[FULL_Q_R_BIT_S4];
            s_bit_s5_comb = mant_quotient_full_s4_q[FULL_Q_S_BIT_S4];

            round_up_s5_comb = (g_bit_s5_comb && (r_bit_s5_comb || s_bit_s5_comb)) ||
                                (g_bit_s5_comb && !r_bit_s5_comb && !s_bit_s5_comb && mant_final_s5_comb[0]);

            if (round_up_s5_comb) begin 
                mant_final_s5_comb = mant_final_s5_comb + 1;
                if (mant_final_s5_comb[MANT_WIDTH]) begin  //Mantissa overflow
                    rounding_overflow_occured_s5_comb = 1'b1;
                    mant_final_s5_comb = {MANT_WIDTH{1'b0}}; //mantissa becomes 0.0, means 1.0
                    exp_quotient_s4_q = exp_quotient_s4_q + 1; //increase exponent
                end
            end

            //Exponent Overflow/Underflow and denormal handling
            if (exp_quotient_s4_q > ((1 << EXP_WIDTH) - 2 - BIAS)) begin  // Check if exponent is too large
                is_exp_overflow_s5_comb = 1'b1;
            end
            if (exp_quotient_s4_q < (1 - BIAS)) begin 
                is_exp_underflow_s5_comb = 1'b1;
                integer denormal_shift = (1 - BIAS) - exp_quotient_s4_q;
                if (denormal_shift >= (MANT_WIDTH + 1)) begin //shift too large, becomes zero
                    packed_result_s5_comb = {sign_final_s5_comb, {DATA_WIDTH-1{1'b0}}}; //zero
                end else begin
                    is_result_denormal_s5_comb = 1'b1;
                    mant_final_s5_comb = ({1'b1, mant_final_s5_comb} >> denormal_shift)[MANT_WIDTH-1:0];
                    exp_final_s5_comb = {EXP_WIDTH{1'b0}}; //denormal exponent is 0
                end
            end
                
            //final result packing for normal/denormal
            if (is_exp_overflow_s5_comb) begin 
                packed_result_s5_comb = {sign_final_s5_comb, {EXP_WIDTH{1'b1}}, {MANT_WIDTH{1'b0}}}; //infinity
            end else if (is_result_denormal_s5_comb) begin 
                packed_result_s5_comb = {sign_final_s5_comb, exp_final_s5_comb, mant_final_s5_comb};
            end else begin 
                exp_final_s5_comb = exp_quotient_s4_q[EXP_WIDTH-1:0] + BIAS;
                packed_result_s5_comb = {sign_final_s5_comb, exp_final_s5_comb, mant_final_s5_comb};
            end
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin 
            result <= '0;
            result_valid <= 1'b0;
        end else if (stage4_valid_q) begin 
            result <= packed_result_s5_comb;
            result_valid <= 1'b1;
        end else begin 
            result_valid <= 1'b0;
        end
    end

endmodule
`endif