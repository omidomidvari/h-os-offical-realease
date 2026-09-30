[org 0x7c00]

init_loader:
    xor ax, ax          ; Reset data segments
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00      ; Establish safe stack space

    ; --- LOW-LEVEL DISK SECTOR CHIP INTERFACE ---
    mov ah, 0x02        ; INT 13h Function 02h: Read sectors from disk
    mov al, 1           ; Read exactly 1 sector (Sector 2) -> 2 Sectors Total
    mov ch, 0           ; Cylinder track 0
    mov cl, 2           ; Start reading at Sector 2
    mov dh, 0           ; Drive Head 0
    mov bx, stage_2     ; Memory mapping target location
    int 0x13            
    jc .halt            ; If hardware fault happens, freeze execution

    jmp stage_2         ; Clean jump into Stage 2!

.halt:
    hlt
    jmp .halt

times 510-($-$$) db 0 
dw 0xaa55               ; Sector 1 structural signature wrap

; =============================================================================
; STAGE 2: FIXED 3-COMMAND DIRECT SHELL (help, clear, sys)
; =============================================================================
stage_2:
    ; 1. Clear Screen and Set 80x25 Text Mode
    mov ax, 3         
    int 0x10             

    ; 2. Print Operating System Welcome Header
    mov si, h_os_banner    
    call print_string

shell_prompt:
    ; 3. Draw Prompt Interface
    mov si, prompt_symbol
    call print_string_raw   
    mov di, cmd_buffer
    xor cx, cx          ; Tracks active character input count

read_keys:
    ; 4. Capture Keyboard Stroke
    mov ah, 0x00
    int 0x16        

    cmp al, 0x0D        ; ENTER?
    je execute_cmd

    cmp al, 0x08        ; BACKSPACE?
    je handle_backspace

    cmp cx, 15          ; Increased clamp room to allow smooth string parsing
    jge read_keys      

    ; 5. Print and Store Valid Character
    mov ah, 0x0E
    int 0x10           
    stosb               
    inc cx             
    jmp read_keys

handle_backspace:
    cmp cx, 0          
    je read_keys       
    
    dec di             
    dec cx             
    
    mov ah, 0x0E
    mov al, 0x08       
    int 0x10
    mov al, ' '        
    int 0x10
    mov al, 0x08       
    int 0x10
    jmp read_keys

execute_cmd:
    mov si, newline
    call print_string_raw  
    mov byte [di], 0    ; Null-terminate input string safely

    cmp cx, 0          
    je shell_prompt

    ; --- ULTRA-RELIABLE DIRECT COMPARISON ENGINE ---
    ; 1. Test "help"
    mov si, cmd_buffer
    mov di, str_help
    call compare_string
    jc do_help

    ; 2. Test "clear"
    mov si, cmd_buffer
    mov di, str_clear
    call compare_string
    jc do_clear

    ; 3. Test "sys"
    mov si, cmd_buffer
    mov di, str_sys
    call compare_string
    jc do_sys

.unknown:
    ; Silently drop through back to the prompt if no commands match
    jmp shell_prompt

; --- Global System Functions ---
print_string:
    call print_string_raw
    mov si, newline    
print_string_raw:      
    push si
    push ax
.loop:
    lodsb
    cmp al, 0
    je .done
    mov ah, 0x0e
    int 0x10           
    jmp .loop
.done:
    pop ax
    pop si
    ret

compare_string:
    push si            
    push di
.loop:
    mov al, [si]
    mov bl, [di]
    cmp al, bl
    jne .not_equal     
    cmp al, 0
    je .equal          
    inc si
    inc di
    jmp .loop
.not_equal:
    pop di
    pop si
    clc                
    ret
.equal:
    pop di
    pop si
    stc                 
    ret

; --- Action Subroutines (Strictly 3 Core Commands) ---
do_help:
    mov si, help_text
    call print_string
    jmp shell_prompt

do_clear:
    jmp stage_2         ; Hard jump back to initialization natively clears screen completely

do_sys:
    mov si, h_os_banner
    call print_string
    jmp shell_prompt

; --- Data Repositories ---
; FIXED: Changed operating system name and version banner text
h_os_banner:   db 'hos 0.1 experimental', 0
prompt_symbol: db '> ', 0
newline:       db 13, 10, 0
help_text:     db 'help, clear, sys', 0

; Individual direct command match keys
str_help:      db 'help', 0
str_clear:     db 'clear', 0
str_sys:       db 'sys', 0

; --- Fixed Memory Buffer Mapping ---
align 2
cmd_buffer: times 16 db 0

times 1024-($-$$) db 0
