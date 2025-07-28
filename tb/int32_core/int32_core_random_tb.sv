//tb/int32_core_random_tb,sv
//Random testbench for the 2 stage pipelinined
// Uses randomization for stimulus generation and a scoreboard for self-checking.

`timescale 1ns / 1ps

import gpu_opcodes::*;
import gpu_parameters::*;

module int32_core_random_tb;

    localparam CLK_PERIOD = 10ns;
    localparam NUM_TRANSACTION = 5;

    logic clk;
    logic rst;
    logic valid_instruction;
    logic [OPCODE_WIDTH-1:0] opcode;
    logic [DATA_WIDTH-1:0] operand_a;
    logic [DATA_WIDTH-1:0] operand_b;
    logic use_immediate;
    logic [DATA_WIDTH-1:0] immediate_value;

    logic result_valid;
    logic [DATA_WIDTH-1:0] result_out;
    logic carry_out;
    logic overflow_out;
    logic is_zero_out;
    logic is_negative_out;

    int32_core dut(
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

    always #((CLK_PERIOD)/2) clk = ~clk;

    //transaction class
    //1.defines a transaction for the int core inputs
    //2. contains randomization constraints to generate diverse test cases
    class int32_core_transaction;
        rand logic [OPCODE_WIDTH-1:0] opcode;
        rand logic [DATA_WIDTH-1:0] operand_a;
        rand logic [DATA_WIDTH-1:0] operand_b;
        rand logic use_immediate;
        rand logic [DATA_WIDTH-1:0] immediate_value;

        //value of the operand_b to used by dut post randmization
        logic [DATA_WIDTH-1:0] current_operand_b_val;

        //contructor
        function new();
            
        endfunction

        //post randmization
        function void post_randomize();
            current_operand_b_val = use_immediate ? immediate_value : operand_b;
        endfunction

        //defining constraints for operand values
        constraint operand_val_c {
            if (opcode inside {
                OPCODE_INT_ADD_R, OPCODE_INT_ADD_I, OPCODE_INT_SUB_R, OPCODE_INT_SUB_I,
                              OPCODE_INT_MUL_R, OPCODE_INT_MUL_I, OPCODE_INT_DIV_R,
                              OPCODE_INT_NEG_R, OPCODE_INT_ABS_R,
                              OPCODE_INT_ADDSAT_R, OPCODE_INT_SUBSAT_R,
                              OPCODE_INT_ADDCC_R, OPCODE_INT_SUBCC_R, OPCODE_INT_MULCC_R,
                              OPCODE_INT_LTS_R, OPCODE_INT_LES_R, OPCODE_INT_GTS_R, OPCODE_INT_GES_R,
                              OPCODE_INT_LTU_R, OPCODE_INT_LEU_R, OPCODE_INT_GTU_R, OPCODE_INT_GEU_R,
                              OPCODE_INT_MINS_R, OPCODE_INT_MAXS_R, OPCODE_INT_MINU_R, OPCODE_INT_MAXU_R
            }) {
                operand_a dist {
                    '0 := 10,
                    32'd1 := 5,
                    32'(-1) := 5,
                    32'h7FFFFFFF := 5,
                    32'h80000000 := 5,
                    [32'd2 : 32'h7FFFFFFF] := 60,
                    [32'h80000001 : 32'hFFFFFFFF] := 60
                };
                operand_b dist {
                    '0 := 10,
                    32'd1 := 5,
                    32'(-1) := 5,
                    32'h7FFFFFFF := 5,
                    32'h80000000 := 5,
                    [32'd2 : 32'h7FFFFFFF] := 60,
                    [32'h00000001 : 32'hFFFFFFFF] := 60
                };
                immediate_value dist {
                    '0 := 10,
                    32'd1 := 5,
                    32'(-1) := 5,
                    32'h7FFFFFFF := 5,
                    32'h80000000 := 5,
                    [32'd2 : 32'h7FFFFFFF] := 60,
                    [32'h80000001 : 32'hFFFFFFFF] := 60 
                };
            }

            if (opcode inside {
                OPCODE_INT_SHL_R, OPCODE_INT_SHR_R, OPCODE_INT_SAR_R,
                              OPCODE_INT_ROTL_R, OPCODE_INT_ROTR_R, OPCODE_INT_BFE_R
            }) {
                operand_b[4:0] dist {
                    0 := 10,
                    1 := 5,
                    DATA_WIDTH-1 := 5,
                    [2 : DATA_WIDTH-2] := 80
                };
                immediate_value[4:0] dist {
                    0 := 10,
                    1 := 5,
                    DATA_WIDTH-1 := 5,
                    [2 : DATA_WIDTH-2] := 80
                };
            }

            if (opcode == OPCODE_INT_BFE_R) { 
                operand_b[9:5] dist {
                    0 := 10,
                    1 := 5,
                    DATA_WIDTH := 5,
                    [2 : DATA_WIDTH-1] := 80
                }; //length
                operand_b[4:0] dist {
                    0 := 10,
                    1 := 5,
                    DATA_WIDTH-1 := 5,
                    [2 : DATA_WIDTH-2] := 80
                }; //start bit
            }
        }

        //constraint for opcode
        constraint opcode_c {
            opcode dist {
                OPCODE_INT_ADD_R := 5, OPCODE_INT_ADD_I := 5,
                OPCODE_INT_SUB_R := 5, OPCODE_INT_SUB_I := 5,
                OPCODE_INT_MUL_R := 5, OPCODE_INT_MUL_I := 5,
                OPCODE_INT_DIV_R := 5,
                OPCODE_INT_NEG_R := 3, OPCODE_INT_ABS_R := 3,
                OPCODE_INT_AND_R := 2,
                OPCODE_INT_OR_R  := 2,
                OPCODE_INT_XOR_R := 2, OPCODE_INT_NOT_R := 2, OPCODE_INT_NOR_R := 2,
                OPCODE_INT_SHL_R := 3, OPCODE_INT_SHR_R := 3, OPCODE_INT_SAR_R := 3,
                OPCODE_INT_ROTL_R := 2, OPCODE_INT_ROTR_R := 2,
                OPCODE_INT_EQ_R := 2, OPCODE_INT_NE_R := 2,
                OPCODE_INT_LTS_R := 2, OPCODE_INT_LES_R := 2, OPCODE_INT_GTS_R := 2, OPCODE_INT_GES_R := 2,
                OPCODE_INT_LTU_R := 2, OPCODE_INT_LEU_R := 2, OPCODE_INT_GTU_R := 2, OPCODE_INT_GEU_R := 2,
                OPCODE_INT_MINS_R := 2, OPCODE_INT_MAXS_R := 2,
                OPCODE_INT_MINU_R := 2, OPCODE_INT_MAXU_R := 2,
                OPCODE_INT_BITREV_R := 1, OPCODE_INT_CLZ_R := 1,
                OPCODE_INT_POPC_R := 1, OPCODE_INT_BYTEREV_R := 1,
                OPCODE_INT_BFE_R  := 1,
                OPCODE_INT_ADDSAT_R := 3, OPCODE_INT_SUBSAT_R := 3,
                OPCODE_INT_ADDCC_R := 2, OPCODE_INT_SUBCC_R := 2, OPCODE_INT_MULCC_R := 2,
                OPCODE_NOP := 1
            };
        }

        //constraint to force use_immediate based on opcode type
        constraint use_immediate_c {
            if (opcode inside {
                OPCODE_INT_ADD_I,
                OPCODE_INT_SUB_I,
                OPCODE_INT_MUL_I
            }) {
                use_immediate == 1;
            } else {
                use_immediate == 0;
            }
        }

        //constraint to explicitly generate divide by zero
        constraint div_by_zero_c {
            if (opcode == OPCODE_INT_DIV_R) {
                operand_b dist {
                    0 := 10,
                    [1 : 32'hFFFFFFFF] := 90
                };
            }
        }
    endclass

    //scoreboard class
    //contains the reference model, expected results and check the results against the dut
    class int32_core_scoreboard;
        //function to calculate expected results
        function void calculate_expected(
            input int32_core_transaction trans,
            output logic [DATA_WIDTH-1:0] exp_result,
            output logic exp_carry,
            output logic exp_overflow,
            output logic exp_is_zero,
            output logic exp_is_negative
        );

            logic signed [DATA_WIDTH-1:0] ref_operand_a_signed = $signed(trans.operand_a);
            logic signed [DATA_WIDTH-1:0] ref_current_operand_b_signed = $signed(trans.current_operand_b_val);

            exp_result = '0;
            exp_carry = 1'b0;
            exp_overflow = 1'b0;
            exp_is_zero = 1'b0;
            exp_is_negative = 1'b0;

            case(trans.opcode)
                // Arithmetic Operations
                OPCODE_INT_ADD_R: begin
                    logic [DATA_WIDTH:0] sum_unsigned = $unsigned(trans.operand_a) + $unsigned(trans.current_operand_b_val);
                    logic signed [DATA_WIDTH:0] sum_signed_extended = ref_operand_a_signed + ref_current_operand_b_signed;
                    exp_result = sum_unsigned[DATA_WIDTH-1:0];
                    if ((ref_operand_a_signed[DATA_WIDTH-1] == ref_current_operand_b_signed[DATA_WIDTH-1]) &&
                        (ref_operand_a_signed[DATA_WIDTH-1] != sum_signed_extended[DATA_WIDTH-1])) begin
                        exp_overflow = 1'b1;
                    end
                    exp_carry = sum_unsigned[DATA_WIDTH];
                end
                OPCODE_INT_SUB_R: begin
                    logic [DATA_WIDTH:0] diff_unsigned = $unsigned(trans.operand_a) - $unsigned(trans.current_operand_b_val);
                    logic signed [DATA_WIDTH:0] diff_signed_extended = ref_operand_a_signed - ref_current_operand_b_signed;
                    exp_result = diff_unsigned[DATA_WIDTH-1:0];
                    if ((ref_operand_a_signed[DATA_WIDTH-1] != ref_current_operand_b_signed[DATA_WIDTH-1]) &&
                        (ref_operand_a_signed[DATA_WIDTH-1] != diff_signed_extended[DATA_WIDTH-1])) begin
                        exp_overflow = 1'b1;
                    end
                    exp_carry = diff_unsigned[DATA_WIDTH];
                end
                OPCODE_INT_MUL_R: begin
                    logic signed [DATA_WIDTH*2-1:0] product_signed = ref_operand_a_signed * ref_current_operand_b_signed;
                    exp_result = product_signed[DATA_WIDTH-1:0];
                    if (product_signed[DATA_WIDTH*2-1] == 1'b0) begin
                        if (product_signed[DATA_WIDTH*2-1:DATA_WIDTH] != '0) exp_overflow = 1'b1;
                    end else begin
                        if (product_signed[DATA_WIDTH*2-1:DATA_WIDTH] != {DATA_WIDTH{1'b1}}) exp_overflow = 1'b1;
                    end
                end
                OPCODE_INT_DIV_R: begin
                    if (trans.current_operand_b_val == '0) begin
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
                OPCODE_INT_ADD_I: begin
                    logic [DATA_WIDTH:0] sum_unsigned = $unsigned(trans.operand_a) + $unsigned(trans.current_operand_b_val);
                    logic signed [DATA_WIDTH:0] sum_signed_extended = ref_operand_a_signed + ref_current_operand_b_signed;
                    exp_result = sum_unsigned[DATA_WIDTH-1:0];
                    if ((ref_operand_a_signed[DATA_WIDTH-1] == ref_current_operand_b_signed[DATA_WIDTH-1]) &&
                        (ref_operand_a_signed[DATA_WIDTH-1] != sum_signed_extended[DATA_WIDTH-1])) begin
                        exp_overflow = 1'b1;
                    end
                    exp_carry = sum_unsigned[DATA_WIDTH];
                end
                OPCODE_INT_SUB_I: begin
                    logic [DATA_WIDTH:0] diff_unsigned = $unsigned(trans.operand_a) - $unsigned(trans.current_operand_b_val);
                    logic signed [DATA_WIDTH:0] diff_signed_extended = ref_operand_a_signed - ref_current_operand_b_signed;
                    exp_result = diff_unsigned[DATA_WIDTH-1:0];
                    if ((ref_operand_a_signed[DATA_WIDTH-1] != ref_current_operand_b_signed[DATA_WIDTH-1]) &&
                        (ref_operand_a_signed[DATA_WIDTH-1] != diff_signed_extended[DATA_WIDTH-1])) begin
                        exp_overflow = 1'b1;
                    end
                    exp_carry = diff_unsigned[DATA_WIDTH];
                end
                OPCODE_INT_MUL_I: begin
                    logic signed [DATA_WIDTH*2-1:0] product_signed = ref_operand_a_signed * ref_current_operand_b_signed;
                    exp_result = product_signed[DATA_WIDTH-1:0];
                    if (product_signed[DATA_WIDTH*2-1] == 1'b0) begin
                        if (product_signed[DATA_WIDTH*2-1:DATA_WIDTH] != '0) exp_overflow = 1'b1;
                    end else begin
                        if (product_signed[DATA_WIDTH*2-1:DATA_WIDTH] != {DATA_WIDTH{1'b1}}) exp_overflow = 1'b1;
                    end
                end

                OPCODE_INT_AND_R: exp_result = trans.operand_a & trans.current_operand_b_val;
                OPCODE_INT_OR_R:  exp_result = trans.operand_a | trans.current_operand_b_val;
                OPCODE_INT_XOR_R: exp_result = trans.operand_a ^ trans.current_operand_b_val;
                OPCODE_INT_NOT_R: exp_result = ~trans.operand_a;
                OPCODE_INT_NOR_R: exp_result = ~(trans.operand_a | trans.current_operand_b_val);

                OPCODE_INT_SHL_R:  exp_result = trans.operand_a << trans.current_operand_b_val[4:0];
                OPCODE_INT_SHR_R:  exp_result = trans.operand_a >> trans.current_operand_b_val[4:0];
                OPCODE_INT_SAR_R:  exp_result = ref_operand_a_signed >>> trans.current_operand_b_val[4:0];
                OPCODE_INT_ROTL_R: begin
                    logic [4:0] shift_amount = trans.current_operand_b_val[4:0];
                    exp_result = (trans.operand_a << shift_amount) | (trans.operand_a >> (DATA_WIDTH-shift_amount));
                end
                OPCODE_INT_ROTR_R: begin
                    logic [4:0] shift_amount = trans.current_operand_b_val[4:0];
                    exp_result = (trans.operand_a >> shift_amount) | (trans.operand_a << (DATA_WIDTH-shift_amount));
                end

                OPCODE_INT_EQ_R:   exp_result = (trans.operand_a == trans.current_operand_b_val) ? {DATA_WIDTH{1'b1}} : '0;
                OPCODE_INT_NE_R:   exp_result = (trans.operand_a != trans.current_operand_b_val) ? {DATA_WIDTH{1'b1}} : '0;
                OPCODE_INT_LTS_R:  exp_result = (ref_operand_a_signed < ref_current_operand_b_signed) ? {DATA_WIDTH{1'b1}} : '0;
                OPCODE_INT_LES_R:  exp_result = (ref_operand_a_signed <= ref_current_operand_b_signed) ? {DATA_WIDTH{1'b1}} : '0;
                OPCODE_INT_GTS_R:  exp_result = (ref_operand_a_signed > ref_current_operand_b_signed) ? {DATA_WIDTH{1'b1}} : '0;
                OPCODE_INT_GES_R:  exp_result = (ref_operand_a_signed >= ref_current_operand_b_signed) ? {DATA_WIDTH{1'b1}} : '0;
                OPCODE_INT_LTU_R:  exp_result = ($unsigned(trans.operand_a) < $unsigned(trans.current_operand_b_val)) ? {DATA_WIDTH{1'b1}} : '0;
                OPCODE_INT_LEU_R:  exp_result = ($unsigned(trans.operand_a) <= $unsigned(trans.current_operand_b_val)) ? {DATA_WIDTH{1'b1}} : '0;
                OPCODE_INT_GTU_R:  exp_result = ($unsigned(trans.operand_a) > $unsigned(trans.current_operand_b_val)) ? {DATA_WIDTH{1'b1}} : '0;
                OPCODE_INT_GEU_R:  exp_result = ($unsigned(trans.operand_a) >= $unsigned(trans.current_operand_b_val)) ? {DATA_WIDTH{1'b1}} : '0;

                OPCODE_INT_MINS_R: exp_result = (ref_operand_a_signed < ref_current_operand_b_signed) ? trans.operand_a : trans.current_operand_b_val;
                OPCODE_INT_MAXS_R: exp_result = (ref_operand_a_signed > ref_current_operand_b_signed) ? trans.operand_a : trans.current_operand_b_val;
                OPCODE_INT_MINU_R: exp_result = ($unsigned(trans.operand_a) < $unsigned(trans.current_operand_b_val)) ? trans.operand_a : trans.current_operand_b_val;
                OPCODE_INT_MAXU_R: exp_result = ($unsigned(trans.operand_a) > $unsigned(trans.current_operand_b_val)) ? trans.operand_a : trans.current_operand_b_val;

                OPCODE_INT_BITREV_R: begin
                    for (int i = 0; i < DATA_WIDTH; i++) begin
                        exp_result[i] = trans.operand_a[DATA_WIDTH-1-i];
                    end
                end
                OPCODE_INT_CLZ_R: begin
                    int count = 0;
                    for (int i = DATA_WIDTH-1; i >= 0; i--) begin
                        if (trans.operand_a[i] == 1'b1) break;
                        count++;
                    end
                    exp_result = count;
                end
                OPCODE_INT_POPC_R: begin
                    int count = 0;
                    for (int i = 0; i < DATA_WIDTH; i++) begin
                        if (trans.operand_a[i] == 1'b1) count++;
                    end
                    exp_result = count;
                end
                OPCODE_INT_BYTEREV_R: begin
                    for (int i = 0; i < DATA_WIDTH/8; i++) begin
                        for (int j = 0; j < 8; j++) begin
                            exp_result[i*8 + j] = trans.operand_a[i*8 + (7-j)];
                        end
                    end
                end
                OPCODE_INT_BFE_R: begin
                    logic [4:0] bfe_start_bit = trans.current_operand_b_val[4:0];
                    logic [4:0] bfe_length = trans.current_operand_b_val[9:5];
                    exp_result = '0;
                    for (int i = 0; i < bfe_length; i++) begin
                        if ((bfe_start_bit + i) < DATA_WIDTH) begin
                            exp_result[i] = trans.operand_a[bfe_start_bit + i];
                        end
                    end
                end

                OPCODE_INT_ADDSAT_R: begin
                    logic signed [DATA_WIDTH:0] sum_sat_extended = ref_operand_a_signed + ref_current_operand_b_signed;
                    if ((ref_operand_a_signed[DATA_WIDTH-1] == ref_current_operand_b_signed[DATA_WIDTH-1]) &&
                        (ref_operand_a_signed[DATA_WIDTH-1] != sum_sat_extended[DATA_WIDTH-1])) begin
                        exp_overflow = 1'b1;
                        exp_result = (ref_operand_a_signed[DATA_WIDTH-1] == 1'b0) ? {1'b0, {DATA_WIDTH-1{1'b1}}} : {1'b1, {DATA_WIDTH-1{1'b0}}};
                    end else begin
                        exp_result = sum_sat_extended[DATA_WIDTH-1:0];
                    end
                end
                OPCODE_INT_SUBSAT_R: begin
                    logic signed [DATA_WIDTH:0] diff_sat_extended = ref_operand_a_signed - ref_current_operand_b_signed;
                    if ((ref_operand_a_signed[DATA_WIDTH-1] != ref_current_operand_b_signed[DATA_WIDTH-1]) &&
                        (ref_operand_a_signed[DATA_WIDTH-1] != diff_sat_extended[DATA_WIDTH-1])) begin
                        exp_overflow = 1'b1;
                        exp_result = (ref_operand_a_signed[DATA_WIDTH-1] == 1'b0) ? {1'b0, {DATA_WIDTH-1{1'b1}}} : {1'b1, {DATA_WIDTH-1{1'b0}}};
                    end else begin
                        exp_result = diff_sat_extended[DATA_WIDTH-1:0];
                    end
                end

                OPCODE_INT_ADDCC_R: begin
                    logic [DATA_WIDTH:0] sum_cc_extended = $unsigned(trans.operand_a) + $unsigned(trans.current_operand_b_val);
                    logic signed [DATA_WIDTH:0] sum_signed_cc_extended = ref_operand_a_signed + ref_current_operand_b_signed;
                    exp_result = sum_cc_extended[DATA_WIDTH-1:0];
                    exp_carry = sum_cc_extended[DATA_WIDTH];
                    if ((ref_operand_a_signed[DATA_WIDTH-1] == ref_current_operand_b_signed[DATA_WIDTH-1]) &&
                        (ref_operand_a_signed[DATA_WIDTH-1] != sum_signed_cc_extended[DATA_WIDTH-1])) begin
                        exp_overflow = 1'b1;
                    end
                end
                OPCODE_INT_SUBCC_R: begin
                    logic [DATA_WIDTH:0] diff_cc_extended = $unsigned(trans.operand_a) - $unsigned(trans.current_operand_b_val);
                    logic signed [DATA_WIDTH:0] diff_signed_cc_extended = ref_operand_a_signed - ref_current_operand_b_signed;
                    exp_result = diff_cc_extended[DATA_WIDTH-1:0];
                    exp_carry = diff_cc_extended[DATA_WIDTH];
                    if ((ref_operand_a_signed[DATA_WIDTH-1] != ref_current_operand_b_signed[DATA_WIDTH-1]) &&
                        (ref_operand_a_signed[DATA_WIDTH-1] != diff_signed_cc_extended[DATA_WIDTH-1])) begin
                        exp_overflow = 1'b1;
                    end
                end
                OPCODE_INT_MULCC_R: begin
                    logic signed [DATA_WIDTH*2-1:0] product_extended = ref_operand_a_signed * ref_current_operand_b_signed;
                    exp_result = product_extended[DATA_WIDTH-1:0];
                    if (product_extended[DATA_WIDTH*2-1] == 1'b0) begin
                        if (product_extended[DATA_WIDTH*2-1:DATA_WIDTH] != '0) exp_overflow = 1'b1;
                    end else begin
                        if (product_extended[DATA_WIDTH*2-1:DATA_WIDTH] != {DATA_WIDTH{1'b1}}) exp_overflow = 1'b1;
                    end
                end
                OPCODE_NOP: begin
                    exp_result = '0;
                    exp_carry = 1'b0;
                    exp_overflow = 1'b0;
                    exp_is_zero = 1'b1;
                    exp_is_negative = 1'b0;
                end
                default: begin // Unhandled opcodes
                    exp_result = '0;
                    exp_carry = 1'b0;
                    exp_overflow = 1'b0;
                    exp_is_zero = 1'b1;
                    exp_is_negative = 1'b0;
                end
            endcase

            exp_is_zero = (exp_result == '0);
            exp_is_negative = exp_result[DATA_WIDTH-1];
        endfunction

        //function to compare the dut outputs with the expected outputs
        function void check_results(
            input int32_core_transaction sent_trans,
            input logic dut_result_valid,
            input logic [DATA_WIDTH-1:0] dut_result,
            input logic dut_carry,
            input logic dut_overflow,
            input logic dut_is_zero,
            input logic dut_is_negative
        );

            logic [DATA_WIDTH-1:0] exp_result;
            logic exp_carry;
            logic exp_overflow;
            logic exp_is_zero;
            logic exp_is_negative;
            string opcode_name = $sformatf("0x%h", sent_trans.opcode);

            calculate_expected(sent_trans, exp_result, exp_carry, exp_overflow, exp_is_zero, exp_is_negative);

            $info("Checking Opcode=%0s (OpA=0x%h, OpB=0x%h, UseImm=%b, ImmVal=0x%h)", opcode_name, sent_trans.operand_a,sent_trans.operand_b,sent_trans.use_immediate,sent_trans.immediate_value);
            $info("Expected: Result=0x%h, Carry=%b, Overflow=%b, Zero=%b, Negative=%b",exp_result,exp_carry, exp_overflow, exp_is_zero, exp_is_negative);
            $info("Actual: Result=0x%h, Carry=%b, Overflow=%b, Zero=%b, Negative=%b, Valid=%b ",dut_result,dut_carry, dut_overflow, dut_is_zero, dut_is_negative,dut_result_valid);

            //check result_valid first
            if (sent_trans.opcode == OPCODE_NOP) begin 
                if (dut_result_valid) begin 
                    $error("MISCOMPARE: %0s - result_valid asserted for NOP! Expected: 0, Got: 1", opcode_name);
                end
            end else begin //for any other opcode, result_valid should be 1
                if (!dut_result_valid) begin 
                    $error("MISCOMPARE: %0s - result_valid did not assert! Expected: 1, Got: 0", opcode_name);
                end
            end

            //perform detailed comparisons only if result_valid is high 
            //or if its a divide by zero, where flags are necessay
            if (dut_result_valid || sent_trans.opcode == OPCODE_INT_DIV_R) begin 
                if (dut_result !== exp_result) begin 
                    $error("MISCOMPARE: %0s - Result: Exp=0x%h, Act=0x%h", opcode_name, exp_result, dut_result);
                end

                if (dut_carry !== exp_carry) begin
                    $error("MISCOMPARE: %0s - Carry: Exp=%b, Act=%b", opcode_name, exp_carry, dut_carry);
                end

                if (dut_overflow !== exp_overflow) begin
                    $error("MISCOMPARE: %0s - Overflow: Exp=%b, Act=%b", opcode_name, exp_overflow, dut_overflow);
                end

                if (dut_is_zero !== exp_is_zero) begin
                    $error("MISCOMPARE: %0s - Is_Zero: Exp=%b, Act=%b", opcode_name, exp_is_zero, dut_is_zero);
                end

                if (dut_is_negative !== exp_is_negative) begin
                    $error("MISCOMPARE: %0s - Is_Negative: Exp=%b, Act=%b", opcode_name, exp_is_negative, dut_is_negative);
                end
            end
            
        endfunction
    endclass


    initial begin

        int32_core_transaction tr;
        
        int32_core_scoreboard sb = new();

        //queue to hold transaction in flight (for pipeline delay)
        //for a 2 stage pipeline, we need to track 2 transactions (one in S1, one in S2)
        int32_core_transaction transaction_in_flight[2];

        int i;

        clk = 0;
        rst = 1;
        valid_instruction = 0;
        opcode = '0;
        operand_a = '0;
        operand_b = '0;
        use_immediate = 0;
        immediate_value = '0;

        $display("Starting RANDOM TESTBENCH for int32_core...");

        //keeping rst for 2 clock cycles
        @(posedge clk);
        @(posedge clk);

        rst = 0; //de-asserting rst

        @(posedge clk);
        $display("Reset de-asserted. Starting random test cases");


        //Generate, apply and check random transactions
        for (i = 0; i < NUM_TRANSACTION; i++) begin 
            //create a new trasaction
            tr = new();
            if (!tr.randomize()) begin 
                $error("Failed to randomize transaction %0d", i);
                $finish;
            end

            //apply stimulus to DUT at the current clock edge
            @(posedge clk);
            valid_instruction <= 1'b1;
            opcode <= tr.opcode;
            operand_a <= tr.operand_a;
            operand_b <= tr.operand_b;
            use_immediate <= tr.use_immediate;
            immediate_value <= tr.immediate_value;

            //store the current transaction in the pipeline queue
            //the transaction at index 0 is the one currently entering S1;
            //the transaction at index 1 is the one whose result is expected at the output
            transaction_in_flight[0] = tr; // store the transaction entering S1

            //pipeline checking: 
            //checks the output of the pipeline for the instruction that was issue 2 cycles ago
            //this is done on the current clock edge, after the DUT's output have settled
            if (transaction_in_flight[1] != null) begin  //checks if there's an instruction that should be at S2 output
                sb.check_results(transaction_in_flight[1], // pass the transaction that was in S1 two cycles ago
                                result_valid,
                                result_out,
                                carry_out,
                                overflow_out,
                                is_zero_out,
                                is_negative_out);
            end 

            //move transaction through the pipeline queue for the next cycle
            //the instruction that was in S1 moves to S2 for the next cycle's check
            transaction_in_flight[1] = transaction_in_flight[0];
            transaction_in_flight[0] = null; //S1 is now empty, ready for the next input

            //periodically de-assert valid_instruction to create idle cycles
            //as it helps test pipeline draining and reset behaviour
            if (i % 50 == 49) begin //every 50 transaction insert a bubble
                @(posedge clk);
                valid_instruction <= 1'b0;
                // Check for idle pipeline outputs after 2 cycles (for the instruction that just moved from S1 to S2)
                if (transaction_in_flight[1] != null) begin 
                    sb.check_results(transaction_in_flight[1], // pass the transaction that was in S1 two cycles ago
                                result_valid,
                                result_out,
                                carry_out,
                                overflow_out,
                                is_zero_out,
                                is_negative_out);
                end
                transaction_in_flight[1] = null; //clear S2
                @(posedge clk); //allow pipeline to fully clear
                @(posedge clk); //another cycle to ensure all ouputs are idle
            end
        end

        $display("\nDraining Pipeline...");
        @(posedge clk);
        valid_instruction <= 1'b0; //ensure no more instructions are issued
        //check remainning instructions in the pipeline
        if (transaction_in_flight[1] != null) begin 
            sb.check_results(transaction_in_flight[1], // pass the transaction that was in S1 two cycles ago
                                result_valid,
                                result_out,
                                carry_out,
                                overflow_out,
                                is_zero_out,
                                is_negative_out);
        end
        transaction_in_flight[1] = null;

        @(posedge clk); //wait for one more cycle for the pipeline to fully clear
        //at this point, result_valid is 0 and other outputs should be 0
        if (result_valid) $error("FAIL: Result valid after pipeline drain!");
        if (result_out !== '0) $error("FAIL: Result not zero after pipeline drain!");
        if (carry_out !== 0) $error("FAIL: Carry not zero after pipeline drain!");
        if (overflow_out !== 0) $error("FAIL: Overflow not zero after pipeline drain!");
        if (is_zero_out !== 0) $error("FAIL: Is_zero not zero after pipeline drain!");
        if (is_negative_out !== 0) $error("FAIL: Is_negative not zero after pipeline drain!");


        $display("\nRandom Testbench finished.");
        $finish; // Terminate simulation
    end
    
endmodule