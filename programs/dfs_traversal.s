# Depth-First Search (DFS) Tree Traversal
# Complete Binary Tree with 7 nodes stored in M[0..6]:
#         10 (node 0)
#        /  \
#     20(1)  30(2)
#     /  \   /  \
#   40   50 60   70 (nodes 3, 4, 5, 6)
# Expected DFS Pre-Order Traversal: 10, 20, 40, 50, 30, 60, 70

# --- 1. Initialize Tree Nodes in RAM M[0..6] ---
addi x1, x0, 10
sw   x1, 0(x0)          # M[0] = Node 0: 10
addi x1, x0, 20
sw   x1, 4(x0)          # M[1] = Node 1: 20
addi x1, x0, 30
sw   x1, 8(x0)          # M[2] = Node 2: 30
addi x1, x0, 40
sw   x1, 12(x0)         # M[3] = Node 3: 40
addi x1, x0, 50
sw   x1, 16(x0)         # M[4] = Node 4: 50
addi x1, x0, 60
sw   x1, 20(x0)         # M[5] = Node 5: 60
addi x1, x0, 70
sw   x1, 24(x0)         # M[6] = Node 6: 70

# --- 2. Initialize Stack in RAM (top of stack at byte 60 = M[15]) ---
addi x2, x0, 60         # x2 = sp (stack pointer) = 60
addi x5, x0, 60         # x5 = stack base (empty when sp == 60)
addi x7, x0, 7          # x7 = total node count (7)
addi x20, x0, 0         # x20 = visit count

# Push Root Node Index 0 to Stack
addi x1, x0, 0
addi x2, x2, -4         # sp -= 4
sw   x1, 0(x2)          # stack[sp] = 0

dfs_loop:
# Check if stack is empty (sp == stack base)
beq  x2, x5, dfs_done

# Pop node from stack: x8 = curr_node
lw   x8, 0(x2)
addi x2, x2, 4          # sp += 4

# Load visited value from tree[curr_node]
add  x9, x8, x8         # curr_node * 2
add  x9, x9, x9         # curr_node * 4
lw   x10, 0(x9)         # x10 = visited node value!

# Record visit count
addi x20, x20, 1        # visit_count++

# In DFS, push RIGHT child first so LEFT child is popped first!
# Right Child: right = 2 * curr_node + 2
add  x13, x8, x8
addi x13, x13, 2
slt  x14, x13, x7
beq  x14, x0, push_left
addi x2,  x2, -4        # sp -= 4
sw   x13, 0(x2)         # push right child

push_left:
# Left Child: left = 2 * curr_node + 1
add  x11, x8, x8
addi x11, x11, 1
slt  x12, x11, x7
beq  x12, x0, next_iter
addi x2,  x2, -4        # sp -= 4
sw   x11, 0(x2)         # push left child

next_iter:
jal  x0, dfs_loop

dfs_done:
# DFS Complete! Store status code 200 into M[7]
addi x1,  x0, 200       # 200 = DFS status code
sw   x1,  28(x0)        # M[7] = 200
addi x31, x0, 1         # CPU DONE FLAG
halt_dfs:
beq  x0,  x0, halt_dfs
