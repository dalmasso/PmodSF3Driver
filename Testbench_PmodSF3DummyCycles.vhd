------------------------------------------------------------------------
-- Engineer:    Dalmasso Loic
-- Create Date: 19/02/2025
-- Module Name: PmodSF3DummyCycles
-- Description:
--      Pmod SF3 Dummy Cycles Handler for the 32 MB NOR Flash Memory MT25QL256ABA:
--      - When User Read/Write Dummy Cycles from/to memory (Non-Volatile / Volatile register), the module updates its internal Dummy Cycles registers
--      - According to the Flash Memory specifications:
--			- At Power-up, the Dummy Cycles from the Non-Volatile register is used
--			- When RESET_NON_VOLATILE_COMMAND (0x99) command is executed, the Dummy Cycles from the Non-Volatile register is used
--			- When WRITE_VOLATILE_CONFIG_COMMAND (0x81) command is executed, the Dummy Cycles from the Volatile register is used
--
-- Ports
--		Input 	-	i_sys_clock: System Input Clock
--		Input 	-	i_command: Command Byte
--		Input 	-	i_data_to_mem: Data Bytes to Write on FLASH
--		Output 	-	i_data_from_mem: Data Bytes Read from FLASH
--		Output 	-	i_data_from_mem_ready: Data Bytes Read from FLASH Ready (Read Mode) ('0': NOT Ready, '1': Ready)
--		Output 	-	o_dummy_cycles: Dummy Cycles Value
------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY Testbench_PmodSF3DummyCycles is
END Testbench_PmodSF3DummyCycles;

ARCHITECTURE Behavioral of Testbench_PmodSF3DummyCycles is

COMPONENT PmodSF3DummyCycles is

PORT(
	i_sys_clock: IN STD_LOGIC;
    i_command: IN UNSIGNED(7 downto 0);
    i_data_to_mem: IN UNSIGNED(15 downto 0);
    i_data_from_mem: IN UNSIGNED(15 downto 0);
	i_data_from_mem_ready: IN STD_LOGIC;
    o_dummy_cycles: OUT INTEGER range 0 to 15
);

END COMPONENT;

signal sys_clock: STD_LOGIC := '0';
signal reset: STD_LOGIC := '0';
signal command: UNSIGNED(7 downto 0) := (others => '0');
signal data_to_mem: UNSIGNED(15 downto 0) := (others => '0');
signal data_from_mem: UNSIGNED(15 downto 0) := (others => '0');
signal data_from_mem_ready: STD_LOGIC := '0';
signal dummy_cycles: INTEGER range 0 to 15 := 0;

signal write_non_volatile_dummy_cycles_ref: UNSIGNED(3 downto 0) := (others => '0');
signal read_non_volatile_dummy_cycles_ref: UNSIGNED(3 downto 0) := (others => '0');
signal write_volatile_dummy_cycles_ref: UNSIGNED(3 downto 0) := (others => '0');
signal read_volatile_dummy_cycles_ref: UNSIGNED(3 downto 0) := (others => '0');

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
                        '1' after 656.825 us, '0' after 656.845 us;

-- Dummy Cycles References
write_non_volatile_dummy_cycles_ref <= data_to_mem(15 downto 12);
read_non_volatile_dummy_cycles_ref <= data_from_mem(15 downto 12);
write_volatile_dummy_cycles_ref <= data_to_mem(7 downto 4);
read_volatile_dummy_cycles_ref <= data_from_mem(7 downto 4);

uut: PmodSF3DummyCycles
    PORT map(
        i_sys_clock => sys_clock,
        i_command => command,
		i_data_to_mem => data_to_mem,
		i_data_from_mem => data_from_mem,
		i_data_from_mem_ready => data_from_mem_ready,
		o_dummy_cycles => dummy_cycles);

end Behavioral;