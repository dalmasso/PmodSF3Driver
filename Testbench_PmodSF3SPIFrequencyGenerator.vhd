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

ENTITY Testbench_PmodSF3SPIFrequencyGenerator is
END Testbench_PmodSF3SPIFrequencyGenerator;

ARCHITECTURE Behavioral of Testbench_PmodSF3SPIFrequencyGenerator is

COMPONENT PmodSF3SPIFrequencyGenerator is

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

END COMPONENT;

signal sys_clock: STD_LOGIC := '0';
signal reset: STD_LOGIC := '0';
signal spi_single_enable: STD_LOGIC := '0';
signal spi_dual_enable: STD_LOGIC := '0';
signal dummy_cycle_clock: STD_LOGIC := '0';
signal dummy_cycles: INTEGER range 0 to 14 := 0;
signal spi_freq: STD_LOGIC := '0';
signal using_sys_freq: STD_LOGIC := '0';

begin

-- Clock 100 MHz
sys_clock <= not(sys_clock) after 5 ns;

-- Reset
reset <= '1', '0' after 145 ns;

-- SPI Modes (Single, then Dual, then Quad)
spi_single_enable <= '1', '0' after 4950 ns, '0' after 7950 ns;
spi_dual_enable <= '0', '1' after 4950 ns, '0' after 7950 ns;

-- Dummy Cycles
dummy_cycle_clock <= not(dummy_cycle_clock) after 20 ns;
process(dummy_cycle_clock)
begin
    if rising_edge(dummy_cycle_clock) then

        -- Reset Dummy Cycles
        if (reset = '1') or (dummy_cycles = 14) then
            dummy_cycles <= 0;
        
        -- New Dummy Cycles
        else
            dummy_cycles <= dummy_cycles +1;
        end if;
    end if;
end process;

uut: PmodSF3SPIFrequencyGenerator
    
    GENERIC map(
        sys_clock => 100_000_000)
    
    PORT map(
        i_sys_clock => sys_clock,
        i_reset => reset,
        i_spi_single_enable => spi_single_enable,
        i_spi_dual_enable => spi_dual_enable,
        i_dummy_cycles => dummy_cycles,
        o_spi_freq => spi_freq,
        o_using_sys_freq => using_sys_freq);

end Behavioral;