# GPU Instruction Set Architecture (ISA) Definition

This document defines the Instruction Set Architecture (ISA) for the custom GPU design. It specifies the format of all 64-bit instruction words, detailing how different fields are interpreted based on the instruction's primary opcode.

## 1. Core Principles

The ISA adheres to the following principles to support a highly parallel, high-performance GPU:

* **Fixed Instruction Length:** All instructions are exactly 64 bits wide. This simplifies instruction fetching and pipeline management.
* **Opcode-Driven Interpretation:** The 8-bit `OPCODE` field is the primary discriminator, determining the instruction's overall category and dictating the interpretation of the remaining fields.
* **Modularity and Extensibility:** Designed with distinct opcode ranges and reserved bits/fields to allow for future expansion (e.g., new instructions, specialized units, increased precision).
* **Thread Parallelism Support:** Includes explicit fields for predication to enable fine-grained, per-thread control within warps.

## 2. Common Instruction Fields (Always Present)

These fields occupy fixed positions in every 64-bit instruction, regardless of the instruction type.

```systemverilog
// Instruction Word Format: 64 bits
//
// 63         56 55      48 47      42 41      36 35      30 29      14 13      10 9       0
// | PRED_ENABLE | PRED_MASK_ID | OPCODE (8-bit) | RD (6-bit) | RS1 (6-bit) | Format Dependent Fields (22-bit) | MODIFIERS (4-bit) | RESERVED (10-bit) |
```

### PRED\_ENABLE (Bit 63, 1 bit):

1: Apply predicate mask. The instruction is executed only by threads whose corresponding bit in the PRED\_MASK\_ID's predicate register is set.

0: No predication. The instruction executes for all currently active threads in the warp.

### PRED\_MASK\_ID (Bits 62:56, 7 bits):

Identifies the predicate register (P0-P127) containing the thread mask for predication.

### OPCODE (Bits 55:48, 8 bits):

The primary discriminator of the instruction's type and function. Its value determines the format for bits \[35:14] and guides the Dispatch Unit to the correct Execution Unit. Refer to `gpu_opcodes.svh` for specific opcode values.

### RD (Bits 47:42, 6 bits):

Destination Register Address. Address of the general-purpose register (R0-R63 for integer/general, F0-F63 for floating-point) where the result of the operation is written.

### RS1 (Bits 41:36, 6 bits):

Source Register 1 Address. Address of the first general-purpose source register.

### MODIFIERS (Bits 13:10, 4 bits):

General flags that refine instruction behavior. Their specific interpretation is context-dependent on the OPCODE.

* **MODIFIERS\[0] (Bit 10):** IMM\_SELECT / SIGNED\_UNSIGNED

  * For ALU ops: 0 = RS2 is register, 1 = RS2 field is part of Immediate.
  * For Comparison/Conversion: 0 = Signed operation, 1 = Unsigned operation.

* **MODIFIERS\[1] (Bit 11):** SATURATE / ROUNDING\_MODE\_BIT0

  * For integer arithmetic: 1 = Enable saturation.
  * For Floating-Point: Can be a bit for rounding mode selection.

* **MODIFIERS\[2] (Bit 12):** SET\_FLAGS / ROUNDING\_MODE\_BIT1

  * For integer/FP arithmetic: 1 = Generate/set condition flags (carry/overflow/NaN/Inf).
  * For Floating-Point: Can be a bit for rounding mode selection.

* **MODIFIERS\[3] (Bit 13):** INVERT\_PREDICATE / SPECIAL\_FLAG

  * For predication: 1 = Invert the predicate mask.
  * For other ops: Can be a specific flag.

### RESERVED (Bits 9:0, 10 bits):

Currently set to 0. Reserved for future instruction-specific flags, extensions, or future instruction formats.
