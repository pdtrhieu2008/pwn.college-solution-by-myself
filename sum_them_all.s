.intel_syntax noprefix          # Dùng cú pháp Intel thay vì AT&T
.global _start                  # Export nhãn _start để linker biết entry point


_start:
    mov r12, [rsp]              # r12 = argc
                                # [rsp] chứa argc khi chương trình vừa bắt đầu

    mov r13, 1                  # r13 = 1
                                # Bắt đầu duyệt argv từ argv[1]
                                # argv[0] là tên chương trình nên bỏ qua

    xor r14, r14                # r14 = 0
                                # r14 sẽ dùng để lưu TỔNG các số

    cmp r13, r12                # So sánh i với argc
                                # Kiểm tra xem còn argument nào không

    jge loop_done               # Nếu r13 >= argc thì không còn argument
                                # → nhảy tới phần chuyển tổng thành chuỗi


loop:
    mov rdi, [rsp + 8 + r13*8]  # rdi = argv[r13]
                                # Mỗi phần tử argv là một con trỏ 8 byte
                                # argv[0] = [rsp + 8]
                                # argv[1] = [rsp + 16]
                                # argv[2] = [rsp + 24]
                                # ...

    call atoi                   # Gọi hàm atoi
                                # rdi = con trỏ tới chuỗi cần chuyển
                                # Sau khi return:
                                # rax = giá trị số nguyên

    add r14, rax                # r14 += rax
                                # Cộng số vừa chuyển vào tổng

    inc r13                     # i++
                                # Chuyển sang argv tiếp theo

    cmp r13, r12                # So sánh i với argc

    jl loop                     # Nếu i < argc thì tiếp tục vòng lặp


loop_done:
    sub rsp, 32                 # rsp -= 32
                                # Cấp 32 byte trên stack làm buffer tạm
                                # Buffer này dùng để chứa chuỗi kết quả


    mov rdi, r14                # rdi = tổng
                                # Đưa tổng vào argument thứ nhất của itoa
                                # itoa(r14, ...)


    lea rsi, [rsp + 32]         # rsi = địa chỉ cuối buffer
                                # itoa sẽ ghi chuỗi từ cuối buffer đi ngược lên
                                #
                                # Ví dụ:
                                # buffer: [................]
                                #                  ^
                                #                 rsi
                                #
                                # Các chữ số sẽ được ghi từ phải sang trái


    call itoa                    # Gọi itoa
                                 # Chuyển số nguyên rdi thành chuỗi
                                 #
                                 # Sau khi return:
                                 # rax = số byte của chuỗi


    mov rdx, rax                 # rdx = length
                                 # write() cần biết số byte cần ghi


    lea rsi, [rsp + 32]          # rsi = cuối buffer
                                  # Lấy lại địa chỉ cuối buffer


    sub rsi, rdx                 # rsi = rsi - length
                                  # Tính ra địa chỉ bắt đầu của chuỗi
                                  #
                                  # Ví dụ itoa tạo:
                                  #       "12345"
                                  #                ^
                                  #              cuối
                                  #
                                  # length = 5
                                  # rsi = cuối - 5
                                  #       ↓
                                  #      "12345"


    mov rdi, 1                   # rdi = 1
                                  # File descriptor 1 = stdout


    mov rax, 1                   # rax = 1
                                  # Linux x86-64 syscall number:
                                  # write = 1


    syscall                      # write(stdout, buffer, length)
                                  #
                                  # rdi = fd
                                  # rsi = địa chỉ chuỗi
                                  # rdx = số byte
                                  # rax = syscall number


    mov rdi, 0                   # rdi = 0
                                  # exit code = 0


    mov rax, 60                  # rax = 60
                                  # Linux x86-64 syscall number:
                                  # exit = 60


    syscall                      # exit(0)



# ============================================================
# atoi
# Chuyển chuỗi ASCII thành số nguyên
#
# Ví dụ:
# "123"  → 123
# "-45"  → -45
# ============================================================

atoi:
    xor rax, rax                 # rax = 0
                                  # rax sẽ chứa kết quả số nguyên


    xor r10, r10                 # r10 = 0
                                  # r10 dùng làm cờ:
                                  # 0 = số dương
                                  # 1 = số âm


    cmp byte ptr [rdi], '-'      # Kiểm tra ký tự đầu tiên có phải '-' không


    jne loop_atoi                # Nếu không phải '-'
                                  # → xử lý chữ số ngay


    mov r10, 1                   # r10 = 1
                                  # Đánh dấu số âm


    inc rdi                      # rdi++
                                  # Bỏ qua ký tự '-'
                                  #
                                  # "-123"
                                  #  ^
                                  # rdi ban đầu ở '-'
                                  #
                                  # Sau inc:
                                  #  "-123"
                                  #   ^
                                  #  rdi ở '1'


