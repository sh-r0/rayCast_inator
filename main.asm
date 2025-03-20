; SDL3
extern SDL_Init
extern SDL_CreateWindow
extern SDL_CreateRenderer

extern SDL_DestroyRenderer
extern SDL_DestroyWindow
extern SDL_Quit

extern SDL_PollEvent
extern SDL_SetRenderDrawColor
extern SDL_RenderClear
extern SDL_RenderPresent
extern SDL_RenderFillRect
extern SDL_RenderLine

; libc
extern sin, cos
extern sleep
extern printf
extern fflush

global main

section .data
    windowName db "RayCast_inator", 0

    msgInit db "Initialized sdl!", 0xA, 0
    msgCreateWindow db "Created window!", 0xA, 0
    msgCreateRenderer db "Created renderer!", 0xA, 0
    msgDraw db "~Drawing~", 0xA, 0
    msgQuit db "Called sdl_quit!", 0xA, 0
    msgMoving db "Moving!", 0xA, 0
    msgPosition db "Pos: %d %d", 0xA, 0

    initFailure db "Failed to init SDL3!", 0xA, 0
   
    SDL_INIT_VIDEO equ  0x00000020 
    SDL_EVENT_QUIT equ 0x100
    SDL_EVENT_KEY_DOWN equ 0x300
    
    KEY_OFFSET equ 28
    ZERO dq 0.0
    ONE dq 1.0
    MINUS_ONE dq -1.0
    HALF_PI dq 1.57
    PI dq 3.14
    TWO_PI dq 6.28
    SCREEN_HEIGHT dd 600
    SCREEN_WIDTH dd 800
    PLAYER_SPEED dq 0.0625
    PLAYER_ROTATION_SPEED dq 0.1
    MAP_SIZE_X dq 10
    MAP_SIZE_Y dq 10
    
    playerPosX dq 5.0
    playerPosY dq 5.0

    playerAngle dq 0.0 ; 0 - 6.28
    playerDirX dq 0.0
    playerDirY dq 1.0
    

section .bss
    map resb 10*10  ;idk if that works

section .text
main:
    ; SDL_Init(SDL_INIT_VIDEO)
    sub rsp, $8
    xor rdi, rdi
    mov edi, SDL_INIT_VIDEO
    xor rax, rax
    call SDL_Init 
    add rsp, $8
    
    test rax, rax
    jmp init_success
    ; if SDL_Init failed
init_failure:
    mov rdi, initFailure,
    xor rax, rax
    call printf
    jmp main_exit

init_success:
	; call SDL_CreateWindow
    sub rsp, 8
    mov rcx, 0
    mov rdx, [SCREEN_HEIGHT]
    mov rsi, [SCREEN_WIDTH]
    mov rdi, windowName
    call SDL_CreateWindow
    add rsp, 8
    
    ; Check for nullptr 
    cmp rax, 0
    je init_failure
    push rax ; Store window* on stack
    
    mov rdi, msgCreateWindow
    xor rax, rax
    call printf

	; call SDL_CreateRenderer
    xor rax, rax
    mov rdi, [rsp]
    mov rsi, 0
    call SDL_CreateRenderer
    
    cmp rax, 0
    je init_failure
    push rax ; Store renderer* on stack -> window is now +8

    mov rdi, msgCreateRenderer
    xor rax, rax
    call printf

    call init_map

    sub rsp, 136 ; alloc SDL_Event size + bool64
    ; window: +144 
    ; renderer: +136 

while_event:
    mov rdi, rsp 
    xor rax, rax
    call SDL_PollEvent

    cmp al, 0; 
    je draw_flag
check_event_type:
    mov eax, [rsp] 
    cmp eax, SDL_EVENT_QUIT
    je application_quit
    cmp eax, SDL_EVENT_KEY_DOWN
    je keydown_func
    jmp while_event 

