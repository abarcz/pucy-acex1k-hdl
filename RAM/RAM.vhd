--	Blok pamieci RAM	: 1099B -> ograniczona do 1024B ze wzgledu na ilosc EAB
--	Przestrzen adresowa	: 0x1000..0x144A (4096..5194) 
--						-> 0x1000..0x1399 (4096..5119)

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
				last_addr	: natural := 4608 );-- ostatni adres w przestrzeni adr	

	port (	A	: in std_logic_vector (15 downto 0);
			D	: inout std_logic_vector (7 downto 0);
	MRQ, RD, WR	: in std_logic
--	V_CSR :out std_logic;
--	V_CSW : out std_logic;
--	V_LD : out std_logic_vector (7 downto 0);
--	V_LA : out std_logic_vector (10 downto 0);
--	V_DOUT : out std_logic_vector (7 downto 0) 
	);
	
end entity RAM;

architecture arch_RAM of RAM is
	signal CSEL, CSW, CSR	: std_logic; -- zdekodowane sygnal wyboru pamieci RAM
	signal LD	: std_logic_vector (7 downto 0);	-- zalatchowany sygnal D[]
	signal LA	: std_logic_vector (10 downto 0);	-- zalatchowany sygnal A[]
	signal DOUT	: std_logic_vector (7 downto 0);	-- sygnal wyjsciowy D[]
	
	begin
--		V_CSR <= CSR;
--		V_CSW <= CSW;
--		V_LA <= LA;
--		V_LD <= LD;
--		V_DOUT <= DOUT;
	
		-- zatrzasnij D[] i A[] dla WR
	l1: process (A, MRQ, WR, D, LA, LD) is
		begin
			if ((MRQ = '1') and (WR = '1')) then 
				LD <= D; 
				LA <= A(10 downto 0); 
			else
				LD <= LD;
				LA <= LA;
			end if;
		end process l1;
		
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
			
	e0: lpm_ram_dq
		generic map (LPM_WIDTH=>8, LPM_WIDTHAD=>10, LPM_NUMWORDS=>1024,
				LPM_INDATA => "UNREGISTERED", LPM_OUTDATA => "UNREGISTERED",
				LPM_ADDRESS_CONTROL => "UNREGISTERED")
		port map (data => LD, address=> LA(9 downto 0), we => CSW, q => DOUT);
		
	t1: lpm_bustri
		generic map (LPM_WIDTH=>8)
		port map (data => DOUT, enabledt => CSR, tridata => D);
		
end architecture arch_RAM;