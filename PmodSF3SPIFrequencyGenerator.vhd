------------------------------------------------------------------------
-- Engineer:    Dalmasso Loic
-- Create Date: 19/02/2025
-- Module Name: PmodSF3SPIFrequencyGenerator
-- Description:
--      Pmod SF3 SPI Frequency Generator for the 32 MB NOR Flash Memory MT25QL256ABA.
--		From the System Input Clock, this module generate valid SPI Serial Clock Frequency according to the actual Dummy Cycles and SPI Mode (Single, Dual, Quad).
--		If the wanted SPI Serial Clock Frequency cannot be generated (i.e., Specified SPI Flash Frequency > System Input Clock Frequency), the System Input Clock Frequency is used.
--		When the System Input Clock Frequency is used, the 'o_using_sys_freq' signal is set.
--
--		SPI Frequency References:
--		| Dummy Cycles | Single SPI | Dual SPI | Quad SPI |
--		| 	   0	   | 	133 	| 	 94    |   133    |
--		| 	   1	   | 	 94 	| 	 79    | 	44    |
--		| 	   2	   | 	112 	| 	 97    | 	61    |
--		| 	   3	   | 	129 	| 	106    | 	78    |
--		| 	   4	   | 	133 	| 	115    | 	97    |
--		| 	   5	   | 	133 	| 	125    |   106    |
--		| 	   6	   | 	133 	| 	133    |   115    |
--		| 	   7	   | 	133 	| 	 94    |   125    |
--		| 	   8	   | 	133 	| 	 94    |   133    |
--		| 	   9	   | 	133 	| 	 94    |   133    |
--		| 	   10	   | 	133 	| 	 94    |   133    |
--		| 	   11	   | 	133 	| 	 94    |   133    |
--		| 	   12	   | 	133 	| 	 94    |   133    |
--		| 	   13	   | 	133 	| 	 94    |   133    |
--		| 	   14	   | 	133 	| 	 94    |   133    |
--
-- Generics
--		sys_clock: System Input Clock Frequency (Hz)
--
-- Ports
--		Input 	-	i_sys_clock: System Input Clock
--		Input	-	i_reset: System Input Reset ('0': No Reset, '1': Reset)
--		Input	-	i_spi_single_enable: Enable SPI Single Mode ('0': Disable, '1': Enable)
--		Input	-	i_spi_dual_enable: Enable SPI Dual Mode ('0': Disable, '1': Enable)
--		Input 	-	i_dummy_cycles: Number of Dummy Cycles (0 to 14 cycles)
--		Output 	-	o_spi_freq: SPI Serial Clock Frequency
--		Output 	-	o_using_sys_freq: System Input Clock as SPI Serial Clock Frequency ('0': Disable, '1': Enable)
------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY PmodSF3SPIFrequencyGenerator is

GENERIC(
    sys_clock: INTEGER := 100_000_000
);

PORT(
	i_sys_clock: IN STD_LOGIC;
	i_reset: IN STD_LOGIC;
	i_spi_single_enable: IN STD_LOGIC;
	i_spi_dual_enable: IN STD_LOGIC;
	i_dummy_cycles: IN INTEGER range 0 to 14;
	o_spi_freq: OUT STD_LOGIC;
	o_using_sys_freq: OUT STD_LOGIC
);

END PmodSF3SPIFrequencyGenerator;

ARCHITECTURE Behavioral of PmodSF3SPIFrequencyGenerator is

------------------------------------------------------------------------
-- Constant Declarations
------------------------------------------------------------------------
-- ROM Type
type ROM_TYPE is array(INTEGER range 0 to 14) of INTEGER;

-- SPI Mode Frequency ROM Initialization
function spi_mode_rom_initialization (rom_ref: ROM_TYPE) return ROM_TYPE is
variable spi_freq: INTEGER;
variable spi_freq_rom: ROM_TYPE;
begin
	
	for index in INTEGER range 0 to 14 loop
		
		-- Get SPI Single Mode Frequency from ROM Reference (in MHz)
		spi_freq := rom_ref(index) * 1_000_000;

		-- Compare System Clock to ROM Reference
		if (spi_freq > sys_clock) then
			-- No Clock Divider
			spi_freq_rom(index) := 0;
		else
			-- Clock Divider
			spi_freq_rom(index) := (sys_clock / spi_freq) -1;
		end if;
	end loop;
		
	return spi_freq_rom;
end spi_mode_rom_initialization;

-- ROM Memories
constant SINGLE_SPI_ROM: rom_type := spi_mode_rom_initialization(rom_ref => (133, 94, 112, 129, 133, 133, 133, 133, 133, 133, 133, 133, 133, 133, 133));
constant DUAL_SPI_ROM: rom_type := spi_mode_rom_initialization(rom_ref => (94, 79, 97, 106, 115, 125, 133, 94, 94, 94, 94, 94, 94, 94, 94));
constant QUAD_SPI_ROM: rom_type := spi_mode_rom_initialization(rom_ref => (133, 44, 61, 78, 97, 106, 115, 125, 133, 133, 133, 133, 133, 133, 133));

------------------------------------------------------------------------
-- Signal Declarations
------------------------------------------------------------------------
-- SPI Clock Divider Reference
signal spi_clock_div_ref: INTEGER := 0;

-- SPI Clock Divider
signal spi_clock_div: INTEGER := 0;

-- SPI Serial Clock Frequency Enable
signal spi_freq_enable: STD_LOGIC := '0';

------------------------------------------------------------------------
-- Module Implementation
------------------------------------------------------------------------
begin

	------------------------
	-- SPI Clock Dividers --
	------------------------
	process(i_sys_clock)
	begin
		if rising_edge(i_sys_clock) then

			-- SPI Single Mode
			if (i_spi_single_enable = '1') then
				spi_clock_div_ref <= SINGLE_SPI_ROM(i_dummy_cycles);

			-- SPI Dual Mode
			elsif (i_spi_dual_enable = '1') then
				spi_clock_div_ref <= DUAL_SPI_ROM(i_dummy_cycles);

			-- SPI Quad Mode
			else
				spi_clock_div_ref <= QUAD_SPI_ROM(i_dummy_cycles);
			end if;

		end if;
	end process;

	-----------------------
	-- SPI Clock Counter --
	-----------------------
	process(i_sys_clock)
	begin
		if rising_edge(i_sys_clock) then

			-- Reset SPI Clock Divider
			if (i_reset = '1') or (spi_clock_div = 0) then
				spi_clock_div <= spi_clock_div_ref;

			-- Decrement SPI Clock Divider
			else
				spi_clock_div <= spi_clock_div -1;
			end if;
		end if;
	end process;

	--------------------------------
	-- SPI Serial Clock Frequency --
	--------------------------------
	process(i_sys_clock)
	begin
		if rising_edge(i_sys_clock) then
	
			-- SPI Clock Enable
			if (spi_clock_div = 0) then
				spi_freq_enable <= '1';
			else
				spi_freq_enable <= '0';
			end if;
		end if;
	end process;
	o_spi_freq <= i_sys_clock when spi_freq_enable = '1' else '0';

	------------------------------------------------------
	-- System Input Clock as SPI Serial Clock Frequency --
	------------------------------------------------------
	process(i_sys_clock)
	begin
		if rising_edge(i_sys_clock) then

			-- SPI Clock Enable
			if (spi_clock_div_ref = 0) then
				o_using_sys_freq <= '1';
			else
				o_using_sys_freq <= '0';
			end if;
		end if;
	end process;

end Behavioral;