draw_flag:
    mov rdi, [rsp+136] ; first
    mov rsi, 96 ; second
    mov rdx, 96 ; third
    mov rcx, 255 ; fourth
    mov r8, 255  ; fifth
    xor rax, rax
    call SDL_SetRenderDrawColor

    mov rdi, [rsp+136]
    xor rax, rax
    call SDL_RenderClear

    jmp draw_frame_func 
draw_frame_ret: ; prob would be good to call instead, but then would need to jmp anyways so we doin this

    mov rdi, [rsp+136]
    xor rax, rax
    call SDL_RenderPresent
    
    jmp while_event

application_quit:
    xor rax, rax
    call SDL_Quit
    
main_exit:
    mov rax, 60        
    xor rdi, rdi       
    syscall


; init map func
init_map:
    mov rax, 0

init_map_while: 
    mov rbx, rax
    imul rbx, [MAP_SIZE_X]

    mov byte [map+rax], 2       ; moving right 
    mov byte [map+90+rax], 2    ; moving right bottom 
    mov byte [map+rbx], 1       ; moving down
    mov byte [map+9+rbx], 1     ; moving down right side

    inc rax
    cmp rax, [MAP_SIZE_X]
    jne init_map_while
    mov byte [map+20+4], 1
    mov byte [map+20+5], 1
    mov byte [map+20+6], 1

    mov byte [map+70+4], 1
    mov byte [map+70+5], 1
    mov byte [map+70+6], 1
    
    ret
    

move_func:
    movsd xmm0, [playerDirX]
    movsd xmm1, [PLAYER_SPEED]
    cvtsi2sd xmm8, rbx
    mulsd xmm0, xmm8
    mulsd xmm0, xmm1
    mulsd xmm1, [playerDirY]
    addsd xmm0, [playerPosX]
    mulsd xmm1, xmm8
    addsd xmm1, [playerPosY]
    movsd xmm2, xmm0
    movsd xmm3, xmm1
    call get_block
    
    cmp al, 0
    jg while_event ; we move only if we are not going into wall
    movsd [playerPosX], xmm2
    movsd [playerPosY], xmm3
    
    jmp while_event


rotate_func:
    movsd xmm0, [PLAYER_ROTATION_SPEED] 
    cvtsi2sd xmm1, rbx
    mulsd xmm0, xmm1
    addsd xmm0, [playerAngle]
    ; movsd xmm1, [TWO_PI]
    ; cmpsd xmm0, [TWO_PI], 1
    comisd xmm0, [TWO_PI]
    jb rotate1 ; jump below
    subsd xmm0, [TWO_PI]
rotate1:
    comisd xmm0, [ZERO]
    ja rotate2 ; jump above
    addsd xmm0, [TWO_PI]
rotate2:
    movsd [playerAngle], xmm0
    
    xor rax, rax
    call cos
    movsd [playerDirY], xmm0
    
    movsd xmm0, [playerAngle]
    xor rax, rax
    call sin
    movsd [playerDirX], xmm0

    jmp while_event


keydown_func:
    ; probably better with cmov-s IF ONLY they supported immediate values
    xor rbx, rbx
    cmp dword [rsp+KEY_OFFSET], 'w' ; using dword coz key is encoded in uint32_t
    jne keydown_1
    mov rbx, 1
keydown_1:
    cmp dword [rsp+KEY_OFFSET], 's'
    jne keydown_2
    mov rbx, -1
keydown_2:
    cmp rbx, 0
    jne move_func

    cmp dword [rsp+KEY_OFFSET], 'd'
    jne keydown_3
    mov rbx, 1
keydown_3:
    cmp dword [rsp+KEY_OFFSET], 'a'
    jne keydown_4
    mov rbx, -1
keydown_4:
    cmp rbx, 0
    jne rotate_func

    jmp while_event


