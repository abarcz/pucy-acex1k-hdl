--	Blok pamieci ROM	: 90B
--	Przestrzen adresowa	: 0x0000..0x0059 (0..89)
--	Czas ustalenia sie D przy odczycie	: 25ns
--	Czas wyjscia z D po cofnieciu MREQ i RD	: 20ns
--	Poniewaz T(CPU) = 1/f = 50ns > 25ns, ROM nie wystawia sygnalu WT.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
library lpm;
use lpm.lpm_components.all;
library altera;
use altera.altera_primitives_components.all;

entity ROM is
	generic ( last_addr	: natural := 89 );	-- ostatni adres w przestrzeni adr	

	port (	A	: in std_logic_vector (15 downto 0);
			D	: inout std_logic_vector (7 downto 0);
		MRQ, RD	: in std_logic );
	
end entity ROM;

architecture arch_ROM of ROM is
	signal CSEL	: std_logic;	-- zdekodowany sygnal wyboru pamieci ROM przez CPU
	begin

	cs: process (A, MRQ, RD) is
		begin 
			if (((unsigned(A))<=last_addr) and (MRQ='0') and (RD='0'))
				then CSEL <= '1'; else CSEL <= '0'; end if;	-- chip select
		end process cs;
		
	e0: lpm_rom
		generic map (LPM_WIDTH=>8, LPM_WIDTHAD=>7, LPM_NUMWORDS=>90,
				LPM_FILE=>"cpu_asm.mif", LPM_OUTDATA => "UNREGISTERED",
				LPM_ADDRESS_CONTROL => "UNREGISTERED",
				LPM_HINT => "UNUSED")
		port map (address => A(6 downto 0), q => D, memenab => CSEL);
		
end architecture arch_ROM;