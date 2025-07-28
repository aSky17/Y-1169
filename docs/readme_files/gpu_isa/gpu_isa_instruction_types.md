# GPU Instruction Set Architecture: Instruction Types

## Common Fields (Always Present in All 64-bit Instructions)

Regardless of the instruction type, the following fields occupy fixed bit positions:

* **PRED\_ENABLE (Bit 63, 1 bit)**: Control for predication (thread masking).
* **PRED\_MASK\_ID (Bits 62:56, 7 bits)**: Identifies the predicate register.
* **OPCODE (Bits 55:48, 8 bits)**: The main instruction code; determines the instruction type.
* **RD (Bits 47:42, 6 bits)**: Destination Register address (R0-R63 / F0-F63).
* **RS1 (Bits 41:36, 6 bits)**: Source Register 1 address (R0-R63 / F0-F63).
* **MODIFIERS (Bits 13:10, 4 bits)**: General flags (e.g., IMM\_SELECT, SIGNED/UNSIGNED, SATURATE, SET\_FLAGS, INVERT\_PREDICATE).
* **RESERVED (Bits 9:0, 10 bits)**: Reserved for future use.

The remaining 22 bits (Bits 35:14) are the "Format Dependent Fields" and define the instruction type.

---

## Instruction Types Based on OPCODE

### 1. Type A: ALU / General Purpose Register-Based Operations

**Usage**: Integer and Floating-point scalar arithmetic, logical, shift, compare, min/max, bit manipulation.

**OPCODE Ranges**:

* Integer ALU: `0x01–0x1F`
* Floating-Point ALU: `0x90–0xAF`

**Format Dependent Fields (Bits 35:14)**:

```
Bits: 35      30 29      14
      | RS2_OR_IMM_LSB | FUNC_CODE_OR_IMM_MSB |
```

* `MODIFIERS[0] = 0`:

  * RS2\_OR\_IMM\_LSB: RS2 (6-bit address)
  * FUNC\_CODE\_OR\_IMM\_MSB: FUNC\_CODE (16-bit sub-opcode)
* `MODIFIERS[0] = 1`:

  * RS2\_OR\_IMM\_LSB: LSB of immediate
  * FUNC\_CODE\_OR\_IMM\_MSB: MSB of immediate (total 22-bit immediate)

### 2. Type M: Memory Operation Format

**Usage**: Load, Store, Atomic Memory Operations

**OPCODE Range**: `0x20–0x2F`

**Format Dependent Fields (Bits 35:14)**:

```
Bits: 35      30 29      14
      | BASE_REG_OR_INDEX | OFFSET_IMM_OR_MEM_MODS |
```

* BASE\_REG\_OR\_INDEX (6-bit)
* OFFSET\_IMM\_OR\_MEM\_MODS (16-bit signed offset or memory modifier bits)

### 3. Type C: Control Flow Format

**Usage**: Conditional Branches, Jumps, Calls, Returns

**OPCODE Range**: `0x40–0x4F`

**Format Dependent Fields (Bits 35:14)**:

```
Bits: 35      14
      | TARGET_OFFSET_OR_ADDR (22-bit) |
```

* RS1: Could hold flags or base register for indirect jumps.
* TARGET\_OFFSET\_OR\_ADDR: Signed PC-relative offset or absolute address.

### 4. Type S: Specialized Unit Operation Format

**Usage**: Tensor Cores, Ray Tracing Cores, Special Function Units (SFU)

**OPCODE Ranges**:

* SFU: `0x50–0x5F`
* Tensor: `0x60–0x7F`
* RT Core: `0x80–0x8F`

**Format Dependent Fields (Bits 35:14)**:

```
Bits: 35      30 29      14
      | RS2_OR_SPEC_INPUTS | UNIT_SPECIFIC_CTRL |
```

* RS2\_OR\_SPEC\_INPUTS: RS2 or unit-specific parameters
* UNIT\_SPECIFIC\_CTRL: 16-bit control for SFU/Matrix/RT operations

### 5. Type D: Data Movement / Predicate / Miscellaneous

**Usage**: MOV, predicate operations, load large immediates

**OPCODE Range**: `0xC0–0xDF`

**Format Dependent Fields (Bits 35:14)**:

```
Bits: 35      14
      | SOURCE_OR_LARGE_IMM (22-bit) |
```

* RS1: Source register for MOV
* SOURCE\_OR\_LARGE\_IMM: 22-bit signed immediate or RS2/predicate address

### 6. Reserved Opcode Ranges

**Range**: `0xE0–0xFF`

Reserved for:

* FP64 extensions
* Atomic memory ops
* Synchronization
* Debug features
* New Execution Units

---

This instruction set design ensures flexibility, scalability, and alignment with future GPU architectural advancements.
