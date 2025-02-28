	------------------------------------------------------------------------
-- Engineer:    Dalmasso Loic
-- Create Date: 17/02/2025
-- Module Name: PmodSF3Driver
-- Description:
--      Pmod SF3 Driver for the 32 MB NOR Flash memory MT25QL256ABA. The communication with the Flash uses the SPI protocol (Simple, Dual or Quad SPI)
--      User specifies the System Input Clock and the Pmod SF3 Driver dynamically computes the SPI Serial Clock Frequency according to the actual Dummy Cycles
--
-- Usage:
--		The o_ready signal (set to '1') indicates the PmodSF3Driver is ready to receive new command/data (...).
--		Once data are set, the i_enable signal can be triggered (set to '1') to begin transmission.
--		The o_ready signal is set to '0' to acknowledge the receipt and the application of the new command/data.
--		When the transmission is complete, the o_ready is set to '1' and the PmodSF3Driver is ready for new transmission.
--
-- Generics
--		sys_clock: System Input Clock Frequency (Hz)
-- Ports
--		Input 	-	i_sys_clock: System Input Clock
--		Input 	-	i_reset: Module Reset ('0': No Reset, '1': Reset)
--		Input 	-	i_enable: Module Enable ('0': Disable, '1': Enable)
--		Input 	-	i_rw: Read / Write Mode ('0': Write, '1': Read)
--		Input 	-	i_command: FLASH Command Byte
--		Input 	-	i_addr: FLASH Address Bytes
--		Input 	-	i_addr_byte: Number of Address Bytes
--		Input 	-	i_data: FLASH Data Bytes to Write
--		Input 	-	i_data_byte: Number of Data Bytes to Read/Write
--		Output 	-	o_data: Read FLASH Data Bytes
--		Output 	-	o_data_ready: FLASH Data Output Ready (Read Mode) ('0': NOT Ready, '1': Ready)
--		Output 	-	o_ready: Module Ready ('0': NOT Ready, '1': Ready)
--		Output 	-	o_sclk: SPI Serial Clock
--		Output 	-	io_dq: SPI Data Lines (Simple, Dual or Quad Modes)
--		Output 	-	o_ss: SPI Slave Select Line ('0': Enable, '1': Disable)
------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY PmodSF3Driver is

GENERIC(
	sys_clock: INTEGER := 100_000_000
);

PORT(
	i_sys_clock: IN STD_LOGIC;
	i_reset: IN STD_LOGIC;
    i_enable: IN STD_LOGIC;
    i_rw: IN STD_LOGIC;
    i_command: IN UNSIGNED(7 downto 0);
    i_addr: IN UNSIGNED(31 downto 0);
    i_addr_byte: IN INTEGER range 0 to 4;
    i_data: IN UNSIGNED(15 downto 0);
    i_data_byte: IN INTEGER;
	o_data: OUT UNSIGNED(7 downto 0);
	o_data_ready: OUT STD_LOGIC;
    o_ready: OUT STD_LOGIC;
	o_sclk: OUT STD_LOGIC;
    io_dq: INOUT STD_LOGIC;
	o_ss: OUT STD_LOGIC
);

END PmodSF3Driver;

ARCHITECTURE Behavioral of PmodSF3Driver is

------------------------------------------------------------------------
-- Constant Declarations
------------------------------------------------------------------------
-- Write Non Volatile Configuration Register
constant WRITE_NON_VOLATILE_CONFIG_REG: UNSIGNED(7 downto 0) := x"B1";
constant NON_VOLATILE_CONFIG_REG_DUMMY_CYCLE_MSB_BIT: INTEGER := 15;
constant NON_VOLATILE_CONFIG_REG_DUMMY_CYCLE_LSB_BIT: INTEGER := 12;
constant NON_VOLATILE_CONFIG_REG_QUAD_SPI_BIT: INTEGER := 3;
constant NON_VOLATILE_CONFIG_REG_DUAL_SPI_BIT: INTEGER := 2;

-- Volatile Configuration Register
constant WRITE_VOLATILE_CONFIG_REG: UNSIGNED(7 downto 0) := x"81";
constant VOLATILE_CONFIG_REG_DUMMY_CYCLE_MSB_BIT: INTEGER := 7;
constant VOLATILE_CONFIG_REG_DUMMY_CYCLE_LSB_BIT: INTEGER := 4;