draw_frame_func:
    mov rdi, [rsp+136]
    mov rsi, 64 
    mov rdx, 255 
    mov rcx, 64 
    mov r8, 255  
    xor rax, rax
    call SDL_SetRenderDrawColor

    cvtsd2ss xmm0, [ZERO]
    movss [rsp], xmm0
    
    cvtsi2ss xmm1, [SCREEN_WIDTH]
    movss [rsp+8], xmm1
    cvtsi2ss xmm1, [SCREEN_HEIGHT]
    mov rax, 2
    cvtsi2ss xmm0, rax
    divss xmm1, xmm0   
    movss [rsp+12], xmm1
    movss [rsp+4], xmm1

    mov rdi, [rsp+136]
    mov rsi, rsp
    xor rax, rax
    call SDL_RenderFillRect

    mov dword [rsp], 0 ; 4bytes for iterator 
    movsd xmm1, [HALF_PI]
    mov rdx, 2
    cvtsi2sd xmm2, rdx
    divsd xmm1, xmm2 

    movsd xmm0, [playerAngle]
    subsd xmm0, xmm1 
    movsd [rsp+4], xmm0 ; mov pA-45* to rsp+4
    
    movsd xmm0, [HALF_PI]
    cvtsi2sd xmm1, dword [SCREEN_WIDTH]
    divsd xmm0, xmm1 
    movsd [rsp+12], xmm0 ; mov delta angle to rsp+12
    
    mov rax, [ZERO]
    mov [rsp+68], rax ; zero timeTillWall
    ; 20 - rayDirX
    ; 28 - rayDirY
    ; 36 - currPosX
    ; 44 - currPosY
    ; 52 - nextWallPosX
    ; 60 - nextWallPosY
    ; 68 - timeTillWall
draw_frame_while:
    mov eax, [rsp]
    cmp eax, [SCREEN_WIDTH]
    jge draw_frame_ret
    
    xor rax, rax
    movsd xmm0, qword [rsp+4]
    call sin
    movsd [rsp+20], xmm0
    movsd xmm1, xmm0 ;
    xor rax, rax
    movsd xmm0, qword [rsp+4]
    call cos
    movsd [rsp+28], xmm0

    mov rax, [playerPosX] ; we reset position to playerPos for every search
    mov [rsp+36], rax
    mov rax, [playerPosY]
    mov [rsp+44], rax

    mov rax, [ZERO]
    mov [rsp+68], rax
wall_search:
    movsd xmm0, [rsp+28]
    movsd xmm1, [rsp+20] 
    comisd xmm1, [ZERO]
    movsd xmm3, [rsp+36]
    jb ws_neg_x
    ; pos dirX
    roundsd xmm2, xmm3, 2 ; round up 
    call resolve_if_same
    movsd [rsp+52], xmm2 ; mov next posX to 52
    subsd xmm2, xmm3
    movsd xmm4, xmm2
    jmp ws_x_end
ws_neg_x:
    roundsd xmm2, xmm3, 1 ; round down
    call resolve_if_same_neg 
    movsd [rsp+52], xmm2 
    subsd xmm3, xmm2    
    movsd xmm4, xmm3   
ws_x_end:
    ; prob just this
    comisd xmm0, [ZERO]
    jb ws_neg_y
    movsd xmm3, [rsp+44]
    roundsd xmm2, xmm3, 2
    call resolve_if_same
    movsd [rsp+60], xmm2
    subsd xmm2, xmm3
    jmp ws_y_end
ws_neg_y:
    movsd xmm3, [rsp+44]
    roundsd xmm2, xmm3, 1
    call resolve_if_same_neg
    movsd [rsp+60], xmm2
    subsd xmm2, xmm3
ws_y_end:   
    ; div distance by velocity to get time 
    divsd xmm4, [rsp+20] ; !!! WILL BE NEGATIVE SOMETIMES
    divsd xmm2, [rsp+28] 
    ; xmm2/4 has distY/X
    ; xmm 3/5 has abs(distY/X)
    movsd xmm5, xmm4
    comisd xmm4, [ZERO]
    ja dist_resolved_x
    mulsd xmm5, [MINUS_ONE]
dist_resolved_x:
    movsd xmm3, xmm2
    comisd xmm2, [ZERO]
    ja dist_resolved_y
    mulsd xmm3, [MINUS_ONE]
