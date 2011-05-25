library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
library lpm;
use lpm.lpm_components.all;
library altera;
use altera.altera_primitives_components.all;

entity CPU is 
	port (
			GEN			:	in std_logic;							-- Clock
			RESET		:	in std_logic;							-- Reset
			ADDR		:	out std_logic_vector (15 downto 0);		-- Address bus
			DATA		:	inout std_logic_vector (7 downto 0);	-- Data bus
			MREQ		:	out std_logic;							-- Memory request
			IORQ		:	out std_logic;							-- I/O request
			WR			: 	out std_logic;							-- Write enable
			RD			:	out std_logic;							-- Read enable
			WT			:	in std_logic;							-- Wait bus
			WAIT_CPU	: 	out std_logic;							-- Wait cpu
		
			-- debug
			D_REG_ACC_EN		:	out std_logic;							-- Accumulator wr. en.
			D_ADDR_REG_A		:	out std_logic_vector (2 downto 0);		-- Register A address
			D_ADDR_REG_B		:	out std_logic_vector (2 downto 0);		-- Register B address
			D_ADDR_REG_ACC		:	out std_logic_vector (2 downto 0);		-- Accumulator address
			D_REG_A				: 	out std_logic_vector (7 downto 0);
			
			D_DATA				: 	out std_logic_vector (7 downto 0);
			D_REGADDRn			: 	out std_logic_vector (15 downto 0);
			D_REG_ADDRESS		:	out std_logic_vector (15 downto 0);
			D_AUT_CPU			:	out std_logic_vector (4 downto 0);
			D_AUT_BUS			:	out std_logic_vector (2 downto 0);
			D_PC				:	out std_logic_vector (15 downto 0)
			
			--D_REG_PC			:	out std_logic_vector (15 downto 0);
			--D_REG_PCn			:	out std_logic_vector (15 downto 0);
			--D_REG_PCx			:	out std_logic_vector (15 downto 0);
			--D_REG_CMD			:	out std_logic_vector (23 downto 0);
			--D_REG_CMDn			:	out std_logic_vector (23 downto 0)
		);
end entity CPU;

