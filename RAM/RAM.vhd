--	Blok pamieci RAM	: 1099B
--	Przestrzen adresowa	: 0x1000..0x144A (4096..5194)
--	Czas ustalenia sie D przy odczycie: 25ns
--	Czas wyjscia z szyny D po cofnieciu MRQ i RD: 20ns
--	Czas zapisu: 10ns (!MRQ&!WR&A), 
--	 ale po cofnieciu MRQ i WR: A i D musza pozostac niezmienione przez 10ns
--	Poniewaz T(CPU) = 1/f = 50ns > 25ns > 10ns, RAM nie wystawia sygnalu WT.

--	Wersja z zatrzaskiwaniem:
--	Czas ustalenia sie D przy odczycie: 30ns
--		UWAGA: A i D musza byc ustalone na 10ns przed opuszczeniem MRQ i RD
--	Czas wyjscia z szyny D po odczycie: 15ns
--	Czas zapisu: 20ns
--		UWAGA: A i D musza byc ustalone na 20ns przed opuszczeniem MRQ i WR

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
library lpm;
use lpm.lpm_components.all;
library altera;
use altera.altera_primitives_components.all;

entity RAM is
	generic (	base_addr	: natural := 4096;	-- adres bazowy w przestrzeni adr
				last_addr	: natural := 5194 );-- ostatni adres w przestrzeni adr	

	port (	A	: in std_logic_vector (15 downto 0);
			D	: inout std_logic_vector (7 downto 0);
	MRQ, RD, WR	: in std_logic
--	V_CSR :out std_logic;
--	V_CSW : out std_logic;
--	V_LD : out std_logic_vector (7 downto 0);
--	V_LA : out std_logic_vector (10 downto 0);
--	V_RIO : out std_logic_vector (7 downto 0) 
	);
	
end entity RAM;

architecture arch_RAM of RAM is
	signal CSEL, CSW, CSR	: std_logic; -- zdekodowane sygnal wyboru pamieci RAM
	signal LD	: std_logic_vector (7 downto 0);	-- zalatchowany sygnal D[]
	signal LA	: std_logic_vector (10 downto 0);	-- zalatchowany sygnal A[]
	signal RIO	: std_logic_vector (7 downto 0);	-- szyna trojstanowa do podlaczenia RAMu
	
	

	begin
--		V_CSR <= CSR;
--		V_CSW <= CSW;
--		V_LA <= LA;
--		V_LD <= LD;
--		V_RIO <= RIO;
		
	
	-- zatrzasnij D[] dla WR
	l1: process (A, MRQ, D) is
		begin
			if (((unsigned(A))>=base_addr) and ((unsigned(A))<=last_addr) and falling_edge(MRQ))
				then LD <= D; end if;
		end process l1;
	
	-- zatrzasnij A[] dla WR
	l2: process (A, MRQ) is
		begin
			if (((unsigned(A))>=base_addr) and ((unsigned(A))<=last_addr) and falling_edge(MRQ))
				then LA <= A(10 downto 0); end if;
		end process l2;
		
	-- zdekodowanie sygnalu WR
	sw: process (A, MRQ, WR) is
		begin
			if (((unsigned(A))>=base_addr) and ((unsigned(A))<=last_addr) and (MRQ='0') and (WR='0'))
				then CSW <= '1'; else CSW <= '0'; end if;
		end process sw;
	
	-- zdekodowanie sygnalu RD	
	sr: process (A, MRQ, RD) is
		begin
			if (((unsigned(A))>=base_addr) and ((unsigned(A))<=last_addr) and (MRQ='0') and (RD='0'))
				then CSR <= '1'; else CSR <= '0'; end if;
		end process sr;
			
	-- zdekodowanie sygnalu chip select
	cs: process (A, MRQ) is
		begin 
			if (((unsigned(A))>=base_addr) and ((unsigned(A))<=last_addr) and (MRQ='0'))
				then CSEL <= '1'; else CSEL <= '0'; end if;	-- chip select
		end process cs;
		
	-- pamiec RAM
	e0: lpm_ram_io
		generic map (LPM_WIDTH=>8, LPM_WIDTHAD=>11, LPM_NUMWORDS=>1099,
				LPM_INDATA => "UNREGISTERED", LPM_OUTDATA => "UNREGISTERED",
				LPM_ADDRESS_CONTROL => "UNREGISTERED")
		port map (dio => RIO, address => LA, memenab => CSEL,
					we => not WR, outenab => not RD);
	
	-- trojstanowa szyna danych do podlaczenia RAMu z zatrzasnietym D[]
	t1: lpm_bustri
		generic map (LPM_WIDTH=>8)
		port map (data => LD, enabledt => CSW, enabletr => CSR, result => D, tridata => RIO);
		
end architecture arch_RAM;