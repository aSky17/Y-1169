//Integer 32-bit ALU core 

`ifndef INT32_CORE_SV
`define INT32_CORE_SV

module int32_core #(
    import gpu_parameters::*,
    import gpu_opcodes::*
) (

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
    

    logic [DATA_WIDTH-1:0] current_operand_b;

    //selecting operand_b or immediate_value
    always_comb begin
        current_operand_b = use_immediate ? immediate_value : operand_b;
    end

    //internal registers for pipelined output 
    //If the results are not registered -> the output may be read too early, even before computation finishes. Hence buggy bugs
    logic [DATA_WIDTH-1:0] result_reg;
    logic result_valid_reg;
    logic carry_reg;
    logic overflow_reg;
    logic is_zero_reg;
    logic is_negative_reg;


    always_ff @( posedge clk or posedge rst ) begin
        if (rst) begin 
            result_valid_reg <= 1'b0;
            result_reg <= '0;
            carry_reg <= 1'b0;
            overflow_reg <= 1'b0;
            is_zero_reg <= 1'b0;
            is_negative_reg <= 1'b0;
        end else if (valid_instruction) begin 
            logic [DATA_WIDTH-1:0] next_result_val = '0;
            logic next_carry_val = 1'b0;
            logic next_overflow_val = 1'b0;
            logic next_is_zero_val = 1'b0;
            logic next_is_negative_val = 1'b0;

            //sign casting: behavioural modelling
            logic signed [DATA_WIDTH-1:0] operand_a_signed_val = $signed(operand_a);
            logic signed [DATA_WIDTH-1:0] current_operand_b_signed_val = $signed(current_operand_b);

            case(opcode) 
                //arithmetic operations
                OPCODE_INT_ABS_R, OPCODE_INT_ADD_I: begin
                    logic [DATA_WIDTH:0] sum_unsigned =  $unsigned(operand_a) + $unsigned(current_operand_b);
                    logic [DATA_WIDTH:0] sum_signed = operand_a_signed_val + current_operand_b_signed_val;

                    next_result_val = sum_unsigned[DATA_WIDTH-1:0];

                    //overflow for signed: if sign of both the operands are same and sign of one of the operand is different from result
                    if (operand_a_signed_val[DATA_WIDTH-1] == current_operand_b_signed_val[DATA_WIDTH-1] &&
                        operand_a_signed_val[DATA_WIDTH-1] != next_result_val[DATA_WIDTH-1]) begin
                            next_overflow_val = 1'b1;
                    end

                    next_carry_val = sum_unsigned[DATA_WIDTH]; //carry for unsigned
                end
                OPCODE_INT_SUB_R, OPCODE_INT_SUB_I: begin 
                    logic [DATA_WIDTH:0] diff_unsigned = $unsigned(operand_a) - $unsigned(current_operand_b);
                    logic [DATA_WIDTH:0] diff_signed = operand_a_signed_val - current_operand_b_signed_val;

                    next_result_val = diff_unsigned[DATA_WIDTH-1:0];

                    //overflow for signed: if both operand's sign is diff but sign of result is same is operand_b
                    if (operand_a_signed_val[DATA_WIDTH-1] != current_operand_b_signed_val[DATA_WIDTH-1] &&
                        current_operand_b_signed_val[DATA_WIDTH] == next_result_val[DATA_WIDTH-1]) begin 
                            next_overflow_val = 1'b1;
                    end

                    next_carry_val = diff_unsigned[DATA_WIDTH];
                end
                OPCODE_INT_MUL_R, OPCODE_INT_MUL_I: begin 
                    logic [DATA_WIDTH*2-1:0] product_signed = operand_a_signed_val * current_operand_b_signed_val;
                    next_result_val = product_signed[DATA_WIDTH-1:0];

                    //overflow for signed mul: if upper bits are not signed extension of lower bits
                    if (product_signed[DATA_WIDTH*2-1] == 1'b0) begin //result is positive
                        if (product_signed[DATA_WIDTH*2-1:DATA_WIDTH] != '0) next_overflow_val = 1'b1; 
                    end else if (product_signed[DATA_WIDTH*2-1] == 1'b1) begin //result is negative
                        if (product_signed[DATA_WIDTH*2-1:DATA_WIDTH] != {DATA_WIDTH{1'b1}}) next_overflow_val = 1'b1;
                    end
                end
                OPCODE_INT_DIV_R: begin 
                    if (current_operand_b == 1'b0) begin
                        next_result_val = 'x;
                    end else begin 
                        next_result_val = operand_a_signed_val / current_operand_b_signed_val;
                        // Overflow for signed division: MIN_INT / -1 results in positive overflow
                        //-2147483648 / -1 = 2147483648 → doesn't fit in 32-bit signed int (max is 2147483647)
                        if (operand_a_signed_val == 32'h80000000 && current_operand_b_signed_val == 32'hFFFFFFFF) begin
                            next_overflow_val = 1'b1;
                        end
                    end
                end
                OPCODE_INT_NEG_R: begin 
                    next_result_val = -operand_a_signed_val;

                    //-(-2147483648) = 2147483648 → not representable in 32-bit signed int
                    if (operand_a_signed_val = 32'h80000000) begin
                        next_overflow_val = 1'b1;
                    end
                end
                OPCODE_INT_ABS_R: begin 
                    next_result_val = (operand_a_signed_val[DATA_WIDTH-1]) ? -operand_a_signed_val : operand_a_signed_val;
                    if (operand_a_signed_val == 32'h80000000) begin 
                        next_overflow_val = 1'b1;
                    end
                end
                //Logical operations
                OPCODE_INT_AND_R, OPCODE_INT_AND_I: next_result_val = operand_a & current_operand_b;
                OPCODE_INT_OR_R,  OPCODE_INT_OR_I:  next_result_val = operand_a | current_operand_b;
                OPCODE_INT_XOR_R: next_result_val = operand_a ^ current_operand_b;
                OPCODE_INT_NOT_R: next_result_val = ~operand_a;
                OPCODE_INT_NOR_R: next_result_val = ~(operand_a | current_operand_b);

                //Shift and rotate opertions
                //logical shift, assuming shift length is stored in last five bits of current_operand_b
                OPCODE_INT_SHL_R: next_result_val = operand_a << current_operand_b[4:0];
                OPCODE_INT_SHR_R: next_result_val = operand_a >> current_operand_b[4:0];
                // Arithmetic right shift
                OPCODE_INT_SAR_R: next_result_val = operand_a_signed_val >>> current_operand_b[4:0]; 

                OPCODE_INT_ROTL_R: begin
                    logic [4:0] shift_amount = current_operand_b[4:0];
                    next_result_val = (operand_a << shift_amount) | (operand_a >> (DATA_WIDTH-shift_amount));
                end
                OPCODE_INT_ROTR_R: begin
                    logic [4:0] shift_amount = current_operand_b[4:0];
                    next_result_val = (operand_a >> shift_amount) | (operand_a << (DATA_WIDTH-shift_amount));
                end

                //comparison operations
                OPCODE_INT_EQ_R:    next_result_val = (operand_a == current_operand_b) ? {DATA_WIDTH{1'b1}} : '0;
                OPCODE_INT_NE_R:    next_result_val = (operand_a != current_operand_b) ? {DATA_WIDTH{1'b1}} : '0;
                OPCODE_INT_LTS_R:   next_result_val = (operand_a_signed_val < current_operand_b_signed_val) ? {DATA_WIDTH{1'b1}} : '0;
                OPCODE_INT_LES_R:   next_result_val = (operand_a_signed_val <= current_operand_b_signed_val) ? {DATA_WIDTH{1'b1}} : '0;
                OPCODE_INT_GTS_R:   next_result_val = (operand_a_signed_val > current_operand_b_signed_val) ? {DATA_WIDTH{1'b1}} : '0;
                OPCODE_INT_GES_R:   next_result_val = (operand_a_signed_val >= current_operand_b_signed_val) ? {DATA_WIDTH{1'b1}} : '0;
                OPCODE_INT_LTU_R:   next_result_val = ($unsigned(operand_a) < $unsigned(current_operand_b)) ? {DATA_WIDTH{1'b1}} : '0;
                OPCODE_INT_LEU_R:   next_result_val = ($unsigned(operand_a) <= $unsigned(current_operand_b)) ? {DATA_WIDTH{1'b1}} : '0;
                OPCODE_INT_GTU_R:   next_result_val = ($unsigned(operand_a) > $unsigned(current_operand_b)) ? {DATA_WIDTH{1'b1}} : '0;
                OPCODE_INT_GEU_R:   next_result_val = ($unsigned(operand_a) >= $unsigned(current_operand_b)) ? {DATA_WIDTH{1'b1}} : '0;
            
                // Min/Max Operations
                OPCODE_INT_MINS_R:  next_result_val = (operand_a_signed_val < current_operand_b_signed_val) ? operand_a : current_operand_b;
                OPCODE_INT_MAXS_R:  next_result_val = (operand_a_signed_val > current_operand_b_signed_val) ? operand_a : current_operand_b;
                OPCODE_INT_MINU_R:  next_result_val = ($unsigned(operand_a) < $unsigned(current_operand_b)) ? operand_a : current_operand_b;
                OPCODE_INT_MAXU_R:  next_result_val = ($unsigned(operand_a) > $unsigned(current_operand_b)) ? operand_a : current_operand_b;

                //bit manipulation operations
                OPCODE_INT_BIOPCODE_INT_BITREV_R: begin 
                    for (int i = 0;i<DATA_WIDTH;i++) begin 
                        next_result_val[i] = operand_a[DATA_WIDTH-1-i]
                    end
                end
                OPCODE_INT_CLZ_R: begin 
                    int count = 0;
                    for (int i = DATA_WIDTH-1;i>=0;i++) begin 
                        if (operand_a[i] == 1'b1) begin 
                            break;
                        end
                        count++;
                    end
                    next_result_val = count;
                end
                OPCODE_INT_POPC_R: begin 
                    int count = 0;
                    for (int i = 0; i<DATA_WIDTH;i++) begin 
                        if (operand_a[i] == 1'b1) begin 
                            count++;
                        end
                    end
                    next_result_val = count;
                end
                OPCODE_INT_BYTEREV_R: begin 
                    for (int i = 0;i<DATA_WIDTH/8;i++) begin 
                        for (int j = 0;j<8;j++) begin 
                            next_result_val[i*8 + j] = operand_a[i*8 + (7-j)];
                        end
                    end
                end
                OPCODE_INT_BFE_R: begin 
                    logic [4:0] bfe_start_bit = current_operand_b[4:0];
                    logic [4:0] bfe_length = current_operand_b[9:5];

                    next_result_val = '0; //clear the result first
                    for (int i = 0; i < bfe_length;i++) begin 
                        if ((bfe_start_bit+i) < DATA_WIDTH) begin 
                            next_result_val[i] = operand_a[bfe_start_bit+i]; 
                        end
                    end
                end

                // Saturated Operations
                OPCODE_INT_ADDSAT_R: begin
                    logic signed [DATA_WIDTH:0] sum_sat_extended = operand_a_signed_val + current_operand_b_signed_val;
                    if ((operand_a_signed_val > 0 && current_operand_b_signed_val > 0 && sum_sat_extended[DATA_WIDTH] == 1'b1) || // Positive overflow
                        (operand_a_signed_val < 0 && current_operand_b_signed_val < 0 && sum_sat_extended[DATA_WIDTH] == 1'b0)) begin // Negative overflow
                        next_overflow_val = 1'b1;
                        if (sum_sat_extended[DATA_WIDTH] == 1'b1) next_result_val = 32'h7FFFFFFF; // Max signed 32-bit
                        else next_result_val = 32'h80000000; // Min signed 32-bit
                    end else begin
                        next_result_val = sum_sat_extended[DATA_WIDTH-1:0];
                    end
                end
                OPCODE_INT_SUBSAT_R: begin
                    logic signed [DATA_WIDTH:0] diff_sat_extended = operand_a_signed_val - current_operand_b_signed_val;
                    if ((operand_a_signed_val > 0 && current_operand_b_signed_val < 0 && diff_sat_extended[DATA_WIDTH] == 1'b1) || // Positive overflow
                        (operand_a_signed_val < 0 && current_operand_b_signed_val > 0 && diff_sat_extended[DATA_WIDTH] == 1'b0)) begin // Negative overflow
                        next_overflow_val = 1'b1;
                        if (diff_sat_extended[DATA_WIDTH] == 1'b1) next_result_val = 32'h7FFFFFFF; // Max signed 32-bit
                        else next_result_val = 32'h80000000; // Min signed 32-bit
                    end else begin
                        next_result_val = diff_sat_extended[DATA_WIDTH-1:0];
                    end
                end

                // Overflow/Carry Detect Operations (set flags but result is normal wrapped arithmetic)
                OPCODE_INT_ADDCC_R: begin
                    logic [DATA_WIDTH:0] sum_cc_extended = $unsigned(operand_a) + $unsigned(current_operand_b);
                    next_result_val = sum_cc_extended[DATA_WIDTH-1:0];
                    next_carry_val = sum_cc_extended[DATA_WIDTH];
                    // Overflow flag for signed behavior, even if not setting it for unsigned.
                    // For unsigned, 'carry' is the primary flag. If 'overflow_out' is also desired for unsigned,
                    // it would be equivalent to 'carry_out' here.
                end
                OPCODE_INT_SUBCC_R: begin
                    logic [DATA_WIDTH:0] diff_cc_extended = $unsigned(operand_a) - $unsigned(current_operand_b);
                    next_result_val = diff_cc_extended[DATA_WIDTH-1:0];
                    next_carry_val = diff_cc_extended[DATA_WIDTH]; // Borrow
                end
                OPCODE_INT_MULCC_R: begin
                    logic signed [DATA_WIDTH*2-1:0] product_extended = operand_a_signed_val * current_operand_b_signed_val;
                    next_result_val = product_extended[DATA_WIDTH-1:0];
                    if (product_extended[DATA_WIDTH*2-1] == 1'b0) begin // Result is positive
                        if (product_extended[DATA_WIDTH*2-1:DATA_WIDTH] != '0) next_overflow_val = 1'b1;
                    end else begin // Result is negative
                        if (product_extended[DATA_WIDTH*2-1:DATA_WIDTH] != {DATA_WIDTH{1'b1}}) next_overflow_val = 1'b1;
                    end
                end

                default: begin 
                    //NOP
                    result_valid_reg <= 1'b0; //result is invalid for consumption
                    next_result_val = '0;
                    next_carry_val = 1'b0;
                    next_overflow_val = 1'b0;
                end
            endcase

            // Common flag setting for all operations
            next_is_zero_val = (next_result_val == '0); // set this when the result is zero
            // Negative flag based on MSB for signed interpretation, or if it's a comparison result
            next_is_negative_val = next_result_val[DATA_WIDTH-1]; // MSB of the result

            //updating registers for next cycle
            result_reg        <= next_result_val;
            result_valid_reg  <= 1'b1; // Valid if instruction was processed
            carry_reg         <= next_carry_val;
            overflow_reg      <= next_overflow_val;
            is_zero_reg       <= next_is_zero_val;
            is_negative_reg   <= next_is_negative_val;
        end else begin //no valid instruction received
            result_valid_reg  <= 1'b0;
            carry_reg         <= 1'b0;
            overflow_reg      <= 1'b0;
            is_zero_reg       <= 1'b0;
            is_negative_reg   <= 1'b0;
        end
    end

    // Outputs from registers
    assign result_out        = result_reg;
    assign result_valid      = result_valid_reg;
    assign carry_out         = carry_reg;
    assign overflow_out      = overflow_reg;
    assign is_zero_out       = is_zero_reg;
    assign is_negative_out   = is_negative_reg;

endmodule

`endif