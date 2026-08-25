.intel_syntax noprefix
.global _start

_start:
        mov rdi,[rsp+16]
        xor r13,r13
loop:
        cmp byte ptr [rdi+r13],0
        je loop_done

        inc r13
        jmp loop

loop_done:
        mov rsi,rdi
        mov rax,1
        mov rdi,1
        mov rdx,r13
        syscall
        mov rax,60
        mov rdi,0
        syscall
        ret
