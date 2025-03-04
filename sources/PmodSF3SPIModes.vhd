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

ENTITY PmodSF3SPIModes is

PORT(
	i_sys_clock: IN STD_LOGIC;
	i_reset: IN STD_LOGIC;
    i_command: IN UNSIGNED(7 downto 0);
	i_new_data_to_mem: IN STD_LOGIC;
    i_data_to_mem: IN UNSIGNED(7 downto 0);
	i_data_from_mem_ready: IN STD_LOGIC;
    i_data_from_mem: IN UNSIGNED(7 downto 0);
    o_spi_single_enable: OUT STD_LOGIC;
    o_spi_dual_enable: OUT STD_LOGIC;
    o_spi_quad_enable: OUT STD_LOGIC
);

END PmodSF3SPIModes;

ARCHITECTURE Behavioral of PmodSF3SPIModes is

------------------------------------------------------------------------
-- Constant Declarations
------------------------------------------------------------------------
-- Non Volatile Configuration Register
constant WRITE_NON_VOLATILE_COMMAND: UNSIGNED(7 downto 0) := x"B1";
constant READ_NON_VOLATILE_COMMAND: UNSIGNED(7 downto 0) := x"B5";
constant RESET_NON_VOLATILE_COMMAND: UNSIGNED(7 downto 0) := x"99";
constant NON_VOLATILE_CONFIG_REG_SPI_QUAD_BIT: INTEGER := 3;
constant NON_VOLATILE_CONFIG_REG_SPI_DUAL_BIT: INTEGER := 2;

-- Enhanced Volatile Configuration Register
constant WRITE_ENHANCED_VOLATILE_CONFIG_COMMAND: UNSIGNED(7 downto 0) := x"61";
constant READ_ENHANCED_VOLATILE_CONFIG_COMMAND: UNSIGNED(7 downto 0) := x"65";
constant ENHANCED_VOLATILE_CONFIG_REG_SPI_QUAD_BIT: INTEGER := 7;
constant ENHANCED_VOLATILE_CONFIG_REG_SPI_DUAL_BIT: INTEGER := 6;

-- Internal Register SPI Quad Bit
constant INTERNAL_REG_SPI_QUAD_BIT: INTEGER := 1;

-- SPI Mode Output Enable (Note: '0' = Enable Bit, '1' = Disable Bit)
constant SPI_SINGLE_MODE: UNSIGNED(1 downto 0) := "11";
constant SPI_DUAL_MODE: UNSIGNED(1 downto 0) := "10";
constant SPI_QUAD_MODE: UNSIGNED(0 downto 0) := "0";

------------------------------------------------------------------------
-- Signal Declarations
------------------------------------------------------------------------
-- Non Volatile SPI Mode (Write mode)
signal non_volatile_w_bit_counter: UNSIGNED(2 downto 0) := (others => '0');
signal non_volatile_w_second_byte: STD_LOGIC := '0';

-- Non Volatile SPI Mode (Read mode)
signal non_volatile_r_byte_counter: UNSIGNED(0 downto 0) := (others => '0');
signal non_volatile_r_second_byte: STD_LOGIC := '0';

-- Non Volatile SPI Mode Register
signal non_volatile_spi_mode_reg: UNSIGNED(1 downto 0) := (others => '0');

-- Enhanced Volatile SPI Mode Register
signal enhanced_volatile_spi_mode_reg: UNSIGNED(1 downto 0) := (others => '0');
signal apply_enhanced_volatile_spi_mode: STD_LOGIC := '0';

-- SPI Mode Output Register
signal spi_mode_out_reg: UNSIGNED(1 downto 0) := (others => '0');

