--	Blok pamieci RAM	: 1099B
--	Przestrzen adresowa	: 0x1000..0x144A (4096..5194)
--	Czas ustalenia sie D przy odczycie: 25ns
--	Czas wyjscia z szyny D po cofnieciu MRQ i RD: 20ns
--	Czas zapisu: 10ns (!MRQ&!WR&A), 
--	 ale po cofnieciu MRQ i WR: A i D musza pozostac niezmienione przez 10ns
--	Poniewaz T(CPU) = 1/f = 50ns > 25ns > 10ns, RAM nie wystawia sygnalu WT.

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
	MRQ, RD, WR	: in std_logic );
	
end entity RAM;

architecture arch_RAM of RAM is
	signal CSEL	: std_logic;	-- zdekodowany sygnal wyboru pamieci RAM przez CPU
	begin

	cs: process (A, MRQ) is
		begin 
			if (((unsigned(A))>=base_addr) and ((unsigned(A))<=last_addr) and (MRQ='0'))
				then CSEL <= '1'; else CSEL <= '0'; end if;	-- chip select
		end process cs;
		
	e0: lpm_ram_io
		generic map (LPM_WIDTH=>8, LPM_WIDTHAD=>11, LPM_NUMWORDS=>1099,
				LPM_INDATA => "UNREGISTERED", LPM_OUTDATA => "UNREGISTERED",
				LPM_ADDRESS_CONTROL => "UNREGISTERED")
		port map (dio => D, address => A(10 downto 0), memenab => CSEL,
					we => not WR, outenab => not RD);
		
end architecture arch_RAM;