-- Enhanced Volatile Configuration Register
constant WRITE_ENHANCED_VOLATILE_CONFIG_REG: UNSIGNED(7 downto 0) := x"61";
constant ENHANCED_VOLATILE_CONFIG_REG_QUAD_SPI_BIT: INTEGER := 7;
constant ENHANCED_VOLATILE_CONFIG_REG_DUAL_SPI_BIT: INTEGER := 6;

-- FLASH SPI Mode (Simple: 0, Dual: 1, Quad: 2)
constant SPI_SIMPLE_MODE: INTEGER := 0;
constant SPI_DUAL_MODE: INTEGER := 1;
constant SPI_QUAD_MODE: INTEGER := 2;

------------------------------------------------------------------------
-- Signal Declarations
------------------------------------------------------------------------
-- FLASH Dummy Cycles
signal dummy_cycles: INTEGER := '0';

-- Pmod SF3 SPI Mode
signal pmodsf3_spi_mode: INTEGER range 0 to 2 := SPI_SIMPLE_MODE;

-- Pmod SF3 End of Initialization
signal pmodsf3_init_end: STD_LOGIC := '0';





-- SPI Clock Dividers
constant CLOCK_DIV: INTEGER := sys_clock / spi_clock;
constant CLOCK_DIV_X2: INTEGER := CLOCK_DIV /2;

-- SPI SCLK IDLE Bit
constant SCLK_IDLE_BIT: STD_LOGIC := '0';

-- SPI MOSI IDLE Bit
constant MOSI_IDLE_BIT: STD_LOGIC := '0';

-- SPI Enable Slave Select Line
constant ENABLE_SS_LINE: STD_LOGIC := '0';

------------------------------------------------------------------------
-- Signal Declarations
------------------------------------------------------------------------
-- Pmod SF3 States
TYPE pmodsf3State is (IDLE, DUMMY_CYCLES, WRITE_BYTES,, WAITING);
signal state: pmodsf3State := IDLE;
signal next_state: pmodsf3State;




-- Pmod DA4 Input Registers
signal enable_reg: STD_LOGIC := '0';
signal command_reg: UNSIGNED(3 downto 0) := (others => '0');
signal addr_reg: UNSIGNED(3 downto 0) := (others => '0');
signal digital_value_reg: UNSIGNED(11 downto 0) := (others => '0');
signal config_reg: UNSIGNED(7 downto 0) := (others => '0');



-- SPI Clock Divider
signal spi_clock_divider: INTEGER range 0 to CLOCK_DIV-1 := 0;
signal spi_clock_rising: STD_LOGIC := '0';
signal spi_clock_falling: STD_LOGIC := '0';

-- SPI Transmission Bit Counter (31 bits)
signal bit_counter: UNSIGNED(4 downto 0) := (others => '0');
signal bit_counter_end: STD_LOGIC := '0';

-- SPI SCLK
signal sclk_out: STD_LOGIC := '0';

-- SPI MOSI Register
signal mosi_reg: UNSIGNED(31 downto 0) := (others => '0');

