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

ENTITY PmodSF3DummyCycles is

PORT(
	i_sys_clock: IN STD_LOGIC;
    i_command: IN UNSIGNED(7 downto 0);
    i_data_to_mem: IN UNSIGNED(15 downto 0);
    i_data_from_mem: IN UNSIGNED(15 downto 0);
	i_data_from_mem_ready: IN STD_LOGIC;
    o_dummy_cycles: OUT INTEGER range 0 to 15
);

END PmodSF3DummyCycles;

ARCHITECTURE Behavioral of PmodSF3DummyCycles is

------------------------------------------------------------------------
-- Constant Declarations
------------------------------------------------------------------------
-- Non Volatile Configuration Register
constant WRITE_NON_VOLATILE_COMMAND: UNSIGNED(7 downto 0) := x"B1";
constant READ_NON_VOLATILE_COMMAND: UNSIGNED(7 downto 0) := x"B5";
constant RESET_NON_VOLATILE_COMMAND: UNSIGNED(7 downto 0) := x"99";
constant NON_VOLATILE_CONFIG_REG_DUMMY_CYCLES_MSB_BIT: INTEGER := 15;
constant NON_VOLATILE_CONFIG_REG_DUMMY_CYCLES_LSB_BIT: INTEGER := 12;

-- Volatile Configuration Register
constant WRITE_VOLATILE_CONFIG_COMMAND: UNSIGNED(7 downto 0) := x"81";
constant READ_VOLATILE_CONFIG_COMMAND: UNSIGNED(7 downto 0) := x"85";
constant VOLATILE_CONFIG_REG_DUMMY_CYCLES_MSB_BIT: INTEGER := 7;
constant VOLATILE_CONFIG_REG_DUMMY_CYCLES_LSB_BIT: INTEGER := 4;

------------------------------------------------------------------------
-- Signal Declarations
------------------------------------------------------------------------
-- Non Volatile Dummy Cycles Register
signal non_volatile_dummy_cycles_reg: UNSIGNED(3 downto 0) := (others => '0');

-- Volatile Dummy Cycles Register
signal volatile_dummy_cycles_reg: UNSIGNED(3 downto 0) := (others => '0');
signal apply_volatile_dummy_cycles: STD_LOGIC := '0';

-- Dummy Cycles Output Register
signal dummy_cycles_out_reg: UNSIGNED(3 downto 0) := (others => '0');

------------------------------------------------------------------------
-- Module Implementation
------------------------------------------------------------------------
begin

	----------------------------------------
	-- Non-Volatile Configuration Handler --
	----------------------------------------
	process(i_sys_clock)
	begin

		if rising_edge(i_sys_clock) then

			-- Write Non-Volatile Configuration Register
			if (i_command = WRITE_NON_VOLATILE_COMMAND) then
				non_volatile_dummy_cycles_reg <= i_data_to_mem(NON_VOLATILE_CONFIG_REG_DUMMY_CYCLES_MSB_BIT downto NON_VOLATILE_CONFIG_REG_DUMMY_CYCLES_LSB_BIT);

			-- Read Non-Volatile Configuration Register
			elsif (i_data_from_mem_ready = '1') and (i_command = READ_NON_VOLATILE_COMMAND) then
				non_volatile_dummy_cycles_reg <= i_data_from_mem(NON_VOLATILE_CONFIG_REG_DUMMY_CYCLES_MSB_BIT downto NON_VOLATILE_CONFIG_REG_DUMMY_CYCLES_LSB_BIT);
			end if;
        end if;
    end process;

	------------------------------------
	-- Volatile Configuration Handler --
	------------------------------------
	process(i_sys_clock)
	begin

		if rising_edge(i_sys_clock) then

			-- Write Volatile Configuration Register
			if (i_command = WRITE_VOLATILE_CONFIG_COMMAND) then
				volatile_dummy_cycles_reg <= i_data_to_mem(VOLATILE_CONFIG_REG_DUMMY_CYCLES_MSB_BIT downto VOLATILE_CONFIG_REG_DUMMY_CYCLES_LSB_BIT);

			-- Read Volatile Configuration Register
			elsif (i_data_from_mem_ready = '1') and (i_command = READ_VOLATILE_CONFIG_COMMAND) then
				volatile_dummy_cycles_reg <= i_data_from_mem(VOLATILE_CONFIG_REG_DUMMY_CYCLES_MSB_BIT downto VOLATILE_CONFIG_REG_DUMMY_CYCLES_LSB_BIT);
			end if;

			-- Apply New Volatile Configuration Register to Output Register
            if (i_command = WRITE_VOLATILE_CONFIG_COMMAND) then
                apply_volatile_dummy_cycles <= '1';
            else
				apply_volatile_dummy_cycles <= '0';
            end if;

		end if;
    end process;

	----------------------------------
	-- Dummy Cycles Output Register --
	----------------------------------
	process(i_sys_clock)
	begin
		if rising_edge(i_sys_clock) then

			-- Reset Memory Command (use Non-Volatile Dummy Cycles)
			if (i_command = RESET_NON_VOLATILE_COMMAND) then
				dummy_cycles_out_reg <= non_volatile_dummy_cycles_reg;

			-- Write Volatile Configuration Register (use Volatile Dummy Cycles)
			elsif (apply_volatile_dummy_cycles = '1') then
				dummy_cycles_out_reg <= volatile_dummy_cycles_reg;
			end if;
		end if;
	end process;

	-------------------------
	-- Dummy Cycles Output --
	-------------------------
	o_dummy_cycles <= TO_INTEGER(dummy_cycles_out_reg);

end Behavioral;