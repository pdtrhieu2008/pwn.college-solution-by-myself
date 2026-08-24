.intel_syntax noprefix
.global _start


_start:
    mov r12, [rsp + 16]       # argv[1]
    mov r13, [rsp + 24]       # argv[2]
    mov r14, [rsp + 32]       # argv[3]

  
    ############################
    # kiểm tra operator
    ############################

    mov al, byte ptr [r13]
    cmp al, '-'
    je do_sub

    mov al, byte ptr [r13]
    cmp al, '+'
    je do_add

    mov al, byte ptr [r13]
    cmp al, '*'
    je do_mul

    mov al, byte ptr [r13]
    cmp al, '|'
    je do_or

    mov al, byte ptr [r13]
    cmp al, '&'
    je do_and

    mov al, byte ptr [r13]
    cmp al, '^'
    je do_xor

    mov al, byte ptr [r12]
    cmp al,'-'
    je do_neg

    mov al, byte ptr [r12]
    cmp al,'~'
    je do_not
###############################
# unsupported operator
###############################

unsupported:
    mov rax, 60                # exit
    mov rdi, 1                 # exit code = 1
    syscall

do_or:
    mov rdi,r12
    call atoi
    mov r15,rax
    
    mov rdi,r14
    call atoi
    or r15,rax
    jmp make_output

do_and:
    mov rdi,r12
    call atoi
    mov r15,rax
    
    mov rdi,r14
    call atoi
    and r15,rax
    jmp make_output

do_xor:
    mov rdi,r12
    call atoi
    mov r15,rax
    
    mov rdi,r14
    call atoi
    xor r15,rax
    jmp make_output


do_add:
    mov rdi,r12
    call atoi
    mov r15,rax
    
    mov rdi,r14
    call atoi
    add r15,rax
    jmp make_output
    
do_sub:
    mov rdi,r12
    call atoi
    mov r15,rax
    
    mov rdi,r14
    call atoi
    sub r15,rax
    jmp make_output

do_mul:
    mov rdi,r12
    call atoi
    mov r15,rax
    
    mov rdi,r14
    call atoi
    imul r15,rax
    jmp make_output  

do_neg:
    mov rdi,r13
    call atoi
    mov r15,rax
    imul r15,-1
    jmp make_output

do_not:
    mov rdi,r13
    call atoi
    mov r15,rax
    imul r15,-1
    sub r15,1
    jmp make_output  
make_output:
    sub rsp, 0x80

    mov rdi, r15
    lea rsi, [rsp + 0x80]

    call itoa


    ############################
    # write(1, rsi, rax)
    ############################

    mov rdx, rax               # length

    mov rax, 1                 # syscall write
    mov rdi, 1                 # stdout
    syscall


    ############################
    # exit(0)
    ############################

    mov rax, 60
    mov rdi,0
    syscall

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