------------------------------------------------------------------------
-- Module Implementation
------------------------------------------------------------------------
begin

	------------------------------
	-- Pmod DA4 Input Registers --
	------------------------------
	process(i_sys_clock)
	begin

		if rising_edge(i_sys_clock) then

            -- Load Inputs
            if (state = IDLE) then
				enable_reg <= i_enable;
                command_reg <= i_command;
                addr_reg <= i_addr;
                digital_value_reg <= i_digital_value;
				config_reg <= i_config;
            end if;

        end if;
    end process;

	-----------------------
	-- SPI Clock Divider --
	-----------------------
	process(i_sys_clock)
	begin
		if rising_edge(i_sys_clock) then

			-- Reset SPI Clock Divider
			if (enable_reg = '0') or (spi_clock_divider = CLOCK_DIV-1) then
				spi_clock_divider <= 0;

			-- Increment SPI Clock Divider
			else
                spi_clock_divider <= spi_clock_divider +1;
			end if;
		end if;
	end process;

	---------------------
	-- SPI Clock Edges --
	---------------------
	process(i_sys_clock)
	begin
		if rising_edge(i_sys_clock) then

			-- SPI Clock Rising Edge
			if (spi_clock_divider = CLOCK_DIV-1) then
				spi_clock_rising <= '1';
			else
				spi_clock_rising <= '0';
			end if;

			-- SPI Clock Falling Edge
			if (spi_clock_divider = CLOCK_DIV_X2-1) then
				spi_clock_falling <= '1';
			else
				spi_clock_falling <= '0';
			end if;

		end if;
	end process;

	-----------------------
	-- SPI State Machine --
	-----------------------
    -- SPI State
	process(i_sys_clock)
	begin
		if rising_edge(i_sys_clock) then

			-- Next State (When SPI Clock Rising Edge)
			if (spi_clock_rising = '1') then
				state <= next_state;
			end if;
			
		end if;
	end process;

	-- SPI Next State
	process(state, enable_reg, bit_counter_end)
	begin
		case state is
			when IDLE =>    if (enable_reg = '1') then
                                next_state <= BYTES_TX;
                            else
                                next_state <= IDLE;
							end if;

			-- Bytes TX Cycle
			when BYTES_TX =>
							-- End of Bytes TX Cycle
							if (bit_counter_end = '1') then
                                next_state <= WAITING;
							else
								next_state <= BYTES_TX;
							end if;

            -- Waiting Time for Next Transmission
			when others => next_state <= IDLE;
		end case;
	end process;

	---------------------
	-- SPI Bit Counter --
	---------------------
	process(i_sys_clock)
	begin
		if rising_edge(i_sys_clock) then

			-- SPI Clock Rising Edge
			if (spi_clock_rising = '1') then

                -- Increment Bit Counter
                if (state = BYTES_TX) then
                    bit_counter <= bit_counter +1;
                
                -- Reset Bit Counter
				else
					bit_counter <= (others => '0');
				end if;
			end if;
		end if;
    end process;

	-- Bit Counter End
	bit_counter_end <= bit_counter(4) and bit_counter(3) and bit_counter(2) and bit_counter(1) and bit_counter(0);

	--------------------
	-- Pmod DA4 Ready --
	--------------------
    o_ready <= '1' when (state = IDLE) else '0';

    ---------------------
	-- SPI SCLK Output --
	---------------------
	process(i_sys_clock)
	begin
		if rising_edge(i_sys_clock) then

			-- SCLK Rising Edge
			if (spi_clock_rising = '1') then
				sclk_out <= '1';
			
			-- SCLK Falling Edge
			elsif (spi_clock_falling = '1') then
                sclk_out <= '0';
			
			end if;
		end if;
	end process;
	o_sclk <= sclk_out when state = BYTES_TX else SCLK_IDLE_BIT;

	----------------------------
	-- SPI Write Value (MOSI) --
	----------------------------
	process(i_sys_clock)
	begin

		if rising_edge(i_sys_clock) then
			
			-- Load MOSI Register
			if (state = IDLE) then

                -- Don't Care Bits
				mosi_reg(31 downto 28) <= (others => AD5628_DONT_CARE_BIT);

                -- Command Bits
                mosi_reg(27 downto 24) <= command_reg;

                -- Address Bits
                mosi_reg(23 downto 20) <= addr_reg;

                -- Data Bits
                mosi_reg(19 downto 8) <= digital_value_reg;

                -- Configuration Bits
				mosi_reg(7 downto 0) <= config_reg;

			-- Left-Shift MOSI Register 
			elsif (state = BYTES_TX) and (spi_clock_rising = '1') then
				mosi_reg <= mosi_reg(30 downto 0) & MOSI_IDLE_BIT;
			end if;

		end if;
	end process;
	o_mosi <= mosi_reg(31) when state = BYTES_TX else MOSI_IDLE_BIT;

    ---------------------------
	-- SPI Slave Select Line --
	---------------------------
    o_ss <= ENABLE_SS_LINE when state = BYTES_TX else not(ENABLE_SS_LINE);

end Behavioral;