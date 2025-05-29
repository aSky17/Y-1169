`ifndef FP_COMPARE_SV
`define FP_COMPARE_SV

module fp_compare #(
    import gpu_parameters::*
) (
    input logic clk,
    input logic rst,
    input logic [DATA_WIDTH-1:0] a,
    input logic [DATA_WIDTH-1:0] b,
    input [OPCODE_WIDTH-1:0] opcode,
    output logic result, //boolean result
    output logic result_valid
);

    import gpu_opcodes::OPCODE_FP_FEQ;
    import gpu_opcodes::OPCODE_FP_FNE;
    import gpu_opcodes::OPCODE_FP_FLT;
    import gpu_opcodes::OPCODE_FP_FLE;
    import gpu_opcodes::OPCODE_FP_FGT;
    import gpu_opcodes::OPCODE_FP_FGE;
    
    initial begin 
        if (DATA_WIDTH != 32) begin 
            $fatal(1, "Error: DATA_WIDTH is not 32 bit");
        end 
    end

    localparam EXP_WIDTH = 8;
    localparam MANT_WIDHT = 23;
    localparam BIAS = 127;

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
            sign_a_s1 <= a[DATA_WIDTH-1:0];
            exp_a_s1 <= exp_a_comb;
            mant_a_s1 <= mant_a_padded_comb;
            sign_b_s1 <= b[DATA_WIDTH-1:0];
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
        end else begin 
            stage2_valid <= 1'b0;
        end
    end

    //Pipelining: Stage-3
    //spedial case resolution and final result calculation
    logic result_comb;

    always_comb begin 
        result_comb = 1'b0;

        //IEEE 754 comparison rules:
        //1.NaN cases: Any ordered comparison involvinng NaN is false
        //Oly FNE is true
        if (is_a_nan_s2 || is_b_nan_s2) begin 
            result_comb = (opcode_s2 == OPCODE_FP_FNE);
        end else begin 
            //2.Zero cases: +0 == -0 is considered true
            if (is_a_zero_s2 && is_b_zero_s2) begin 
                case (opcode_s2) 
                    OPCODE_FP_FEQ: result_comb = 1'b1; // +0 == -0
                    OPCODE_FP_FNE: result_comb = 1'b0; // +0 != -0 (false)
                    OPCODE_FP_FLT: result_comb = 1'b0; // 0 < 0 (false)
                    OPCODE_FP_FLE: result_comb = 1'b1; // 0 <= 0 (true)
                    OPCODE_FP_FGT: result_comb = 1'b0; // 0 > 0 (false)
                    OPCODE_FP_FGE: result_comb = 1'b1; // 0 >= 0 (true)
                    default: result_comb = 1'b0;
                endcase
            //3. Infinity cases
            end else if (is_a_inf_s2 && is_b_inf_s2) begin 
                //both are infinity
                case (opcode_s2) 
                    OPCODE_FP_FEQ: result_comb = (sign_a_s2 == sign_b_s2);
                    OPCODE_FP_FNE: result_comb = (sign_a_s2 != sign_b_s2);
                    OPCODE_FP_FLE: result_comb = (sign_a_s2 == 1 && sign_b_s2 == 0);
                    OPCODE_FP_FLE: result_comb = (sign_a_s2 == 1 || (sign_a_s2 == sign_b_s2));
                    OPCODE_FP_FGT: result_comb = (sign_a_s2 == 0 && sign_b_s2 == 1);
                    OPCODE_FP_FGE: result_comb = (sign_a_s2 == 0 || (sign_a_s2 == sign_b_s2));
                    default: result_comb = 1'b0;
                endcase
            end else if (is_a_inf_s2) begin
                //A is inf, B is finite
                case (opcode_s2)
                    OPCODE_FP_FEQ: result_comb = 1'b0;
                    OPCODE_FP_FNE: result_comb = 1'b1;
                    OPCODE_FP_FLT: result_comb = (sign_a_s2 == 1); // -Inf < finite
                    OPCODE_FP_FLE: result_comb = (sign_a_s2 == 1);
                    OPCODE_FP_FGT: result_comb = (sign_a_s2 == 0); // +Inf > finite
                    OPCODE_FP_FGE: result_comb = (sign_a_s2 == 0);
                    default: result_comb = 1'b0;
                endcase
            end else if (is_b_inf_s2) begin 
                // B is Inf, A is finite
                case (opcode_s2)
                    OPCODE_FP_FEQ: result_comb = 1'b0;
                    OPCODE_FP_FNE: result_comb = 1'b1;
                    OPCODE_FP_FLT: result_comb = (sign_b_s2 == 0); // finite < +Inf
                    OPCODE_FP_FLE: result_comb = (sign_b_s2 == 0);
                    OPCODE_FP_FGT: result_comb = (sign_b_s2 == 1); // finite > -Inf
                    OPCODE_FP_FGE: result_comb = (sign_b_s2 == 1);
                    default: result_comb = 1'b0;
                endcase
            //4. finite non-zero
            end else if (is_a_zero_s2) begin 
                // B is positive (sign_b_s2 == 0) or negative (sign_b_s2 == 1)
                case (opcode_s2)
                    OPCODE_FP_FEQ: result_comb = 1'b0; // 0 != non-zero
                    OPCODE_FP_FNE: result_comb = 1'b1;
                    OPCODE_FP_FLT: result_comb = (sign_b_s2 == 0); // 0 < +B (e.g., 0 < 5.0)
                    OPCODE_FP_FLE: result_comb = (sign_b_s2 == 0);
                    OPCODE_FP_FGT: result_comb = (sign_b_s2 == 1); // 0 > -B (e.g., 0 > -5.0)
                    OPCODE_FP_FGE: result_comb = (sign_b_s2 == 1);
                    default: result_comb = 1'b0;
                endcase
            end else if (is_b_zero_s2) begin 
                case (opcode_s2)
                    OPCODE_FP_FEQ: result_comb = 1'b0;
                    OPCODE_FP_FNE: result_comb = 1'b1;
                    OPCODE_FP_FLT: result_comb = (sign_a_s2 == 1); // -A < 0 (e.g., -5.0 < 0)
                    OPCODE_FP_FLE: result_comb = (sign_a_s2 == 1);
                    OPCODE_FP_FGT: result_comb = (sign_a_s2 == 0); // +A > 0 (e.g., 5.0 > 0)
                    OPCODE_FP_FGE: result_comb = (sign_a_s2 == 0);
                    default: result_comb = 1'b0;
                endcase
            //5 normal finite number comparison, use results ffrom stage 2
            end else begin 
                case (opcode_s2)
                    OPCODE_FP_FEQ: result_comb = comp_a_eq_b_s2;
                    OPCODE_FP_FNE: result_comb = !comp_a_eq_b_s2;
                    OPCODE_FP_FLT: result_comb = comp_a_lt_b_s2;
                    OPCODE_FP_FLE: result_comb = comp_a_lt_b_s2 || comp_a_eq_b_s2;
                    OPCODE_FP_FGT: result_comb = comp_a_gt_b_s2;
                    OPCODE_FP_FGE: result_comb = comp_a_gt_b_s2 || comp_a_eq_b_s2;
                    default: result_comb = 1'b0;
                endcase
            end
        end
    end


    //registering the final combinatorial result
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            result <= 1'b0;
            result_valid <= 1'b0;
        end else if (stage2_valid) begin // Only update if Stage 2 provided valid data
            result <= result_comb;
            result_valid <= 1'b1;
        end else begin
            result_valid <= 1'b0; // No valid input from previous stage, so no valid output
        end
    end

endmodule

`endif