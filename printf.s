.intel_syntax noprefix
.global _start


_start:
    # ============================================================
    # KHỞI TẠO
    #
    # rsp:
    # [rsp + 16] = argv[1] = format string
    # [rsp + 24] = argv[2]
    # [rsp + 32] = argv[3]
    # ...
    #
    # r12 = con trỏ đang scan format string
    # r13 = con trỏ tới argv argument tiếp theo
    # ============================================================

    mov r12, [rsp + 16]       # r12 = địa chỉ argv[1] (format string)
    lea r13, [rsp + 24]       # r13 = địa chỉ ô argv[2]


loop:
    # ============================================================
    # KIỂM TRA KẾT THÚC FORMAT STRING
    #
    # [r12] = ký tự hiện tại
    # '\0' = 0 → kết thúc chuỗi
    # ============================================================

    cmp byte ptr [r12], 0
    je .ret


    # ============================================================
    # KIỂM TRA BACKSLASH '\'
    #
    # ASCII:
    # '\' = 92
    #
    # Nếu gặp '\' → xử lý:
    #   \\     → \
    #   \n     → newline
    #   \xNN   → byte hex
    # ============================================================

    cmp byte ptr [r12], 92
    je .backslash


    # ============================================================
    # KIỂM TRA '%'
    #
    # ASCII:
    # '%' = 37
    #
    # Nếu gặp '%' → xử lý:
    #   %% → %
    #   %d → số nguyên
    #   %s → chuỗi
    # ============================================================

    cmp byte ptr [r12], 37
    je .percent


    # ============================================================
    # KÝ TỰ BÌNH THƯỜNG
    #
    # write(1, r12, 1)
    #
    # rax = 1  → syscall write
    # rdi = 1  → stdout
    # rsi = r12 → địa chỉ ký tự cần in
    # rdx = 1  → in 1 byte
    # ============================================================

.normal:
    mov rax, 1
    mov rdi, 1
    mov rsi, r12
    mov rdx, 1
    syscall

    inc r12                   # sang ký tự tiếp theo
    jmp loop



# ================================================================
# XỬ LÝ BACKSLASH
#
# Khi [r12] = '\'
#
# Kiểm tra ký tự phía sau:
#
#   [r12+1] = '\' → \\
#   [r12+1] = 'n' → \n
#   [r12+1] = 'x' → \xNN
# ================================================================

.backslash:

    cmp byte ptr [r12 + 1], 92
    je .double_backslash


    cmp byte ptr [r12 + 1], 'n'
    je .newline


    cmp byte ptr [r12 + 1], 'x'
    je .hex_escape


    # Không phải escape hợp lệ
    # → coi '\' như ký tự bình thường

    jmp .normal



# ================================================================
# hex_digit
#
# INPUT:
#   AL = ASCII của 1 ký tự hex
#
# OUTPUT:
#   AL = giá trị số từ 0 → 15
#
# Ví dụ:
#
#   '0' → 0
#   '4' → 4
#   '9' → 9
#   'a' → 10
#   'f' → 15
#   'A' → 10
#   'F' → 15
#
# ================================================================

hex_digit:

    # ------------------------------------------------------------
    # KIỂM TRA 0-9
    #
    # cmp A, B:
    #   so sánh A với B
    #
    # jb:
    #   A < B → jump
    #
    # jbe:
    #   A <= B → jump
    # ------------------------------------------------------------

    cmp al, '0'
    jb .check_lower

    cmp al, '9'
    jbe .number


.check_lower:

    # ------------------------------------------------------------
    # KIỂM TRA a-f
    #
    # Nếu AL < 'a' → đi kiểm tra A-F
    # Nếu AL <= 'f' → đây là a-f
    # ------------------------------------------------------------

    cmp al, 'a'
    jb .check_upper

    cmp al, 'f'
    jbe .lower


.check_upper:

    # ------------------------------------------------------------
    # KIỂM TRA A-F
    #
    # 'A' → 10
    # 'B' → 11
    # ...
    # 'F' → 15
    #
    # Công thức:
    #
    #   AL - 'A' + 10
    #
    # Ví dụ:
    #
    #   'C' - 'A' = 2
    #   2 + 10 = 12
    # ------------------------------------------------------------

    sub al, 'A'
    add al, 10
    ret


