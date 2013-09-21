//; func IndexNotEqual(a, b []byte) int
TEXT ·IndexNotEqual(SB),7,$0
	MOVQ a+0(FP), SI  //; pointer to a
	MOVQ a+8(FP), CX  //; length of a
	MOVQ b+24(FP), DI //; pointer to b
	MOVQ b+32(FP), BX //; length of b

//; Move in the smallest of AX and BX in to BX
	CMPQ CX,BX
	CMOVQLT CX, BX

//; If the shortest []byte of a and b is less than 8 bytes jump to small
	CMPQ BX, $8
	JB ineSmall

//; 64 bytes at a time using xmm registers
ineHuge:
//; Jump to bigloopBody if it is less than 64 bytes left
	CMPQ BX, $64
	JB ineBigBody

//; Copy in 64 bytes of a and b in to the xmm registers X0 to X7
	MOVOU (SI), X0
	MOVOU (DI), X1
	MOVOU 16(SI), X2
	MOVOU 16(DI), X3
	MOVOU 32(SI), X4
	MOVOU 32(DI), X5
	MOVOU 48(SI), X6
	MOVOU 48(DI), X7

//; PCMPEQB will set X0, X2, X4 and X6 to only contain 0xFF if a and b are the same.
	PCMPEQB X1, X0
	PCMPEQB X3, X2
	PCMPEQB X5, X4
	PCMPEQB X7, X6

//; PMOVMSKB takes the highest bit from every byte in X0, X2, X4 and X6
//; respectivly and copys them in to the 16 least significant bits of
//; R8, R9, R10 and R11 respectivly.
	PMOVMSKB X0, R8
	PMOVMSKB X2, R9
	PMOVMSKB X4, R10
	PMOVMSKB X6, R11

//; Compare the 16 least significant bits of R8, R9, R10 and R11 to
//; 0xFFFF (all bits set to 1) and jump to found1, found2, found3 or found4 if
//; any of the 64 bits is not set (non matching byte found).
	CMPW R8, $0xFFFF
	JNE ineFound1
	CMPW R9, $0xFFFF
	JNE ineFound2
	CMPW R10, $0xFFFF
	JNE ineFound3
	CMPW R11, $0xFFFF
	JNE ineFound4

//; Update the pointers and counter then jump back to the start of the loop.
	ADDQ $64, SI
	ADDQ $64, DI
	SUBQ $64, BX
	JMP ineHuge

//; Update the pointers and counter
ineBig:
	ADDQ $8, SI
	ADDQ $8, DI
	SUBQ $8, BX

//; 8 bytes at a time using 64-bit registers
ineBigBody:
//; Jump to small if it is less than 8 bytes left
	CMPQ BX, $8
	JB ineSmall

//; Compare 8 bytes of a and b and jump back to bigloop if they match
	MOVQ (SI), CX
	MOVQ (DI), DX
	CMPQ CX, DX
	JEQ ineBig

//; If a match is found in the bigloop compare one byte at the time untill SI
//; points to the first non matching byte.
ineFindMatch:
	CMPB  CL, DL
	JNE    ineMatchFound

ineFindMatchBody:
	SHRQ  $8, CX
	SHRQ  $8, DX
	ADDQ  $1, SI
	JMP ineFindMatch

ineSmallBody:
	ADDQ $1, DI
	ADDQ $1, SI
	SUBQ $1, BX

//; 1 byte at a time using the 8 least significant bits of 64-bit registers
ineSmall:
//; If one of string a or b is of length 0 then they are the equal if we follow
//; the logic from bytes.Index
	CMPB BX, $0
	JE ineEq
	MOVB (SI), R13
	CMPB R13, (DI)
	JE ineSmallBody

//; Subtract the current possition of SI with SI's starting possition to get the
//; index of the match and return
ineMatchFound:
	SUBQ s1+0(FP), SI
	MOVQ SI, res+48(FP)
	RET

//; Return -1 if the strings are equal
ineEq:
	MOVQ $-1, res+48(FP)
	RET

//; Calculate the index of the match and return.
ineFound1:
	XORQ $0xffff, R8 //; Convert from equal to not equal.
	BSFW R8, DX      //; Get the index of the least significant set bit wich
	                 //; represents the first non matching byte.
	ANDQ $0xffff, DX //; Set the 48 most significant bits of DX to 0.
	JMP ineReturn
