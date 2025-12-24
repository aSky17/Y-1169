//common opcodes for the GPU ISA are defined here

`ifndef GPU_OPCODES_SVH
`define GPU_OPCODES_SVH

package gpu_opcodes;
    
    // Integer Arithmetic Operations (0x00 - 0x1F)
    localparam OPCODE_INT_ADD_R   = 8'h01; // ADD (Register-Register)
    localparam OPCODE_INT_SUB_R   = 8'h02; // SUB (Register-Register)
    localparam OPCODE_INT_MUL_R   = 8'h03; // MUL (Register-Register)
    localparam OPCODE_INT_DIV_R   = 8'h04; // DIV (Register-Register) - Signed
    localparam OPCODE_INT_NEG_R   = 8'h05; // NEG (Negate)
    localparam OPCODE_INT_ABS_R   = 8'h06; // ABS (Absolute Value)
    // Added I-type for integer ops
    localparam OPCODE_INT_ADD_I   = 8'h10; // ADD (Register-Immediate)
    localparam OPCODE_INT_SUB_I   = 8'h11; // SUB (Register-Immediate)
    localparam OPCODE_INT_MUL_I   = 8'h12; // MUL (Register-Immediate)

    // Logical Operations (0x20 - 0x2F)
    localparam OPCODE_INT_AND_R   = 8'h20; // AND
    localparam OPCODE_INT_OR_R    = 8'h21; // OR
    localparam OPCODE_INT_XOR_R   = 8'h22; // XOR
    localparam OPCODE_INT_NOT_R   = 8'h23; // NOT
    localparam OPCODE_INT_NOR_R   = 8'h24; // NOR

    // Shift and Rotate Operations (0x30 - 0x3F)
    localparam OPCODE_INT_SHL_R   = 8'h30; // Logical Shift Left
    localparam OPCODE_INT_SHR_R   = 8'h31; // Logical Shift Right
    localparam OPCODE_INT_ROTL_R  = 8'h32; // Rotate Left
    localparam OPCODE_INT_ROTR_R  = 8'h33; // Rotate Right
    localparam OPCODE_INT_SAR_R   = 8'h34; // Arithmetic Shift Right

    // Comparison Operations (0x40 - 0x5F)
    localparam OPCODE_INT_EQ_R    = 8'h40; // Equal
    localparam OPCODE_INT_NE_R    = 8'h41; // Not Equal
    localparam OPCODE_INT_LTS_R   = 8'h42; // Less Than Signed
    localparam OPCODE_INT_LES_R   = 8'h43; // Less Than Equal Signed
    localparam OPCODE_INT_GTS_R   = 8'h44; // Greater Than Signed
    localparam OPCODE_INT_GES_R   = 8'h45; // Greater Than Equal Signed
    localparam OPCODE_INT_LTU_R   = 8'h46; // Less Than Unsigned
    localparam OPCODE_INT_LEU_R   = 8'h47; // Less Than Equal Unsigned
    localparam OPCODE_INT_GTU_R   = 8'h48; // Greater Than Unsigned
    localparam OPCODE_INT_GEU_R   = 8'h49; // Greater Than Equal Unsigned

    // Min/Max Operations (0x60 - 0x6F)
    localparam OPCODE_INT_MINS_R  = 8'h60; // Signed Minimum
    localparam OPCODE_INT_MAXS_R  = 8'h61; // Signed Maximum
    localparam OPCODE_INT_MINU_R  = 8'h62; // Unsigned Minimum
    localparam OPCODE_INT_MAXU_R  = 8'h63; // Unsigned Maximum

    // Bit Manipulation Operations (0x70 - 0x7F)
    localparam OPCODE_INT_BITREV_R= 8'h70; // Bit Reverse
    localparam OPCODE_INT_CLZ_R   = 8'h71; // Count Leading Zeros
    localparam OPCODE_INT_POPC_R  = 8'h72; // Population Count (Count Set Bits)
    localparam OPCODE_INT_BYTEREV_R = 8'h73; // Byte Reverse
    localparam OPCODE_INT_BFE_R   = 8'h74; // Bit Field Extract

    // Saturated Operations (0x80 - 0x8F)
    localparam OPCODE_INT_ADDSAT_R= 8'h80; // Saturated Add
    localparam OPCODE_INT_SUBSAT_R= 8'h81; // Saturated Subtract

    // Overflow/Carry Detect Operations (0x90 - 0x9F)
    localparam OPCODE_INT_ADDCC_R = 8'h90; // Add with Carry Check (Unsigned)
    localparam OPCODE_INT_SUBCC_R = 8'h91; // Subtract with Carry Check (Unsigned)
    localparam OPCODE_INT_MULCC_R = 8'h92; // Multiply with Overflow Check (Signed)
    localparam OPCODE_NOP = 8'h9F;

    // Floating-Point Arithmetic Operations (0xA0 - 0xBF)
    localparam OPCODE_FP_FADD     = 8'hA0; // Floating-Point Add
    localparam OPCODE_FP_FSUB     = 8'hA1; // Floating-Point Subtract
    localparam OPCODE_FP_FMUL     = 8'hA2; // Floating-Point Multiply
    localparam OPCODE_FP_FDIV     = 8'hA3; // Floating-Point Divide
    localparam OPCODE_FP_FNEG     = 8'hA4; // Floating-Point Negate
    localparam OPCODE_FP_FABS     = 8'hA5; // Floating-Point Absolute Value
    localparam OPCODE_FP_FSQRT    = 8'hA6; // Floating-Point Square Root
    localparam OPCODE_FP_FRCP     = 8'hA7; // Floating-Point Reciprocal (1/x)
    localparam OPCODE_FP_FRSQRT   = 8'hA8; // Floating-Point Reciprocal Square Root (1/sqrt(x))
    localparam OPCODE_FP_FMA      = 8'hA9; // Floating-Point Fused Multiply-Add (A*B + C)
    localparam OPCODE_FP_FMIN     = 8'hAA; // Floating-Point Minimum
    localparam OPCODE_FP_FMAX     = 8'hAB; // Floating-Point Maximum

    // Floating-Point Type Conversion Operations (0xAC - 0xAF)
    localparam OPCODE_FP_FTOI     = 8'hAC; // Float to Signed Integer (Truncate)
    localparam OPCODE_FP_ITOF     = 8'hAD; // Signed Integer to Float

    // Floating-Point Comparison Operations (0xB0 - 0xBF)
    localparam OPCODE_FP_FEQ      = 8'hB0; // Equal
    localparam OPCODE_FP_FNE      = 8'hB1; // Not Equal
    localparam OPCODE_FP_FLT      = 8'hB2; // Less Than
    localparam OPCODE_FP_FLE      = 8'hB3; // Less Than or Equal
    localparam OPCODE_FP_FGT      = 8'hB4; // Greater Than
    localparam OPCODE_FP_FGE      = 8'hB5; // Greater Than or Equal

    //memory opcodes:(Range: 0xC0 - 0xDF)
    localparam OPCODE_MEMORY_LOAD = 8'hC0; //load from memory
    localparam OPCODE_MEMORY_STORE = 8'hC1; //store to memory
    // 0xC2 - 0xDF: Reserved for atomic memory ops, different load/store sizes, cache control

    //control flow opcodes: (Range: 0xE0 - 0xEF)
    localparam OPCODE_JMP = 8'hE0; //unconditional jump
    localparam OPCODE_BRANCH_EQ = 8'hE1; //branch if equal
    localparam OPCODE_BRANCH_NE = 8'hE2; //branch if not equal
    localparam OPCODE_CALL = 8'hE3; //function call
    localparam OPCODE_RET = 8'hE4; //return from function
    localparam OPCODE_SYNC = 8'hE5; //synchronization
    // 0xE6 - 0xEF: Reserved for other conditional branches, traps, exceptions

    //system opcodes (Range: 0xF0 - 0xFF)
    localparam OPCODE_SYS_HALT = 8'hF0; //halt the processor
    localparam OPCODE_SYS_CSR_READ = 8'hF1; //read control status register
    localparam OPCODE_SYS_CSR_WRITE = 8'hF2; //write control status register
    // 0xF3 - 0xFF: Reserved for debugging, power management, privileged instructions
    

endpackage

`endif