architecture CPU_module of CPU is
	-- Signals 
	signal SIG_DATA 		: 	std_logic_vector (7 downto 0);		-- Tri-state data output
	signal SIG_IS_IO		: 	std_logic;							-- Is I/O request
	signal SIG_IS_WR		:	std_logic;							-- Is write
	signal SIG_WAIT			:	std_logic;							-- Tri-state wait output
	signal SIG_BUS_START	:	std_logic;							-- Start bus communication
	signal SIG_BUS_STOP		:	std_logic;							-- Stop bus communication
	-- System registers
	signal REG_ADDRESS		:	std_logic_vector (15 downto 0);		-- Current PC address
	signal REG_PC			:	std_logic_vector (15 downto 0);		-- Program counter
	signal REG_PCn			:	std_logic_vector (15 downto 0);		-- Next program counter
	signal REG_PCx			:	std_logic_vector (15 downto 0);		-- Intermediate PC
	signal REG_CMD			:	std_logic_vector (23 downto 0);		-- Current command
	signal REG_CMDn			:	std_logic_vector (23 downto 0);		-- Next current command
	-- Bus
	signal REG_ADDR			:	std_logic_vector (15 downto 0);		-- Bus address
	signal REG_ADDRn		:	std_logic_vector (15 downto 0);		-- Next bus address
	signal REG_DATA			:	std_logic_vector (7 downto 0);		-- Bus data
	signal REG_DATAn		:	std_logic_vector (7 downto 0);		-- Next bus data
	signal SIG_MREQ			:	std_logic;							-- Bus memory request
	signal SIG_MREQn		:	std_logic;							-- Next bus mem. req.
	signal SIG_IORQ			:	std_logic;							-- Bus I/O request
	signal SIG_IORQn		:	std_logic;							-- Next bus I/O req.
	signal SIG_RD			:	std_logic;							-- Bus read enable
	signal SIG_RDn			:	std_logic;							-- Next bus read en.
	signal SIG_WR			:	std_logic;							-- Bus write enable
	signal SIG_WRn			:	std_logic;							-- Next bus write en.
	signal SIG_DOUT			:	std_logic;							-- Enables DATA output to bus
	signal SIG_DOUTn		:	std_logic;
	-- State machines
	-- Main CPU state machine ( instruction fetch etc. )
	signal AUT_CPU			: 	std_logic_vector (4 downto 0);
	signal AUT_CPUn			:	std_logic_vector (4 downto 0);
	---- AUT_CPU states
	constant AUT_CPU_FETCH			:	std_logic_vector (4 downto 0) := "00000";
	constant AUT_CPU_CMD			:	std_logic_vector (4 downto 0) := "00001";
	constant AUT_CPU_CMD1			:	std_logic_vector (4 downto 0) := "00010";
	constant AUT_CPU_CMD2			:	std_logic_vector (4 downto 0) := "00011";
	constant AUT_CPU_CMD3			:	std_logic_vector (4 downto 0) := "00100";
	constant AUT_CPU_CMD4			:	std_logic_vector (4 downto 0) := "00101";
	constant AUT_CPU_CMD5			:	std_logic_vector (4 downto 0) := "00110";
	constant AUT_CPU_CMD6			:	std_logic_vector (4 downto 0) := "00111";
	constant AUT_CPU_EXE			:	std_logic_vector (4 downto 0) := "01000";
	constant AUT_CPU_RAM_WR1		:	std_logic_vector (4 downto 0) := "01001";
	constant AUT_CPU_RAM_WR2		:	std_logic_vector (4 downto 0) := "01010";
	
	constant AUT_CPU_RAM_WR3		:	std_logic_vector (4 downto 0) := "11000";
	constant AUT_CPU_RAM_WR4		:	std_logic_vector (4 downto 0) := "11001";
	
	constant AUT_CPU_OUT1			:	std_logic_vector (4 downto 0) := "01100";
	constant AUT_CPU_OUT2			:	std_logic_vector (4 downto 0) := "01101";

	constant AUT_CPU_IN1			:	std_logic_vector (4 downto 0) := "01111";
	constant AUT_CPU_IN2			:	std_logic_vector (4 downto 0) := "10000";
	constant AUT_CPU_IN3			:	std_logic_vector (4 downto 0) := "10001";
	
	constant AUT_CPU_RAM_RD1		:	std_logic_vector (4 downto 0) := "10011";
	constant AUT_CPU_RAM_RD2		:	std_logic_vector (4 downto 0) := "10100";
	constant AUT_CPU_MUL			:	std_logic_vector (4 downto 0) := "10101";
	
	constant AUT_CPU_RAM_RD3		:	std_logic_vector (4 downto 0) := "11010";
	constant AUT_CPU_RAM_RD4		:	std_logic_vector (4 downto 0) := "11011";
	
	constant AUT_CPU_FETCH2			:	std_logic_vector (4 downto 0) := "11111";

	-- Bus communication state machine ( mreq, iorq, rd, wr etc. )
	signal AUT_BUS			:	std_logic_vector (2 downto 0);
	signal AUT_BUSn			:	std_logic_vector (2 downto 0);
	---- AUT_BUS states
	constant AUT_BUS_START		:	std_logic_vector (2 downto 0) := "000";
	constant AUT_BUS_CYCLE1		:	std_logic_vector (2 downto 0) := "001";
	constant AUT_BUS_CYCLE2		:	std_logic_vector (2 downto 0) := "010";
	constant AUT_BUS_STOP		:	std_logic_vector (2 downto 0) := "011"; 
	constant AUT_BUS_WAIT		: 	std_logic_vector (2 downto 0) := "100";
	constant AUT_BUS_WAIT2		:	std_logic_vector (2 downto 0) := "101";
	constant AUT_BUS_WAIT3		:	std_logic_vector (2 downto 0) := "110";
	-- Universal registers
	signal REG_ACC_EN		:	std_logic;							-- Accumulator wr. en.
	signal REG_ACC_ENn		:	std_logic;
	signal ADDR_REG_A		:	std_logic_vector (2 downto 0);		-- Register A address
	signal ADDR_REG_B		:	std_logic_vector (2 downto 0);		-- Register B address
	signal ADDR_REG_ACC		:	std_logic_vector (2 downto 0);		-- Accumulator address
	signal REG_A			:	std_logic_vector (7 downto 0);		-- Register A
	signal REG_B			:	std_logic_vector (7 downto 0);		-- Register B
	signal REG_ACC			:	std_logic_vector (7 downto 0);		-- Accumulator Register
	signal REG_ACCn			:	std_logic_vector (7 downto 0);		-- Accumulator Register
	signal REG_ACCx			:	std_logic_vector (7 downto 0);		-- Accumulator Reg. inter.
	signal MUL_RES			:	std_logic_vector (7 downto 0);		-- Multiplication result
	signal MUL_GO			: 	std_logic;							-- 0 => starts MUL operation
	signal MUL_READY		:	std_logic;							-- 0 => MUL result ready
	-- RegA o RegB
	signal REG_A2			:	std_logic_vector (7 downto 0);		-- Register A2
	signal REG_B2			:	std_logic_vector (7 downto 0);		-- Register B2
	
	component MUL is 
		port (
			GEN		: in std_logic;
			RESET	: in std_logic;
			A 		: in std_logic_vector (7 downto 0);
			B 		: in std_logic_vector (7 downto 0);
			RESULT 	: out std_logic_vector (7 downto 0);-- wynik mnozenia
			GO		: in std_logic;		-- uruchamia MUL, aktywne LOW
			READY	: out std_logic		-- czy wynik gotowy? (LOW)
		);
	end component MUL;
	 
	begin

	AUT_CPU_PROC:
		process	(
					AUT_CPU,
					SIG_BUS_STOP,
					REG_DATA,
					REG_CMD,
					REG_PC,
					REG_PCx,
					SIG_DATA,
					REG_A,
					REG_B,
					REG_A2,
					REG_B2,
					REG_ACCx,
					REG_ACC,
					ADDR_REG_ACC,
					MUL_READY,
					MUL_RES
					--
					--
					--
				) is
				
				begin
					REG_DATAn<=REG_DATA;
					REG_CMDn<=REG_CMD;
					REG_PCn<=REG_PC;
					REG_ACC_ENn<='0';
					REG_ACCn<=REG_ACC;
					--
					REG_ADDRESS<=REG_PC;
					
					ADDR_REG_ACC <= REG_CMD(18 downto 16);
					ADDR_REG_A <= REG_CMD(14 downto 12);
					ADDR_REG_B <= REG_CMD(10 downto 8);
					--
					--
					SIG_BUS_START<='0';
					SIG_IS_IO<='0';
					SIG_IS_WR<='0';
					REG_PCx<=unsigned(REG_PC)+1;
					--
					MUL_GO <= '1';
					
					case AUT_CPU is		
						when AUT_CPU_FETCH =>
							--
							--SIG_BUS_START<='1';
							--REG_CMDn<=(others => '0');
							
							AUT_CPUn<=AUT_CPU_FETCH2;
							
						when AUT_CPU_FETCH2 =>
							--
							SIG_BUS_START<='1';
							--REG_CMDn<=(others => '0');
							
							AUT_CPUn<=AUT_CPU_CMD;
							
						when AUT_CPU_CMD =>
							--
							REG_CMDn(23 downto 16)<=SIG_DATA;
							if SIG_BUS_STOP='0'then
								AUT_CPUn<=AUT_CPU_CMD;
							else
								AUT_CPUn<=AUT_CPU_CMD1;
							end if;
						
						when AUT_CPU_CMD1 =>
							REG_PCn<=std_logic_vector(REG_PCx);
							--
							--
							if	(REG_CMD(23 downto 19)="00000") or
								(REG_CMD(23 downto 19)="01111") then
								AUT_CPUn<=AUT_CPU_EXE;
							else
								AUT_CPUn<=AUT_CPU_CMD2;
							end if;
							--
						when AUT_CPU_CMD2 =>
							AUT_CPUn<=AUT_CPU_CMD3;
							
						when AUT_CPU_CMD3 =>
							SIG_BUS_START<='1';
							REG_CMDn(15 downto 8)<=SIG_DATA;
							if SIG_BUS_STOP='0' then
								AUT_CPUn<=AUT_CPU_CMD3;
							else
								AUT_CPUn<=AUT_CPU_CMD4;
							end if;
							
						when AUT_CPU_CMD4 =>
							REG_PCn<=std_logic_vector(REG_PCx);
							--
							--
							if	(REG_CMD(23 downto 19)="01010") or
								(REG_CMD(23 downto 19)="01011") then
								AUT_CPUn<=AUT_CPU_CMD5;
							else
								REG_A2<=REG_A;
								REG_B2<=REG_B;
								AUT_CPUn<=AUT_CPU_EXE;
							end if;
							
						when AUT_CPU_CMD5 =>
							AUT_CPUn<=AUT_CPU_CMD6;
							
						when AUT_CPU_CMD6 =>
							SIG_BUS_START<='1';
							REG_CMDn(7 downto 0)<=SIG_DATA;
							if SIG_BUS_STOP='0' then
								AUT_CPUn<=AUT_CPU_CMD6;
							else
								REG_PCn<=std_logic_vector(REG_PCx);
								AUT_CPUn<=AUT_CPU_EXE;
							end if;
							
						-- 1 byte: 00000,01111
						-- 2 byte: 00001,00010,00011,00100,00101,00110,00111,01000,01001
						--		   01100,01101,01110,11110
						-- 3 byte: 01010,01011
						when AUT_CPU_EXE =>
							--

							-- [00] JMP 0 (1 byte)
							if		REG_CMD(23 downto 19)="00000" then
									REG_PCn<=(others => '0');
									
									AUT_CPUn<=AUT_CPU_FETCH;
								  
							-- [01] JMP Rd=0,A (2 byte)
							elsif 	REG_CMD(23 downto 19)="00001" then
									if signed(REG_ACC) = 0 then
										REG_PCn(15 downto 8)<="00000000";
										REG_PCn(7 downto 0)<=REG_CMD(15 downto 8);
									end if;
									
									AUT_CPUn<=AUT_CPU_FETCH;
							
							-- [02] JMP A (2 byte)
							elsif	REG_CMD(23 downto 19)="00010" then
									REG_PCn(15 downto 8)<="00000000";
									REG_PCn(7 downto 0)<=REG_CMD(15 downto 8);
									
									AUT_CPUn<=AUT_CPU_FETCH;
							
							-- [03] Rd<=Ra (2 byte)
							elsif	REG_CMD(23 downto 19)="00011" then
									REG_ACCn<=REG_A;
									REG_ACC_ENn<='1';
									
									AUT_CPUn<=AUT_CPU_FETCH;
							
							-- [04] Rd<=Ra+Rb (2 byte)
							elsif	REG_CMD(23 downto 19)="00100" then
									REG_ACCx<=signed(REG_A)+signed(REG_B);
									REG_ACCn<=std_logic_vector(REG_ACCx);
									REG_ACC_ENn<='1';
									
									AUT_CPUn<=AUT_CPU_FETCH;
							
							-- [05] Rd<=Ra-Rb (2 byte)
							elsif	REG_CMD(23 downto 19)="00101" then
									REG_ACCx<=signed(REG_A)-signed(REG_B);
									REG_ACCn<=std_logic_vector(REG_ACCx);
									REG_ACC_ENn<='1';
									
									AUT_CPUn<=AUT_CPU_FETCH;
							
							-- [06] Rd<=Ra#Rb (2 byte)
							elsif	REG_CMD(23 downto 19)="00110" then
									REG_ACCn<=REG_A or REG_B;
									REG_ACC_ENn<='1';
									
									AUT_CPUn<=AUT_CPU_FETCH;
							
							-- [07] Rd<=Ra&Rb (2 byte)
							elsif	REG_CMD(23 downto 19)="00111" then
									REG_ACCn<=REG_A and REG_B;
									REG_ACC_ENn<='1';
									
									AUT_CPUn<=AUT_CPU_FETCH;
							
							-- [08] Rd<=RAM(RaoRb) (2 byte) NIETESTOWANE
							elsif	REG_CMD(23 downto 19)="01000" then
									REG_ADDRESS(15 downto 8)<=REG_A(7 downto 0);
									REG_ADDRESS(7 downto 0)<=REG_B(7 downto 0);
									
									
									
									AUT_CPUn<=AUT_CPU_RAM_RD3;
									
							-- [09] Rd=>RAM(RaoRb) (2 byte) NIETESTOWANE
							elsif	REG_CMD(23 downto 19)="01001" then
							-- bedzie problem, bo chcemy czytac naraz z trzech rejestrow
							-- musimy spamietac na boku albo RaoRb albo Rd
									REG_ADDRESS(15 downto 8)<=REG_A2(7 downto 0);
									REG_ADDRESS(7 downto 0)<=REG_B2(7 downto 0);
									
									ADDR_REG_A <= ADDR_REG_ACC; -- Rd becomes source
							
									AUT_CPUn<=AUT_CPU_RAM_WR3;
									
							-- [0A] Rd<=RAM(A) (3 byte)
							elsif	REG_CMD(23 downto 19)="01010" then
									REG_ADDRESS(15 downto 8)<=REG_CMD(7 downto 0);
									REG_ADDRESS(7 downto 0)<=REG_CMD(15 downto 8);
									
									AUT_CPUn<=AUT_CPU_RAM_RD1;
									
							-- [0B] Rd=>RAM(A) (3 byte)
							elsif	REG_CMD(23 downto 19)="01011" then
									REG_ADDRESS(15 downto 8)<=REG_CMD(7 downto 0);
									REG_ADDRESS(7 downto 0)<=REG_CMD(15 downto 8);
									ADDR_REG_A <= ADDR_REG_ACC; -- Rd becomes source
									
									AUT_CPUn<=AUT_CPU_RAM_WR1;
									
							-- [0C] Rd<=INP(A) (2 byte) NIETESTOWANE
							elsif	REG_CMD(23 downto 19)="01100" then
									REG_ADDRESS(7 downto 0)<=REG_CMD(15 downto 8);
									
									AUT_CPUn<=AUT_CPU_IN1;
									
							-- [0D] Rd=>OUT(A) (2 byte)
							elsif	REG_CMD(23 downto 19)="01101" then
									--REG_ADDRESS(15 downto 8)<=REG_CMD(7 downto 0);
									REG_ADDRESS(7 downto 0)<=REG_CMD(15 downto 8);
									ADDR_REG_A <= ADDR_REG_ACC; -- Rd becomes source
									
									AUT_CPUn<=AUT_CPU_OUT1;
									
							-- [0E] Rd<=DI (2 byte)
							elsif	REG_CMD(23 downto 19)="01110" then
									REG_ACCn<=REG_CMD(15 downto 8);
									REG_ACC_ENn<='1';
									
									AUT_CPUn<=AUT_CPU_FETCH;
									
							-- [0F] STOP (1 byte)
							elsif	REG_CMD(23 downto 19)="01111" then
							
									AUT_CPUn<=AUT_CPU_EXE;
									
							-- [1E] Rd<=Ra op Rb (2 byte) op == multiply
							elsif	REG_CMD(23 downto 19)="11110" then
									MUL_GO <= '0';	-- start multiplication
									AUT_CPUn<=AUT_CPU_MUL;
									
							--
							-- Command unknown
							else
								AUT_CPUn<=AUT_CPU_FETCH;
							end if;
						
						when AUT_CPU_RAM_WR1 =>
							REG_ADDRESS(15 downto 8)<=REG_CMD(7 downto 0);
							REG_ADDRESS(7 downto 0)<=REG_CMD(15 downto 8);
							SIG_IS_WR<='1';
							
							ADDR_REG_A <= ADDR_REG_ACC;
							REG_DATAn<=REG_A;
							
							SIG_BUS_START<='1';
							AUT_CPUn<=AUT_CPU_RAM_WR2;
							
						when AUT_CPU_RAM_WR2 =>
							REG_ADDRESS(15 downto 8)<=REG_CMD(7 downto 0);
							REG_ADDRESS(7 downto 0)<=REG_CMD(15 downto 8);
							SIG_IS_WR<='1';
							
							ADDR_REG_A <= ADDR_REG_ACC;
							REG_DATAn<=REG_A;
							
							if SIG_BUS_STOP='0' then
								AUT_CPUn<=AUT_CPU_RAM_WR2;
							else
								AUT_CPUn<=AUT_CPU_FETCH;
							end if;
						
						when AUT_CPU_RAM_WR3 =>
							REG_ADDRESS(15 downto 8)<=REG_A2(7 downto 0);
							REG_ADDRESS(7 downto 0)<=REG_B2(7 downto 0);
							SIG_IS_WR<='1';
							
							ADDR_REG_A <= ADDR_REG_ACC;
							REG_DATAn<=REG_A;
							
							SIG_BUS_START<='1';
							AUT_CPUn<=AUT_CPU_RAM_WR4;
							
						when AUT_CPU_RAM_WR4 =>
							REG_ADDRESS(15 downto 8)<=REG_A2(7 downto 0);
							REG_ADDRESS(7 downto 0)<=REG_B2(7 downto 0);
							SIG_IS_WR<='1';
							
							ADDR_REG_A <= ADDR_REG_ACC;
							REG_DATAn<=REG_A;
							
							if SIG_BUS_STOP='0' then
								AUT_CPUn<=AUT_CPU_RAM_WR4;
							else
								AUT_CPUn<=AUT_CPU_FETCH;
							end if;

						
						when AUT_CPU_RAM_RD1 =>
							REG_ADDRESS(15 downto 8)<=REG_CMD(7 downto 0);
							REG_ADDRESS(7 downto 0)<=REG_CMD(15 downto 8);
							SIG_IS_WR<='0';
							
							SIG_BUS_START<='1';
							AUT_CPUn<=AUT_CPU_RAM_RD2;
							
						when AUT_CPU_RAM_RD2 =>
							REG_ADDRESS(15 downto 8)<=REG_CMD(7 downto 0);
							REG_ADDRESS(7 downto 0)<=REG_CMD(15 downto 8);
							SIG_IS_WR<='0';
							REG_DATAn<=SIG_DATA;
							--?
							if SIG_BUS_STOP='0' then
								AUT_CPUn<=AUT_CPU_RAM_RD2;
							else
								REG_ACCn<=SIG_DATA;
								REG_ACC_ENn<='1';	-- now write data to Rd
								AUT_CPUn<=AUT_CPU_FETCH;
							end if;
						
						when AUT_CPU_RAM_RD3 =>
							REG_ADDRESS(15 downto 8)<=REG_A(7 downto 0);
							REG_ADDRESS(7 downto 0)<=REG_B(7 downto 0);
							SIG_IS_WR<='0';
							
							SIG_BUS_START<='1';
							AUT_CPUn<=AUT_CPU_RAM_RD4;
							
						when AUT_CPU_RAM_RD4 =>
							REG_ADDRESS(15 downto 8)<=REG_A(7 downto 0);
							REG_ADDRESS(7 downto 0)<=REG_B(7 downto 0);
							SIG_IS_WR<='0';
							REG_DATAn<=SIG_DATA;
							--?
							if SIG_BUS_STOP='0' then
								AUT_CPUn<=AUT_CPU_RAM_RD4;
							else
								REG_ACCn<=SIG_DATA;
								REG_ACC_ENn<='1';	-- now write data to Rd
								AUT_CPUn<=AUT_CPU_FETCH;
							end if;
						
						when AUT_CPU_OUT1 =>
							REG_ADDRESS(7 downto 0)<=REG_CMD(15 downto 8);
							ADDR_REG_A <= ADDR_REG_ACC; -- Rd becomes source
							SIG_IS_WR<='1';
							SIG_IS_IO<='1';
							
							REG_DATAn<=REG_A;
							SIG_BUS_START<='1';
							AUT_CPUn<=AUT_CPU_OUT2;
							
						when AUT_CPU_OUT2 =>
							REG_ADDRESS(7 downto 0)<=REG_CMD(15 downto 8);
							ADDR_REG_A <= ADDR_REG_ACC; -- Rd becomes source
							SIG_IS_WR<='1';
							SIG_IS_IO<='1';
							
							REG_DATAn<=REG_A;
							if SIG_BUS_STOP='0' then
								AUT_CPUn<=AUT_CPU_OUT2;
							else
								AUT_CPUn<=AUT_CPU_FETCH;
							end if;
							
						when AUT_CPU_IN1 =>
							--REG_ADDRESS(15 downto 8)<=REG_CMD(7 downto 0);
							REG_ADDRESS(7 downto 0)<=REG_CMD(15 downto 8);
							SIG_IS_WR<='0';
							SIG_IS_IO<='1';
							
							SIG_BUS_START<='1';
							--SIG_BUS_START<='1';
							AUT_CPUn<=AUT_CPU_IN2;
							
						when AUT_CPU_IN2 =>
							--REG_ADDRESS(15 downto 8)<=REG_CMD(7 downto 0);
							REG_ADDRESS(7 downto 0)<=REG_CMD(15 downto 8);
							SIG_IS_WR<='0';
							SIG_IS_IO<='1';
							
							REG_DATAn<=SIG_DATA;
							--?
							if SIG_BUS_STOP='0' then
								AUT_CPUn<=AUT_CPU_IN2;
							else
								AUT_CPUn<=AUT_CPU_IN3;
							end if;
							
						when AUT_CPU_IN3 =>
							--REG_ADDRESS(15 downto 8)<=REG_CMD(7 downto 0);
							REG_ADDRESS(7 downto 0)<=REG_CMD(15 downto 8);
							SIG_IS_WR<='0';
							SIG_IS_IO<='1';
							
							REG_DATAn<=SIG_DATA;
							REG_ACCn<=REG_DATA;
							REG_ACC_ENn<='1';
							
							AUT_CPUn<=AUT_CPU_FETCH;
							
							MUL_GO <= '0';	-- start multiplication
							
						when AUT_CPU_MUL =>
							if MUL_READY = '0' then
								REG_ACCn <= MUL_RES;
								REG_ACC_ENn <= '1';
								AUT_CPUn <= AUT_CPU_FETCH;
							else
								AUT_CPUn <= AUT_CPU_MUL;
							end if;
						
						when others =>
							AUT_CPUn<=AUT_CPU;
						
					end case;
				end process AUT_CPU_PROC;
						
	AUT_BUS_PROC:
		process (
					AUT_BUS,
					SIG_BUS_START,
					REG_ADDR,
					SIG_WAIT,
					REG_ADDRESS,
					SIG_IS_IO,
					SIG_IS_WR,
					SIG_MREQ,
					SIG_IORQ,
					SIG_RD,
					SIG_WR,
					SIG_DOUT
				) is
				
			begin
				
				SIG_MREQn<='1';
				SIG_IORQn<='1';
				SIG_RDn<='1';
				SIG_WRn<='1';
				SIG_DOUTn<='1';
				SIG_BUS_STOP<='0';
				REG_ADDRn<=REG_ADDR;
				
				if SIG_WAIT='1' then 
					WAIT_CPU<='0';
				else
					WAIT_CPU<='1';
				end if;
				
				case AUT_BUS is
	
					when AUT_BUS_START =>
						if SIG_BUS_START='0' then
							REG_ADDRn<=REG_ADDRESS;
							AUT_BUSn<=AUT_BUS_START;
						else
							AUT_BUSn<=AUT_BUS_CYCLE1;
						if SIG_IS_WR='1' then
							SIG_DOUTn<='0';
						end if;
					end if;
					
					when AUT_BUS_CYCLE1 =>
						SIG_DOUTn <= SIG_DOUT;
						if SIG_IS_IO='0' then
							SIG_MREQn<='0';
						else
							SIG_IORQn<='0';
						end if;
						
						if SIG_IS_WR='0' then
							SIG_RDn<='0';
						else
							SIG_WRn<='0';
						end if;
						AUT_BUSn<=AUT_BUS_CYCLE2;
						
					when AUT_BUS_CYCLE2 =>
						SIG_DOUTn <= SIG_DOUT;
						SIG_MREQn<=SIG_MREQ;
						SIG_IORQn<=SIG_IORQ;
						SIG_RDn<=SIG_RD;
						SIG_WRn<=SIG_WR;
						AUT_BUSn<=AUT_BUS_WAIT;
						
					when AUT_BUS_WAIT =>
						SIG_DOUTn <= SIG_DOUT;
						SIG_MREQn<=SIG_MREQ;
						SIG_IORQn<=SIG_IORQ;
						SIG_RDn<=SIG_RD;
						SIG_WRn<=SIG_WR;
						if SIG_WAIT='0' then
							AUT_BUSn<=AUT_BUS_WAIT;
						else
							if SIG_IS_IO = '1' then
								AUT_BUSn<=AUT_BUS_WAIT2;
							else
								AUT_BUSn<=AUT_BUS_STOP;
							end if;
						end if;
					
					when AUT_BUS_WAIT2 => -- for IO only
						SIG_DOUTn <= SIG_DOUT;
						SIG_MREQn<=SIG_MREQ;
						SIG_IORQn<=SIG_IORQ;
						SIG_RDn<=SIG_RD;
						SIG_WRn<=SIG_WR;
						if SIG_WAIT='0' then
							AUT_BUSn<=AUT_BUS_WAIT2;
						else
							AUT_BUSn<=AUT_BUS_STOP;
						end if;
						
					when AUT_BUS_STOP =>
						REG_ADDRn<=REG_ADDRESS;
						SIG_BUS_STOP<='1';
						
						if SIG_BUS_START='0' then
							AUT_BUSn<=AUT_BUS_START;
						else
							AUT_BUSn<=AUT_BUS_STOP;
						end if;
			
					when others =>
						REG_ADDRn<=REG_ADDRESS;
						SIG_BUS_STOP<='1';
						
						if SIG_BUS_START='0' then
							AUT_BUSn<=AUT_BUS_START;
						else
							AUT_BUSn<=AUT_BUS_STOP;
						end if;
				
				end case;
			end process AUT_BUS_PROC;
			
	ADDR<=REG_ADDR;
	MREQ<=SIG_MREQ;
	IORQ<=SIG_IORQ;
	RD<=SIG_RD;
	WR<=SIG_WR;
	
	D_REGADDRn <= REG_ADDRn;
	D_REG_ADDRESS <= REG_ADDRESS;
	
	mul0: MUL port map (GEN, RESET, REG_A, REG_B, MUL_RES, MUL_GO, MUL_READY);
			
	e0: lpm_bustri
		generic map 
		(
			LPM_WIDTH =>8
		)
		port map 
		(
			data=>REG_DATA, 
			result=>SIG_DATA, 
			tridata=>DATA,
			enabledt=>not SIG_DOUT,
			enabletr=>not SIG_RD
		);
	
