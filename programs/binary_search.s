# Binary Search on a sorted 8-element array in Data Memory
# Array at M[0..7]: [2, 5, 8, 12, 16, 23, 38, 56]
# Search Target: 23 (expected found at index 5)

# --- 1. Initialize Array in RAM M[0..7] ---
addi x1, x0, 2
sw   x1, 0(x0)
addi x1, x0, 5
sw   x1, 4(x0)
addi x1, x0, 8
sw   x1, 8(x0)
addi x1, x0, 12
sw   x1, 12(x0)
addi x1, x0, 16
sw   x1, 16(x0)
addi x1, x0, 23
sw   x1, 20(x0)
addi x1, x0, 38
sw   x1, 24(x0)
addi x1, x0, 56
sw   x1, 28(x0)

# --- 2. Setup Search Parameters ---
addi x5, x0, 0          # x5 = low = 0
addi x6, x0, 7          # x6 = high = 7
addi x7, x0, 23         # x7 = search target (23)

search_loop:
# Check if low > high (not found)
slt  x8, x6, x5
bne  x8, x0, not_found

# Compute mid = (low + high) / 2
add  x9, x5, x6         # x9 = sum = low + high
addi x10, x0, 0         # x10 = mid = 0
div_loop:
addi x11, x0, 2
slt  x12, x9, x11       # sum < 2 ?
bne  x12, x0, div_done
addi x9, x9, -2
addi x10, x10, 1
jal  x0, div_loop
div_done:

# Compute byte offset: x13 = mid * 4
add  x13, x10, x10      # mid * 2
add  x13, x13, x13      # mid * 4

# Load element: x14 = mem[mid*4]
lw   x14, 0(x13)

# Check if val == target
sub  x15, x14, x7
beq  x15, x0, found

# Check if val < target
slt  x16, x14, x7
bne  x16, x0, go_right

# Else go left: high = mid - 1
addi x6, x10, -1
jal  x0, search_loop

go_right:
# low = mid + 1
addi x5, x10, 1
jal  x0, search_loop

found:
# Target found at index x10!
sw   x10, 32(x0)        # M[8] = found index (5)
sw   x7,  36(x0)        # M[9] = target value (23)
addi x1,  x0, 1
sw   x1,  40(x0)        # M[10] = status (1 = found)
addi x31, x0, 1         # CPU DONE FLAG
halt_found:
beq  x0,  x0, halt_found

not_found:
addi x1,  x0, -1
sw   x1,  32(x0)        # M[8] = -1
addi x31, x0, 1         # CPU DONE FLAG
halt_not_found:
beq  x0,  x0, halt_not_found