loop_atoi:
    movzx ecx, byte ptr [rdi]    # Đọc 1 byte từ chuỗi
                                  # và zero-extend thành số nguyên
                                  #
                                  # Ví dụ:
                                  # '5' = 0x35
                                  # ecx = 0x00000035


    test cl, cl                  # Kiểm tra cl có bằng 0 không
                                  # '\0' = kết thúc chuỗi


    jz .atoi_end                 # Nếu cl == 0
                                  # → kết thúc atoi


    cmp cl, '0'                  # So sánh ký tự với '0'


    jb .atoi_end                 # Nếu cl < '0'
                                  # → không phải chữ số


    cmp cl, '9'                  # So sánh ký tự với '9'


    ja .atoi_end                 # Nếu cl > '9'
                                  # → không phải chữ số


    imul rax, 10                 # rax *= 10
                                  #
                                  # Ví dụ đang có 12:
                                  # 12 * 10 = 120
                                  #
                                  # Sau đó sẽ cộng chữ số mới


    sub cl, '0'                  # Chuyển ASCII thành giá trị số
                                  #
                                  # '0' = 48 → 0
                                  # '1' = 49 → 1
                                  # '5' = 53 → 5


    movzx rcx, cl                # Mở rộng cl thành rcx
                                  # rcx = giá trị chữ số


    add rax, rcx                 # rax += chữ số
                                  #
                                  # Ví dụ:
                                  # rax = 120
                                  # rcx = 3
                                  # → rax = 123


    inc rdi                      # Di chuyển tới ký tự tiếp theo


    jmp loop_atoi               # Quay lại xử lý ký tự tiếp theo



.atoi_end:
    test r10, r10                # Kiểm tra cờ âm


    jz .atoi_ret                 # Nếu r10 == 0
                                  # → số dương, trả về luôn


    neg rax                      # Nếu số âm:
                                  # rax = -rax
                                  #
                                  # Ví dụ:
                                  # rax = 123
                                  # → rax = -123


.atoi_ret:
    ret                          # Quay về chỗ call atoi
                                  # Giá trị trả về nằm trong rax



# ============================================================
# itoa
# Chuyển số nguyên thành chuỗi ASCII
#
# Input:
#   rdi = số nguyên
#   rsi = địa chỉ cuối buffer
#
# Output:
#   rax = số byte của chuỗi
#
# Ví dụ:
#   rdi = 123
#
# Buffer ban đầu:
#
# [................]
#                 ^
#                 rsi
#
# Sau itoa:
#
# [...........123]
#              ^
#              rcx
# ============================================================

itoa:
    mov rax, rdi                 # rax = số cần chuyển
                                  # Dùng rax để thực hiện phép chia


    mov rcx, rsi                 # rcx = cuối buffer
                                  # rcx sẽ chạy lùi dần khi ghi ký tự


    xor r10, r10                 # r10 = 0
                                  # Cờ âm:
                                  # 0 = dương
                                  # 1 = âm


    test rax, rax                # Kiểm tra số có âm không


    jns .itoa_check_zero         # JNS = Jump if Not Sign
                                  # Nếu rax >= 0 → bỏ qua phần xử lý số âm


    neg rax                      # rax = -rax
                                  # Đưa số âm thành số dương
                                  #
                                  # Ví dụ:
                                  # -123 → 123


    mov r10, 1                   # Đánh dấu ban đầu là số âm



.itoa_check_zero:
    test rax, rax                # Kiểm tra rax có bằng 0 không


    jnz .itoa_digits             # Nếu rax != 0
                                  # → bắt đầu tách từng chữ số


    dec rcx                      # rcx--
                                  # Lùi 1 byte trong buffer


    mov byte ptr [rcx], '0'      # Ghi ký tự '0' vào buffer
                                  #
                                  # Đây là trường hợp đặc biệt:
                                  # số cần chuyển = 0


    jmp .itoa_sign               # Kiểm tra xem có dấu '-' không



.itoa_digits:
    test rax, rax                # Kiểm tra còn chữ số nào không


    jz .itoa_sign                # Nếu rax == 0
                                  # → đã xử lý hết các chữ số


    xor rdx, rdx                 # rdx = 0
                                  # Chuẩn bị cho phép chia unsigned div


    mov r8, 10                   # r8 = 10
                                  # Chia cho 10 để lấy từng chữ số


    div r8                       # rdx:rax / 10
                                  #
                                  # Sau div:
                                  # rax = thương
                                  # rdx = số dư
                                  #
                                  # Ví dụ:
                                  # 123 / 10
                                  #
                                  # rax = 12
                                  # rdx = 3


    add dl, '0'                  # Chuyển chữ số thành ASCII
                                  #
                                  # 3 + '0' = '3'


    dec rcx                      # Lùi 1 byte trong buffer


    mov [rcx], dl                # Ghi ký tự vào buffer
                                  #
                                  # Ví dụ:
                                  # [rcx] = '3'


    jmp .itoa_digits             # Tiếp tục chia phần thương cho 10
                                  #
                                  # 123
                                  # ↓
                                  # 12
                                  # ↓
                                  # 1
                                  # ↓
                                  # 0



.itoa_sign:
    test r10, r10                # Kiểm tra số ban đầu có âm không


    jz .itoa_done                # Nếu không âm
                                  # → hoàn thành


    dec rcx                      # Lùi 1 byte


    mov byte ptr [rcx], '-'      # Ghi dấu '-' vào buffer



.itoa_done:
    mov rax, rsi                 # rax = địa chỉ cuối buffer


    sub rax, rcx                 # rax = rsi - rcx
                                  # Tính số byte đã ghi
                                  #
                                  # Ví dụ:
                                  # rsi = 100
                                  # rcx = 97
                                  #
                                  # length = 100 - 97 = 3


    ret                          # Trả về caller
                                  #
                                  # rax = độ dài chuỗi
