--	Mikrokontroler

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
library lpm;
use lpm.lpm_components.all;
library altera;
use altera.altera_primitives_components.all;

entity Microcontroller is
	generic (
				ext_io_addr	: natural := 4609		-- pierwszy adres zewn. IO
	);
	port (		GEN		: in std_logic;
				
				-- wyjscie na szyne zewnetrzna (:TODO: przypisanie pinow)
				V_A		: out std_logic_vector(15 downto 0);
				VI_D	: inout std_logic_vector(7 downto 0);
				V_MRQ, V_IORQ, V_RD, V_WR : out std_logic;
				V_WT	: inout std_logic;
				
				-- sygnaly WE / WY
				L_A		: out std_logic_vector(7 downto 0); -- diody gorny rzad
				L_B		: out std_logic_vector(7 downto 0); -- diody dolny rzad
				P_1		: out std_logic_vector(7 downto 0); -- port danych do LPT (SV1)
				P_2		: in std_logic_vector(7 downto 0); 	-- port stanu z LPT (SV2)
				P_3		: out std_logic_vector(7 downto 0); -- port sterowania do LPT (SV3)
				P_4		: in std_logic_vector(7 downto 0); 	-- port wejsciowy z PS/2 (SV4)
				--P_5		: out std_logic_vector(7 downto 0); -- port SV5 (nieuzywany)
				--P_7		: out std_logic_vector(7 downto 0); -- port SV7 (nieuzywany)
				--SW1B		: in std_logic;					-- przelacznik SW1B, nieuzywany
				--SW2B		: in std_logic;					-- przelacznik SW2B, nieuzywany				
				SW3B	: in std_logic;						-- przelacznik RESET: GND=>RES
				
				DX_REG_ACC_EN		:	out std_logic;							-- Accumulator wr. en.
				DX_ADDR_REG_A		:	out std_logic_vector (2 downto 0);		-- Register A address
				DX_ADDR_REG_B		:	out std_logic_vector (2 downto 0);		-- Register B address
				DX_ADDR_REG_ACC		:	out std_logic_vector (2 downto 0);		-- Accumulator address
				DX_REG_A			: 	out std_logic_vector (7 downto 0)
				
				--DX_AUT_CPU			:	out std_logic_vector (4 downto 0);
				--DX_REGADDRn			: 	out std_logic_vector (15 downto 0)
				--DX_REG_ADDRESS		:	out std_logic_vector (15 downto 0)
				);
	
end entity Microcontroller;