------------------------------------------------------------------------
-- Module Implementation
------------------------------------------------------------------------
begin

	----------------------------------------------
	-- Non-Volatile Write Configuration Handler --
	----------------------------------------------
	process(i_sys_clock)
	begin

		if rising_edge(i_sys_clock) then

			-- Reset Bit Counter
			if (i_command /= WRITE_NON_VOLATILE_COMMAND) then
				non_volatile_w_bit_counter <= (others => '1');
			
			-- Decrement Bit Counter
			elsif (i_new_data_to_mem = '1') then
				non_volatile_w_bit_counter <= non_volatile_w_bit_counter -1;
			end if;
		end if;
	end process;
	non_volatile_w_second_byte <= '1' when (non_volatile_w_bit_counter = "000") else '0';

	----------------------------------------------
	-- Non-Volatile Read Configuration Handler --
	----------------------------------------------
	process(i_sys_clock)
	begin

		if rising_edge(i_sys_clock) then

			-- Reset Byte Counter
			if (i_command /= READ_NON_VOLATILE_COMMAND) then
				non_volatile_r_byte_counter <= (others => '1');
			
			-- Decrement Byte Counter
			elsif (i_data_from_mem_ready = '1') then
				non_volatile_r_byte_counter <= non_volatile_r_byte_counter -1;
			end if;
		end if;
	end process;
	non_volatile_r_second_byte <= '1' when (non_volatile_r_byte_counter = "0") else '0';

	----------------------------------------
	-- Non-Volatile Configuration Handler --
	----------------------------------------
	process(i_sys_clock)
	begin

		if rising_edge(i_sys_clock) then

			-- Write Non-Volatile Configuration Register
			if (i_command = WRITE_NON_VOLATILE_COMMAND) and (non_volatile_w_second_byte = '1') then
				non_volatile_spi_mode_reg <= i_data_to_mem(NON_VOLATILE_CONFIG_REG_SPI_QUAD_BIT) & i_data_to_mem(NON_VOLATILE_CONFIG_REG_SPI_DUAL_BIT);

			-- Read Non-Volatile Configuration Register
			elsif (i_command = READ_NON_VOLATILE_COMMAND) and (i_data_from_mem_ready = '1') and (non_volatile_r_second_byte = '1') then
				non_volatile_spi_mode_reg <= i_data_from_mem(NON_VOLATILE_CONFIG_REG_SPI_QUAD_BIT) & i_data_from_mem(NON_VOLATILE_CONFIG_REG_SPI_DUAL_BIT);
			end if;
        end if;
    end process;

	---------------------------------------------
	-- Enhanced Volatile Configuration Handler --
	---------------------------------------------
	process(i_sys_clock)
	begin

		if rising_edge(i_sys_clock) then

			-- Write Enhanced Volatile Configuration Register
			if (i_command = WRITE_ENHANCED_VOLATILE_CONFIG_COMMAND) then
				enhanced_volatile_spi_mode_reg <= i_data_to_mem(ENHANCED_VOLATILE_CONFIG_REG_SPI_QUAD_BIT) & i_data_to_mem(ENHANCED_VOLATILE_CONFIG_REG_SPI_DUAL_BIT);

			-- Read Enhanced Volatile Configuration Register
			elsif (i_data_from_mem_ready = '1') and (i_command = READ_ENHANCED_VOLATILE_CONFIG_COMMAND) then
				enhanced_volatile_spi_mode_reg <= i_data_from_mem(ENHANCED_VOLATILE_CONFIG_REG_SPI_QUAD_BIT) & i_data_from_mem(ENHANCED_VOLATILE_CONFIG_REG_SPI_DUAL_BIT);
			end if;

            -- Apply New Enhanced Volatile Configuration Register to Output Register
            if (i_command = WRITE_ENHANCED_VOLATILE_CONFIG_COMMAND) then
                apply_enhanced_volatile_spi_mode <= '1';
            else
                apply_enhanced_volatile_spi_mode <= '0';
            end if;

        end if;
    end process;

	------------------------------
	-- SPI Mode Output Register --
	------------------------------
	process(i_sys_clock)
	begin
		if rising_edge(i_sys_clock) then

			-- Reset
			if (i_reset = '1') then
				spi_mode_out_reg <= SPI_SINGLE_MODE;

			-- Reset Memory Command (use Non-Volatile SPI Mode)
			elsif (i_command = RESET_NON_VOLATILE_COMMAND) then
				spi_mode_out_reg <= non_volatile_spi_mode_reg;

			-- Write Enhanced Volatile Configuration Register (use Enhanced Volatile SPI Mode)
			elsif (apply_enhanced_volatile_spi_mode = '1') then
				spi_mode_out_reg <= enhanced_volatile_spi_mode_reg;
			end if;
		end if;
	end process;

	----------------------
	-- SPI Mode Outputs --
	----------------------
    -- SPI Single Mode Enable
    o_spi_single_enable <= '1' when (spi_mode_out_reg = SPI_SINGLE_MODE) else '0';

    -- SPI Dual Mode Enable
    o_spi_dual_enable <= '1' when (spi_mode_out_reg = SPI_DUAL_MODE) else '0';

    -- SPI Quad Mode Enable
    o_spi_quad_enable <= '1' when (spi_mode_out_reg(INTERNAL_REG_SPI_QUAD_BIT) = SPI_QUAD_MODE(0)) else '0';

end Behavioral;