------------------------------------------------------------------------
-- Engineer:    Dalmasso Loic
-- Create Date: 19/02/2025
-- Module Name: PmodSF3SPIModes
-- Description:
--      Pmod SF3 SPI Modes Handler for the 32 MB NOR Flash Memory MT25QL256ABA:
--      - When User Read/Write SPI Mode from/to memory (Non-Volatile / Enhanced Volatile register), the module updates its internal SPI Mode registers
--      - According to the Flash Memory specifications:
--			- At Power-up, the SPI Mode from the Non-Volatile register is used
--			- When RESET_NON_VOLATILE_COMMAND (0x99) command is executed, the SPI Mode from the Non-Volatile register is used
--			- When WRITE_ENHANCED_VOLATILE_CONFIG_COMMAND (0x..) command is executed, the SPI Mode from the Enhanced Volatile register is used
--
--      SPI Single Mode: DQ0 as Input, DQ1 as Output, DQ[3:2] NOT USED
--      SPI Dual Mode: DQ[1:0] as InOut, DQ[3:2] NOT USED
--      SPI Quad Mode: DQ[3:0] as InOut
--
--		SPI Mode Bits ('0' = Enable Bit, '1' = Disable Bit)
--		| Quad | Dual | SPI Mode Output
--		|   0  |   0  | Quad
--		|   0  |   1  | Quad
--		|   1  |   0  | Dual
--		|   1  |   1  | Single (Default)
--
-- Ports
--		Input 	-	i_sys_clock: System Input Clock
--		Input 	-	i_reset: Module Reset ('0': No Reset, '1': Reset)
--		Input 	-	i_end_of_tx: End of SPI Transmission ('0': In progress, '1': End of Transmission)
--		Input 	-	i_command: Command Byte
--		Input 	-	i_new_data_to_mem: New Data to Write on FLASH Ready (Write Mode) ('0': NOT Ready, '1': Ready)
--		Input 	-	i_data_to_mem: Data Bytes to Write on FLASH
--		Input 	-	i_data_from_mem_ready: Data Bytes Read from FLASH Ready (Read Mode) ('0': NOT Ready, '1': Ready)
--		Input 	-	i_data_from_mem: Data Bytes Read from FLASH
--		Output 	-	o_spi_single_enable: SPI Single Mode Enable ('0': Disable, '1': Enable)
--		Output 	-	o_spi_dual_enable: SPI Dual Mode Enable ('0': Disable, '1': Enable)
--		Output 	-	o_spi_quad_enable: SPI Quad Mode Enable ('0': Disable, '1': Enable)
------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY Testbench_PmodSF3SPIModes is
END Testbench_PmodSF3SPIModes;

ARCHITECTURE Behavioral of Testbench_PmodSF3SPIModes is

COMPONENT PmodSF3SPIModes is

PORT(
	i_sys_clock: IN STD_LOGIC;
	i_reset: IN STD_LOGIC;
	i_end_of_tx: IN STD_LOGIC;
    i_command: IN UNSIGNED(7 downto 0);
	i_new_data_to_mem: IN STD_LOGIC;
    i_data_to_mem: IN UNSIGNED(7 downto 0);
	i_data_from_mem_ready: IN STD_LOGIC;
    i_data_from_mem: IN UNSIGNED(7 downto 0);
    o_spi_single_enable: OUT STD_LOGIC;
    o_spi_dual_enable: OUT STD_LOGIC;
    o_spi_quad_enable: OUT STD_LOGIC
);

END COMPONENT;

signal sys_clock: STD_LOGIC := '0';
signal sys_clock_2: STD_LOGIC := '0';
signal reset: STD_LOGIC := '0';
signal end_of_tx: STD_LOGIC := '0';
signal command: UNSIGNED(7 downto 0) := (others => '0');
signal new_data_to_mem: STD_LOGIC := '0';
signal data_to_mem: UNSIGNED(7 downto 0) := x"AB";
signal data_from_mem_ready: STD_LOGIC := '0';
signal data_from_mem: UNSIGNED(7 downto 0) := x"CD";
signal spi_single_enable: STD_LOGIC := '0';
signal spi_dual_enable: STD_LOGIC := '0';
signal spi_quad_enable: STD_LOGIC := '0';

begin

-- Clock 100 MHz
sys_clock <= not(sys_clock) after 5 ns;

-- Command Clock
process
begin
    sys_clock_2 <= not(sys_clock_2) after 5 ns;
    wait for 80 ns;
end process;

-- Reset
reset <= '1', '0' after 50 ns;

-- End of Transmission
end_of_tx <='1', '0' after 145 ns,
            -- End after Write Enhanced Volatile
            '1' after 15.685 us, '0' after 15.845 us,
            -- End after Write Non Volatile
            '1' after 28.485 us, '0' after 28.645 us;

-- Command
process(sys_clock_2)
begin
    if rising_edge(sys_clock_2) then

        -- Increment Command
        if (command < "11111111") then
            command <= command +1;
        
        -- Apply Non Volatile Dummy Cycle Register
        else
            command <= x"99";
        end if;
    end if;
end process;

-- New Data to Memory for Test
process(sys_clock)
begin
    if rising_edge(sys_clock) then
        
        -- No Data to Memory
        if (reset = '1') then
            new_data_to_mem <= '0';
        
        -- New Data to Memory
        else
            new_data_to_mem <= '1';
        end if;
    end if;
end process;

-- Data to Memory for Test
process(sys_clock)
begin
    if rising_edge(sys_clock) then
        
        -- Increment Data to Memory
        data_to_mem <= data_to_mem +2;

    end if;
end process;

-- Data from Memory Ready
data_from_mem_ready <=  '0',
                        '1' after 1.105 us, '0' after 1.175 us,
                        '1' after 16.005 us, '0' after 16.165 us,
                        '1' after 28.805 us, '0' after 28.965 us;

-- Data from Memory for Test
process(sys_clock)
begin
    if rising_edge(sys_clock) then

        -- Decrement Data to Memory
        data_from_mem <= data_from_mem -3;

    end if;
end process;

uut: PmodSF3SPIModes
    PORT map(
        i_sys_clock => sys_clock,
        i_reset => reset,
        i_end_of_tx => end_of_tx,
        i_command => command,
        i_new_data_to_mem => new_data_to_mem,
		i_data_to_mem => data_to_mem,
        i_data_from_mem_ready => data_from_mem_ready,
		i_data_from_mem => data_from_mem,
        o_spi_single_enable => spi_single_enable,
        o_spi_dual_enable => spi_dual_enable,
        o_spi_quad_enable => spi_quad_enable);

end Behavioral;