ineFound2:
	XORQ $0xffff, R9
	BSFW R9, DX
	ANDQ $0xffff, DX
	ADDQ $16, DX
	JMP ineReturn
ineFound3:
	XORQ $0xffff, R10
	BSFW R10, DX
	ANDQ $0xffff, DX
	ADDQ $32, DX
	JMP ineReturn
ineFound4:
	XORQ $0xffff, R11
	BSFW R11, DX
	ANDQ $0xffff, DX
	ADDQ $48, DX
	JMP ineReturn
ineReturn:
	SUBQ s1+0(FP), SI
	ADDQ DX, SI
	MOVQ SI, res+48(FP)
	RET

//; func EqualThreshold(a, b []byte, t uint8) eq bool
TEXT ·EqualThreshold(SB),7,$0
	MOVQ a+0(FP), SI  //; Pointer to a
	MOVQ a+8(FP), CX  //; Length of a
							//; a+16(FP) capacity (not used)
	MOVQ b+24(FP), DI //; Pointer to b
	MOVQ b+32(FP), BX //; Length of b
							//; b+40(FP) capacity (not used)

	//;MOVBQZX t+48(FP), AL //; Threshold
	XORQ AX, AX
	MOVB t+48(FP), AL

//; Move in the smallest of CX and BX in to BX
	CMPQ CX, BX
	CMOVQLT CX, BX

//; If the shortest []byte of a and b is less than 16 bytes jump to eqtsmall
	CMPQ BX, $16
	JB eqtSmall

//; Copy the threshold byte to every possition in X8
	MOVD AX, X8
	PUNPCKLBW X8, X8
	PUNPCKLBW X8, X8
	PSHUFL $0, X8, X8

//; Set DX to point at the last 64 bytes of the search
	MOVQ SI, DX
	ADDQ BX, DX
	SUBQ $64, DX
	JMP eqtHuge

eqtHugeBody:
//; Copy in 64 bytes of a and b in to the xmm registers X0 to X7
	MOVOU (SI), X0
	MOVOU (DI), X1
	MOVOU 16(SI), X2
	MOVOU 16(DI), X3
	MOVOU 32(SI), X4
	MOVOU 32(DI), X5
	MOVOU 48(SI), X6
	MOVOU 48(DI), X7

//; Copy registers X0 to X6 in to X9 to X15 (to be used by lower threshold check).
	MOVOU X0, X9
	MOVOU X1, X10
	MOVOU X2, X11
	MOVOU X3, X12
	MOVOU X4, X13
	MOVOU X5, X14
	MOVOU X6, X15

//; Add the threshold value to every byte of the xmm registers that contain
//; bytes from a.
	PADDUSB X8, X0
	PADDUSB X8, X2
	PADDUSB X8, X4
	PADDUSB X8, X6

//; Copy the biggest value of every byte from a+threshold and bytes from b.
	PMAXUB X0, X1
	PMAXUB X2, X3
	PMAXUB X4, X5
	PMAXUB X6, X7

//; PCMPEQB will set X0, X2, X4 and X6 to only contain 0xFF if a+threshold is
//; the highest value in every byte possition.
	PCMPEQB X1, X0
	PCMPEQB X3, X2
	PCMPEQB X5, X4
	PCMPEQB X7, X6

//; If any of the bytes in X0, X2, X4 or X6 is not set to 0xFF then that will
//; propagate in to X6.
	PAND X0, X2
	PAND X4, X6
	PAND X2, X6

//; PMOVMSKB takes the highest bit from every byte in X6 and copies them in to
//; the 16 least significant bits of CX.
	PMOVMSKB X6, CX

//; Compare the 16 least significant bits of CX to 0xFFFF (all bits set to 1)
//; and jump to false if they are not equal.
	CMPW CX, $0xFFFF
	JNE eqtFalse

//; We have saved a copy of all 64 first bytes of a and the first 48 bytes of b
//; now we copy the remaning 16 bytes of b in to X0
	MOVOU 48(DI), X0

//; Subtract the threshold value from every byte of the xmm registers that
//; contain bytes from a.
	PSUBUSB X8, X9
	PSUBUSB X8, X11
	PSUBUSB X8, X13
	PSUBUSB X8, X15

//; Copy the minimum value of every byte from a+threshold and bytes from b.
	PMINUB X9, X10
	PMINUB X11, X12
	PMINUB X13, X14
	PMINUB X15, X0

