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
--		|   1  |   1  | Single
--
-- Ports
--		Input 	-	i_sys_clock: System Input Clock
--		Input 	-	i_command: Command Byte
--		Input 	-	i_data_to_mem: Data Bytes to Write on FLASH
--		Output 	-	i_data_from_mem: Data Bytes Read from FLASH
--		Output 	-	i_data_from_mem_ready: Data Bytes Read from FLASH Ready (Read Mode) ('0': NOT Ready, '1': Ready)
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
    i_command: IN UNSIGNED(7 downto 0);
    i_data_to_mem: IN UNSIGNED(15 downto 0);
    i_data_from_mem: IN UNSIGNED(15 downto 0);
	i_data_from_mem_ready: IN STD_LOGIC;
    o_spi_single_enable: OUT STD_LOGIC;
    o_spi_dual_enable: OUT STD_LOGIC;
    o_spi_quad_enable: OUT STD_LOGIC
);

END COMPONENT;

signal sys_clock: STD_LOGIC := '0';
signal reset: STD_LOGIC := '0';
signal command: UNSIGNED(7 downto 0) := (others => '0');
signal data_to_mem: UNSIGNED(15 downto 0) := (others => '0');
signal data_from_mem: UNSIGNED(15 downto 0) := (others => '0');
signal data_from_mem_ready: STD_LOGIC := '0';
signal spi_single_enable: STD_LOGIC := '0';
signal spi_dual_enable: STD_LOGIC := '0';
signal spi_quad_enable: STD_LOGIC := '0';

signal write_non_volatile_spi_ref: UNSIGNED(1 downto 0) := (others => '0');
signal read_non_volatile_spi_ref: UNSIGNED(1 downto 0) := (others => '0');
signal write_enhanced_volatile_spi_ref: UNSIGNED(1 downto 0) := (others => '0');
signal read_enhanced_volatile_spi_ref: UNSIGNED(1 downto 0) := (others => '0');

begin

-- Clock 100 MHz
sys_clock <= not(sys_clock) after 5 ns;

-- Reset
reset <= '1', '0' after 145 ns;

-- Command
process(sys_clock)
begin
    if rising_edge(sys_clock) then
        
        -- Reset Command
        if (reset = '1') then
            command <= (others => '0');
        
        -- Increment Command
        else
            command <= command +1;
        end if;
    end if;
end process;

-- Data to Memory for Test
process(sys_clock)
begin
    if rising_edge(sys_clock) then
        
        -- Reset Data to Memory
        if (reset = '1') then
            data_to_mem <= (others => '0');
        
        -- Increment Data to Memory
        elsif(data_to_mem < "1111111111111111") then
            data_to_mem <= data_to_mem +1;
            
        end if;
    end if;
end process;

-- Data from Memory for Test
process(sys_clock)
begin
    if rising_edge(sys_clock) then
        
        -- Reset Data to Memory
        if (reset = '1') then
            data_from_mem <= (others => '1');
        
        -- Increment Data to Memory
        elsif (data_from_mem > "0000000000000000") then
            data_from_mem <= data_from_mem -1;
        end if;
    end if;
end process;

-- Data from Memory Ready
data_from_mem_ready <=  '0',
                        '1' after 1.105 us, '0' after 1.175 us,
                        '1' after 1.945 us, '0' after 2 us,
                        '1' after 233 us, '0' after 280 us,
                        '1' after 656.505 us, '0' after 656.525 us;

-- SPI Mode References
write_non_volatile_spi_ref <= data_to_mem(3 downto 2);
read_non_volatile_spi_ref <= data_from_mem(3 downto 2);
write_enhanced_volatile_spi_ref <= data_to_mem(7 downto 6);
read_enhanced_volatile_spi_ref <= data_from_mem(7 downto 6);

uut: PmodSF3SPIModes
    PORT map(
        i_sys_clock => sys_clock,
        i_command => command,
		i_data_to_mem => data_to_mem,
		i_data_from_mem => data_from_mem,
		i_data_from_mem_ready => data_from_mem_ready,
        o_spi_single_enable => spi_single_enable,
        o_spi_dual_enable => spi_dual_enable,
        o_spi_quad_enable => spi_quad_enable);

end Behavioral;