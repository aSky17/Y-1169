`ifndef FP_COMPARE_SV
`define FP_COMPARE_SV

module fp_compare #(
    import parameters::*
) (
    input logic clk,
    input logic rst,
    input logic [DATA_WIDTH-1:0] a,
    input logic [DATA_WIDTH-1:0] b,
    input [OPCODE_WIDTH-1:0] opcode,
    output logic [DATA_WIDTH-1:0] result_fp,  // Floating-point result (for FNEG, FABS, FMIN, FMAX)
    output logic result, //boolean result
    output logic result_valid
);

    import opcodes::OPCODE_FP_FEQ;
    import opcodes::OPCODE_FP_FNE;
    import opcodes::OPCODE_FP_FLT;
    import opcodes::OPCODE_FP_FLE;
    import opcodes::OPCODE_FP_FGT;
    import opcodes::OPCODE_FP_FGE;
    import opcodes::OPCODE_FP_FNEG;
    import opcodes::OPCODE_FP_FABS;
    import opcodes::OPCODE_FP_FMIN;
    import opcodes::OPCODE_FP_FMAX;
    
    initial begin 
        if (DATA_WIDTH != 32) begin 
            $fatal(1, "Error: DATA_WIDTH is not 32 bit");
        end 
    end

    //IEEE 754 single-precision constants
    localparam SIGN_BIT = DATA_WIDTH - 1;
    localparam EXP_WIDTH = 8;
    localparam MANT_WIDTH = 23;
    localparam BIAS = 127;

    //Canonical floating-point values for results
    localparam QNAN = {1'b0, {EXP_WIDTH{1'b1}}, 1'b1, {MANT_WIDTH-1{1'b0}}};
    localparam POS_ZERO = {DATA_WIDTH{1'b0}}; // +0.0
    localparam NEG_ZERO = {1'b1, {DATA_WIDTH-1{1'b0}}}; // -0.0
    localparam POS_INF = {1'b0, {EXP_WIDTH{1'b1}}, {MANT_WIDTH{1'b0}}}; // +Infinity
    localparam NEG_INF = {1'b1, {EXP_WIDTH{1'b1}}, {MANT_WIDTH{1'b0}}}; // -Infinity



    function automatic logic is_nan(input logic [DATA_WIDTH-1:0] fp_val);
        logic [EXP_WIDTH-1:0] exp_val = fp_val[DATA_WIDTH-2:MANT_WIDTH];
        logic [MANT_WIDTH-1:0] mant_val = fp_val[MANT_WIDTH-1:0];
        is_nan = (exp_val == {EXP_WIDTH{1'b1}}) && (mant_val != 0);
    endfunction

    function automatic logic is_inf(input logic [DATA_WIDTH-1:0] fp_val);
        logic [EXP_WIDTH-1:0] exp_val = fp_val[DATA_WIDTH-2:MANT_WIDTH];
        logic [MANT_WIDTH-1:0] mant_val = fp_val[MANT_WIDTH-1:0];
        is_inf = (exp_val == {EXP_WIDTH{1'b1}}) && (mant_val == 0);
    endfunction

    function automatic logic is_zero(input logic [DATA_WIDTH-1:0] fp_val);
        logic [EXP_WIDTH-1:0] exp_val = fp_val[DATA_WIDTH-2:MANT_WIDTH];
        logic [MANT_WIDTH-1:0] mant_val = fp_val[MANT_WIDTH-1:0];
        is_zero = (exp_val == 0) && (mant_val == 0);
    endfunction

    //Pipelining Stage-1
    //Field Extraction, Special case detection
    //Registers to pass data to Stage-2
    logic [EXP_WIDTH-1:0] exp_a_s1, exp_b_s1;
    logic [MANT_WIDTH:0] mant_a_s1, mant_b_s1; // Mantissa with hidden bit (23+1 = 24 bits)
    logic sign_a_s1, sign_b_s1;

    logic is_a_nan_s1, is_b_nan_s1;
    logic is_a_inf_s1, is_b_inf_s1;
    logic is_a_zero_s1, is_b_zero_s1;

    logic [OPCODE_WIDTH-1:0] opcode_s1;
    logic [DATA_WIDTH-1:0] a_s1, b_s1;
    logic stage1_valid;

    //Internal wires
    logic [EXP_WIDTH-1:0] exp_a_comb, exp_b_comb;
    logic [MANT_WIDTH-1:0] raw_mant_a_comb, raw_mant_b_comb;
    logic [MANT_WIDTH:0] mant_a_padded_comb, mant_b_padded_comb;

    logic is_a_nan_comb, is_b_nan_comb;
    logic is_a_inf_comb, is_b_inf_comb;
    logic is_a_zero_comb, is_b_zero_comb;

    // Combinational logic for Stage 1: Extracts fields and detects special values.
    always_comb begin
        exp_a_comb = a[DATA_WIDTH-2:MANT_WIDTH];
        raw_mant_a_comb = a[MANT_WIDTH-1:0];
        // Pad mantissa with hidden bit: '1' for normalized, '0' for denormal/zero (for comparison purposes)
        mant_a_padded_comb = (exp_a_comb == 0) ? {1'b0, raw_mant_a_comb} : {1'b1, raw_mant_a_comb};

        exp_b_comb = b[DATA_WIDTH-2:MANT_WIDTH];
        raw_mant_b_comb = b[MANT_WIDTH-1:0];
        // Pad mantissa with hidden bit
        mant_b_padded_comb = (exp_b_comb == 0) ? {1'b0, raw_mant_b_comb} : {1'b1, raw_mant_b_comb};

        // Detect special values using helper functions
        is_a_nan_comb = is_nan(a);
        is_b_nan_comb = is_nan(b);
        is_a_inf_comb = is_inf(a);
        is_b_inf_comb = is_inf(b);
        is_a_zero_comb = is_zero(a);
        is_b_zero_comb = is_zero(b);
    end

    //Register the combinatorial results from this clock cycle to be used in stage 2
    always_ff @( posedge clk or posedge rst ) begin 
        if (rst) begin 
            stage1_valid <= 1'b0;
            sign_a_s1 <= 1'b0;
            exp_a_s1 <= 0; 
            mant_a_s1 <= 0;
            sign_b_s1 <= 1'b0; 
            exp_b_s1 <= 0; 
            mant_b_s1 <= 0;
            is_a_nan_s1 <= 1'b0; 
            is_b_nan_s1 <= 1'b0;
            is_a_inf_s1 <= 1'b0; 
            is_b_inf_s1 <= 1'b0;
            is_a_zero_s1 <= 1'b0; 
            is_b_zero_s1 <= 1'b0;
            opcode_s1 <= 0;
        end else begin 
            stage1_valid <= 1'b1;

            sign_a_s1 <= a[SIGN_BIT];
            exp_a_s1 <= exp_a_comb;
            mant_a_s1 <= mant_a_padded_comb;
            sign_b_s1 <= b[SIGN_BIT];
            exp_b_s1 <= exp_b_comb;
            mant_b_s1 <= mant_b_padded_comb;

            // Register special case flags
            is_a_nan_s1 <= is_a_nan_comb;
            is_b_nan_s1 <= is_b_nan_comb;
            is_a_inf_s1 <= is_a_inf_comb; 
            is_b_inf_s1 <= is_b_inf_comb;
            is_a_zero_s1 <= is_a_zero_comb; 
            is_b_zero_s1 <= is_b_zero_comb;

            //register the opcode
            opcode_s1 <= opcode;
            a_s1 <= a;
            b_s1 <= b;
        end
    end


    //Pipelining: Stage 2
    //Signed magnitude comparsion
    //register to pass data to stage 3
    logic comp_a_gt_b_s2;
    logic comp_a_lt_b_s2;
    logic comp_a_eq_b_s2;

    logic is_a_nan_s2;
    logic is_b_nan_s2;
    logic is_a_inf_s2;
    logic is_b_inf_s2;
    logic is_a_zero_s2;
    logic is_b_zero_s2;
    logic sign_a_s2;
    logic sign_b_s2;
    logic [OPCODE_WIDTH-1:0] opcode_s2;
    logic [DATA_WIDTH-1:0] a_s2, b_s2;
    logic stage2_valid;

    //internal wires for stage 2
    logic comp_a_gt_b_comb;
    logic comp_a_lt_b_comb;
    logic comp_a_eq_b_comb;

    always_comb begin 
        comp_a_gt_b_comb = 1'b0;
        comp_a_lt_b_comb = 1'b0;
        comp_a_eq_b_comb = 1'b0;

        if (sign_a_s1 != sign_b_s1) begin //different signs
            if (sign_a_s1 == 0) begin //A is positive, B negative
                comp_a_gt_b_comb = 1'b1;
            end else begin 
                comp_a_lt_b_comb = 1'b1;
            end
        end else begin //same signs
            if (sign_a_s1 == 0) begin //Both positive
                if (exp_a_s1 > exp_b_s1) comp_a_gt_comb = 1'b1;
                else if (exp_a_s1 < exp_b_s1)  comp_a_lt_b_comb = 1'b1;
                else begin // Exponents are equal, compare mantissas
                    if (mant_a_s1 > mant_b_s1) comp_a_gt_b_comb = 1'b1;
                    else if (mant_a_s1 < mant_b_s1) comp_a_lt_b_comb = 1'b1;
                    else comp_a_eq_b_comb = 1'b1; // Exps and mants are equal
               end
            end else begin //Both negative
                if (exp_a_s1 > exp_b_s1) comp_a_lt_b_comb = 1'b1; // A has larger magnitude, so A < B
                else if (exp_a_s1 < exp_b_s1) comp_a_gt_b_comb = 1'b1; // A has smaller magnitude, so A > B
                else begin // Exponents are equal, compare mantissas
                    if (mant_a_s1 > mant_b_s1) comp_a_lt_b_comb = 1'b1; // A has larger magnitude, so A < B
                    else if (mant_a_s1 < mant_b_s1) comp_a_gt_b_comb = 1'b1; // A has smaller magnitude, so A > B
                    else comp_a_eq_b_comb = 1'b1; // Exps and mants are equal
                end
            end
        end
    end
    
    //registering the combinational results from this clock cycle to be used in stage 3
    always_ff @(posedge clk or posedge rst) begin 
        if (rst) begin
            stage2_valid <= 1'b0;
            comp_a_gt_b_s2 <= 1'b0; comp_a_lt_b_s2 <= 1'b0; comp_a_eq_b_s2 <= 1'b0;
            is_a_nan_s2 <= 1'b0; is_b_nan_s2 <= 1'b0;
            is_a_inf_s2 <= 1'b0; is_b_inf_s2 <= 1'b0;
            is_a_zero_s2 <= 1'b0; is_b_zero_s2 <= 1'b0;
            sign_a_s2 <= 1'b0; sign_b_s2 <= 1'b0;
            opcode_s2 <= 0;
        end else if (stage1_valid) begin 
            stage2_valid <= 1'b1;
            comp_a_gt_b_s2 <= comp_a_gt_b_comb;
            comp_a_lt_b_s2 <= comp_a_lt_b_comb;
            comp_a_eq_b_s2 <= comp_a_eq_b_comb;

            // Pass through flags and opcode from Stage 1 to Stage 3
            is_a_nan_s2 <= is_a_nan_s1; is_b_nan_s2 <= is_b_nan_s1;
            is_a_inf_s2 <= is_a_inf_s1; is_b_inf_s2 <= is_b_inf_s1;
            is_a_zero_s2 <= is_a_zero_s1; is_b_zero_s2 <= is_b_zero_s1;
            sign_a_s2 <= sign_a_s1; sign_b_s2 <= sign_b_s1;
            opcode_s2 <= opcode_s1;
            a_s2 <= a_s1;
            b_s2 <= b_s1;
        end else begin 
            stage2_valid <= 1'b0;
        end
    end

    //Pipelining: Stage-3
    //spedial case resolution and final result calculation
    logic [DATA_WIDTH-1:0] result_fp_comb;
    logic result_bool_comb;

    always_comb begin 
        result_fp_comb = QNAN;
        result_bool_comb = 1'b0;

        case (opcode_s2)
            //floating point comparison
            OPCODE_FP_FEQ, OPCODE_FP_FNE, OPCODE_FP_FLT, OPCODE_FP_FLE, OPCODE_FP_FGT, OPCODE_FP_FGE: begin 
                //IEEE 754 comparison rules
                //1.NaN cases: Any ordered comparison involving NaN is false. FNE is TRUE
                if (is_a_nan_s2 || is_b_nan_s2) begin 
                    result_bool_comb = (opcode_s2 == OPCODE_FP_FNE);
                end else begin 
                    //2.Zero cases: +0 == -0 is true
                    if (is_a_zero_s2 && is_b_zero_s2) begin 
                        case (opcode_s2)
                            OPCODE_FP_FEQ: result_bool_comb = 1'b1; // +0 == -0
                            OPCODE_FP_FNE: result_bool_comb = 1'b0; // +0 != -0 (false)
                            OPCODE_FP_FLT: result_bool_comb = 1'b0; // 0 < 0 (false)
                            OPCODE_FP_FLE: result_bool_comb = 1'b1; // 0 <= 0 (true)
                            OPCODE_FP_FGT: result_bool_comb = 1'b0; // 0 > 0 (false)
                            OPCODE_FP_FGE: result_bool_comb = 1'b1; // 0 >= 0 (true)
                            default: result_bool_comb = 1'b0;
                        endcase
                    //3. Infinity cases    
                    end else if (is_a_inf_s2 && is_b_inf_s2) begin 
                        //both are infinity
                        case (opcode_s2)
                            OPCODE_FP_FEQ: result_bool_comb = (sign_a_s2 == sign_b_s2); // +Inf == +Inf, -Inf == -Inf
                            OPCODE_FP_FNE: result_bool_comb = (sign_a_s2 != sign_b_s2);
                            OPCODE_FP_FLT: result_bool_comb = (sign_a_s2 == 1 && sign_b_s2 == 0); // -Inf < +Inf
                            OPCODE_FP_FLE: result_bool_comb = (sign_a_s2 == 1 || (sign_a_s2 == sign_b_s2)); // -Inf <= +Inf, +Inf <= +Inf, -Inf <= -Inf
                            OPCODE_FP_FGT: result_bool_comb = (sign_a_s2 == 0 && sign_b_s2 == 1); // +Inf > -Inf
                            OPCODE_FP_FGE: result_bool_comb = (sign_a_s2 == 0 || (sign_a_s2 == sign_b_s2)); // +Inf >= -Inf, +Inf >= +Inf, -Inf >= -Inf
                            default: result_bool_comb = 1'b0;
                        endcase
                    end else if (is_a_inf_s2) begin 
                        //a is inf, b is finite
                        case (opcode_s2)
                            OPCODE_FP_FEQ: result_bool_comb = 1'b0;
                            OPCODE_FP_FNE: result_bool_comb = 1'b1;
                            OPCODE_FP_FLT: result_bool_comb = (sign_a_s2 == 1); // -Inf < finite
                            OPCODE_FP_FLE: result_bool_comb = (sign_a_s2 == 1);
                            OPCODE_FP_FGT: result_bool_comb = (sign_a_s2 == 0); // +Inf > finite
                            OPCODE_FP_FGE: result_bool_comb = (sign_a_s2 == 0);
                            default: result_bool_comb = 1'b0;
                        endcase
                    end else if (is_b_inf_s2) begin 
                        //a is finite, b is infinite
                        case (opcode_s2)
                            OPCODE_FP_FEQ: result_bool_comb = 1'b0;
                            OPCODE_FP_FNE: result_bool_comb = 1'b1;
                            OPCODE_FP_FLT: result_bool_comb = (sign_b_s2 == 0); // finite < +Inf
                            OPCODE_FP_FLE: result_bool_comb = (sign_b_s2 == 0);
                            OPCODE_FP_FGT: result_bool_comb = (sign_b_s2 == 1); // finite > -Inf
                            OPCODE_FP_FGE: result_bool_comb = (sign_b_s2 == 1);
                            default: result_bool_comb = 1'b0;
                        endcase
                    // 4. Finite non-zero against zero (handled after general inf/nan checks)
                    end else if (is_a_zero_s2) begin 
                        // B is positive (sign_b_s2 == 0) or negative (sign_b_s2 == 1)
                        case (opcode_s2)
                            OPCODE_FP_FEQ: result_bool_comb = 1'b0; // 0 != non-zero
                            OPCODE_FP_FNE: result_bool_comb = 1'b1;
                            OPCODE_FP_FLT: result_bool_comb = (sign_b_s2 == 0); // 0 < +B (e.g., 0 < 5.0)
                            OPCODE_FP_FLE: result_bool_comb = (sign_b_s2 == 0);
                            OPCODE_FP_FGT: result_bool_comb = (sign_b_s2 == 1); // 0 > -B (e.g., 0 > -5.0)
                            OPCODE_FP_FGE: result_bool_comb = (sign_b_s2 == 1);
                            default: result_bool_comb = 1'b0;
                        endcase
                    end else if (is_b_zero_s2) begin 
                        case (opcode_s2)
                            OPCODE_FP_FEQ: result_bool_comb = 1'b0;
                            OPCODE_FP_FNE: result_bool_comb = 1'b1;
                            OPCODE_FP_FLT: result_bool_comb = (sign_a_s2 == 1); // -A < 0 (e.g., -5.0 < 0)
                            OPCODE_FP_FLE: result_bool_comb = (sign_a_s2 == 1);
                            OPCODE_FP_FGT: result_bool_comb = (sign_a_s2 == 0); // +A > 0 (e.g., 5.0 > 0)
                            OPCODE_FP_FGE: result_bool_comb = (sign_a_s2 == 0);
                            default: result_bool_comb = 1'b0;
                        endcase
                    //5. Normal finite number comparison
                    end else begin 
                        case (opcode_s2)
                            OPCODE_FP_FEQ: result_bool_comb = comp_a_eq_b_s2;
                            OPCODE_FP_FNE: result_bool_comb = !comp_a_eq_b_s2;
                            OPCODE_FP_FLT: result_bool_comb = comp_a_lt_b_s2;
                            OPCODE_FP_FLE: result_bool_comb = comp_a_lt_b_s2 || comp_a_eq_b_s2;
                            OPCODE_FP_FGT: result_bool_comb = comp_a_gt_b_s2;
                            OPCODE_FP_FGE: result_bool_comb = comp_a_gt_b_s2 || comp_a_eq_b_s2;
                            default: result_bool_comb = 1'b0;
                        endcase
                    end
                end
            end //end of comparison operations

            OPCODE_FP_FNEG: begin 
                // FNEG (Floating-Point Negate): Flip the sign bit of 'a'.
                // This applies to all numbers, including NaN, Inf, and Zero.
                result_fp_comb = {~a_s2[SIGN_BIT], a_s2[SIGN_BIT-1:0]};
            end 
            OPCODE_FP_ABS: begin 
                // FABS (Floating-Point Absolute): Clear the sign bit of 'a'.
                // This applies to all numbers, including NaN, Inf, and Zero.
                result_fp_comb = {1'b0, a_s2[SIGN_BIT-1:0]};
            end
            OPCODE_FP_FMIN: begin 
                // FMIN (Floating-Point Minimum): Returns the numerically smaller value.
                // IEEE 754 minNum rules:
                // 1. If one operand is NaN and the other is not, return the non-NaN operand.
                // 2. If both are NaN, return a canonical Quiet NaN (QNAN).
                // 3. If one is +0 and the other is -0, return -0.
                // 4. Otherwise, return the numerically smaller value.
                if (is_a_nan_s2 && !is_b_nan_s2) begin 
                    result_fp_comb = b_s2;
                end else if (!is_a_nan_s2 && is_b_nan_s2) begin
                    result_fp_comb = a_s2;
                end else if (is_a_nan_s2 && is_b_nan_s2) begin 
                    result_fp_comb = QNAN;
                end else if (is_a_zero_s2 && is_b_zero_s2) begin 
                    result_fp_comb = NEG_ZERO; //rule 3. min(+0,-0) = -0
                end else begin 
                    // Rule 4: For all other cases (finite non-zeros, Infs, zero vs non-zero finite),
                    // the numerical comparison determines the minimum.
                    if (comp_a_lt_b_s2) begin // A is numerically less than B
                        result_fp_comb = a_s2;
                    end else if (comp_a_gt_b_s2) begin // A is numerically greater than B
                        result_fp_comb = b_s2;
                    end else begin // A is numerically equal to B (e.g., +Inf == +Inf, 5.0 == 5.0)
                        result_fp_comb = a_s2; // Arbitrarily return A (or B, doesn't matter for equal values)
                    end
                end
            end
            OPCODE_FP_FMAX: begin 
                // FMAX (Floating-Point Maximum): Returns the numerically larger value.
                // IEEE 754 maxNum rules:
                // 1. If one operand is NaN and the other is not, return the non-NaN operand.
                // 2. If both are NaN, return a canonical Quiet NaN (QNAN).
                // 3. If one is +0 and the other is -0, return +0.
                // 4. Otherwise, return the numerically larger value.

                if (is_a_nan_s2 && !is_b_nan_s2) begin
                    result_fp_comb = b_s2; // Rule 1: A is NaN, B is not. Return B.
                end else if (!is_a_nan_s2 && is_b_nan_s2) begin
                    result_fp_comb = a_s2; // Rule 1: B is NaN, A is not. Return A.
                end else if (is_a_nan_s2 && is_b_nan_s2) begin
                    result_fp_comb = QNAN; // Rule 2: Both are NaN. Return QNAN.
                end else if (is_a_zero_s2 && is_b_zero_s2) begin
                    result_fp_comb = POS_ZERO; // Rule 3: max(+0, -0) is +0.
                end else begin
                    // Rule 4: For all other cases (finite non-zeros, Infs, zero vs non-zero finite),
                    // the numerical comparison determines the maximum.
                    if (comp_a_gt_b_s2) begin // A is numerically greater than B
                        result_fp_comb = a_s2;
                    end else if (comp_a_lt_b_s2) begin // A is numerically less than B
                        result_fp_comb = b_s2;
                    end else begin // A is numerically equal to B
                        result_fp_comb = a_s2; // Arbitrarily return A (or B, doesn't matter for equal values)
                    end
                end
            end
            default: begin
                //handles unknown opcodes
                result_fp_comb = QNAN;
                result_bool_comb = 1'b0;
            end
        endcase
    end

    // Sequential Logic for Stage 3: Registers the final combinatorial results.
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            result_fp <= QNAN; // Reset to a known invalid state (NaN)
            result_bool <= 1'b0;
            result_valid <= 1'b0;
        end else if (stage2_valid) begin // Only update if Stage 2 provided valid data
            result_fp <= result_fp_comb;
            result_bool <= result_bool_comb;
            result_valid <= 1'b1;
        end else begin
            result_valid <= 1'b0; // No valid input from previous stage, so no valid output
        end
    end


endmodule

`endif