//; PCMPEQB will set X9, X11, X13 and X15 to only contain 0xFF if a+threshold is
//; the lowest value in every byte possition.
	PCMPEQB X10, X9
	PCMPEQB X12, X11
	PCMPEQB X14, X13
	PCMPEQB X0, X15

//; If any of the bytes in X9, X11, X13 or X15 is not set to 0xFF then that will
//; propagate in to X15.
	PAND X9, X11
	PAND X13, X15
	PAND X11, X15

//; PMOVMSKB takes the highest bit from every byte in X15 and copies them in to
//; the 16 least significant bits of CX.
	PMOVMSKB X15, CX

//; Compare the 16 least significant bits of CX to 0xFFFF (all bits set to 1)
//; and jump to false if they are not equal.
	CMPW CX, $0xFFFF
	JNE eqtFalse

//; Update the pointer values and jump back to the start of the loop.
	ADDQ $64, SI
	ADDQ $64, DI

//; 64 bytes at a time using xmm registers.
eqtHuge:
	CMPQ	SI, DX
	JLE eqtHugeBody

//; Every step is equal to the steps in the enormousloop but now we only test
//; 16 bytes at a time using xmm registers.
eqtBig:
	MOVQ a+0(FP), CX
	ADDQ BX, CX //; Last byte of a
	MOVQ CX, AX
	SUBQ $16, CX //; 16 last bytes of a

eqtBigBody:
	MOVOU (SI), X0
	MOVOU (DI), X1
	MOVOU X0, X2
	MOVOU X1, X3

	PADDUSB X8, X0
	PMAXUB X0, X1
	PCMPEQB X1, X0
	PMOVMSKB X0, DX
	CMPW DX, $0xFFFF
	JNE eqtFalse

	PSUBUSB X8, X2
	PMINUB X2, X3
	PCMPEQB X3, X2
	PMOVMSKB X2, DX
	CMPW DX, $0xFFFF
	JNE eqtFalse

	ADDQ $16, SI
	ADDQ $16, DI

//; Check if we are less than 16 bytes from the end
	CMPQ CX, SI
	JG eqtBigBody

//; If all bytes have been checked jump to true
	CMPQ AX, SI
	JE eqtTrue

//; If less than 16 bytes are left to check copy in the last 16 bytes of a and b
//; and run the eqtbigbody one last time.
	MOVQ CX, SI
	MOVQ b+24(FP), DI
	ADDQ BX, DI
	SUBQ $16, DI //; 16 last byes of b
	JMP eqtBigBody //; Do the last bytes

//; 1 bytes at a time using the 8 least significant bits of 64-bits registers.
eqtSmall:
	MOVQ SI, R8
	ADDQ BX, R8

eqtSmallBody:
	CMPQ SI, R8
	JE eqtTrue

	MOVBQZX (SI), CX
	MOVBQZX (DI), DX

	CMPQ DX, CX
	JGE eqtNoSwitch
	XCHGQ DX, CX
eqtNoSwitch:
	SUBQ CX, DX

	CMPQ DX, AX
	JG eqtFalse

	INCQ SI
	INCQ DI
	JMP eqtSmallBody

eqtFalse:
	MOVQ	$0, ret+56(FP) //; [8+8+8 a], [8+8+8 b], [1 t], [7 padding] [1 eq]
	RET

eqtTrue:
	MOVQ	$1, ret+56(FP) //; [8+8+8 a], [8+8+8 b], [1 t], [7 padding] [1 eq]
	RET

//; func IndexByteThreshold(a []byte, b, t uint8) index int
TEXT ·IndexByteThreshold(SB),7,$0
	MOVQ a+0(FP), SI  //; Pointer to a
	MOVQ a+8(FP), CX  //; Length of a
							//; a+16(FP) capacity (not used)
	MOVBQZX b+24(FP), AX //; b
	MOVBQZX b+25(FP), BX //; t

//;set DI to point at the last byte of a
	MOVQ SI, DI
	ADDQ CX, DI

//; If the a is shorter than 16 bytes jump to eqtsmall
	CMPQ CX, $16
	JB ibtSmall

//; Set CX to contain the pointer to the last 64 bytes of a
	MOVQ DI, CX
	SUBQ $64, CX

//; Copy the search byte value to all possitions in the xmm register
	MOVD AX, X14
	PUNPCKLBW X14, X14
	PUNPCKLBW X14, X14
	PSHUFL $0, X14, X14

