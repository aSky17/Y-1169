//int32_core_direct_tb.sv
//Direct testbench for the 2-stage pipelined int32_core ALU

`timescale 1ns/1ps

import gpu_parameters::*;
import gpu_opcodes::*;


module int32_core_direct_tb;

    localparam CLK_PERIOD = 10ns; // 1 clock cycle = 10ns ~= 0.1GHz freq.

    //DUT signals
    //inputs
    logic clk;
    logic rst;
    logic valid_instruction;
    logic [OPCODE_WIDTH-1:0] opcode;
    logic [DATA_WIDTH-1:0] operand_a;
    logic [DATA_WIDTH-1:0] operand_b;
    logic use_immediate;
    logic [DATA_WIDTH-1:0] immediate_value;

    //outputs
    logic result_valid;
    logic [DATA_WIDTH-1:0] result_out;
    logic carry_out;
    logic overflow_out;
    logic is_zero_out;
    logic is_negative_out;

    //instantiation of the DUT
    int32_core dut (
        .clk(clk),
        .rst(rst),
        .valid_instruction(valid_instruction),
        .opcode(opcode),
        .operand_a(operand_a),
        .operand_b(operand_b),
        .use_immediate(use_immediate),
        .immediate_value(immediate_value),

        .result_valid(result_valid),
        .result_out(result_out),
        .carry_out(carry_out),
        .overflow_out(overflow_out),
        .is_zero_out(is_zero_out),
        .is_negative_out(is_negative_out)
    );

    //generate a continuous clock signal
    always #((CLK_PERIOD)/2) clk = ~clk;

    //reference expected model
    task automatic calculate_expected(
        input [OPCODE_WIDTH-1:0] ref_opcode,
        input [DATA_WIDTH-1:0] ref_operand_a,
        input [DATA_WIDTH-1:0] ref_current_operand_b,
        output [DATA_WIDTH-1:0] exp_result,
        output logic exp_carry,
        output logic exp_overflow,
        output logic exp_is_zero,
        output logic exp_is_negative
    );

    //sign casting
    logic signed [DATA_WIDTH-1:0] ref_operand_a_signed = $signed(ref_operand_a);
    logic signed [DATA_WIDTH-1:0] ref_current_operand_b_signed = $signed(ref_current_operand_b);

    exp_result = '0;
    exp_carry = 1'b0;
    exp_overflow = 1'b0;
    exp_is_zero = 1'b0;
    exp_is_negative = 1'b0;

    case(ref_opcode) 

        //arithmetica operations
        OPCODE_INT_ADD_R, OPCODE_INT_ADD_I: begin 
            logic [DATA_WIDTH:0] sum_unsigned = $unsigned(ref_operand_a) + $unsigned(ref_current_operand_b);
            logic signed [DATA_WIDTH:0] sum_signed_extended = ref_operand_a_signed + ref_current_operand_b_signed;

            exp_result = sum_unsigned[DATA_WIDTH-1:0];

            if ((ref_operand_a_signed[DATA_WIDTH-1] == ref_current_operand_b_signed[DATA_WIDTH-1]) &&
                (ref_operand_a_signed[DATA_WIDTH-1] != sum_signed_extended[DATA_WIDTH-1])) begin 
                exp_overflow = 1'b1;        
            end
            exp_carry = sum_unsigned[DATA_WIDTH];
        end

        OPCODE_INT_SUB_R, OPCODE_INT_SUB_I: begin 
            logic [DATA_WIDTH:0] diff_unsigned = $unsigned(ref_operand_a) - $unsigned(ref_current_operand_b);
            logic signed [DATA_WIDTH:0] diff_signed_extended = ref_operand_a_signed - ref_current_operand_b_signed;

            exp_result = diff_unsigned[DATA_WIDTH-1:0];

            if ((ref_operand_a_signed[DATA_WIDTH-1] != ref_current_operand_b_signed[DATA_WIDTH-1]) &&
                ref_operand_a_signed[DATA_WIDTH-1] != diff_signed_extended[DATA_WIDTH-1]) begin 
                exp_overflow = 1'b1;
            end
            exp_carry = diff_unsigned[DATA_WIDTH];
        end

        OPCODE_INT_MUL_R, OPCODE_INT_MUL_I: begin 
            logic [2*DATA_WIDTH-1:0] product_signed = ref_operand_a_signed * ref_current_operand_b_signed;
            exp_result = product_signed[DATA_WIDTH-1:0];
            if (product_signed[2*DATA_WIDTH-1] == 1'b0) begin
                if (product_signed[2*DATA_WIDTH-1:DATA_WIDTH] != '0) exp_overflow = 1'b1;
            end else begin 
                if (product_signed[2*DATA_WIDTH-1:DATA_WIDTH] != {DATA_WIDTH{1'b1}}) exp_overflow = 1'b1;
            end
        end

        OPCODE_INT_DIV_R: begin 
            if (ref_current_operand_b == '0) begin 
                exp_result = 'x;
            end else begin 
                exp_result = ref_operand_a_signed / ref_current_operand_b_signed;
                if (ref_operand_a_signed == 32'h80000000 && ref_current_operand_b_signed == 32'hFFFFFFFF) begin 
                    exp_overflow = 1'b1;
                end
            end
        end

        OPCODE_INT_NEG_R: begin 
            exp_result = -ref_operand_a_signed;
            if (ref_operand_a_signed == 32'h80000000) begin
                exp_overflow = 1'b1;
            end
        end

        OPCODE_INT_ABS_R: begin
            exp_result = (ref_operand_a_signed[DATA_WIDTH-1]) ? -ref_operand_a_signed : ref_operand_a_signed;
            if (ref_operand_a_signed == 32'h80000000) begin
                exp_overflow = 1'b1;
            end
        end

        //logical operatioms
        OPCODE_INT_AND_R: exp_result = ref_operand_a & ref_current_operand_b;
        OPCODE_INT_OR_R: exp_result = ref_operand_a | ref_current_operand_b;
        OPCODE_INT_XOR_R: exp_result = ref_operand_a ^ ref_current_operand_b;
        OPCODE_INT_NOT_R: exp_result = ~ref_operand_a;
        OPCODE_INT_NOR_R: exp_result = ~(ref_operand_a | ref_current_operand_b);

        //shift and rotate operations
        OPCODE_INT_SHL_R: exp_result = ref_operand_a << ref_current_operand_b[4:0];
        OPCODE_INT_SHR_R: exp_result = ref_operand_a >> ref_current_operand_b[4:0];
        OPCODE_INT_SAR_R: exp_result = ref_operand_a_signed >>> ref_current_operand_b[4:0];
        OPCODE_INT_ROTL_R: begin 
            logic [4:0] shift_amount = ref_current_operand_b[4:0];
            exp_result = (ref_operand_a << shift_amount) | (ref_operand_a >> (DATA_WIDTH-shift_amount));
        end
        OPCODE_INT_ROTR_R: begin 
            logic [4:0] shift_amount = ref_current_operand_b[4:0];
            exp_result = (ref_operand_a >> shift_amount) | (ref_operand_a << (DATA_WIDTH-shift_amount));
        end 

        //comparison operations
        OPCODE_INT_EQ_R: exp_result = (ref_operand_a == ref_current_operand_b) ? {DATA_WIDTH{1'b1}} : '0;
        OPCODE_INT_NE_R: exp_result = (ref_operand_a != ref_current_operand_b) ? {DATA_WIDTH{1'b1}} : '0;
        OPCODE_INT_LTS_R: exp_result = (ref_operand_a_signed < ref_current_operand_b_signed) ? {DATA_WIDTH{1'b1}} : '0;
        OPCODE_INT_LES_R: exp_result = (ref_operand_a_signed <= ref_current_operand_b_signed) ? {DATA_WIDTH{1'b1}} : '0;
        OPCODE_INT_GTS_R: exp_result = (ref_operand_a_signed > ref_current_operand_b_signed) ? {DATA_WIDTH{1'b1}} : '0;
        OPCODE_INT_GES_R: exp_result = (ref_operand_a_signed >= ref_current_operand_b_signed) ? {DATA_WIDTH{1'b1}} : '0;
        OPCODE_INT_LTU_R: exp_result = ($unsigned(ref_operand_a) < $unsigned(ref_current_operand_b)) ? {DATA_WIDTH{1'b1}} : '0;
        OPCODE_INT_LEU_R: exp_result = ($unsigned(ref_operand_a) <= $unsigned(ref_current_operand_b)) ? {DATA_WIDTH{1'b1}} : '0;
        OPCODE_INT_GTU_R: exp_result = ($unsigned(ref_operand_a) > $unsigned(ref_current_operand_b)) ? {DATA_WIDTH{1'b1}} : '0;
        OPCODE_INT_GEU_R: exp_result = ($unsigned(ref_operand_a) >= $unsigned(ref_current_operand_b)) ? {DATA_WIDTH{1'b1}} : '0;
        

        //min/max operations
        OPCODE_INT_MINS_R: exp_result = (ref_operand_a_signed < ref_current_operand_b_signed) ? ref_operand_a : ref_current_operand_b;
        OPCODE_INT_MAXS_R: exp_result = (ref_operand_a_signed > ref_current_operand_b_signed) ? ref_operand_a : ref_current_operand_b;
        OPCODE_INT_MINU_R: exp_result = ($unsigned(ref_operand_a) < $unsigned(ref_current_operand_b)) ? ref_operand_a : ref_current_operand_b;
        OPCODE_INT_MAXU_R: exp_result = ($unsigned(ref_operand_a) > $unsigned(ref_current_operand_b)) ? ref_operand_a : ref_current_operand_b;

        //bit manipulation operations
        OPCODE_INT_BITREV_R: begin 
            for (int i = 0; i < DATA_WIDTH; i++) begin 
                exp_result[i] = ref_operand_a[DATA_WIDTH-1-i];
            end
        end
        OPCODE_INT_CLZ_R: begin //count leading zero
            int count = 0;
            for (int i = DATA_WIDTH-1; i >= 0; i--) begin 
                if (ref_operand_a[i] == 1'b1) break;
                count++;
            end
            exp_result = count;
        end
        OPCODE_INT_POPC_R: begin 
            int count = 0;
            for (int i = 0; i < DATA_WIDTH; i++) begin 
                if (ref_operand_a[i] == 1'b1) count++;
            end
            exp_result = count;
        end
        OPCODE_INT_BYTEREV_R: begin 
            for (int i = 0; i < DATA_WIDTH/8; i++) begin 
                for (int j = 0; i < 8; j++) begin 
                    exp_result[i*8 + j] = ref_operand_a[i*8 + (7-j)];
                end
            end
        end
        OPCODE_INT_BFE_R: begin 
            logic [4:0] bfe_start_bit = ref_current_operand_b[4:0];
            logic [4:0] bfe_length = ref_current_operand_b[9:0];
            exp_result = '0;
            for (int i = 0; i < bfe_length; i++) begin 
                if ((bfe_start_bit + 1) < DATA_WIDTH) begin 
                    exp_result[i] = ref_operand_a[bfe_start_bit + 1];
                end 
            end 
        end

        //saturated operations
        OPCODE_INT_ADDSAT_R: begin 
            logic signed [DATA_WIDTH:0] sum_sat_extended = ref_operand_a_signed + ref_current_operand_b_signed;
            if ((ref_operand_a_signed[DATA_WIDTH-1] == ref_current_operand_b_signed[DATA_WIDTH-1]) &&
                (ref_operand_a_signed[DATA_WIDTH-1] != sum_sat_extended[DATA_WIDTH-1])) begin 
                    exp_overflow = 1'b1;
                    exp_result = (ref_operand_a_signed[DATA_WIDTH-1] == 1'b0) ? {1'b0, {DATA_WIDTH-1{1'b1}}} : {1'b1, {DATA_WIDTH-1{1'b0}}};
            end else begin 
                exp_result = sum_sat_extended[DATA_WIDTH-1];
            end
        end
        OPCODE_INT_SUBSAT_R: begin 
            logic signed [DATA_WIDTH:0] diff_sat_extended = ref_operand_a_signed - ref_current_operand_b_signed;
            if ((ref_operand_a_signed[DATA_WIDTH-1] != ref_current_operand_b_signed[DATA_WIDTH-1]) && 
                (ref_operand_a_signed[DATA_WIDTH-1] != diff_sat_extended[DATA_WIDTH-1])) begin 
                    exp_overflow = 1'b1;
                    exp_result = (ref_operand_a_signed[DATA_WIDTH-1] == 1'b0) ? {1'b0, {DATA_WIDTH-1{1'b1}}} : {1'b1, {DATA_WIDTH-1{1'b0}}};
            end else begin 
                exp_result = diff_sat_extended[DATA_WIDTH-1];
            end
        end

        //overflow/carry detect operations
        OPCODE_INT_ADDCC_R: begin 
            logic [DATA_WIDTH:0] sum_cc_extended = $unsigned(ref_operand_a) + $unsigned(ref_current_operand_b);
            logic signed [DATA_WIDTH:0] sum_signed_cc_extended = ref_operand_a_signed + ref_current_operand_b_signed;
            exp_result = sum_cc_extended[DATA_WIDTH-1:0];
            exp_carry = sum_cc_extended[DATA_WIDTH];
            if ((ref_operand_a_signed[DATA_WIDTH-1] == ref_current_operand_b_signed[DATA_WIDTH-1]) &&
                (ref_operand_a_signed[DATA_WIDTH-1] != sum_signed_cc_extended[DATA_WIDTH-1])) begin
                    exp_overflow = 1'b1;
            end
        end
        OPCODE_INT_SUBCC_R: begin 
            logic [DATA_WIDTH:0] diff_cc_extended = $unsigned(ref_operand_a) - $unsigned(ref_current_operand_b);
            logic signed [DATA_WIDTH:0] diff_signed_cc_extended = ref_operand_a_signed - ref_current_operand_b_signed;
            exp_result = diff_cc_extended[DATA_WIDTH-1:0];
            exp_carry = diff_cc_extended[DATA_WIDTH];
            if ((ref_operand_a_signed[DATA_WIDTH-1] != ref_current_operand_b_signed[DATA_WIDTH-1]) &&
                (ref_operand_a_signed[DATA_WIDTH-1] != diff_signed_cc_extended[DATA_WIDTH-1])) begin
                    exp_overflow = 1'b1;
            end
        end
        OPCODE_INT_MULCC_R: begin 
            logic signed [2*DATA_WIDTH-1:0] product_extended = ref_operand_a_signed * ref_current_operand_b_signed;
            exp_result = product_extended[2*DATA_WIDTH-1];
            if (product_extended[2*DATA_WIDTH-1] == 1'b0) begin 
                if (product_extended[2*DATA_WIDTH-1] != '0) exp_overflow = 1'b0;
            end else begin 
                if (product_extended[2*DATA_WIDTH-1:DATA_WIDTH] != {DATA_WIDTH{1'b1}}) exp_overflow = 1'b0;
            end
        end

        OPCODE_NOP: begin
                exp_result = '0;
                exp_carry = 1'b0;
                exp_overflow = 1'b0;
                exp_is_zero = 1'b1; // NOP result is zero
                exp_is_negative = 1'b0;
        end

        default: begin 
            exp_result = '0;
            exp_carry = 1'b0;
            exp_overflow = 1'b0;
            exp_is_zero = 1'b0;
            exp_is_negative = 1'b0;
        end
    endcase

    exp_is_zero = (exp_result == '0);
    exp_is_negative = exp_result[DATA_WIDTH-1];

    endtask

    //task to apply stimulus and check results
    task automatic run_test_case(
        input string test_name,
        input [OPCODE_WIDTH-1:0] test_opcode,
        input [DATA_WIDTH-1:0] test_operand_a,
        input [DATA_WIDTH-1:0] test_operand_b,
        input logic test_use_immediate,
        input [DATA_WIDTH-1:0] test_immediate_value
    );

    logic [DATA_WIDTH-1:0] expected_result;
    logic expected_carry;
    logic expected_overflow;
    logic expected_is_zero;
    logic expected_is_negative;
    logic [DATA_WIDTH-1:0] selected_operand_b_for_ref;

    $display("Running tests: %0s ",test_name);
    $info("Inputs: Opcode = %0s (0x%h), OpA = 0x%h, OpB = 0x%h, UseImm = %b, ImmVal = 0x%h",
              test_opcode, test_opcode, test_operand_a, test_operand_b, test_use_immediate, test_immediate_value);

    selected_operand_b_for_ref = test_use_immediate ? test_immediate_value : test_operand_b;

    calculate_expected(
        test_opcode,
        test_operand_a,
        selected_operand_b_for_ref,
        expected_result,
        expected_carry,
        expected_overflow,
        expected_is_zero,
        expected_is_negative
    );

    //apply inputs to the DUT at the positive edge of the clock
    @(posedge clk);
    valid_instruction <= 1'b1;
    opcode <= test_opcode;
    operand_a <= test_operand_a;
    operand_b <= test_operand_b;
    use_immediate <= test_use_immediate;
    immediate_value <= test_immediate_value;

    //wait for the pipeline latency(2 cyles for a 2-stage pipeline)
    //ie instruction issued at T0 will have its result valid at T2
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    //self checking 
    //check result_valid first. For NOP, result_valid is 0
    if (test_opcode == OPCODE_NOP) begin 
        if (result_valid) begin 
            $error("FAIL: %0s - result_valid asserted for NOP! Expected: 0, Got: 1", test_name);
        end else begin
            $info("PASS: %0s - result_valid correctly de-asserted for NOP.", test_name);
        end
    end else begin //for all other opcode
        if (!result_valid) begin
            $error("FAIL: %0s - result_valid did not assert after 2 cycles! Expected: 1, Got: 0", test_name);
        end else begin
            $info("PASS: %0s - result_valid correctly asserted.", test_name);
        end
    end

    //proceed only if result_valid is asserted or if the case is of Division becasue even if the result_valid is not asserted
    //because of divide by zero, we would still want to check status flags
    if (result_valid || test_opcode inside {OPCODE_INT_DIV_R}) begin 
        //immma using !== as it detects unknows(x and z) as well, useful in division 
        if (result_out !== expected_result) begin 
            $error("FAIL: %0s - Result mismatch! Expected: %h, Got: %h", test_name, expected_result, result_out);
        end else begin 
            $info("PASS: %0s - Result matches: %h", test_name, result_out);
        end

        //flag comparisons
        if (carry_out !== expected_carry) begin 
            $error("FAIL: %0s - Carry Mismatch! Expected: %0h, Got: %0h", test_name, expected_carry, carry_out);
        end else begin
            $info("PASS: %0s - Carry matches: %b", test_name, carry_out);
        end

        if (overflow_out !== expected_overflow) begin 
            $error("FAIL: %0s - Overflow Mismatch! Expected: %0h, Got: %0h", test_name, expected_overflow, overflow_out);
        end else begin 
            $info("PASS: %0s - Overflow matches: %b", test_name, overflow_out);
        end

        if (is_zero_out !== expected_is_zero) begin
                $error("FAIL: %0s - Is_Zero mismatch! Expected: %b, Got: %b", test_name, expected_is_zero, is_zero_out);
        end else begin
            $info("PASS: %0s - Is_Zero matches: %b", test_name, is_zero_out);
        end

        if (is_negative_out !== expected_is_negative) begin
            $error("FAIL: %0s - Is_Negative mismatch! Expected: %b, Got: %b", test_name, expected_is_negative, is_negative_out);
        end else begin
            $info("PASS: %0s - Is_Negative matches: %b", test_name, is_negative_out);
        end
    end

    //de-assert the valid_instruction to prepare for the next test
    @(posedge clk);
    valid_instruction <= 1'b0;
    opcode <= '0;
    operand_a <= '0;
    operand_b <= '0;
    use_immediate <= 1'b0;
    immediate_value <= '0;

    @(posedge clk); //allow pipeline to clear
    @(posedge clk); //ensuring pipeline is fully flushed before next text's input
    endtask

    initial begin
        clk = 0;
        rst = 1;
        valid_instruction = 0;
        opcode = '0;
        operand_a = '0;
        operand_b = '0;
        use_immediate = 0;
        immediate_value = '0;

        $display("Starting direct tb for int32_core");

        //keeping reset for 2 clock cycles
        @(posedge clk);
        @(posedge clk);
        
        rst = 0; //de-asserting reset

        @(posedge clk);
        $display("Reset de-asserted, starting test cases");

        // --- Comprehensive Direct Test Cases ---

        // 1. Basic Arithmetic Operations (Register and Immediate)
        run_test_case("ADD_R_Pos_Pos", OPCODE_INT_ADD_R, 32'd10, 32'd20, 1'b0, '0); // 10 + 20 = 30
        run_test_case("ADD_I_Neg_Neg", OPCODE_INT_ADD_I, 32'(-10), 32'd0, 1'b1, 32'(-20)); // -10 + (-20) = -30
        run_test_case("SUB_R_Pos_Neg", OPCODE_INT_SUB_R, 32'd50, 32'(-30), 1'b0, '0); // 50 - (-30) = 80
        run_test_case("SUB_I_Zero", OPCODE_INT_SUB_I, 32'd100, 32'd0, 1'b1, 32'd100); // 100 - 100 = 0
        run_test_case("MUL_R_Basic", OPCODE_INT_MUL_R, 32'd5, 32'd7, 1'b0, '0); // 5 * 7 = 35
        run_test_case("MUL_I_Negative", OPCODE_INT_MUL_I, 32'(-5), 32'd0, 1'b1, 32'd3); // -5 * 3 = -15
        run_test_case("DIV_R_Basic", OPCODE_INT_DIV_R, 32'd100, 32'd10, 1'b0, '0); // 100 / 10 = 10
        run_test_case("NEG_R_Positive", OPCODE_INT_NEG_R, 32'd25, '0, 1'b0, '0); // -25
        run_test_case("ABS_R_Negative", OPCODE_INT_ABS_R, 32'(-42), '0, 1'b0, '0); // |-42| = 42

        // 2. Arithmetic Overflow/Underflow (Signed)
        run_test_case("ADD_I_Overflow_Pos", OPCODE_INT_ADD_I, 32'h7FFFFFFF, 32'd0, 1'b1, 32'd1); // MAX_INT + 1
        run_test_case("ADD_R_Underflow_Neg", OPCODE_INT_ADD_R, 32'h80000000, 32'(-1), 1'b0, '0); // MIN_INT + (-1)
        run_test_case("SUB_R_Overflow_Pos", OPCODE_INT_SUB_R, 32'h7FFFFFFF, 32'h80000000, 1'b0, '0); // MAX_INT - MIN_INT (MAX_INT - (-MAX_INT-1))
        run_test_case("SUB_I_Underflow_Neg", OPCODE_INT_SUB_I, 32'h80000000, 32'd0, 1'b1, 32'd1); // MIN_INT - 1
        run_test_case("MUL_R_Overflow_Pos", OPCODE_INT_MUL_R, 32'h40000000, 32'd2, 1'b0, '0); // (2^30) * 2 = 2^31 (overflows signed positive)
        run_test_case("MUL_I_Overflow_Neg", OPCODE_INT_MUL_I, 32'h40000000, 32'd0, 1'b1, 32'(-2)); // (2^30) * -2
        run_test_case("DIV_R_MinIntDivNeg1_Overflow", OPCODE_INT_DIV_R, 32'h80000000, 32'hFFFFFFFF, 1'b0, '0); // MIN_INT / -1
        run_test_case("NEG_R_MinInt_Overflow", OPCODE_INT_NEG_R, 32'h80000000, '0, 1'b0, '0); // -MIN_INT
        run_test_case("ABS_R_MinInt_Overflow", OPCODE_INT_ABS_R, 32'h80000000, '0, 1'b0, '0); // ABS(MIN_INT)

        // 3. Divide by Zero
        run_test_case("DIV_R_DivByZero", OPCODE_INT_DIV_R, 32'd100, 32'd0, 1'b0, '0);

        // 4. Logical Operations
        run_test_case("AND_R_AllBits", OPCODE_INT_AND_R, 32'hFFFFFFFF, 32'h00000000, 1'b0, '0);
        run_test_case("OR_R_AllBits", OPCODE_INT_OR_R, 32'hAAAAAAAA, 32'h55555555, 1'b0, '0);
        run_test_case("XOR_R_Self", OPCODE_INT_XOR_R, 32'h12345678, 32'h12345678, 1'b0, '0); // XOR with self = 0
        run_test_case("NOT_R_Zero", OPCODE_INT_NOT_R, 32'd0, '0, 1'b0, '0); // ~0 = all 1s
        run_test_case("NOR_R_Basic", OPCODE_INT_NOR_R, 32'hF, 32'h0, 1'b0, '0); // ~(F | 0) = ~F

        // 5. Shift and Rotate Operations
        run_test_case("SHL_R_ShiftBy0", OPCODE_INT_SHL_R, 32'h12345678, 32'd0, 1'b0, '0); // No shift
        run_test_case("SHL_R_ShiftBy1", OPCODE_INT_SHL_R, 32'h00000001, 32'd1, 1'b0, '0); // 1 << 1 = 2
        run_test_case("SHL_R_ShiftByMax", OPCODE_INT_SHL_R, 32'h80000000, 32'd31, 1'b0, '0); // 0x80000000 << 31 = 0
        run_test_case("SHR_R_ShiftBy0", OPCODE_INT_SHR_R, 32'h12345678, 32'd0, 1'b0, '0);
        run_test_case("SHR_R_ShiftBy1", OPCODE_INT_SHR_R, 32'h80000000, 32'd1, 1'b0, '0); // Logical shift
        run_test_case("SHR_R_ShiftByMax", OPCODE_INT_SHR_R, 32'h00000001, 32'd31, 1'b0, '0); // 1 >> 31 = 0
        run_test_case("SAR_R_ShiftBy0", OPCODE_INT_SAR_R, 32'h80000000, 32'd0, 1'b0, '0); // -2^31 >> 0
        run_test_case("SAR_R_ShiftBy1", OPCODE_INT_SAR_R, 32'h80000000, 32'd1, 1'b0, '0); // -2^31 >>> 1 (sign-extended)
        run_test_case("SAR_R_ShiftByMax", OPCODE_INT_SAR_R, 32'h00000001, 32'd31, 1'b0, '0); // 1 >>> 31 = 0
        run_test_case("ROTL_R_Basic", OPCODE_INT_ROTL_R, 32'h00000001, 32'd31, 1'b0, '0); // 1 ROTL 31 = 0x80000000
        run_test_case("ROTR_R_Basic", OPCODE_INT_ROTR_R, 32'h80000000, 32'd31, 1'b0, '0); // 0x80000000 ROTR 31 = 0x00000001
        run_test_case("ROTL_R_FullCycle", OPCODE_INT_ROTL_R, 32'hABCDEF01, 32'd32, 1'b0, '0); // Rotate by 32 (full cycle)

        // 6. Comparison Operations
        run_test_case("EQ_R_Equal", OPCODE_INT_EQ_R, 32'd10, 32'd10, 1'b0, '0);
        run_test_case("NE_R_NotEqual", OPCODE_INT_NE_R, 32'd10, 32'd11, 1'b0, '0);
        run_test_case("LTS_R_True", OPCODE_INT_LTS_R, 32'd5, 32'd10, 1'b0, '0);
        run_test_case("LTS_R_False", OPCODE_INT_LTS_R, 32'd10, 32'd5, 1'b0, '0);
        run_test_case("LTS_R_Negatives", OPCODE_INT_LTS_R, 32'(-10), 32'(-5), 1'b0, '0);
        run_test_case("LTU_R_True", OPCODE_INT_LTU_R, 32'd5, 32'd10, 1'b0, '0);
        run_test_case("LTU_R_UnsignedMaxVsZero", OPCODE_INT_LTU_R, 32'hFFFFFFFF, 32'd0, 1'b0, '0); // MAX_UNSIGNED < 0 is FALSE

        // 7. Min/Max Operations
        run_test_case("MINS_R_Negatives", OPCODE_INT_MINS_R, 32'(-5), 32'(-10), 1'b0, '0); // Min(-5, -10) = -10
        run_test_case("MAXS_R_Mixed", OPCODE_INT_MAXS_R, 32'd50, 32'(-100), 1'b0, '0); // Max(50, -100) = 50
        run_test_case("MINU_R_Basic", OPCODE_INT_MINU_R, 32'd5, 32'd10, 1'b0, '0); // Min(5, 10) = 5
        run_test_case("MAXU_R_UnsignedMax", OPCODE_INT_MAXU_R, 32'hFFFFFFFF, 32'd10, 1'b0, '0); // Max(unsigned MAX, 10) = unsigned MAX

        // 8. Bit Manipulation Operations
        run_test_case("BITREV_R_Simple", OPCODE_INT_BITREV_R, 32'h12345678, '0, 1'b0, '0); // Expected: 0x1E6A2C48
        run_test_case("CLZ_R_Zeros", OPCODE_INT_CLZ_R, 32'h0000000F, '0, 1'b0, '0); // Expected: 28
        run_test_case("CLZ_R_AllZeros", OPCODE_INT_CLZ_R, 32'd0, '0, 1'b0, '0); // Expected: 32
        run_test_case("POPC_R_HalfSet", OPCODE_INT_POPC_R, 32'hF0F0F0F0, '0, 1'b0, '0); // Expected: 16
        run_test_case("POPC_R_AllSet", OPCODE_INT_POPC_R, 32'hFFFFFFFF, '0, 1'b0, '0); // Expected: 32
        run_test_case("BYTEREV_R_Simple", OPCODE_INT_BYTEREV_R, 32'h11223344, '0, 1'b0, '0); // Expected: 0x11223344 (byte reversal within each byte)
        run_test_case("BFE_R_ExtractMid", OPCODE_INT_BFE_R, 32'hABCDEF01, {5'd4, 5'd8}, 1'b0, '0); // Extract 8 bits starting at bit 4 (F0 in 0xABCDEF01) -> 0xF0
        run_test_case("BFE_R_ExtractZeroLength", OPCODE_INT_BFE_R, 32'hABCDEF01, {5'd4, 5'd0}, 1'b0, '0); // Extract 0 bits -> 0
        run_test_case("BFE_R_ExtractBeyondWidth", OPCODE_INT_BFE_R, 32'hABCDEF01, {5'd30, 5'd5}, 1'b0, '0); // Extract 5 bits starting at bit 30 (should only get 2 bits, others 0)

        // 9. Saturated Arithmetic
        run_test_case("ADDSAT_R_PosSaturation", OPCODE_INT_ADDSAT_R, 32'h7FFFFFFF, 32'd10, 1'b0, '0); // MAX_INT + 10 -> MAX_INT
        run_test_case("ADDSAT_R_NegSaturation", OPCODE_INT_ADDSAT_R, 32'h80000000, 32'(-10), 1'b0, '0); // MIN_INT - 10 -> MIN_INT
        run_test_case("SUBSAT_R_PosSaturation", OPCODE_INT_SUBSAT_R, 32'h7FFFFFFF, 32'(-10), 1'b0, '0); // MAX_INT - (-10) -> MAX_INT
        run_test_case("SUBSAT_R_NegSaturation", OPCODE_INT_SUBSAT_R, 32'h80000000, 32'd10, 1'b0, '0); // MIN_INT - 10 -> MIN_INT
        run_test_case("ADDSAT_R_NoSaturation", OPCODE_INT_ADDSAT_R, 32'd100, 32'd200, 1'b0, '0); // 100 + 200 = 300

        // 10. Overflow/Carry Detect Operations (CC - Condition Codes)
        run_test_case("ADDCC_R_Carry", OPCODE_INT_ADDCC_R, 32'hFFFFFFFF, 32'd1, 1'b0, '0); // Unsigned MAX + 1
        run_test_case("ADDCC_R_Overflow", OPCODE_INT_ADDCC_R, 32'h7FFFFFFF, 32'd1, 1'b0, '0); // Signed MAX + 1
        run_test_case("SUBCC_R_Borrow", OPCODE_INT_SUBCC_R, 32'd0, 32'd1, 1'b0, '0); // 0 - 1 (unsigned)
        run_test_case("MULCC_R_Overflow", OPCODE_INT_MULCC_R, 32'h40000000, 32'd2, 1'b0, '0); // Signed overflow

        // 11. NOP Test
        run_test_case("NOP_Instruction", OPCODE_NOP, 32'hDEADBEEF, 32'hCAFEF00D, 1'b0, '0); // Should result in 0, valid=0

        $display("\nDirect Testbench finished.");
        $finish;
    end

endmodule