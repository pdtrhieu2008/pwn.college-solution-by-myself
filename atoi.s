###############################
# atoi
#
# rdi = pointer tới string
# rax = integer
###############################

atoi:
    xor rax, rax

    xor r10, r10               # 0 = dương, 1 = âm

    cmp byte ptr [rdi], '-'
    jne loop_atoi

    mov r10, 1
    inc rdi


loop_atoi:
    movzx ecx, byte ptr [rdi]

    test cl, cl
    jz atoi_end

    cmp cl, '0'
    jb atoi_end

    cmp cl, '9'
    ja atoi_end

    imul rax, 10

    sub cl, '0'

    add rax, rcx

    inc rdi

    jmp loop_atoi


atoi_end:
    test r10, r10
    jz atoi_ret

    neg rax


atoi_ret:
    ret
