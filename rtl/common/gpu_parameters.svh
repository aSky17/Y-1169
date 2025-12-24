//gloabl parameters for the GPU architecture

`ifndef GPU_PARAMETERS_SVH
`define GPU_PARAMETERS_SVH

package gpu_parameters;
    parameter DATA_WIDTH = 32;
    parameter OPCODE_WIDTH = 8;
    parameter INSTRUCTION_WIDTH = 64;
    parameter REGISTER_ADDRESS_WIDTH = 14; //physical hardware view. from software programmer view they will have only 64 registers i.e., 6 bits
    parameter PREDICATE_ADDRESS_WIDTH = 7;
    parameter MEMORY_ADDRESS_WIDTH = 32;

    //LO instruction cache of 64KB per processing block
    //64KB = 64 * 1024 bytes = 65536 bytes
    //with INSTRUCTION_WIDTH = 64 bits = 8 bytes per instruction
    //number of instruction = 65536/8 = 8192 instructions
    parameter INSTRUCTION_MEMORY_DEPTH = 8192;
    parameter INSTRUCTION_MEMORY_ADDRESS_WIDTH = 13; //log2(8192) = 13
    
    //test data memory of 4KB
    parameter DATA_MEMORY_DEPTH = 1024; //4KB of test data memory
    parameter DATA_MEMORY_ADDRESS_WIDTH = 10; //log2(1024) = 10

    //register file specific parameters
    parameter NUM_READ_PORTS_RF = 3; //for concurrent read ports e.g., for RS1, RS2, RS3/operand_c
    parameter NUM_WRITE_PORTS_RF = 5; // for concurrent write ports e.g., from INT32, FP32, LSU, Tensor, SFU
endpackage

`endif