.number:

    # ------------------------------------------------------------
    # AL đang là '0'...'9'
    #
    # Chuyển ASCII thành số:
    #
    # '4' - '0' = 4
    # ------------------------------------------------------------

    sub al, '0'
    ret


.lower:

    # ------------------------------------------------------------
    # AL đang là 'a'...'f'
    #
    # Chuyển:
    #
    # 'a' → 10
    # 'b' → 11
    # ...
    # 'f' → 15
    # ------------------------------------------------------------

    sub al, 'a'
    add al, 10
    ret



# ================================================================
# XỬ LÝ \xNN
#
# Ví dụ:
#
#   format = "\x4a"
#
# Bộ nhớ:
#
#   r12+0 = '\'
#   r12+1 = 'x'
#   r12+2 = '4'
#   r12+3 = 'a'
#
# Mục tiêu:
#
#   '4' → 4
#   'a' → 10
#
#   (4 << 4) | 10
#   = 0x4a
#
# ================================================================

.hex_escape:

    # ------------------------------------------------------------
    # LẤY HEX DIGIT THỨ NHẤT
    # ------------------------------------------------------------

    mov al, byte ptr [r12 + 2]    # AL = ASCII hex thứ nhất
    call hex_digit                # AL = giá trị 0..15


    # ------------------------------------------------------------
    # Đưa nibble thứ nhất lên 4 bit cao
    #
    # Ví dụ:
    #
    #   4 = 0000 0100
    #
    #   4 << 4
    #       ↓
    #   0100 0000 = 0x40
    # ------------------------------------------------------------

    shl al, 4

    mov r8b, al                   # lưu nibble cao vào r8b


    # ------------------------------------------------------------
    # LẤY HEX DIGIT THỨ HAI
    # ------------------------------------------------------------

    mov al, byte ptr [r12 + 3]    # AL = ASCII hex thứ hai
    call hex_digit                # AL = giá trị 0..15


    # ------------------------------------------------------------
    # GHÉP 2 NIBBLE
    #
    # Ví dụ:
    #
    #   r8b = 0x40
    #   AL  = 0x0a
    #
    #   0x40 | 0x0a
    #   = 0x4a
    # ------------------------------------------------------------

    or al, r8b


    # ============================================================
    # LƯU BYTE VÀO STACK
    #
    # AL chứa byte cần output.
    #
    # write() cần:
    #   RSI = ĐỊA CHỈ dữ liệu
    #
    # nên phải lưu AL vào memory trước.
    # ============================================================

    sub rsp, 1                    # dành 1 byte trên stack
    mov byte ptr [rsp], al        # [rsp] = byte cần in


    # ============================================================
    # WRITE BYTE
    #
    # write(1, rsp, 1)
    #
    # rax = 1 → write
    # rdi = 1 → stdout
    # rsi = rsp → địa chỉ byte
    # rdx = 1 → 1 byte
    # ============================================================

    mov rax, 1
    mov rdi, 1
    mov rsi, rsp
    mov rdx, 1
    syscall


    # Trả lại stack
    add rsp, 1

    # \xNN gồm 4 byte:
    #
    #   \ x N N
    #
    # nên bỏ qua 4 byte

    add r12, 4
    jmp loop



# ================================================================
# XỬ LÝ \\
#
# Input:
#
#   "\\"
#
# Output:
#
#   "\"
#
# Chỉ write byte đầu tiên rồi bỏ qua cả 2 byte input.
# ================================================================

.double_backslash:

    mov rax, 1
    mov rdi, 1
    mov rsi, r12
    mov rdx, 1
    syscall

    add r12, 2                   # bỏ qua "\\"
    jmp loop



# ================================================================
# XỬ LÝ \n
#
# Input:
#
#   "\n"
#
# Output:
#
#   newline = 0x0a
#
# ================================================================

.newline:

    mov rax, 1
    mov rdi, 1

    # rsi = địa chỉ byte newline
    lea rsi, [rip + newline]

    mov rdx, 1
    syscall

    add r12, 2                   # bỏ qua "\n"
    jmp loop



# ================================================================
# XỬ LÝ '%'
#
# Kiểm tra:
#
#   %% → %
#   %d → số nguyên
#   %s → chuỗi
# ================================================================

