--	Mikrokontroler

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
library lpm;
use lpm.lpm_components.all;
library altera;
use altera.altera_primitives_components.all;

entity Microcontroller is
	port (		GEN		: in std_logic;
				
				-- wyjscie na szyne zewnetrzna
				--OUT_A		: out std_logic_vector(15 downto 0);
				--OUT_D		: out std_logic_vector(7 downto 0);
				--OUT_MRQ, OUT_IORQ, OUT_RD, OUT_WR : out std_logic;
				
				-- debug
				V_A		: in std_logic_vector(15 downto 0);
				VI_D	: inout std_logic_vector(7 downto 0);
				VO_D	: out std_logic_vector(7 downto 0);
				V_MRQ, V_IORQ, V_RD, V_WR : in std_logic;
				V_WT	: out std_logic;
				
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
				SW3B	: in std_logic						-- przelacznik RESET: GND=>RES
				);
	
end entity Microcontroller;

architecture arch_Microcontroller of Microcontroller is
	
	-- sygnaly szyny wewnetrznej
	signal B_A			: std_logic_vector(15 downto 0);
	signal B_D			: std_logic_vector(7 downto 0);
	signal B_MRQ, B_IORQ, B_RD, B_WR, B_WT : std_logic;
	signal RESET		: std_logic;
	
	-- sygnal z PS2 sygnalizujacy ilosc wczytanych kodow
	signal PS2_KEYNUM	: std_logic_vector(7 downto 0);
	
	-- sygnal z LPT sygnalizujacy gotowosc drukarki
	signal LPT_READY	: std_logic;
	
	
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
		--OUT_A <= B_A; OUT_D <= B_D;
		--OUT_MRQ <= B_MRQ; OUT_IORQ <= B_IORQ; OUT_RD <= B_RD; OUT_WR <= B_WR;
		
		-- debug
		B_A <= V_A; 
		B_D <= VI_D; -- :TODO: B_D nieuzywane, uzyte VI_D!
		--VO_D <= B_D;
		B_MRQ <= V_MRQ; B_IORQ <= V_IORQ; B_RD <= V_RD; B_WR <= V_WR; V_WT<=B_WT;
		
		-- sygnal resetujacy z przelacznika 3
		RESET		<= SW3B;

		-- sygnalizacja na diodach
		L_A			<= (LPT_READY & B_WT & "111" & PS2_KEYNUM(2 downto 0));
		L_B			<= VI_D; -- :TODO: powinno byc B_D
	
	e0: ROM port map (B_A, VI_D, B_MRQ, B_RD);
	
	e1: RAM port map (B_A, VI_D, B_MRQ, B_RD, B_WR);
	
	e2: LPT_OUT port map (GEN, RESET, B_A(7 downto 0), VI_D, B_IORQ, B_WR, B_WT, 
							LPT_READY, P_3, P_2, P_1);
							
	e3:	PS2_IN port map (GEN, RESET, B_A(7 downto 0), B_D, B_WT, B_IORQ, B_RD, PS2_KEYNUM, P_4);
	
end architecture arch_Microcontroller;