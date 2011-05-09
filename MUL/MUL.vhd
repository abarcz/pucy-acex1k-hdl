-- Automat mnozacy metoda podstawowa

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;

entity MUL is
	generic (
		wsize 	: natural := 8;		-- rozmiar slowa
		asize	: natural := 2 * 8 - 1;	-- rozmiar akumulatora
		csize	: natural := 3		-- rozmiar licznika rund (log2(wsize))
	);
	port (
		GEN		: in std_logic;
		RESET	: in std_logic;
		A 		: in std_logic_vector (wsize - 1 downto 0);
		B 		: in std_logic_vector (wsize - 1 downto 0);
		RESULT 	: out std_logic_vector (wsize - 1 downto 0);-- wynik mnozenia
		GO		: in std_logic;		-- uruchamia MUL, aktywne LOW
		READY	: out std_logic		-- czy wynik gotowy? (LOW)
--		D_ACC	: out std_logic_vector (asize - 1 downto 0);
--		D_ASHL	: out std_logic_vector (asize - 1 downto 0);
--		D_BSHR 	: out std_logic_vector (wsize - 1 downto 0);
--		D_AUT	: out std_logic_vector (1 downto 0);
--		D_ROUND : out std_logic_vector (csize - 1 downto 0)
	);
end entity MUL;

architecture arch_MUL of MUL is
	signal ashl : unsigned (asize - 1 downto 0);-- SHL(Ra,n-1)
	signal ashln: unsigned (asize - 1 downto 0);-- SHL(Ra,n-1)
	signal bshr : unsigned (wsize - 1 downto 0);-- B
	signal bshrn: unsigned (wsize - 1 downto 0);-- B
	signal acc 	: unsigned (asize - 1 downto 0);-- akumulator
	signal accn : unsigned (asize - 1 downto 0);-- akumulator
	
	signal round: unsigned (csize - 1 downto 0);-- licznik rund
	signal roundn:unsigned (csize - 1 downto 0);-- licznik rund
	constant maxround: unsigned (csize - 1 downto 0) := (others => '1');
	
	signal RESULT_BUF	: std_logic_vector (wsize - 1 downto 0);
	signal RESULT_BUFn	: std_logic_vector (wsize - 1 downto 0);
	
	signal READY_BUF	: std_logic := '1';
	
	signal AUT_MUL		: std_logic_vector (1 downto 0) := "00";
	signal AUT_MULn		: std_logic_vector (1 downto 0);
	constant AUT_IDLE	: std_logic_vector (1 downto 0) := "00";
	constant AUT_RUNNING: std_logic_vector (1 downto 0) := "01";
	constant AUT_OUTPUT	: std_logic_vector (1 downto 0) := "11";
	constant AUT_DONE	: std_logic_vector (1 downto 0) := "10";
	
	begin
--	D_ACC <= std_logic_vector(acc);
--	D_ASHL <= std_logic_vector(ashl);
--	D_BSHR <= std_logic_vector(bshr);
--	D_AUT <= std_logic_vector(AUT_MUL);
--	D_ROUND <= std_logic_vector(round);
	RESULT <= RESULT_BUF;
	
	process_clock:
	process (RESET, GEN, AUT_MULn, accn, bshrn, 
			roundn, ashln, RESULT_BUFn, READY_BUF)
	begin
		if RESET = '0' then
			AUT_MUL <= AUT_IDLE;
			READY <= '1';
			RESULT_BUF <= (others => '0');
		else
			if rising_edge(GEN) then
				AUT_MUL <= AUT_MULn;
				acc <= accn;
				bshr <= bshrn;
				ashl <= ashln;
				round <= roundn;
				RESULT_BUF <= RESULT_BUFn;
				READY <= READY_BUF;
			end if;
		end if;
	end process;
	
	multiply: 
	process (GEN, ashl, acc, bshr, round, RESULT_BUF, AUT_MUL, A, B, GO) is
	begin
		case AUT_MUL is
			when AUT_IDLE =>
				READY_BUF <= '1';
				RESULT_BUFn <= RESULT_BUF;
				ashln(asize - 1 downto wsize - 1) <= unsigned(A(wsize - 1 downto 0));
				ashln(wsize - 2 downto 0) <= (others => '0');
				bshrn <= unsigned(B);
				roundn <= (others => '0');
				accn <= (others => '0');
				if GO = '0' then
					AUT_MULn <= AUT_RUNNING;
				else
					AUT_MULn <= AUT_IDLE;
				end if;
			when AUT_RUNNING =>
				READY_BUF <= '1';
				RESULT_BUFn <= RESULT_BUF;
				ashln <= ashl;
		
				if bshr(0) = '1' then
					accn <= ('0' & acc(asize - 1 downto 1)) + ashl;
				else
					accn <= '0' & acc(asize - 1 downto 1);
				end if;
				
				roundn <= round + 1;
				bshrn(wsize - 1 downto 0) <= '0' & bshr(wsize - 1 downto 1);
				
				if round < maxround then
					AUT_MULn <= AUT_RUNNING;
				else
					AUT_MULn <= AUT_OUTPUT;
				end if;
			when AUT_OUTPUT =>
				READY_BUF <= '1';
				accn <= acc;
				ashln <= ashl;
				bshrn <= bshr;
				roundn <= round;
				RESULT_BUFn <= std_logic_vector(acc(wsize - 1 downto 0));
				AUT_MULn <= AUT_DONE;
			when AUT_DONE =>
				accn <= acc;
				ashln <= ashl;
				bshrn <= bshr;
				roundn <= round;
				RESULT_BUFn <= RESULT_BUF;
				READY_BUF <= '0';
				if GO = '1' then
					AUT_MULn <= AUT_IDLE;
				else
					AUT_MULn <= AUT_DONE;
				end if;
		end case;
	end process;

end architecture arch_MUL;
	