.percent:

    # %% ?
    cmp byte ptr [r12 + 1], 37
    je .double_percent


    # %d ?
    cmp byte ptr [r12 + 1], 'd'
    je .decimal_makers


    # %s ?
    cmp byte ptr [r12 + 1], 's'
    je .string_makers


    # Không phải syntax đã biết
    jmp .normal



# ================================================================
# %s
#
# argv[2], argv[3], ... là chuỗi.
#
# r13 = địa chỉ ô argv hiện tại
#
# [r13] = địa chỉ chuỗi
#
# Ví dụ:
#
# r13 → argv[2]
#        ↓
#        "hacker"
#
# ================================================================

.string_makers:

    # strlen cần:
    # rdi = địa chỉ chuỗi

    mov rdi, [r13]

    call strlen

    # strlen trả:
    # rax = length

    mov rdx, rax                  # write cần rdx = length


    # ------------------------------------------------------------
    # write(1, string, length)
    # ------------------------------------------------------------

    mov rax, 1
    mov rdi, 1
    mov rsi, [r13]                # địa chỉ argv hiện tại
    syscall


    # Đã sử dụng argv hiện tại
    # → chuyển sang argv tiếp theo

    add r13, 8

    # Bỏ qua "%s"
    add r12, 2

    jmp loop



# ================================================================
# strlen
#
# INPUT:
#   RDI = địa chỉ chuỗi
#
# OUTPUT:
#   RAX = độ dài chuỗi
#
# Ví dụ:
#
#   "hello\0"
#
#   h e l l o \0
#   0 1 2 3 4 5
#
#   RAX = 5
# ================================================================

strlen:

    xor rax, rax                  # rax = 0 = length


strlen_loop:

    # Kiểm tra ký tự hiện tại
    #
    # [rdi + rax]
    # = ký tự thứ rax của chuỗi

    cmp byte ptr [rdi + rax], 0
    je strlen_done


    inc rax                       # length++

    jmp strlen_loop


strlen_done:
    ret



# ================================================================
# %%
#
# Input:
#
#   "%%"
#
# Output:
#
#   "%"
#
# Chỉ write byte đầu tiên.
# ================================================================

.double_percent:

    mov rax, 1
    mov rdi, 1
    mov rsi, r12
    mov rdx, 1
    syscall

    add r12, 2                    # bỏ qua "%%"
    jmp loop



# ================================================================
# %d
#
# argv hiện tại là một chuỗi số.
#
# Ví dụ:
#
# argv[2] = "-42"
#
# r13 → argv[2]
#        ↓
#       "-42"
#
# atoi:
#
# "-42" → -42
#
# sau đó itoa:
#
# -42 → "-42"
#
# rồi write ra màn hình.
# ================================================================

.decimal_makers:

    # ------------------------------------------------------------
    # Lấy argv hiện tại
    # ------------------------------------------------------------

    mov rdi, [r13]

    # atoi:
    #
    # rdi = chuỗi
    # rax = số nguyên

    call atoi


    # ------------------------------------------------------------
    # TẠO BUFFER CHO ITOA
    #
    # itoa sẽ ghi số từ cuối buffer đi ngược lên.
    #
    # sub rsp, 32
    # → dành 32 byte trên stack.
    # ------------------------------------------------------------

    sub rsp, 32


    # rdi = số nguyên cần convert
    mov rdi, rax


    # rsi = cuối buffer
    #
    # [rsp, rsp+32)
    #
    # byte cuối cùng là rsp+31
    # nên rsi = rsp+32 là vị trí "sau cuối buffer".
    #
    # itoa sẽ:
    #
    #   dec rsi
    #   ghi ký tự
    #
    lea rsi, [rsp + 32]

    call itoa


    # ------------------------------------------------------------
    # ITOA TRẢ:
    #
    # rsi = địa chỉ đầu chuỗi
    # rax = độ dài
    #
    # write(1, rsi, rax)
    # ------------------------------------------------------------

    mov rdx, rax                  # length

    mov rax, 1                    # write
    mov rdi, 1                    # stdout

    # rsi vẫn đang chứa địa chỉ đầu chuỗi
    syscall


    # Trả lại stack
    add rsp, 32


    # Đã sử dụng argv hiện tại
    add r13, 8

    # Bỏ qua "%d"
    add r12, 2

    jmp loop



