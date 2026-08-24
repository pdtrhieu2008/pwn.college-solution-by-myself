###############################
# itoa
#
# rdi = số nguyên
# rsi = cuối buffer
#
# output:
# rsi = đầu string
# rax = length
###############################

itoa:
    xor r8, r8                 # r8 = length

    ###########################
    # kiểm tra âm
    ###########################

    test rdi, rdi
    jns itoa_positive

    mov r10, 1                 # số âm
    neg rdi

    jmp itoa_convert


itoa_positive:
    xor r10, r10               # số dương


itoa_convert:

    ###########################
    # trường hợp số 0
    ###########################

    test rdi, rdi
    jnz itoa_loop

    dec rsi
    mov byte ptr [rsi], '0'

    mov rax, 1

    ret


itoa_loop:

    ###########################
    # rdi / 10
    #
    # rax = quotient
    # rdx = remainder
    ###########################

    mov rax, rdi
    xor rdx, rdx

    mov rcx, 10

    div rcx


    ###########################
    # remainder -> ASCII
    ###########################

    add dl, '0'

    dec rsi

    mov byte ptr [rsi], dl

    inc r8


    ###########################
    # quotient
    ###########################

    mov rdi, rax

    test rdi, rdi
    jnz itoa_loop


    ###########################
    # thêm '-' nếu âm
    ###########################

    test r10, r10
    jz itoa_done

    dec rsi
    mov byte ptr [rsi], '-'

    inc r8


itoa_done:
    mov rax, r8

    ret
