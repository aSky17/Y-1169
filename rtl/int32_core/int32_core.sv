//2 stage pipelined Integer 32-bit ALU core 

`ifndef INT32_CORE_SV
`define INT32_CORE_SV

import parameters::*;
import opcodes::*;

module int32_core(

    //inputs
    input logic clk,
    input logic rst,
    input logic valid_instruction,
    input logic [OPCODE_WIDTH-1:0] opcode,
    input logic [DATA_WIDTH-1:0] operand_a,
    input logic [DATA_WIDTH-1:0] operand_b, 
    input logic use_immediate,
    input logic [DATA_WIDTH-1:0] immediate_value,

    output logic result_valid,
    output logic [DATA_WIDTH-1:0] result_out,
    output logic carry_out, //for unsigned
    output logic overflow_out, //for signed
    output logic is_zero_out, //if result is zero, flag
    output logic is_negative_out //if result is negative, flag
);
    

    logic [DATA_WIDTH-1:0] current_operand_b_comb;

    //selecting operand_b or immediate_value
    always_comb begin
        current_operand_b_comb = use_immediate ? immediate_value : operand_b;
    end

    //pipelining registers
    //Stage-1 registers: Latch inputs from current cycle
    logic valid_instruction_s1_q;
    logic [OPCODE_WIDTH-1:0] opcode_s1_q;
    logic [DATA_WIDTH-1:0] operand_a_s1_q;
    logic [DATA_WIDTH-1:0] current_operand_b_s1_q;

    //Stage-2 registers: Latch results after execution
    logic [DATA_WIDTH-1:0] result_q;
    logic result_valid_q;
    logic carry_q;
    logic overflow_q;
    logic is_zero_q;
    logic is_negative_q;

    always_ff @(posedge clk or posedge rst) begin 
        if (rst) begin
            valid_instruction_s1_q <= 1'b0;
            opcode_s1_q <= '0;
            operand_a_s1_q <= '0;
            current_operand_b_s1_q <= '0;
        end else begin 
            valid_instruction_s1_q <= valid_instruction;
            opcode_s1_q <= opcode;
            operand_a_s1_q <= operand_a;
            current_operand_b_s1_q <= current_operand_b_comb;
        end
    end


    //combinational logic for stage 2
    //wires 
    logic [DATA_WIDTH-1:0] result_s2_comb;
    logic carry_s2_comb;
    logic overflow_s2_comb;
    logic is_zero_s2_comb;
    logic is_negative_s2_comb;

    always_comb begin
        result_s2_comb = '0;
        carry_s2_comb = 1'b0;
        overflow_s2_comb = 1'b0;
        is_zero_s2_comb = 1'b0;
        is_negative_s2_comb = 1'b0;

        if(valid_instruction_s1_q) begin
            //sign casting for stage 1 
            automatic logic signed [DATA_WIDTH-1:0] operand_a_signed_s1_comb = $signed(operand_a_s1_q);
            automatic logic signed [DATA_WIDTH-1:0] current_operand_b_signed_s1_comb = $signed(current_operand_b_s1_q);
            
            case (opcode_s1_q)

            // Arithmetic Operations
                OPCODE_INT_ADD_R, OPCODE_INT_ADD_I: begin
                    // Signed and unsigned sums with one extra bit for carry/overflow detection
                    automatic logic [DATA_WIDTH:0] sum_unsigned = $unsigned(operand_a_s1_q) + $unsigned(current_operand_b_s1_q); // Using _s1_q variables
                    automatic logic signed [DATA_WIDTH:0] sum_signed_extended = operand_a_signed_s1_comb + current_operand_b_signed_s1_comb;

                    result_s2_comb = sum_unsigned[DATA_WIDTH-1:0]; // Result is the lower DATA_WIDTH bits

                    // Overflow for signed add: (sign_A == sign_B) && (sign_A != sign_Result)
                    if ((operand_a_signed_s1_comb[DATA_WIDTH-1] == current_operand_b_signed_s1_comb[DATA_WIDTH-1]) &&
                        (operand_a_signed_s1_comb[DATA_WIDTH-1] != sum_signed_extended[DATA_WIDTH-1])) begin
                        overflow_s2_comb = 1'b1;
                    end
                    carry_s2_comb = sum_unsigned[DATA_WIDTH]; // Carry for unsigned add
                end
                OPCODE_INT_SUB_R, OPCODE_INT_SUB_I: begin
                    // Signed and unsigned differences with one extra bit for borrow/overflow detection
                    automatic logic [DATA_WIDTH:0] diff_unsigned = $unsigned(operand_a_s1_q) - $unsigned(current_operand_b_s1_q); // Using _s1_q variables
                    automatic logic signed [DATA_WIDTH:0] diff_signed_extended = operand_a_signed_s1_comb - current_operand_b_signed_s1_comb;

                    result_s2_comb = diff_unsigned[DATA_WIDTH-1:0]; // Result is the lower DATA_WIDTH bits

                    // Overflow for signed subtract: (sign_A != sign_B) && (sign_A != sign_Result)
                    if ((operand_a_signed_s1_comb[DATA_WIDTH-1] != current_operand_b_signed_s1_comb[DATA_WIDTH-1]) &&
                        (operand_a_signed_s1_comb[DATA_WIDTH-1] != diff_signed_extended[DATA_WIDTH-1])) begin
                        overflow_s2_comb = 1'b1;
                    end
                    carry_s2_comb = diff_unsigned[DATA_WIDTH]; // Borrow for unsigned subtract (MSB of diff_unsigned)
                end
                OPCODE_INT_MUL_R, OPCODE_INT_MUL_I: begin
                    // Signed multiplication produces a 2*DATA_WIDTH bit result
                    automatic logic signed [DATA_WIDTH*2-1:0] product_signed = operand_a_signed_s1_comb * current_operand_b_signed_s1_comb;
                    result_s2_comb = product_signed[DATA_WIDTH-1:0]; // Truncate to DATA_WIDTH bits

                    // Overflow for signed multiply: if upper DATA_WIDTH bits are not sign extension of lower bits
                    if (product_signed[DATA_WIDTH*2-1] == 1'b0) begin // Result is positive
                        if (product_signed[DATA_WIDTH*2-1:DATA_WIDTH] != '0) overflow_s2_comb = 1'b1;
                    end else begin // Result is negative
                        if (product_signed[DATA_WIDTH*2-1:DATA_WIDTH] != {DATA_WIDTH{1'b1}}) overflow_s2_comb = 1'b1;
                    end
                end
                OPCODE_INT_DIV_R: begin
                    if (current_operand_b_s1_q == '0) begin // Using current_operand_b_s1_q
                        result_s2_comb = 'x; // Indicate undefined result for simulation on divide by zero
                        // In real hardware, consider a specific error flag or default value.
                    end else begin
                        result_s2_comb = operand_a_signed_s1_comb / current_operand_b_signed_s1_comb;
                        // Overflow for signed division: MIN_INT / -1 results in positive overflow
                        // e.g., -2147483648 / -1 = 2147483648 (which doesn't fit in 32-bit signed int max 2147483647)
                        if (operand_a_signed_s1_comb == 32'h80000000 && current_operand_b_signed_s1_comb == 32'hFFFFFFFF) begin
                            overflow_s2_comb = 1'b1;
                        end
                    end
                end
                OPCODE_INT_NEG_R: begin
                    result_s2_comb = -operand_a_signed_s1_comb;

                    // Overflow for negation: -MIN_INT results in positive overflow
                    // -(-2147483648) = 2147483648 (not representable in 32-bit signed int)
                    if (operand_a_signed_s1_comb == 32'h80000000) begin
                        overflow_s2_comb = 1'b1;
                    end
                end
                OPCODE_INT_ABS_R: begin
                    result_s2_comb = (operand_a_signed_s1_comb[DATA_WIDTH-1]) ? -operand_a_signed_s1_comb : operand_a_signed_s1_comb;
                    // Overflow for absolute: |MIN_INT| results in positive overflow
                    if (operand_a_signed_s1_comb == 32'h80000000) begin
                        overflow_s2_comb = 1'b1;
                    end
                end

                // Logical Operations
                OPCODE_INT_AND_R: result_s2_comb = operand_a_s1_q & current_operand_b_s1_q; 
                OPCODE_INT_OR_R:  result_s2_comb = operand_a_s1_q | current_operand_b_s1_q; 
                OPCODE_INT_XOR_R: result_s2_comb = operand_a_s1_q ^ current_operand_b_s1_q; 
                OPCODE_INT_NOT_R: result_s2_comb = ~operand_a_s1_q; 
                OPCODE_INT_NOR_R: result_s2_comb = ~(operand_a_s1_q | current_operand_b_s1_q);

                // Shift and Rotate Operations
                // Shift amount is assumed to be in the lower 5 bits for 32-bit data (log2(32) = 5)
                OPCODE_INT_SHL_R: result_s2_comb = operand_a_s1_q << current_operand_b_s1_q[4:0];
                OPCODE_INT_SHR_R: result_s2_comb = operand_a_s1_q >> current_operand_b_s1_q[4:0]; 
                OPCODE_INT_SAR_R: result_s2_comb = operand_a_signed_s1_comb >>> current_operand_b_s1_q[4:0]; 

                OPCODE_INT_ROTL_R: begin // Rotate Left
                    automatic logic [4:0] shift_amount = current_operand_b_s1_q[4:0]; 
                    result_s2_comb = (operand_a_s1_q << shift_amount) | (operand_a_s1_q >> (DATA_WIDTH-shift_amount)); 
                end
                OPCODE_INT_ROTR_R: begin // Rotate Right
                    automatic logic [4:0] shift_amount = current_operand_b_s1_q[4:0]; 
                    result_s2_comb = (operand_a_s1_q >> shift_amount) | (operand_a_s1_q << (DATA_WIDTH-shift_amount)); 
                end

                // Comparison Operations
                OPCODE_INT_EQ_R:   result_s2_comb = (operand_a_s1_q == current_operand_b_s1_q) ? {DATA_WIDTH{1'b1}} : '0; 
                OPCODE_INT_NE_R:   result_s2_comb = (operand_a_s1_q != current_operand_b_s1_q) ? {DATA_WIDTH{1'b1}} : '0; 
                OPCODE_INT_LTS_R:  result_s2_comb = (operand_a_signed_s1_comb < current_operand_b_signed_s1_comb) ? {DATA_WIDTH{1'b1}} : '0;
                OPCODE_INT_LES_R:  result_s2_comb = (operand_a_signed_s1_comb <= current_operand_b_signed_s1_comb) ? {DATA_WIDTH{1'b1}} : '0;
                OPCODE_INT_GTS_R:  result_s2_comb = (operand_a_signed_s1_comb > current_operand_b_signed_s1_comb) ? {DATA_WIDTH{1'b1}} : '0;
                OPCODE_INT_GES_R:  result_s2_comb = (operand_a_signed_s1_comb >= current_operand_b_signed_s1_comb) ? {DATA_WIDTH{1'b1}} : '0;
                OPCODE_INT_LTU_R:  result_s2_comb = ($unsigned(operand_a_s1_q) < $unsigned(current_operand_b_s1_q)) ? {DATA_WIDTH{1'b1}} : '0; 
                OPCODE_INT_LEU_R:  result_s2_comb = ($unsigned(operand_a_s1_q) <= $unsigned(current_operand_b_s1_q)) ? {DATA_WIDTH{1'b1}} : '0; 
                OPCODE_INT_GTU_R:  result_s2_comb = ($unsigned(operand_a_s1_q) > $unsigned(current_operand_b_s1_q)) ? {DATA_WIDTH{1'b1}} : '0;
                OPCODE_INT_GEU_R:  result_s2_comb = ($unsigned(operand_a_s1_q) >= $unsigned(current_operand_b_s1_q)) ? {DATA_WIDTH{1'b1}} : '0; 

                // Min/Max Operations
                OPCODE_INT_MINS_R: result_s2_comb = (operand_a_signed_s1_comb < current_operand_b_signed_s1_comb) ? operand_a_s1_q : current_operand_b_s1_q; 
                OPCODE_INT_MAXS_R: result_s2_comb = (operand_a_signed_s1_comb > current_operand_b_signed_s1_comb) ? operand_a_s1_q : current_operand_b_s1_q; 
                OPCODE_INT_MINU_R: result_s2_comb = ($unsigned(operand_a_s1_q) < $unsigned(current_operand_b_s1_q)) ? operand_a_s1_q : current_operand_b_s1_q; 
                OPCODE_INT_MAXU_R: result_s2_comb = ($unsigned(operand_a_s1_q) > $unsigned(current_operand_b_s1_q)) ? operand_a_s1_q : current_operand_b_s1_q; 

                // Bit Manipulation Operations
                OPCODE_INT_BITREV_R: begin
                    for (int i = 0; i < DATA_WIDTH; i++) begin
                        result_s2_comb[i] = operand_a_s1_q[DATA_WIDTH-1-i]; // Using operand_a_s1_q
                    end
                end

                OPCODE_INT_CLZ_R: begin // Count Leading Zeros
                    automatic int count = 0;
                    for (int i = DATA_WIDTH-1; i >= 0; i--) begin
                        if (operand_a_s1_q[i] == 1'b1) begin // Using operand_a_s1_q
                            break; // Stop counting when first '1' is found
                        end
                        count++;
                    end
                    result_s2_comb = count;
                end

                OPCODE_INT_POPC_R: begin // Population Count (Count Set Bits)
                    automatic int count = 0;
                    for (int i = 0; i < DATA_WIDTH; i++) begin
                        if (operand_a_s1_q[i] == 1'b1) begin // Using operand_a_s1_q
                            count++;
                        end
                    end
                    result_s2_comb = count;
                end

                OPCODE_INT_BYTEREV_R: begin // Byte Reversal (for 32-bit, reverses 4 bytes)
                    for (int i = 0; i < DATA_WIDTH/8; i++) begin // Iterate through bytes
                        for (int j = 0; j < 8; j++) begin // Iterate through bits within each byte
                            result_s2_comb[i*8 + j] = operand_a_s1_q[i*8 + (7-j)]; // Using operand_a_s1_q
                        end
                    end
                end
                OPCODE_INT_BFE_R: begin // Bit Field Extract
                    automatic logic [4:0] bfe_start_bit = current_operand_b_s1_q[4:0]; // Using current_operand_b_s1_q
                    automatic logic [4:0] bfe_length = current_operand_b_s1_q[9:5]; // Length is in bits [9:5] of current_operand_b_s1_q

                    result_s2_comb = '0; // Clear the result register first
                    for (int i = 0; i < bfe_length; i++) begin
                        if ((bfe_start_bit + i) < DATA_WIDTH) begin // Ensure we don't read beyond operand_a_s1_q's width
                            result_s2_comb[i] = operand_a_s1_q[bfe_start_bit + i]; // Using operand_a_s1_q
                        end
                    end
                end

                // Saturated Operations (for signed integers)
                OPCODE_INT_ADDSAT_R: begin
                    automatic logic signed [DATA_WIDTH:0] sum_sat_extended = operand_a_signed_s1_comb + current_operand_b_signed_s1_comb;
                    // Check for signed overflow using classic condition
                    if ((operand_a_signed_s1_comb[DATA_WIDTH-1] == current_operand_b_signed_s1_comb[DATA_WIDTH-1]) && // Signs are the same
                        (operand_a_signed_s1_comb[DATA_WIDTH-1] != sum_sat_extended[DATA_WIDTH-1])) begin // Sign of sum is different
                        overflow_s2_comb = 1'b1;
                        if (operand_a_signed_s1_comb[DATA_WIDTH-1] == 1'b0) begin // Positive overflow, saturate to MAX_INT
                            result_s2_comb = {1'b0, {DATA_WIDTH-1{1'b1}}}; // 32'h7FFFFFFF
                        end else begin // Negative overflow, saturate to MIN_INT
                            result_s2_comb = {1'b1, {DATA_WIDTH-1{1'b0}}}; // 32'h80000000
                        end
                    end else begin
                        result_s2_comb = sum_sat_extended[DATA_WIDTH-1:0]; // No overflow, regular result
                    end
                end

                OPCODE_INT_SUBSAT_R: begin
                    automatic logic signed [DATA_WIDTH:0] diff_sat_extended = operand_a_signed_s1_comb - current_operand_b_signed_s1_comb;
                    // Check for signed overflow using classic condition
                    if ((operand_a_signed_s1_comb[DATA_WIDTH-1] != current_operand_b_signed_s1_comb[DATA_WIDTH-1]) && // Signs are different
                        (operand_a_signed_s1_comb[DATA_WIDTH-1] != diff_sat_extended[DATA_WIDTH-1])) begin // Sign of difference is different from op_a
                        overflow_s2_comb = 1'b1;
                        if (operand_a_signed_s1_comb[DATA_WIDTH-1] == 1'b0) begin // Positive overflow, saturate to MAX_INT
                            result_s2_comb = {1'b0, {DATA_WIDTH-1{1'b1}}}; // 32'h7FFFFFFF
                        end else begin // Negative overflow, saturate to MIN_INT
                            result_s2_comb = {1'b1, {DATA_WIDTH-1{1'b0}}}; // 32'h80000000
                        end
                    end else begin
                        result_s2_comb = diff_sat_extended[DATA_WIDTH-1:0]; // No overflow, regular result
                    end
                end

                // Overflow/Carry Detect Operations (set flags but result is normal wrapped arithmetic)
                OPCODE_INT_ADDCC_R: begin // Add with Carry/Overflow flags set
                    automatic logic [DATA_WIDTH:0] sum_cc_extended = $unsigned(operand_a_s1_q) + $unsigned(current_operand_b_s1_q); // Using _s1_q variables
                    automatic logic signed [DATA_WIDTH:0] sum_signed_cc_extended = operand_a_signed_s1_comb + current_operand_b_signed_s1_comb;
                    result_s2_comb = sum_cc_extended[DATA_WIDTH-1:0];
                    carry_s2_comb = sum_cc_extended[DATA_WIDTH]; // Unsigned carry
                    if ((operand_a_signed_s1_comb[DATA_WIDTH-1] == current_operand_b_signed_s1_comb[DATA_WIDTH-1]) &&
                        (operand_a_signed_s1_comb[DATA_WIDTH-1] != sum_signed_cc_extended[DATA_WIDTH-1])) begin
                        overflow_s2_comb = 1'b1; // Signed overflow
                    end
                end
                OPCODE_INT_SUBCC_R: begin // Subtract with Carry/Overflow flags set
                    automatic logic [DATA_WIDTH:0] diff_cc_extended = $unsigned(operand_a_s1_q) - $unsigned(current_operand_b_s1_q); // Using _s1_q variables
                    automatic logic signed [DATA_WIDTH:0] diff_signed_cc_extended = operand_a_signed_s1_comb - current_operand_b_signed_s1_comb;
                    result_s2_comb = diff_cc_extended[DATA_WIDTH-1:0];
                    carry_s2_comb = diff_cc_extended[DATA_WIDTH]; // Unsigned borrow
                     if ((operand_a_signed_s1_comb[DATA_WIDTH-1] != current_operand_b_signed_s1_comb[DATA_WIDTH-1]) &&
                        (operand_a_signed_s1_comb[DATA_WIDTH-1] != diff_signed_cc_extended[DATA_WIDTH-1])) begin
                        overflow_s2_comb = 1'b1; // Signed overflow
                    end
                end
                OPCODE_INT_MULCC_R: begin // Multiply with Overflow flag set
                    automatic logic signed [DATA_WIDTH*2-1:0] product_extended = operand_a_signed_s1_comb * current_operand_b_signed_s1_comb;
                    result_s2_comb = product_extended[DATA_WIDTH-1:0];
                    // Overflow check for signed multiply (same as regular multiply)
                    if (product_extended[DATA_WIDTH*2-1] == 1'b0) begin // Result is positive
                        if (product_extended[DATA_WIDTH*2-1:DATA_WIDTH] != '0) overflow_s2_comb = 1'b1;
                    end else begin // Result is negative
                        if (product_extended[DATA_WIDTH*2-1:DATA_WIDTH] != {DATA_WIDTH{1'b1}}) overflow_s2_comb = 1'b1;
                    end
                end

                OPCODE_NOP: begin 
                    result_s2_comb = '0;
                    carry_s2_comb = 1'b0;
                    overflow_s2_comb = 1'b0;
                    is_zero_s2_comb = 1'b1;
                    is_negative_s2_comb = 1'b1;
                end

                default: begin 
                    result_s2_comb = '0;
                    carry_s2_comb = 1'b0;
                    overflow_s2_comb = 1'b0;
                    is_zero_s2_comb = 1'b1; // Result is zero for unhandled op
                    is_negative_s2_comb = 1'b0; // Result is not negative
                end
            endcase

            is_zero_s2_comb = (result_s2_comb == '0); // Set if the result is zero
            is_negative_s2_comb = result_s2_comb[DATA_WIDTH-1]; // Set if MSB is 1 (negative for signed)
        end

    end

    //registering
    always_ff @( posedge clk or posedge rst ) begin
        if (rst) begin
            result_valid_q <= 1'b0;
            result_q <= '0;
            carry_q <= 1'b0;
            overflow_q <= 1'b0;
            is_zero_q <= 1'b0;
            is_negative_q <= 1'b0;
        end else begin
            if (valid_instruction_s1_q) begin // Using valid_instruction_s1_q
                result_q <= result_s2_comb;
                result_valid_q <= 1'b1; // Result is valid from this pipeline stage
                carry_q <= carry_s2_comb;
                overflow_q <= overflow_s2_comb;
                is_zero_q <= is_zero_s2_comb;
                is_negative_q <= is_negative_s2_comb;
            end else begin
                // If Stage 1 did NOT have a valid instruction in the previous cycle,
                // then this stage should output an invalid result and clear its registers.
                result_valid_q <= 1'b0;
                result_q <= '0;
                carry_q <= 1'b0;
                overflow_q <= 1'b0;
                is_zero_q <= 1'b0;
                is_negative_q <= 1'b0;
            end
        end
    end


    // Outputs are directly from the stage-2 registers
    assign result_out        = result_q;
    assign result_valid      = result_valid_q;
    assign carry_out         = carry_q;
    assign overflow_out      = overflow_q;
    assign is_zero_out       = is_zero_q;
    assign is_negative_out   = is_negative_q;
endmodule

`endif