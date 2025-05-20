`ifndef int32_core
`define int32_core

module int32_core #(
    parameter DATA_WIDTH = 32,
    parameter OPCODE_WIDTH = 8
) (
    //inputs to integer core
    input logic clk,
    input logic rst,
    input logic valid_instruction, //dispatch unit asserts this
    input logic [OPCODE_WIDTH-1:0] opcode, 
    input logic [DATA_WIDTH-1:0] operand_a, //RS1
    input logic [DATA_WIDTH-1:0] operand_b, //RS2, if not immediate
    input logic use_immediate,
    input logic [DATA_WIDTH0-1:0] immediate_value,
    
    //outputs from integer core
    output logic result_valid,
    output logic [DATA_WIDTH-1:0] result_out,
    output logic carry_out,
    output logic overflow_out
);
    
    logic [DATA_WIDTH-1:0] operand_b_final;
    logic [DATA_WIDTH-1:0] operand_a_signed;
    logic [DATA_WIDTH-1:0] operand_b_final_signed;

    //logic to select operand_b or immediate value
    always_comb begin
        if(use_immediate) begin 
            operand_b_final = immediate_value;
        end else begin 
            operand_b_final = operand_b;
        end
    end

    //separate for signed operations
    assign operand_a_signed = $signed(operand_a);
    assign operand_b_final_signed = $signed(operand_b_final);


    always_ff @( posedge clk or posedge rst ) begin
        if (rst) begin 
            result_valid <= 1'b0;
            result_out <= '0;
            carry_out <= 1'b0;
            overflow_out <= 1'b0;
        end else if (valid_instruction) begin 
            //if instruction is processed, then default result is valid
            result_valid <= 1'b1;
            //carry and overflow is 0 unless set by special op
            carry_out <= 1'h0;
            overflow_out <= 1'b0;

            case (opcode)
                
                //arithmetic operations 0x01 to 0x06, 0x07 to 0x1F reserved for future arithmetic extensions
                //ADD
                8'h01: begin 
                    logic [DATA_WIDTH-1:0] sum_extended = operand_a + operand_b_final;
                    result_out <= sum_extended[DATA_WIDTH-1:0];
                end
                //SUB
                8'h02: begin
                    logic diff_extended = operand_a - operand_b_final;
                    result_out <= diff_extended[DATA_WIDTH-1:0];
                end
                //MUL
                8'h03: begin 
                    result_out <= operand_a*operand_b_final;
                end
                //DIV
                8'h04: begin 
                    if(operand_b_final != '0) result_out <= $signed(operand_a) / $signed(operand_b_final);
                    else result_out <= 'x;
                end
                //NEG
                8'h05: begin 
                    result_out <= -operand_a;
                end
                //ABS
                8'h06: begin 
                    result_out <= (operand_a_signed[31] == 1'b1) ? -operand_a_signed : operand_a_signed;
                end

                //Logical Operations 0x20 to 0x24, 0x25 to 0x2F: Reserved for future logical extensions
                //AND
                8'h20: result_out <= operand_a & operand_b_final;
                //OR
                8'h21: result_out <= operand_a | operand_b_final;
                //XOR
                8'h22: result_out <= operand_a ^ operand_b_final;
                //NOT
                8'h23: result_out <= ~operand_a;
                //NOR
                8'h24: result_out <= ~(operand_a | operand_b_final);

                //Shift and rotate operations 0x30 to 0x33, 0x34 - 0x3F: Reserved for future shift/rotate extensions (e.g., ASR - Arithmetic Shift Right, or specific double-precision shifts)
                //shifts are limited to the lower 5 bits
                //SHL(logical left shift): Shifts operand_a to the left by the number of positions specified in the lower 5 bits of operand_b_fina, and 0 are added to the vacant places
                8'h30: result_out <= operand_a << operand_b_final[4:0];
                //SHR(logical right shift)
                8'h31: result_out <= operand_a >> operand_b_final[4:0];
                //ROTL: Bits shifted out on the left are re-introduced on the right.
                8'h32: begin 
                    logic  [4:0] shift_amount = operand_b_final[4:0];
                    result_out <= (operand_a << shift_amount) | (operand_a >> (DATA_WIDTH-shift_amount));
                end
                //ROTR: Bits shifted out on the right are re-introduced on the left.
                8'h33: begin 
                    logic  [4:0] shift_amount = operand_b_final[4:0];
                    result_out <= (operand_a >> shift_amount) | (operand_a << (DATA_WIDTH-shift_amount));
                end

                //Comparison Operations 0x40 to 0x49, 0x4A - 0x5F: Reserved for future comparison extensions (e.g., bitfield comparisons, specialized predicates)
                //EQ
                8'h40: result_out <= (operand_a == operand_b_final) ? {DATA_WIDTH{~1'b0}} : '0; 
                //NE
                8'h41: result_out <= (operand_a != operand_b_final) ? {DATA_WIDTH{~1'b0}} : '0; 
                //LTS
                8'h42: result_out <= (operand_a_signed < operand_b_final_signed) ? {DATA_WIDTH{~1'b0}} : '0; 
                //LES
                8'h43: result_out <= (operand_a_signed <= operand_b_final_signed) ? {DATA_WIDTH{~1'b0}} : '0; 
                //GTS
                8'h44: result_out <= (operand_a_signed > operand_b_final_signed) ? {DATA_WIDTH{~1'b0}} : '0; 
                //GES
                8'h45: result_out <= (operand_a_signed >= operand_b_final_signed) ? {DATA_WIDTH{~1'b0}} : '0; 
                //LTU
                8'h46: result_out <= (operand_a < operand_b_final) ? {DATA_WIDTH{~1'b0}} : '0;
                //LEU
                8'h47: result_out <= (operand_a <= operand_b_final) ? {DATA_WIDTH{~1'b0}} : '0;
                //GTU
                8'h48: result_out <= (operand_a > operand_b_final) ? {DATA_WIDTH{~1'b0}} : '0;
                //GEU
                8'h49: result_out <= (operand_a >= operand_b_final) ? {DATA_WIDTH{~1'b0}} : '0;

                //Min/Max Operations 0x60 to 0x63, 0x64 - 0x6F: Reserved for future min/max or clamp operations
                //MINS
                8'h60: result_out <= (operand_a_signed < operand_b_final_signed) ? operand_a : operand_b_final;
                //MAXS
                8'h61: result_out <= (operand_a_signed > operand_b_final_signed) ? operand_a : operand_b_final;
                //MINU
                8'h62: result_out <= (operand_a < operand_b_final) ? operand_a : operand_b_final;
                //MAXU
                8'h63: result_out <= (operand_a > operand_b_final) ? operand_a : operand_b_final;

                //Bit manipulation operations 0x70 to 0x74, 0x75 - 0x7F: Reserved for future bit manipulation extensions (e.g., BFI - Bit Field Insert, Find First Set/Clear)
                //BITREV: reverses all the bits in operand_a
                8'h70: begin 
                    for (int i = 0; i < DATA_WIDTH; i++) begin 
                        result_out[i] <= operand_a[DATA_WIDTH-1-i];
                    end
                end
                //CLZ: count leading zeroes 
                8'h71: begin
                    result <= '0;
                    for (int i = DATA_WIDTH; i>=0; i--) begin
                        if (operand_a[i] == 1'b1) break;
                        result_out = result_out + 1'b1;
                    end
                end
                //POPC: population count - count set bits
                8'h72: begin 
                    result_out <= '0;
                    for (int i = 0; i< DATA_WIDTH; i++) begin 
                        if (operand_a[i] == 1'b1) result_out <= result_out + 1'b1; 
                    end
                end
                //BREV: BYTE reverse data width divided into bytes, then each byte is reversed
                8'h73: begin 
                    for (int i = 0; i < DATA_WIDTH/8; i++) begin
                        for (int j = 0; j < 8; j++) begin 
                            result_out[i*8 + j] <= operand_a[i*8 + (7-j)];
                        end
                    end
                end
                //BFE: bit field extract, needs start bit and length
                8'h47: begin 
                    //assuming operand_b_final[4:0] is start bit
                    //and operand_b_final[9:5] is length
                    logic bfe_start_bit = operand_b_final[4:0];
                    logic bfe_length = operand_b_final[9:5];
                    result_out <= '0;
                    for (int i = 0; i < bfe_length; i++) begin
                        if ((bfe_start_bit + i) < DATA_WIDTH)
                            result_out <= operand_a[bfe_start_bit+i];
                    end
                end

                //Saturated operations: 0x80 to 0x81, 0x82 - 0x8F: Reserved for future saturated operations (e.g., MUL.SAT)
                //helps in preventing overflow by clipping results to maximum or minimum possible value of wrapping around, useful is DSP and image processing 
                //Normal overflow: 127 + 1 = -128 (wraps around)
                //Saturated overflow: 127 + 1 = 127 (stays at max)
                //ADDSAT
                8'h80: begin
                    logic signed [DATA_WIDTH:0] sum_sat_extended = operand_a_signed + operand_b_final_signed;
                    if ((operand_a_signed > 0 && operand_b_final_signed > 0 && sum_sat_extended[DATA_WIDTH] == 1'b1) || 
                    (operand_a_signed < 0 && operand_b_final_signed < 0 && sum_sat_extended[DATA_WIDTH] == 1'b0)) begin 
                        //overflow detected
                        if (sum_sat_extended[DATA_WIDTH] == 1'b1) //positive overflow
                            result_out <= 32'h7FFF_FFFF; //max signed 32 bit
                        else //negative overflow
                            result_out <= 32'h8000_0000; //min signed 32 bit
                        overflow_out <= 1'b1;
                    end else begin 
                        result_out <= sum_sat_extended[DATA_WIDTH-1:0];
                    end
                end
                //SUBSAT
                8'h81: begin
                    logic signed [DATA_WIDTH:0] diff_sat_extended = operand_a_signed - operand_b_final_signed;
                    if ((operand_a_signed > 0 && operand_b_final_signed < 0 && diff_sat_extended[DATA_WIDTH] == 1'b1) || 
                    (operand_a_signed < 0 && operand_b_final_signed > 0 && diff_sat_extended[DATA_WIDTH] == 1'b0)) begin 
                        //overflow detected
                        if (diff_sat_extended[DATA_WIDTH] == 1'b1) //positive overflow
                            result_out <= 32'h7FFF_FFFF; //max signed 32 bit
                        else //negative overflow
                            result_out <= 32'h8000_0000; //min signed 32 bit
                        overflow_out <= 1'b1;
                    end else begin 
                        result_out <= diff_sat_extended[DATA_WIDTH-1:0];
                    end
                end

                //overflow detect operations 0x90 to 0x92, 0x93 - 0x9F: Reserved for future overflow/carry chain operations
                //ADDCC:unsigned
                8'h90: begin 
                    logic [DATA_WIDTH:0] sum_cc_extended = operand_a + operand_b_final;
                    result_out <= sum_cc_extended[DATA_WIDTH-1:0];
                    carry_out <= sum_cc_extended[DATA_WIDTH];
                end
                //SUBCC:unsigned
                8'h91: begin 
                    logic [DATA_WIDTH:0] diff_cc_extended = operand_a - operand_b_final;
                    result_out <= diff_cc_extended[DATA_WIDTH-1:0];
                    carry_out <= diff_cc_extended[DATA_WIDTH];
                end
                //MULCC:signed
                8'h92: begin 
                    logic signed [DATA_WIDTH*2-1:0] product_extended = operand_a_signed * operand_b_final_signed;
                    result_out <= product_extended[DATA_WIDTH-1:0];

                    if (product_extended[DATA_WIDTH*2-1] == 1'b0) begin // result is positive
                        if (product_extended[DATA_WIDTH*2-1:DATA_WIDTH] != '0) begin //uper bits are not all zero
                            overflow_out <= 1'b1;
                        end
                    end else begin //result is negative
                        if (product_extended[DATA_WIDTH*2-1:DATA_WIDTH] != {DATA_WIDTH{1'b1}}) begin 
                            overflow_out <= 1'b1;
                        end
                    end
                end

                //default case of undefined opcodes
                default: begin 
                    //NOP
                    result_out <= '0;
                    result_valid <= 1'b0; //result is invalid for consumption
                end
            endcase
        end else begin 
            result_valid <= 1'b0;
            carry_out <= 1'b0;
            overflow_out <= 1'b0;
        end
    end

endmodule

`endif