//; Copy the threshold value to all possitions in the xmm register
	MOVD BX, X1
	PUNPCKLBW X1, X1
	PUNPCKLBW X1, X1
	PSHUFL $0, X1, X1

	MOVOU X14, X15
	PADDUSB X1, X14 //; Max
	PSUBUSB X1, X15 //; Min

	XORQ R9,R9
	XORQ R11,R11
	XORQ R13,R13
	XORQ R15,R15
	JMP ibtHuge

ibtHugeBody:
	MOVOU (SI), X0 //; 16 bytes to test
	MOVOU 16(SI), X2
	MOVOU 32(SI), X4
	MOVOU 48(SI), X6
	MOVOU X0, X1 //; 16 bytes to test
	MOVOU X2, X3
	MOVOU X4, X5
	MOVOU X6, X7

	PMAXUB X14, X0 //; compare upper limit to the current 16 bytes
	PMAXUB X14, X2
	PMAXUB X14, X4
	PMAXUB X14, X6

	PCMPEQB X14, X0
	PCMPEQB X14, X2
	PCMPEQB X14, X4
	PCMPEQB X14, X6

	PMOVMSKB X0, R8
	PMOVMSKB X2, R10
	PMOVMSKB X4, R12
	PMOVMSKB X6, R14

	PMINUB X15, X1 //; compare lower limit to the current 16 bytes
	PMINUB X15, X3
	PMINUB X15, X5
	PMINUB X15, X7

	PCMPEQB X15, X1
	PCMPEQB X15, X3
	PCMPEQB X15, X5
	PCMPEQB X15, X7

	PMOVMSKB X1, R9
	PMOVMSKB X3, R11
	PMOVMSKB X5, R13
	PMOVMSKB X7, R15

	ANDW R8, R9
	ANDW R10, R11
	ANDW R12, R13
	ANDW R14, R15

	CMPW R9, $0
	JNE ibtFound1

	CMPW R11, $0
	JNE ibtFound2

	CMPW R13, $0
	JNE ibtFound3

	CMPW R15, $0
	JNE ibtFound4

	ADDQ $64, SI

ibtHuge:
//; Check if it is less than 64 bytes left
	//CMPQ SI, CX
	//JG ibtHugeBody

//; Set CX to contain the pointer to the last 64 bytes of a
	MOVQ DI, CX
	SUBQ $16, CX
	JMP ibtBig

//; ibtBigBody functions the same way as ibtHugeBody but works with 16 byte at the time
ibtBigBody:
	MOVOU (SI), X0
	MOVOU X0, X1
	PMAXUB X14, X0
	PCMPEQB X14, X0
	PMOVMSKB X0, R8
	PMINUB X15, X1
	PCMPEQB X15, X1
	PMOVMSKB X1, R9
	ANDQ $0xffff, R8 //tmp
	ANDQ $0xffff, R9 //tmp
	ANDW R8, R9
	CMPW R9, $0
	JNE ibtFound1
	ADDQ $16, SI

ibtBig:
	CMPQ SI, CX
	//JG ibtBigBody
	JMP ibtSmall

//; 1 bytes at a time using the 8 least significant bits of 64-bits registers
ibtSmallBody:
	INCQ SI
ibtSmall:
	CMPQ SI, DI //; jump to ibtNoMatch if we have checked all bytes
	JG ibtNoMatch

	MOVBQZX (SI), CX //; current byte to test
	MOVQ AX, DX

	CMPQ DX, CX
	JGE ibtNoSwitch
	XCHGQ DX, CX
ibtNoSwitch:
	SUBQ CX, DX

	CMPQ DX, BX
	JG ibtSmallBody

	SUBQ a+0(FP), SI
	MOVQ SI, r+32(FP)
	RET

ibtFound1:
	ANDQ $0xffff, DX
	BSFW R9, DX
	JMP ibtReturn
ibtFound2:
	ANDQ $0xffff, DX
	BSFW R11, DX
	ADDQ $16, DX
	JMP ibtReturn
ibtFound3:
	ANDQ $0xffff, DX
	BSFW R13, DX
	ADDQ $32, DX
	JMP ibtReturn
ibtFound4:
	ANDQ $0xffff, DX
	BSFW R15, DX
	ADDQ $48, DX

ibtReturn:
	SUBQ a+0(FP), SI //; SI = current - start
	ADDQ DX, SI
	MOVQ SI, r+32(FP)
	RET

ibtNoMatch:
	MOVQ $-1, r+32(FP)
	RET