# ================================================================
# KẾT THÚC CHƯƠNG TRÌNH
# ================================================================

.ret:

    mov rax, 60                   # syscall exit
    mov rdi, 0                    # exit status = 0
    syscall



# ================================================================
# NEWLINE BYTE
#
# .byte 10 = tạo 1 byte có giá trị 10 = 0x0a
# ================================================================

newline:
    .byte 10



################################################################
#                              atoi
################################################################
#
# INPUT:
#   RDI = pointer tới chuỗi số
#
# OUTPUT:
#   RAX = số nguyên
#
# Ví dụ:
#
#   "123"  → 123
#   "-42"  → -42
#   "0"    → 0
#
################################################################

atoi:

    # rax = kết quả
    xor rax, rax


    # r10:
    #
    # 0 = số dương
    # 1 = số âm

    xor r10, r10


    # Kiểm tra ký tự đầu tiên có phải '-' không

    cmp byte ptr [rdi], '-'
    jne loop_atoi


    # Nếu âm

    mov r10, 1
    inc rdi                       # bỏ qua '-'


loop_atoi:

    # Đọc 1 ký tự
    #
    # movzx:
    # lấy byte rồi mở rộng thành 32-bit

    movzx ecx, byte ptr [rdi]


    # '\0' → kết thúc chuỗi

    test cl, cl
    jz atoi_end


    # Kiểm tra < '0'

    cmp cl, '0'
    jb atoi_end


    # Kiểm tra > '9'

    cmp cl, '9'
    ja atoi_end


    # ------------------------------------------------------------
    # result = result * 10
    # ------------------------------------------------------------

    imul rax, 10


    # ASCII → số
    #
    # '7' - '0' = 7

    sub cl, '0'


    # result += digit

    add rax, rcx


    # sang ký tự tiếp theo

    inc rdi

    jmp loop_atoi



atoi_end:

    # Nếu r10 = 1 → số âm

    test r10, r10
    jz atoi_ret

    neg rax


atoi_ret:
    ret



################################################################
#                              itoa
################################################################
#
# INPUT:
#   RDI = số nguyên
#   RSI = cuối buffer
#
# OUTPUT:
#   RSI = địa chỉ đầu chuỗi
#   RAX = độ dài chuỗi
#
# Ví dụ:
#
#   123 → "123"
#   -42 → "-42"
#   0   → "0"
#
################################################################

itoa:

    # r8 = length
    xor r8, r8


    # ============================================================
    # KIỂM TRA SỐ ÂM
    # ============================================================

    test rdi, rdi
    jns itoa_positive


    # số âm

    mov r10, 1

    # đổi thành số dương để chia
    neg rdi

    jmp itoa_convert


itoa_positive:

    # số dương
    xor r10, r10



itoa_convert:

    # ============================================================
    # TRƯỜNG HỢP SỐ 0
    # ============================================================

    test rdi, rdi
    jnz itoa_loop


    # Buffer tăng từ phải sang trái
    #
    # dec rsi
    # rồi ghi '0'

    dec rsi
    mov byte ptr [rsi], '0'

    mov rax, 1

    ret



itoa_loop:

    # ============================================================
    # CHIA CHO 10
    #
    # rax = quotient
    # rdx = remainder
    #
    # Ví dụ:
    #
    # 123 / 10
    #
    # quotient  = 12
    # remainder = 3
    # ============================================================

    mov rax, rdi
    xor rdx, rdx

    mov rcx, 10

    div rcx


    # ============================================================
    # REMAINDER → ASCII
    #
    # remainder = 3
    #
    # '0' + 3 = '3'
    # ============================================================

    add dl, '0'


    # Buffer đi ngược từ phải sang trái

    dec rsi

    mov byte ptr [rsi], dl

    inc r8                         # length++


    # ============================================================
    # QUOTIENT
    #
    # rdi = quotient
    #
    # Nếu quotient != 0:
    # tiếp tục chia.
    # ============================================================

    mov rdi, rax

    test rdi, rdi
    jnz itoa_loop


    # ============================================================
    # THÊM '-' NẾU SỐ BAN ĐẦU ÂM
    # ============================================================

    test r10, r10
    jz itoa_done


    dec rsi
    mov byte ptr [rsi], '-'

    inc r8


itoa_done:

    # trả về length

    mov rax, r8

    ret
