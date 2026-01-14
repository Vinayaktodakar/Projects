module pipe_mips32(clk1,clk2);
input clk1,clk2;
reg [31:0] PC,IF_ID_IR,IF_ID_NPC;
reg [31:0] ID_EX_IR,ID_EX_NPC,ID_EX_A,ID_EX_B,ID_EX_Imm;
reg [2:0]  ID_EX_type, EX_MEM_type, MEM_WB_type;
reg [31:0] EX_MEM_IR,EX_MEM_ALUout,EX_MEM_B;
reg	   EX_MEM_cond;
reg [31:0] MEM_WB_IR,MEM_WB_ALUout,MEM_WB_LMD;

reg [31:0] Reg[0:31];// Register bank
reg [31:0] Mem[0:1024];// 1024 x 32 Memory

parameter ADD=6'b000_000, SUB=6'b000_001,AND=6'b000_010,OR=6'b000_011,SLT=6'b000_100,MUL=6'b000_101,LW=6'b001_000,SW=6'b001_001,ADDI=6'b001_010,
	  SUBI=6'b001_011, SLTI=6'b001_100, BNEQZ=6'b001_101, BEQZ=6'b001_100, HLT=6'b111_111;

parameter RR_ALU=3'b000, RM_ALU=3'b001, LOAD=3'b010, STORE=3'b011, BRANCH=3'b100, HALT=3'b101;

reg HALTED ;
	// set after HLT instruction is completedb (in WB stage)
reg TAKEN_BRANCH;
	//Required to disabled instyruction after the branch 

always @(posedge clk1)begin
	if (HALTED == 0)
	begin 
		if( ((EX_MEM_IR[31:26] == BEQZ) && (EX_MEM_cond == 1)) ||  ((EX_MEM_IR[31:26] == BNEQZ )&& (EX_MEM_cond == 0)))
		begin 	
			IF_ID_IR=	<= #2 Mem[EX_MEM_ALUout];
			TAKEN_BRANCH	<= #2 1'b1;
			IF_ID_NPC	<= #2 EX_MEM_ALUout  + 1;
			PC 		<= #2 EX_MEM_ALUout  + 1;
		end
		else 
		  begin 
			IF_ID_IR	<= #2 Mem[PC];
			IF_ID_NPC	<= #2 PC+1;
			PC		<= #2 PC+1;
		  end
	end
end


///////////////////////////////////////////////////////////////////////////////
///////                 Instruction decode stage                        ///////
///////////////////////////////////////////////////////////////////////////////
always @(posedge clk2)
begin 
  if (HALTED == 0)
  begin
	if(IF_ID_IR[25:21] == 5'b00000 )  ID_EX_A <=0;
	else ID_EX_A <= #2 Reg[IF_ID_IR[25:21] ] ; 

	if(IF_ID_IR[20:16] == 5'b00000 )  ID_EX_B <=0;
	else ID_EX_A <= #2 Reg[IF_ID_IR[20:16]] ; 

	ID_EX_NPC	<= #2 IF_ID_NPC;
	ID_EX_IR	<= #2 IF_ID_IR;
	ID_EX_Imm 	<= #2 {{16{IF_ID_IR[15]}},{IF_ID_IR[15:0]}};
	
	case(IF_ID_IR[31:26])
	    ADD,SUB,AND,OR,SLT,MUL : ID_EX_type <= #2 RR_ALU;
	    ADDI, SUBI, SLTI 	   : ID_EX_type <= #2 RM_ALU;
	    LW			   : ID_EX_type <= #2 LOAD;
	    SW			   : ID_EX_type <= #2 STORE;
	    BNEQZ, BEQZ		   : ID_EX_type <= #2 BRANH;
	    HLT			   : ID_EX_type <= #2 HALT;
	    default 		   : ID_EX_type <= #2 HALT;
	endcase
  end
end



 
///////////////////////////////////////////////////////////////////////////////
///////                  Instruction Excute stage                       ///////
///////////////////////////////////////////////////////////////////////////////

always @(posedge clk1)
begin
  if(HALTED == 0)
  begin 
	EX_MEM_type 	<= #2 ID_EX_type;
	EX_MEM_IR	<= #2 ID_EX_IR;
	TAKEN_BRANCH	<= #2 0;
	case(ID_EX_type)
		// Register to register instructions 
	  RR_ALU : begin
		case(ID_EX_IR[31:26])    // OPCODE
		   ADD  : EX_MEM_ALUout	<= #2 ID_EX_A + ID_EX_B;
		   SUB  : EX_MEM_ALUout	<= #2 ID_EX_A - ID_EX_B;
		   AND  : EX_MEM_ALUout	<= #2 ID_EX_A & ID_EX_B;
		   OR   : EX_MEM_ALUout	<= #2 ID_EX_A | ID_EX_B;
		   SLT  : EX_MEM_ALUout	<= #2 ID_EX_A < ID_EX_B;
		   MUL  : EX_MEM_ALUout	<= #2 ID_EX_A * ID_EX_B;
		   default:EX_MEM_ALUout<= #2 32'hxxxxxxxx;
		  endcase
		end
		// Register to Immediate value instructions 
	  RR_ALU : begin
		case(ID_EX_IR[31:26])    // OPCODE
		   ADDI : EX_MEM_ALUout	<= #2 ID_EX_A + ID_EX_Imm;		  
		   SUBI : EX_MEM_ALUout	<= #2 ID_EX_A - ID_EX_Imm;
		   SLTI : EX_MEM_ALUout	<= #2 ID_EX_A < ID_EX_Imm;
		   default:EX_MEM_ALUout<= #2 32'hxxxxxxxx;
		  endcase
		end
	  LOAD , STORE :  begin 
		EX_MEM_ALUout 	<= #2 ID_EX_A + ID_EX_Imm ;
		EX_MEM_B	<= #2 ID_EX_B;
		end
	  BRANCH:  begin 
		EX_MEM_ALUout 	<= #2 ID_EX_NPC + ID_EX_Imm ;
		EX_MEM_cond	<= #2 (ID_EX_A==0);
		end
	endcase
end
///////////////////////////////////////////////////////////////////////////////
///////                    Memory Stage                                 ///////
///////////////////////////////////////////////////////////////////////////////
always @(posedge clk2)
begin
  if (HALTED ==0)
  begin 
	MEM_WB_type <= EX_MEM_type;
	MEM_WB_IR   <= #2 EX_MEM_IR;

	case (EX_MEM_type)
	  RR_ALU,RM_ALU : MEM_WB_ALUout	<= #2 EX_MEM_ALUout ;
	  LOAD 		: MEM_WB_LMD	<= #2 Mem[EX_MEM_ALUout ;
	  STORE 	: if(TAKEN_BRANCH ==0) // DISABLE WRITE 
				Mem[EX_MEM_ALUout] <= #2 EX_MEM_B;
	endcase
  end
end


///////////////////////////////////////////////////////////////////////////////
///////                  Write Back stage                               ///////
///////////////////////////////////////////////////////////////////////////////

always @(posedge clk1)
begin 
   if(TAKEN_BRANCH ==0) // Disable write if branch taken
   case (MEM_WB_type)
	RR_ALU : Reg[MEM_WB_IR[15:11]	<= #2 MEM_WB_ALUout ; //"rd"
	RM_ALU : Reg[MEM_WB_IR[20:16]	<= #2 MEM_WB_ALUout ; //"rT"
	LOAD   : Reg[MEM_WB_IR[20:16]	<= #2 MEM_WB_LMD    ; //"rT"
	HALT   : HALTED <= #2 1'b1;
   endcase
end

endmodule
