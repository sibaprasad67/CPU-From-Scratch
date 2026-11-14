# Breadth-First Search (BFS) Tree Traversal
# Complete Binary Tree with 7 nodes stored in M[0..6]:
#         10 (node 0)
#        /  \
#     20(1)  30(2)
#     /  \   /  \
#   40   50 60   70 (nodes 3, 4, 5, 6)
# Expected BFS Level-Order Traversal: 10, 20, 30, 40, 50, 60, 70

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

# --- 2. Initialize Queue in RAM M[8..15] (bytes 32..60) ---
addi x5, x0, 32         # x5 = head_ptr = byte 32
addi x6, x0, 32         # x6 = tail_ptr = byte 32
addi x7, x0, 7          # x7 = total node count (7)
addi x20, x0, 0         # x20 = traversal visit count

# Enqueue Root (Node Index 0)
addi x1, x0, 0
sw   x1, 0(x6)
addi x6, x6, 4          # tail_ptr += 4

bfs_loop:
# Check if queue empty (head == tail)
beq  x5, x6, bfs_done

# Dequeue node index: x8 = curr_node
lw   x8, 0(x5)
addi x5, x5, 4          # head_ptr += 4

# Load node value: val = tree[curr_node]
add  x9, x8, x8         # curr_node * 2
add  x9, x9, x9         # curr_node * 4 (byte address)
lw   x10, 0(x9)         # x10 = visited node value!

# Record visit in register x21..x27 for display
addi x20, x20, 1        # visit_count++

# Calculate Left Child: left = 2 * curr_node + 1
add  x11, x8, x8        # 2 * curr
addi x11, x11, 1        # left_idx

# If left < 7, enqueue left
slt  x12, x11, x7
beq  x12, x0, check_right
sw   x11, 0(x6)
addi x6, x6, 4          # tail++

check_right:
# Calculate Right Child: right = 2 * curr_node + 2
add  x13, x8, x8        # 2 * curr
addi x13, x13, 2        # right_idx

# If right < 7, enqueue right
slt  x14, x13, x7
beq  x14, x0, next_iter
sw   x13, 0(x6)
addi x6, x6, 4          # tail++

next_iter:
jal  x0, bfs_loop

bfs_done:
# BFS Complete! Store success flag into M[7]
addi x1,  x0, 100       # 100 = BFS status code
sw   x1,  28(x0)        # M[7] = 100
addi x31, x0, 1         # CPU DONE FLAG
halt_bfs:
beq  x0,  x0, halt_bfs