architecture arch_Microcontroller of Microcontroller is
	
	-- sygnaly szyny wewnetrznej
	signal B_A			: std_logic_vector(15 downto 0);
	signal B_D			: std_logic_vector(7 downto 0);
	signal B_MRQ, B_IORQ, B_RD, B_WR, B_WT : std_logic;
	signal RESET		: std_logic;
	
	signal WAIT_CPU		: std_logic;
	
	-- sygnal z PS2 sygnalizujacy ilosc wczytanych kodow
	signal PS2_KEYNUM	: std_logic_vector(7 downto 0);
	
	-- sygnal z LPT sygnalizujacy gotowosc drukarki
	signal LPT_READY	: std_logic;
	
	-- sygnal zezwalajacy na wejscie sygnalu V_WT z zewnatrz
	signal EXTERN_IO_SEL: std_logic;
	
	-- zatrzasniety stan szyny danych z ostatniej operacji
	signal D_LATCH		: std_logic_vector (7 downto 0);
	
	signal DX_DATA		: std_logic_vector (7 downto 0);
	
	component CPU is
		port (
			GEN			:	in std_logic;							-- Clock
			RESET		:	in std_logic;							-- Reset
			ADDR		:	out std_logic_vector (15 downto 0);		-- Address bus
			DATA		:	inout std_logic_vector (7 downto 0);	-- Data bus
			MREQ		:	out std_logic;							-- Memory request
			IORQ		:	out std_logic;							-- I/O request
			WR			: 	out std_logic;							-- Write enable
			RD			:	out std_logic;							-- Read enable
			WT			:	inout std_logic;						-- Wait bus
			WAIT_CPU	: 	out std_logic;							-- Wait cpu
			D_REG_ACC_EN		:	out std_logic;							-- Accumulator wr. en.
			D_ADDR_REG_A		:	out std_logic_vector (2 downto 0);		-- Register A address
			D_ADDR_REG_B		:	out std_logic_vector (2 downto 0);		-- Register B address
			D_ADDR_REG_ACC		:	out std_logic_vector (2 downto 0);		-- Accumulator address
			D_REG_A				: 	out std_logic_vector (7 downto 0)
			--D_DATA		: 	out std_logic_vector (7 downto 0)
			--D_REGADDRn			: 	out std_logic_vector (15 downto 0)
			);
	end component CPU;
	
	component ROM is
		port (	A	: in std_logic_vector (15 downto 0);
				D	: inout std_logic_vector (7 downto 0);
			MRQ, RD	: in std_logic );
	end component ROM;
	
	component RAM is
		port (	A	: in std_logic_vector (15 downto 0);
				D	: inout std_logic_vector (7 downto 0);
		MRQ, RD, WR	: in std_logic );
	end component RAM;
	
	component LPT_OUT is
		port (	GEN : in std_logic;
				RESET:in std_logic;
				A	: in std_logic_vector (7 downto 0);
				D	: in std_logic_vector (7 downto 0);
				IORQ: in std_logic;	
				WR	: in std_logic;	
				WT	: out std_logic;	
				-- sygnal powiadamiajacy o gotowosci drukarki, aktywny '1'
				PRN_READY	: out std_logic;
				-- sygnaly do komunikacji z laczem LPT						
				LCTRL		: out std_logic_vector (7 downto 0); -- SV2: nSI,nI,nAF,nS do LPT
				LSTAT		: in std_logic_vector (7 downto 0);  -- SV3: BS,PE,nF,S z LPT
				LDATASYN	: out std_logic_vector (7 downto 0)  -- SV5: dane do LPT
			);
	end component LPT_OUT;

	component PS2_IN is
		port ( 	GEN		: in std_logic;	-- 20MHz clock 
				RESET	: in std_logic;	-- Reset signal from uC
				-- Bus
				ADDR	: in std_logic_vector (7 downto 0);	-- Address bus
				DATA	: out std_logic_vector (7 downto 0);-- Data bus
				WT	 	: out std_logic;					-- Wait signal
				IORQ	: in std_logic;						-- I/O request signal
				RD		: in std_logic;						-- Read signal
				-- PS/2 debug
				PS2_DEBUG_PORT: out std_logic_vector (7 downto 0);	-- Output port for debugging
				-- PS/2 connection port
				PDATA_IN: in std_logic_vector (7 downto 0)	-- PS/2 bus input port
			);
	end component PS2_IN;
	
	begin
		-- przepisanie stanu wewnetrznej szyny kontrolera na wyjscie
		V_IORQ <= B_IORQ; 
		V_MRQ <= B_MRQ; 
		V_RD <= B_RD; 
		V_WR <= B_WR; 
		V_A <= B_A;
		
		-- sygnal resetujacy z przelacznika 3
		RESET		<= SW3B;

		-- sygnalizacja na diodach
		L_A(7 downto 2) <= (others => '0');		
		L_A(1 downto 0) <= PS2_KEYNUM(7 downto 6);
		L_B(7 downto 3) <= (others => '0');
		L_B(2 downto 0) <= PS2_KEYNUM(2 downto 0);
		
	-- zatrzasniecie stanu linii danych przy kazdej operacji IO / MEM (debug)
	dl: process (VI_D, B_MRQ, B_IORQ, D_LATCH) is
		begin
			if ((B_MRQ = '0') OR (B_IORQ = '0')) then
				D_LATCH(7 downto 0) <= VI_D(7 downto 0);
			else
				D_LATCH(7 downto 0) <= D_LATCH(7 downto 0);
			end if;
		end process;
		
	-- wybranie wejscia WT z zewnetrznego IO
	extern_io: process (B_IORQ, B_A) is
		begin
			if ((B_IORQ = '0') AND (unsigned(B_A) >= ext_io_addr)) then
				EXTERN_IO_SEL <= '1';
			else
				EXTERN_IO_SEL <= '0';
			end if;
		end process;
		
	-- wpuszczenie zewnetrznego sygnalu WAIT na szyne przy wyborze urzadzenia IO	
	t1: TRI port map (V_WT, EXTERN_IO_SEL, B_WT);
	
	-- przepisanie wewnetrznego sygnalu WAIT na wyjscie
	V_WT <= B_WT;
	
	e9: CPU port map (GEN, RESET, B_A, VI_D, B_MRQ, B_IORQ, B_WR, B_RD, B_WT, WAIT_CPU, DX_REG_ACC_EN,DX_ADDR_REG_A,DX_ADDR_REG_B,DX_ADDR_REG_ACC,DX_REG_A);
	
	e0: ROM port map (B_A, VI_D, B_MRQ, B_RD);
	
	e1: RAM port map (B_A, VI_D, B_MRQ, B_RD, B_WR);
	
	e2: LPT_OUT port map (GEN, RESET, B_A(7 downto 0), VI_D, B_IORQ, B_WR, B_WT,LPT_READY, P_3, P_2, P_1);
							
	e3:	PS2_IN port map (GEN, RESET, B_A(7 downto 0), VI_D, B_WT, B_IORQ, B_RD, PS2_KEYNUM, P_4);
	
end architecture arch_Microcontroller;