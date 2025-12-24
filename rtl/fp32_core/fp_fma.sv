//5-Stage Pipelined Fused Multiply-Add(FMA) unit

//Stage-1: Operand field extraction and special cases detection
//Stage-2: Mantissa multiplication and initial exponent sum
//Stage-3: Mantissa alignment and Addition/Subtraction
//Stage-4: Normalization and Rounding 
//Stage-5: Final result packing and output handling

`ifndef FP_FMA_SV
`define FP_FMA_SV

module fp_fma #(
    import parameters::*
) (
    input logic clk,
    input logic rst,
    input logic [DATA_WIDTH-1:0] operand_a,
    input logic [DATA_WIDTH-1:0] operand_b,
    input logic [DATA_WIDTH-1:0] operand_c,
    output logic [DATA_WIDTH-1:0] result,
    output logic result_valid
);
    
    initial begin 
        if (DATA_WIDTH != 32) begin 
            $fatal(1,"DATA_WIDTH must be 32 bits");
        end
    end

    //IEEE 754 single-precision constants
    localparam EXP_WIDTH = 8;
    localparam MANT_WIDTH = 23;
    localparam BIAS = 127;

    //Pipelining Stage-1 Operand field extraction and special cases detection
    //Stage-1 registers
    logic stage1_valid_q;
    logic sign_a_s1_q, sign_b_s1_q, sign_c_s1_q;
    logic [EXP_WIDTH-1:0] exp_a_s1_q, exp_b_s1_q, exp_c_s1_q;
    logic [MANT_WIDTH:0] mant_a_s1_q, mant_b_s1_q, mant_c_s1_q; //mantissa including the hidden bit
    logic is_a_zero_s1_q, is_b_zero_s1_q, is_c_zero_s1_q;
    logic is_a_inf_s1_q, is_b_inf_s1_q, is_c_inf_s1_q;
    logic is_a_nan_s1_q, is_b_nan_s1_q, is_c_nan_s1_q;

    //combinational wires for stage 1
    logic [EXP_WIDTH-1:0] exp_a_s1_comb, exp_b_s1_comb, exp_c_s1_comb;
    logic [MANT_WIDTH-1:0] raw_mant_a_s1_comb, raw_mant_b_s1_comb, raw_mant_c_s1_comb;
    logic [MANT_WIDTH:0] mant_a_padded_s1_comb, mant_b_padded_s1_comb, mant_c_padded_s1_comb;
    logic is_a_zero_s1_comb, is_b_zero_s1_comb, is_c_zero_s1_comb;
    logic is_a_inf_s1_comb, is_b_inf_s1_comb, is_c_inf_s1_comb;
    logic is_a_nan_s1_comb, is_b_nan_s1_comb, is_c_nan_s1_comb; 


    always_comb begin 
        //initializing all wires to default to avoid any latches or undefined states
        exp_a_s1_comb = '0; 
        exp_b_s1_comb = '0;
        exp_c_s1_comb = '0;

        raw_mant_a_s1_comb = '0;
        raw_mant_b_s1_comb = '0;
        raw_mant_c_s1_comb = '0;

        mant_a_padded_s1_comb = '0;
        mant_b_padded_s1_comb = '0;
        mant_c_padded_s1_comb = '0;

        is_a_zero_s1_comb = 1'b0;
        is_b_zero_s1_comb = 1'b0;
        is_c_zero_s1_comb = 1'b0;

        is_a_inf_s1_comb = 1'b0;
        is_b_inf_s1_comb = 1'b0;
        is_c_inf_s1_comb = 1'b0;

        is_a_nan_s1_comb = 1'b0;
        is_b_nan_s1_comb = 1'b0;
        is_c_nan_s1_comb = 1'b0;

        //processing operand_a
        exp_a_s1_comb = operand_a[DATA_WIDTH-2:MANT_WIDTH];
        raw_mant_a_s1_comb = operand_a[MANT_WIDTH-1:0];
        //padding the mantissa with a hidden bit, if normalized then pad 1 else pad with 0
        mant_a_padded_s1_comb = (exp_a_s1_comb == 0) ? {1'b0, raw_mant_a_s1_comb} : {1'b1, raw_mant_a_s1_comb};
        is_a_zero_s1_comb = (exp_a_s1_comb == 0) && (raw_mant_a_s1_comb == 0);
        is_a_inf_s1_comb = (exp_a_s1_comb == {EXP_WIDTH{1'b1}}) && (raw_mant_a_s1_comb == 0);
        is_a_nan_s1_comb = (exp_a_s1_comb == {EXP_WIDTH{1'b1}}) && (raw_mant_a_s1_comb != 0);

        //processing operand_b
        exp_b_s1_comb = operand_b[DATA_WIDTH-2:MANT_WIDTH];
        raw_mant_b_s1_comb = operand_b[MANT_WIDTH-1:0];
        //padding the mantissa with a hidden bit, if normalized then pad 1 else pad with 0
        mant_b_padded_s1_comb = (exp_b_s1_comb == 0) ? {1'b0, raw_mant_b_s1_comb} : {1'b1, raw_mant_b_s1_comb};
        is_b_zero_s1_comb = (exp_b_s1_comb == 0) && (raw_mant_b_s1_comb == 0);
        is_b_inf_s1_comb = (exp_b_s1_comb == {EXP_WIDTH{1'b1}}) && (raw_mant_b_s1_comb == 0);
        is_b_nan_s1_comb = (exp_b_s1_comb == {EXP_WIDTH{1'b1}}) && (raw_mant_b_s1_comb != 0);

        //processing operand_c
        exp_c_s1_comb = operand_c[DATA_WIDTH-2:MANT_WIDTH];
        raw_mant_c_s1_comb = operand_c[MANT_WIDTH-1:0];
        //padding the mantissa with a hidden bit, if normalized then pad 1 else pad with 0
        mant_c_padded_s1_comb = (exp_c_s1_comb == 0) ? {1'b0, raw_mant_c_s1_comb} : {1'b1, raw_mant_c_s1_comb};
        is_c_zero_s1_comb = (exp_c_s1_comb == 0) && (raw_mant_c_s1_comb == 0);
        is_c_inf_s1_comb = (exp_c_s1_comb == {EXP_WIDTH{1'b1}}) && (raw_mant_c_s1_comb == 0);
        is_c_nan_s1_comb = (exp_c_s1_comb == {EXP_WIDTH{1'b1}}) && (raw_mant_c_s1_comb != 0);
    end

    //registering stage 1
    always_ff @( posedge clk or posedge rst ) begin
        if (rst) begin 
            stage1_valid_q <= 1'b0;
            sign_a_s1_q <= 1'b0; exp_a_s1_q <= '0; mant_a_s1_q <= '0;
            sign_b_s1_q <= 1'b0; exp_b_s1_q <= '0; mant_b_s1_q <= '0;
            sign_c_s1_q <= 1'b0; exp_c_s1_q <= '0; mant_c_s1_q <= '0;
            is_a_zero_s1_q <= 1'b0; is_b_zero_s1_q <= 1'b0; is_c_zero_s1_q <= 1'b0;
            is_a_inf_s1_q <= 1'b0; is_b_inf_s1_q <= 1'b0; is_c_inf_s1_q <= 1'b0;
            is_a_nan_s1_q <= 1'b0; is_b_nan_s1_q <= 1'b0; is_c_nan_s1_q <= 1'b0;
        end else begin 
            stage1_valid_q <= 1'b1;

            sign_a_s1_q <= operand_a[DATA_WIDTH-1];
            sign_b_s1_q <= operand_b[DATA_WIDTH-1];
            sign_c_s1_q <= operand_c[DATA_WIDTH-1];

            exp_a_s1_q <= exp_a_s1_comb;
            mant_a_s1_q <= mant_a_padded_s1_comb;
            exp_b_s1_q <= exp_b_s1_comb;
            mant_b_s1_q <= mant_b_padded_s1_comb;
            exp_c_s1_q <= exp_c_s1_comb;
            mant_c_s1_q <= mant_c_padded_s1_comb;

            is_a_zero_s1_q <= is_a_zero_s1_comb;
            is_b_zero_s1_q <= is_b_zero_s1_comb;
            is_c_zero_s1_q <= is_c_zero_s1_comb;

            is_a_inf_s1_q <= is_a_inf_s1_comb;
            is_b_inf_s1_q <= is_b_inf_s1_comb;
            is_c_inf_s1_q <= is_c_inf_s1_comb;
            
            is_a_nan_s1_q <= is_a_nan_s1_comb;
            is_b_nan_s1_q <= is_b_nan_s1_comb;
            is_c_nan_s1_q <= is_c_nan_s1_comb;
        end
    end

    //Pipelining Stage-2 Mantissa multiplication and initial exponent sum
    //stage 2 registers
    logic stage2_valid_q;
    logic [2*MANT_WIDTH+1:0] mant_prod_s2_q; //(MANT_WIDTH+1) * (MANT_WIDTH+1) = 24*24 = 48 bits wide, Index 0 to 47, so [2*MANT_WIDTH+1:0]
    logic signed [EXP_WIDTH:0] exp_prod_s2_q; //Exponent sum (Exp_A + Exp_B - BIAS) can be negative
    logic sign_prod_s2_q;
    logic [MANT_WIDTH:0] mant_c_s2_q;
    logic [EXP_WIDTH-1:0] exp_c_s2_q;
    logic sign_c_s2_q;
    logic is_a_zero_s2_q, is_b_zero_s2_q, is_c_zero_s2_q;
    logic is_a_inf_s2_q, is_b_inf_s2_q, is_c_inf_s2_q;
    logic is_a_nan_s2_q, is_b_nan_s2_q, is_c_nan_s2_q;
    
    //special cases flags for (A*B)
    logic is_ab_zero_s2_q, is_ab_inf_s2_q, is_ab_nan_s2_q;

    //wires for stage 2
    logic [2*MANT_WIDTH+1:0] mant_prod_s2_comb;
    logic signed [EXP_WIDTH:0] exp_prod_s2_comb;
    logic sign_prod_s2_comb;
    logic is_ab_zero_s2_comb;
    logic is_ab_inf_s2_comb;
    logic is_ab_nan_s2_comb;

    always_comb begin 
        mant_prod_s2_comb = '0;
        exp_prod_s2_comb = '0;
        sign_prod_s2_comb = 1'b0;
        is_ab_zero_s2_comb = 1'b0;
        is_ab_inf_s2_comb = 1'b0;
        is_ab_nan_s2_comb = 1'b0;

        //calculating the tentative sign of the product
        sign_prod_s2_comb = sign_a_s1_q ^ sign_b_s1_q;

        //handled special casesfor A*B
        if (is_a_nan_s1_q || is_b_nan_s1_q) begin 
            //if any of the operand is NaN, the prod is NaN
            is_ab_nan_s2_comb = 1'b1;
            //for NaN, setting exp and mant simply to zero
            exp_prod_s2_comb = '0;
            mant_prod_s2_comb = '0;
        end else if ((is_a_inf_s1_q && is_b_zero_s1_q) || (is_a_zero_s1_q && is_b_inf_s1_q)) begin 
            //0*inf case
            is_ab_nan_s2_comb = 1'b1;
            mant_prod_s2_comb = '0;
            exp_prod_s2_comb = '0;
        end else if (is_a_inf_s1_q || is_b_inf_s1_q) begin 
            //inf*non-zero results in infinity. also considers inf*inf
            is_ab_inf_s2_comb = 1'b1;
            //for infinity, mantissa is 0 and exponent is all ones
            mant_prod_s2_comb = '0;
            exp_prod_s2_comb = {EXP_WIDTH+1{1'b1}};
        end else if (is_a_zero_s1_q || is_b_zero_s1_q) begin 
            //zero*non-inf case results in 0
            is_ab_zero_s2_comb = 1'b1;
            mant_prod_s2_comb = '0;
            exp_prod_s2_comb = '0;
        end else begin 
            //normal multiplication
            //(MANT_WIDTH+1)*(MANT_WIDTH+1) = 2*(MANT_WIDTH+1) bits
            //24*24 = 48 bits i.e. [47:0]
            mant_prod_s2_comb = mant_a_s1_q * mant_b_s1_q;
            exp_prod_s2_comb = (exp_a_s1_q + exp_b_s1_q) - BIAS;
        end
    end

    //stage 2 registers
    always_ff @(posedge clk or posedge rst) begin 
        if (rst) begin 
            stage2_valid_q <= 1'b0;
            mant_prod_s2_q <= '0; exp_prod_s2_q <= '0; sign_prod_s2_q <= 1'b0;
            mant_c_s2_q <= '0; exp_c_s2_q <= '0; sign_c_s2_q <= 1'b0;
            is_a_zero_s2_q <= 1'b0; is_b_zero_s2_q <= 1'b0; is_c_zero_s2_q <= 1'b0;
            is_a_inf_s2_q <= 1'b0; is_b_inf_s2_q <= 1'b0; is_c_inf_s2_q <= 1'b0;
            is_a_nan_s2_q <= 1'b0; is_b_nan_s2_q <= 1'b0; is_c_nan_s2_q <= 1'b0;
            is_ab_zero_s2_q <= 1'b0; is_ab_inf_s2_q <= 1'b0; is_ab_nan_s2_q <= 1'b0;
        end else if (stage1_valid_q) begin 
            stage2_valid_q <= 1'b1;

            mant_prod_s2_q <= mant_prod_s2_comb;
            exp_prod_s2_q <= exp_prod_s2_comb;
            sign_prod_s2_q <= sign_prod_s2_comb;

            mant_c_s2_q <= mant_c_s1_q;
            exp_c_s2_q <= exp_c_s1_q;
            sign_c_s2_q <= sign_c_s1_q;

            is_a_zero_s2_q <= is_a_zero_s1_q;
            is_b_zero_s2_q <= is_b_zero_s1_q;
            is_c_zero_s2_q <= is_c_zero_s1_q;
            is_a_inf_s2_q <= is_a_inf_s1_q;
            is_b_inf_s2_q <= is_b_inf_s1_q;
            is_c_inf_s2_q <= is_c_inf_s1_q;
            is_a_nan_s2_q <= is_a_nan_s1_q;
            is_b_nan_s2_q <= is_b_nan_s1_q;
            is_c_nan_s2_q <= is_c_nan_s1_q;

            is_ab_zero_s2_q <= is_ab_zero_s2_comb;
            is_ab_inf_s2_q <= is_ab_inf_s2_comb;
            is_ab_nan_s2_q <= is_ab_nan_s2_comb;
        end else begin 
            stage2_valid_q <= 1'b0;
        end
    end


    //Pipelining Stage-3: Mantissa Alignment and Addition/Subtraction
    //stage 3 registers
    localparam TOTAL_ALIGNED_MANT_WIDTH = 2*MANT_WIDTH+4; //[50:0] so 51 bits, 48+3GRS bits
    logic stage3_valid_q;
    logic [TOTAL_ALIGNED_MANT_WIDTH:0] aligned_mant_sum_s3_q;
    logic signed [EXP_WIDTH:0] exp_sum_post_align_s3_q;
    logic sign_sum_s3_q; //tentative sign of the sum (A*B+C)
    logic is_sum_zero_s3_q;
    logic is_subtraction_effect_s3_q; //flag if the effective operation is subtraction
    logic is_result_zero_pre_norm_s3_q;
    logic is_result_inf_pre_norm_s3_q;
    logic is_result_nan_pre_norm_s3_q;
    
    //local parameters for Stage 3
    //1. width for mantissa operationss: 48 bits from product+3 GRS bits+1 for potential carry-out after addition
    localparam TOTAL_MANT_OP_WIDTH_S3 = TOTAL_ALIGNED_MANT_WIDTH + 1;
    localparam EFFECTIVE_ZERO_SHIFT = MANT_WIDTH+3;

    //wires for stage 3
    logic signed [EXP_WIDTH:0] exp_prod_effective_s3_comb;
    logic signed [EXP_WIDTH:0] exp_c_effective_s3_comb;
    logic is_prod_ge_c_exp_s3_comb;
    logic [EXP_WIDTH:0] exp_diff_s3_comb;
    logic signed [EXP_WIDTH:0] final_exp_s3_comb;

    //mantissas extended to a common width for alignnment
    logic [TOTAL_MANT_OP_WIDTH_S3:0] mant_prod_aligned_s3_comb;
    logiic [TOTAL_MANT_OP_WIDTH_S3:0] mant_c_aligned_s3_comb;

    logic [TOTAL_MANT_OP_WIDTH_S3:0] mant_large_s3_comb; //mantissa of the operand with the larger exponent
    logic [TOTAL_MANT_OP_WIDTH_S3:0] mant_small_shifted_s3_comb; //mantissa of the smaller operand after right shift

    logic effective_subtract_s3_comb; //true if signs are ddifferent and magnitudes are valid
    logic [TOTAL_MANT_OP_WIDTH_S3:0] mant_sum_s3_comb; //result of mantissa add/sub [52bits]
    logic final_sign_s3_comb;

    logic is_sum_zero_s3_comb;

    //final  result flags
    logic is_result_zero_s3_comb;
    logic is_result_inf_s3_comb;
    logic is_result_nan_s3_comb;

    always_comb begin 
        exp_prod_effective_s3_comb = '0;
        exp_c_effective_s3_comb = '0;
        is_prod_ge_c_exp_s3_comb = 1'b0;
        exp_diff_s3_comb = '0;
        final_exp_s3_comb = '0;

        mant_prod_aligned_s3_comb = '0;
        mant_c_aligned_s3_comb = '0;

        mant_large_s3_comb = '0;
        mant_small_shifted_s3_comb = '0;

        effective_subtract_s3_comb = 1'b0;
        mant_sum_s3_comb = '0;
        final_sign_s3_comb = 1'b0;

        is_sum_zero_s3_comb = 1'b0;

        is_result_zero_s3_comb = 1'b0;
        is_result_inf_s3_comb = 1'b0;
        is_result_nan_s3_comb = 1'b0;
        
        //special case resolution (A*B + C)
        //if any input or (A*B) is NaN the the result is NaN
        if (is_a_nan_s2_q || is_b_nan_s2_q || is_c_nan_s2_q || is_ab_nan_s2_q) begin 
            is_result_nan_s3_comb = 1'b1;
        end
        //infinite handling
        else if (is_ab_inf_s2_q || is_c_inf_s2_q) begin
            //inf-inf = NaN
            if (is_ab_inf_s2_q && is_c_inf_s2_q && (sign_prod_s2_q != sign_c_s2_q)) begin 
                is_result_nan_s3_comb = 1'b1;
            end
            //inf+inf = inf or inf+-finite = inf or finite+-inf = inf
            else if ((is_ab_inf_s2_q && is_c_inf_s2_q && (sign_prod_s2_q == sign_c_s2_q)) ||
            (is_ab_inf_s2_q && is_c_inf_s2_q) ||
            (!is_ab_inf_s2_q && is_c_inf_s2_q)) begin 
                is_result_inf_s3_comb = 1'b1;
                final_sign_s3_comb = (is_ab_inf_s2_q) ? sign_prod_s2_q : sign_c_s2_q;
            end
        end
        //zero handling (only if not already NaN or inf)
        else if (is_ab_zero_s2_q && is_c_zero_s2_q) begin 
            //0+0=0
            is_result_zero_s3_comb = 1'b1;
            final_sign_s3_comb = sign_c_s2_q;
        end
        //product is zero and C is finite non-zero = result is 0
        else if (is_ab_zero_s2_q && !is_c_zero_s2_q) begin 
            //padding C's mantissa to the full operation width
            mant_sum_s3_comb = {{(TOTAL_MANT_OP_WIDTH_S3 + 1 - (MANT_WIDTH+1)){1'b0}}, mant_c_s2_q};
            final_exp_s3_comb = exp_c_s2_q;
            final_sign_s3_comb = sign_c_s2_q;
        end
        //prodcut is finite non-zero but C is zero -> result is A*B
        else if (!is_ab_zero_s2_q && is_c_zero_s2_q) begin 
            mant_sum_s3_comb = {{(TOTAL_MANT_OP_WIDTH_S3 + 1 - (2*MANT_WIDTH+1)){1'b0}}, mant_prod_s2_q};
            final_exp_s3_comb = exp_prod_s2_q;
            final_sign_s3_comb = sign_prod_s2_q;
        end
        //normal addition/subtraction
        else begin 

            //adjusting exponent by subtracting bias from C's exponent
            exp_c_effective_s3_comb = exp_c_s2_q - BIAS;

            //determining which operand has larger exponent
            is_prod_ge_c_exp_s3_comb = (exp_prod_s2_q >= exp_c_effective_s3_comb);
            final_exp_s3_comb = is_prod_ge_c_exp_s3_comb ? exp_prod_s2_q : exp_c_effective_s3_comb;
            exp_diff_s3_comb = is_prod_ge_c_exp_s3_comb ? (exp_prod_s2_q - exp_c_effective_s3_comb) : (exp_c_effective_s3_comb - exp_prod_s2_q);

            //extend mantissas to 52 bits
            mant_prod_aligned_s3_comb = {mant_prod_s2_q, {(TOTAL_MANT_OP_WIDTH_S3 - (2*MANT_WIDTH+1)){1'b0}}};
            mant_c_aligned_s3_comb = {mant_c_s2_q, {(TOTAL_MANT_OP_WIDTH_S3 - (MANT_WIDTH+1)){1'b0}}};

            logic [TOTAL_MANT_OP_WIDTH_S3:0] mant_large_src, mant_small_src;
            if (is_prod_ge_c_exp_s3_comb) begin 
                mant_large_src = mant_prod_aligned_s3_comb;
                mant_small_src = mant_c_aligned_s3_comb;
            end else begin 
                mant_large_src = mant_c_aligned_s3_comb;
                mant_small_src = mant_prod_aligned_s3_comb;
            end

            //right shift the mantissa with the smaller exponent by exp_diff
            if (exp_diff_s3_comb >= EFFECTIVE_ZERO_SHIFT) begin 
                mant_small_shifted_s3_comb = '0; //small operand is effectively zero due to large exponent difference
            end else begin
                mant_small_shifted_s3_comb = mant_small_src >> exp_diff_s3_comb;
            end

            //determine if the effective operation is addition or subtraction
            effective_subtract_s3_comb = (sign_prod_s2_q != sign_c_s2_q);

            //perform mantissa addition/subtraction
            if (effective_subtract_s3_comb) begin 
                //subtraction: ensure mant_large_src is always >= mant_small_shifted_s3_comb
                if (mant_large_src >= mant_small_shifted_s3_comb) begin 
                    mant_sum_s3_comb = mant_large_src- mant_small_shifted_s3_comb;
                    final_sign_s3_comb = is_prod_ge_c_exp_s3_comb ? sign_prod_s2_q : sign_c_s2_q;
                end else begin // This case means the smaller operand's magnitude was actually larger (rare if logic is correct)
                    mant_sum_s3_comb = mant_small_shifted_s3_comb - mant_large_src;
                    final_sign_s3_comb = is_prod_ge_c_exp_s3_comb ? sign_c_s2_q : sign_prod_s2_q;
                end
            end else begin 
                //addition
                mant_sum_s3_comb = mant_large_src + mant_small_shifted_s3_comb;
                final_sign_s3_comb = sign_prod_s2_q;// Or sign_c_s2_q, since they are the same
            end

            //check if sum is zero after subtraction
            is_sum_zero_s3_comb = (mant_sum_s3_comb == 0);
        end
    end

    //registering stage 3
    always_ff @(posedge clk or posedge rst) begin 
        if (rst) begin 
            stage3_valid_q <= 1'b0;
            aligned_mant_sum_s3_q <= '0;
            exp_sum_post_align_s3_q <= '0;
            sign_sum_s3_q <= 1'b0;
            is_sum_zero_s3_q <= 1'b0;
            is_subtraction_effect_s3_q <= 1'b0;
            is_result_inf_pre_norm_s3_q <= 1'b0; is_result_nan_pre_norm_s3_q <= 1'b0; is_result_zero_pre_norm_s3_q <= 1'b0;
        end else if (stage2_valid_q) begin 
            stage3_valid_q <= 1'b1;
            aligned_mant_sum_s3_q <= mant_sum_s3_comb;
            exp_sum_post_align_s3_q <= final_exp_s3_comb;
            sign_sum_s3_q <= final_sign_s3_comb;
            is_sum_zero_s3_q <= is_sum_zero_s3_comb;
            is_subtraction_effect_s3_q <= effective_subtract_s3_comb;
            is_result_nan_pre_norm_s3_q <= is_result_nan_s3_comb;
            is_result_inf_pre_norm_s3_q <= is_result_inf_s3_comb;
            is_result_zero_pre_norm_s3_q <= is_result_zero_s3_comb;
        end else begin 
            stage3_valid_q <= 1'b0;
        end
    end


    //Pipelining Stage-4: Normalization and Rounding
    //stage 4 registers
    logic stage4_valid_q;
    logic [MANT_WIDTH-1:0] mant_final_s4_q;
    logic [EXP_WIDTH-1:0] exp_final_s4_q;
    logic sign_final_s4_q;
    logic is_result_nan_final_s4_q;
    logic is_result_inf_final_s4_q;
    logic is_result_zero_final_s4_q;

    //local parameters for stage 4
    localparam CARRY_OUT_BIT_POS_S4 = TOTAL_ALIGNED_MANT_WIDTH; //50
    localparam IMPLIED_ONE_POS_S4 = TOTAL_ALIGNED_MANT_WIDTH - 1; //49
    localparam FRACTION_MSB_POS_S4 = IMPLIED_ONE_POS_S4 - 1; //48 START OF THE 23-BIT FRACTION
    localparam FRACTION_LSB_POS_S4 = IMPLIED_ONE_POS_S4 - MANT_WIDTH; //49 - 23
    localparam G_BIT_POS_S4 = FRACTION_LSB_POS_S4 - 1; //25
    localparam R_BIT_POS_S4 = G_BIT_POS_S4 - 1; //24
    localparam S_BITS_LSB_POS_S4 = R_BIT_POS_S4 - 1; //23 LSB of sticky bit range

    //wires for stage 4
    logic [TOTAL_ALIGNED_MANT_WIDTH:0] norm_mant_s4_comb;
    logic signed [EXP_WIDTH:0] norm_exp_s4_comb;
    logic [MANT_WIDTH-1:0] mant_pre_round_s4_comb;
    logic g_bit_s4_comb, r_bit_s4_comb, s_bit_s4_comb;
    logic round_up_s4_comb;

    logic [MANT_WIDTH-1:0] mant_rounded_s4_comb;
    logic signed [EXP_WIDTH:0] exp_rounded_s4_comb;
    logic rounding_overflow_occured_s4_comb;

    logic [MANT_WIDTH-1:0] final_mant_val_s4_comb;
    logic [EXP_WIDTH-1:0] final_exp_val_s4_comb;
    logic final_sign_val_s4_comb;

    logic is_result_denormal_s4_comb;
    logic is_exp_overflow_s4_comb;
    logic is_exp_underflow_s4_comb;
    
    logic is_final_result_nan_s4_comb;
    logic is_final_result_inf_s4_comb;
    logic is_final_result_zero_s4_comb;

    always_comb begin 
        //initialize internal signals
        norm_mant_s4_comb = '0;
        norm_exp_s4_comb = '0;
        mant_pre_round_s4_comb = '0;
        g_bit_s4_comb = 1'b0; r_bit_s4_comb = 1'b0; s_bit_s4_comb = 1'b0;
        round_up_s4_comb = 1'b0;

        mant_rounded_s4_comb = '0;
        exp_rounded_s4_comb = '0;
        rounding_overflow_occured_s4_comb = 1'b0;

        final_mant_val_s4_comb = '0;
        final_exp_val_s4_comb = '0;
        final_sign_val_s4_comb = 1'b0;

        is_result_denormal_s4_comb = 1'b0;
        is_exp_overflow_s4_comb = 1'b0;
        is_exp_underflow_s4_comb = 1'b0;
        
        is_final_result_inf_s4_comb = 1'b0;
        is_final_result_nan_s4_comb = 1'b0;
        is_final_result_zero_s4_comb = 1'b0;

        //handle special cases resolved in the previous stage
        //these conditions bypass the normalization/rounding path
        if (is_result_nan_pre_norm_s3_q) begin 
            is_final_result_nan_s4_comb = 1'b1;
            final_sign_val_s4_comb = 1'b0; //default QNaN sign
            final_exp_val_s4_comb = {EXP_WIDTH{1'b1}};
            final_mant_val_s4_comb = {1'b1, {MANT_WIDTH-1{1'b0}}}; //typical QNaN
        end else if (is_result_inf_pre_norm_s3_q) begin
            is_final_result_inf_s4_comb = 1'b1;
            final_sign_val_s4_comb = sign_sum_s3_q; 
            final_exp_val_s4_comb = {EXP_WIDTH{1'b1}};
            final_mant_val_s4_comb = {MANT_WIDTH{1'b0}}; //all mantissa zero for inf
        end else if (is_sum_zero_s3_q || is_result_zero_pre_norm_s3_q) begin 
            //if the mantissa sum was zero or overall result is zerp
            is_final_result_zero_s4_comb = 1'b1;
            final_sign_val_s4_comb = sign_sum_s3_q;
            final_exp_val_s4_comb = {EXP_WIDTH{1'b0}};
            final_mant_val_s4_comb = {MANT_WIDTH{1'b0}};
        end
        //Normalization (if not a specialcase)
        else begin
            norm_mant_s4_comb = aligned_mant_sum_s3_q;
            norm_exp_s4_comb = exp_sum_post_align_s3_q;
            final_sign_val_s4_comb = sign_sum_s3_q;

            //handling the potential carry out e.g., 0.111... + 0.111... = 1.111...
            if (norm_mant_s4_comb[CARRY_OUT_BIT_POS_S4]) begin ///check bit 50
                //right-shift by 1 to bring the 1 to the IMPLIED POSITION
                norm_mant_s4_comb = norm_mant_s4_comb >> 1;
                norm_exp_s4_comb = norm_exp_s4_comb + 1;
            end

            //find leading 1 and left shift for normalization
            integer leading_one_index;
            integer shift_amount = 0;

            leading_one_index = IMPLIED_ONE_POS_S4; //assuming its normalized already
            for (int i = IMPLIED_ONE_POS_S4; i>=0; i--) begin
                if (norm_mant_s4_comb[i]) begin 
                    leading_one_index i;
                    break;
                end
            end

            //calculating shift amount
            shift_amount = IMPLIED_ONE_POS_S4 - leading_one_index;

            //applying the shift and ajusting the exponent
            if (shift_amount > 0) begin 
                norm_mant_s4_comb = norm_mant_s4_comb << shift_amount;
                norm_exp_s4_comb = norm_exp_s4_comb - shift_amount;
            end

            //extracting the GRS bit for  rounding
            mant_pre_round_s4_comb = norm_mant_s4_comb[FRACTION_MSB_POS_S4:FRACTION_LSB_POS_S4];
            g_bit_s4_comb = norm_mant_s4_comb[G_BIT_POS_S4];
            r_bit_s4_comb = norm_mant_s4_comb[R_BIT_POS_S4];
            s_bit_s4_comb = norm_mant_s4_comb[S_BITS_LSB_POS_S4];

            //round to nearest, ties to even
            // Rounding logic: Increment mantissa if (G AND (R OR S)) OR (G AND NOT R AND NOT S AND LSB_of_mantissa)
            round_up_s4_comb = (g_bit_s4_comb && (r_bit_s4_comb || s_bit_s4_comb)) || (g_bit_s4_comb && !r_bit_s4_comb && !s_bit_s4_comb && mant_pre_round_s4_comb[0]);

            mant_rounded_s4_comb = mant_pre_round_s4_comb;
            exp_rounded_s4_comb = norm_exp_s4_comb;

            if (round_up_s4_comb) begin 
                mant_rounded_s4_comb = mant_rounded_s4_comb + 1;
                //check if rounding caused mantissa to overflow(e.g., 0.111... -> 1.000...)
                if (mant_rounded_s4_comb[MANT_WIDTH]) begin
                    rounding_overflow_occured_s4_comb = 1'b1;
                    mant_rounded_s4_comb = {MANT_WIDTH{1'b0}}; //mantissa becomes 0
                    exp_rounded_s4_comb = exp_rounded_s4_comb + 1; //exp incremented by 1
                end
            end

            //check for exponent overflow
            if (exp_rounded_s4_comb > ((1 << EXP_WIDTH) - 2 - BIAS)) begin // Check against 127 (max actual exponent)
                is_exp_overflow_s4_comb = 1'b1;
            end

            //check for exponent underflow
            if (exp_rounded_s4_comb < (1 - BIAS)) begin //check against -126
                is_exp_underflow_s4_comb = 1'b1;
                integer denormal_shift = (1-BIAS) - exp_rounded_s4_comb; // shift needed to make exponent 0
                if (denormal_shift > (MANT_WIDTH+1)) begin //if shift is too large, it becomes zero
                    is_final_result_zero_s4_comb = 1'b1;
                    final_mant_val_s4_comb = {MANT_WIDTH{1'b0}};
                    final_exp_val_s4_comb = {EXP_WIDTH{1'b0}};
                end else begin
                    //shift mantissa right for denormalization
                    // The mantissa (1.xxxx) should be treated as a (MANT_WIDTH+1)-bit value (1.fraction).
                    logic [MANT_WIDTH:0] denorm_mant_val = {1'b1, mant_rounded_s4_comb};
                    denorm_mant_val = denorm_mant_val >> denormal_shift;

                    is_result_denormal_s4_comb = 1'b1;
                    final_mant_val_s4_comb = denorm_mant_val[MANT_WIDTH-1:0];
                    final_exp_val_s4_comb = {EXP_WIDTH{1'b0}};
                end
            end

            //final result 
            if (is_exp_overflow_s4_comb) begin
                is_final_result_inf_s4_comb = 1'b1;
                final_exp_val_s4_comb = {EXP_WIDTH{1'b1}};
                final_mant_val_s4_comb = {MANT_WIDTH{1'b0}};
            end else if (is_exp_underflow_s4_comb && !is_final_result_zero_s4_comb) begin
                //do nothing, values are already denormal
            end else if (!is_exp_underflow_s4_comb) begin
                // Exponent is (actual_exponent + BIAS)
                final_exp_val_s4_comb = exp_rounded_s4_comb[EXP_WIDTH-1:0] + BIAS;
                final_mant_val_s4_comb = mant_rounded_s4_comb;
            end
        end
    end

    //registering stage 4
    always_ff @(posedge clk or posedge rst) begin 
        if (rst) begin 
            stage4_valid_q <= 1'b0;
            mant_final_s4_q <= '0; exp_final_s4_q <= '0; sign_final_s4_q <= 1'b0;
            is_result_inf_final_s4_q <= 1'b0; is_result_nan_final_s4_q <= 1'b0; is_result_zero_final_s4_q <= 1'b0;
        end else if (stage3_valid_q) begin
            stage4_valid_q <= 1'b1;
            mant_final_s4_q <= final_mant_val_s4_comb;
            exp_final_s4_q <= final_exp_val_s4_comb;
            sign_final_s4_q <= final_sign_val_s4_comb;
            is_result_inf_final_s4_q <= is_final_result_inf_s4_comb;
            is_result_nan_final_s4_q <= is_final_result_nan_s4_comb;
            is_result_zero_final_s4_q <= is_final_result_zero_s4_comb;
        end else begin
            stage4_valid_q = 1'b0;
        end
    end


    //Pipelining stagee 5: final result packing and output handling

    //wire for stage 5
    logic [DATA_WIDTH-1:0] packed_result_s5_comb;

    always_comb begin
        packed_result_s5_comb = '0;

        // Priority order for special cases: NaN > Infinity > Zero > Normal/Denormal
        if (is_result_nan_final_s4_q) begin
            packed_result_s5_comb = {
                1'b0, // Sign (often 0 for QNaN)
                {EXP_WIDTH{1'b1}}, // Exponent (all ones)
                {1'b1, {MANT_WIDTH-1{1'b0}}} // Mantissa (MSB of fraction set for QNaN)
            };
        end else if (is_result_inf_final_s4_q) begin
            packed_result_s5_comb = {
                sign_final_s4_q,
                {EXP_WIDTH{1'b1}},       // Exponent (all ones)
                {MANT_WIDTH{1'b0}}       // Mantissa (all zeros)
            };
        end else if (is_result_zero_final_s4_q) begin
            packed_result_s5_comb = {
                sign_final_s4_q, // Sign from Stage 4 (+0 or -0)
                {EXP_WIDTH{1'b0}},       // Exponent (all zeros)
                {MANT_WIDTH{1'b0}}       // Mantissa (all zeros)
            };
        end else begin
            packed_result_s5_comb = {
                sign_final_s4_q, // Final determined sign
                exp_final_s4_q,  // Final adjusted exponent (already biased or 0 for denormals)
                mant_final_s4_q  // Final rounded mantissa (fraction part)
            };
        end
    end

    //registering stage 5
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