--	e1: tri
--		port map 
--		(
--			a_in=>WT,
--			oe=>'1',
--			a_out=>SIG_WAIT
--		);
--		
	SIG_WAIT <= WT;

	uni_reg_A: lpm_ram_dp
		generic map 
		(
			LPM_WIDTH=>8,
			LPM_WIDTHAD=>3,
			LPM_NUMWORDS=>8,
			LPM_INDATA=>"REGISTERED",
			LPM_OUTDATA=>"UNREGISTERED",
			LPM_RDADDRESS_CONTROL=>"UNREGISTERED",
			LPM_WRADDRESS_CONTROL=>"UNREGISTERED"
		)
		port map 
		(
			rdaddress=> ADDR_REG_A,
			wraddress=> ADDR_REG_ACC,
			wren=> REG_ACC_EN,
			wrclock=> GEN,
			data=> REG_ACC,
			q=> REG_A 
		);
	
	uni_reg_B: lpm_ram_dp
		generic map 
		(
			LPM_WIDTH=>8,
			LPM_WIDTHAD=>3,
			LPM_NUMWORDS=>8,
			LPM_INDATA=>"REGISTERED",
			LPM_OUTDATA=>"UNREGISTERED",
			LPM_RDADDRESS_CONTROL=>"UNREGISTERED",
			LPM_WRADDRESS_CONTROL=>"UNREGISTERED"
		)
		port map 
		(
			rdaddress=> ADDR_REG_B,
			wraddress=> ADDR_REG_ACC,
			wren=> REG_ACC_EN,
			wrclock=> GEN,
			data=> REG_ACC,
			q=> REG_B
		);
					
	CLOCK_PROC:
		process (
					GEN,
					RESET
				) is
				
				begin
					if RESET='0' then
						AUT_CPU<=(others => '0');
						AUT_BUS<=(others => '0');
						REG_ADDR<=(others => '0');
						REG_DATA<=(others => '0');
						SIG_MREQ<='1';
						SIG_IORQ<='1';
						SIG_RD<='1';
						SIG_WR<='1';
						REG_PC<=(others => '0');
						REG_CMD<=(others => '0');
						
					elsif rising_edge(GEN) then
						AUT_CPU<=AUT_CPUn;
						AUT_BUS<=AUT_BUSn;
						REG_ADDR<=REG_ADDRn;
						REG_DATA<=REG_DATAn;
						SIG_MREQ<=SIG_MREQn;
						SIG_IORQ<=SIG_IORQn;
						SIG_RD<=SIG_RDn;
						SIG_WR<=SIG_WRn;
						SIG_DOUT<=SIG_DOUTn;
						REG_PC<=REG_PCn;
						REG_CMD<=REG_CMDn;
						REG_ACC_EN<=REG_ACC_ENn;
						REG_ACC<=REG_ACCn;
					end if;
				end process CLOCK_PROC;
				
	-- debug
	D_AUT_CPU<=AUT_CPU;
	D_AUT_BUS<=AUT_BUS;
	D_PC<=REG_PC;
	--D_DATA <= REG_DATA;
	D_DATA <= REG_ADDR(7 downto 0);
	
	D_REG_ACC_EN	<= REG_ACC_EN;
	D_ADDR_REG_A	<= ADDR_REG_A;
	D_ADDR_REG_B	<= ADDR_REG_B;
	D_ADDR_REG_ACC	<= ADDR_REG_ACC;
	D_REG_A			<= REG_A;
end architecture CPU_module;