dist_resolved_y:
    comisd xmm5, xmm3 ; check |timeX|>|timeY|
    ja dist_smaller_y
    
    movsd xmm6, xmm5
    addsd xmm6, [rsp+68] ; adding currDist to distTillNext 
    movsd [rsp+68], xmm6
    ; adding to y vecDirY*xTime and settin posX to next wallpos from earlier
    mulsd xmm5, [rsp+28] 
    addsd xmm5, [rsp+44]
    movsd [rsp+44], xmm5

    movsd xmm6, [rsp+52] ; setting currPosX to nextWallPos
    movsd [rsp+36], xmm6

    jmp dist_smaller_end
dist_smaller_y:
    movsd xmm6, xmm3
    addsd xmm6, [rsp+68] 
    movsd [rsp+68], xmm6

    mulsd xmm3, [rsp+20]
    addsd xmm3, [rsp+36]
    movsd [rsp+36], xmm3

    movsd xmm6, [rsp+60]
    movsd [rsp+44], xmm6
dist_smaller_end: 
    ; check for wall in that position
    movsd xmm0, [rsp+36] ; curPosX 
    movsd xmm1, [rsp+44]
    movsd xmm2, [rsp+20]
    movsd xmm3, [rsp+28]

    call get_block_perspective
    cmp al, 0 
    je wall_search
wall_search_end:
    mov rdi, [rsp+136] ; first
    mov rsi, 64; second
    imul rsi, rax
    mov rdx, 64 ; third
    mov rcx, 0 ; fourth
    mov r8, 255  ; fifth
    xor rax, rax
    call SDL_SetRenderDrawColor

    mov rdi, [rsp+136]
    cvtsi2ss xmm0, dword [rsp]
    movsd xmm2, xmm0
    
    xor rax, rax
    mov eax, dword [SCREEN_HEIGHT]
    shr rax, 1
    cvtsi2ss xmm1, rax
    movsd xmm3, xmm1

    cvtsd2ss xmm4, [rsp+68]
    rcpss xmm5, xmm4
    mulss xmm5, xmm1

    addss xmm1, xmm5
    subss xmm3, xmm5
    xor rax, rax
    call SDL_RenderLine

    ;end of 'function'
    movsd xmm0, qword [rsp+4]
    addsd xmm0, [rsp+12]
    movsd [rsp+4], xmm0
    
    add dword [rsp], 1
    jmp draw_frame_while 
;--------------- END OF draw_frame_func


resolve_if_same_neg:
    comisd xmm2, xmm3
    jne resolve_if_same_end
    subsd xmm2, [ONE]
resolve_if_same_neg_end:
    ret

resolve_if_same:
    comisd xmm2, xmm3
    jne resolve_if_same_end
    addsd xmm2, [ONE]
resolve_if_same_end:
    ret


get_block_perspective:
    movsd xmm4, xmm0
    movsd xmm5, xmm1
    roundsd xmm0, xmm0, 1 
    roundsd xmm1, xmm1, 1
    cvttsd2si rbx, xmm0
    cvttsd2si rax, xmm1
    comisd xmm2, [ZERO]
    ja get_block_perspective_y
    comisd xmm4, xmm0
    ja get_block_perspective_y
    sub rbx, 1
get_block_perspective_y:
    comisd xmm3, [ZERO]
    ja get_block_perspective_end
    comisd xmm5, xmm1
    ja get_block_perspective_end
    sub rax, 1
get_block_perspective_end:
    imul rax, [MAP_SIZE_X]
    add rbx, rax
    xor rax, rax
    mov al, [map+rbx]

    ret


get_block:
    roundsd xmm0, xmm0, 1 
    roundsd xmm1, xmm1, 1
    cvttsd2si rbx, xmm0
    cvttsd2si rax, xmm1

    imul rax, [MAP_SIZE_X]
    add rbx, rax
    xor rax, rax
    mov al, [map+rbx]

    ret
