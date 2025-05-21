`ifndef fp32_core
`define fp32_core

module fp32_core #(
    parameter DATA_WIDTH = 32,
    parameter OPCODE_WIDTH = 8
) (

    //inputs
    input logic clk,
    input logic rst,
    input logic valid_instruction,
    input logic [OPCODE_WIDTH-1:0] opcode,
    input logic [DATA_WIDTH-1:0] operand_a,
    input logic [DATA_WIDTH-1:0] operand_b,
    input logic [DATA_WIDTH-1:0] operand_c, //specially for fused multiply-add(FMA)
    input logic use_immediate, //will get from dispatch unit, MODIFIERS
    input logic [DATA_WIDTH-1:0] immediate_value,

    //outputs
    output logic result_valid,
    output logic [DATA_WIDTH-1:0] result_out,
    //outputs for exceptions
    output logic overflow_out, //indicated FP overflow, saturated to infinity
    output logic underflow_out, //indicates FP overflow to zero, i.e., the result was too small and either denormalized or rounded to zero
    output logic nan_out, // indicates not a number (NaN)
    output logic is_zero_out, //result is completely zero
    output logic is_negative_out //result is negative

);

    //internal signals, specially for real type calculations
    logic [DATA_WIDTH-1:0] operand_b_final_bits;
    real operand_a_fp;
    real operand_b_fp;
    real operand_b_final_fp;
    real operant_c_fp;
    real result_fp; //for internal calculations, will be converted to logic once the result is computed

    //logic to select operand_b or immediate_value
    always_comb begin 
        if (use_immediate) begin 
            operand_b_final_bits = immediate_value;
        end else begin 
            operand_b_final_bits = operand_b;
        end
    end

    //casting logic bit inputs to real type
    //$bitstoreal is used, it is IEEE 754 compliant
    assign operand_a_fp = $bitstoreal(operand_a);
    assign operand_b_final_fp = $bitstoreal(operand_b_final_bits);
    assign operant_c_fp = $bitstoreal(operand_c);

    //sequential block for the FP core
    always_ff @(posedge clk or posedge rst) begin 
        if (rst) begin 
            //resest all outputs to default, 0
            result_out <= 0;
            result_valid <= 1'b0;
            overflow_out <= 1'b0;
            underflow_out <= 1'b0;
            nan_out <= 1'b0;
            is_zero_out <= 1'b0;
            is_negative_out <= 1'b0;
            result_fp <= 0.0; //initializing real result to 0.0
        end else if (valid_instruction) begin 
            //default assignments
            result_valid <= 1'b1;
            overflow_out <= 1'b0;
            underflow_out <= 1'b0;
            nan_out <= 1'b0;
            is_zero_out <= 1'b0;
            is_negative_out <= 1'b0;

            //case statement
            case (opcode) 

                //FP: 0xA0 to 0xBF
                //0xB4 - 0xBF: Reserved for future floating-point extensions (e.g., double-precision, transcendentals, more complex conversions, rounding modes).
                
                //FP arithmetic operations: 0xA0 to 0xAB
                //FADD
                8'hA0: result_fp <= operand_a_fp + operand_b_final_fp;
                //FSUB
                8'hA1: result_fp <= operand_a_fp - operand_b_final_fp;
                //FMUL
                8'hA2: result_fp <= operand_a_fp * operand_b_final_fp;
                //FDIV
                8'hA3: result_fp <= operand_a_fp/operand_b_final_fp; //edge case handled at the end
                //FNEG
                8'hA4: result_fp <= -operand_a_fp;
                //FABS
                8'hA5: result_fp <= $fabs(operand_a_fp);
                //FSQRT
                8'hA6: result_fp <= $sqrt(operand_a_fp);
                //FRCP: floating point reciprocal
                8'hA7: result_fp <= 1.0/operand_a_fp;
                //FRSQRT: floating point sqrt of reciprocal
                8'hA8: result_fp <= 1.0/$sqrt(operand_a_fp);
                //FMA
                8'hA9: result_fp <= (operand_a_fp*operand_b_final_fp) + operand_b_fp;
                //FMIN
                8'hAA: result_fp <= (operand_a_fp < operand_b_final_fp) ? operand_a_fp : operand_b_final_fp;
                //FMAX
                8'hAB: result_fp <= (operand_a_fp > operand_b_final_fp) ? operand_a_fp : operand_b_final_fp;
                
                //Type conversion operations: 0xAC to 0xAD
                //FTOI: float to integer
                8'hAC: result_fp <= $rtoi(operand_a_fp);
                //ITOF
                8'hAD: result_fp <= $itor(operand_a);

                //floating point comparison operations 0xAE to 0xB3
                //FEQ
                8'hAE: result_fp <= (operand_a_fp == operand_b_final_fp) ? 1.0 : 0.0;
                //FNE
                8'hAF: result_fp <= (operand_a_fp != operand_b_final_fp) ? 1.0 : 0.0;
                //FLT
                8'hB0: result_fp <= (operand_a_fp < operand_b_final_fp) ? 1.0 : 0.0;
                //FLE
                8'hB1: result_fp <= (operand_a_fp <= operand_b_final_fp) ? 1.0 : 0.0;
                //FGT
                8'hB2: result_fp <= (operand_a_fp > operand_b_final_fp) ? 1.0 : 0.0;
                //FGE
                8'hB3: result_fp <= (operand_a_fp >= operand_b_final_fp) ? 1.0 : 0.0;

                default: begin 
                    result_fp <= 0.0;
                    result_valid <= 1'b0; //no valid operation happened
                end
            endcase

            //determining status flags
            nan_out <= $isnan(result_fp);
            overflow_out <= $isinf(result_fp) && (result_fp>0); //positive infinite indicates overflow
            underflow_out <= $isinf(result_fp) && (result_fp<0); //negative infinite indicates underflow
            is_zero_out <= (result_fp == 0.0);
            is_negative_out <= (result_fp < 0);

            //converting real to logic back
            result_out <= $realtobits(result_fp);
        end else begin //no valid instruction received
            result_out <= '0;
            result_valid <= 1'b0;
            overflow_out <= 1'b0;
            underflow_out <= 1'b0;
            nan_out <= 1'b0;
            is_zero_out <= 1'b0;
            is_negative_out <= 1'b0;
            result_fp <= 0.0; //reseting
        end
    end

endmodule

`endif