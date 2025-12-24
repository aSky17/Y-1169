# Y-1169: Arithmetic Execution Engine
# Integer and Floating-Point Execution Core

Y-1169 is a modular **32-bit arithmetic execution engine** comprising a high-performance **integer execution core** and an **IEEE-754 compliant single-precision floating-point (FP32) core**.

The repository contains RTL implementations of arithmetic, logical, and floating-point functional units with explicit pipelining and well-defined datapaths.

---

## Integer Execution Core

The integer core provides synchronous 32-bit integer computation logic.

### Supported operations
- Arithmetic: add, subtract, multiply, divide
- Unary operations: negate, absolute value
- Logical: and, or, xor, not
- Shifts: logical and arithmetic shifts
- Comparisons: signed and unsigned
- Bit operations: population count, leading zero count, bit reverse, byte reverse
- Saturation and overflow-detect arithmetic variants

The integer units are implemented as standalone execution blocks and require external control and operand sourcing.

---

## Floating-Point Execution Core (FP32)

The floating-point core implements IEEE-754 single-precision arithmetic.

Each operation is implemented as a **separately pipelined functional unit** with explicit stage boundaries.

### Implemented FP units
- Floating-point add and subtract
- Floating-point multiply
- Floating-point divide
- Fused multiply-add (FMA)
- Floating-point compare
- Min / max
- Absolute value and negate
- Integer <--> floating-point conversion

### FP implementation details
- IEEE-754 compliant handling of NaN, infinity, zero, and denormals
- Guard, round, and sticky (GRS) based rounding
- Round-to-nearest-even mode
- Explicit normalization and exponent adjustment logic
- Multi-stage pipelined datapaths

---

## Design Characteristics

- RTL written in SystemVerilog
- Fixed 32-bit data width
- Explicit pipeline stage separation

---

## Verification

Verification is performed at the module level.

- Directed and constrained tests for integer operations
- Bit-accurate checking of floating-point results against IEEE-754 reference behavior
- Validation of pipeline latency, rounding behavior, and special cases

Verification infrastructure is developed alongside RTL.

