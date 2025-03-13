------------------------------------------------------------------------
-- Engineer:    Dalmasso Loic
-- Create Date: 11/03/2025
-- Module Name: Top_PmodSF3Driver
-- Description:
--      Top Module including Pmod SF3 Driver for the 32 MB NOR Flash memory MT25QL256ABA.
--
-- Ports
--		Input 	-	i_sys_clock: System Input Clock
--		Input 	-	i_reset: Module Reset ('0': No Reset, '1': Reset)
--		Input	-	i_start: Start Pmod SF3 Transmission ('0': No Start, '1': Start)
--		Output 	-	o_led: Pmod SF3 Data from Memory
--		Output 	-	o_reset: Pmod SF3 Reset ('0': Reset, '1': No Reset)
--		Output 	-	o_sclk: Pmod SF3SPI Serial Clock
--		In/Out 	-	io_dq: Pmod SF3SPI Data Lines (Simple, Dual or Quad Modes)
--		Output 	-	o_ss: Pmod SF3 SPI Slave Select Line ('0': Enable, '1': Disable)
------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY Top_PmodSF3Driver is

PORT(
	i_sys_clock: IN STD_LOGIC;
    i_reset: IN STD_LOGIC;
    i_start: IN STD_LOGIC;
    o_led: OUT UNSIGNED(15 downto 0);
    -- PMode Ports
    o_reset: OUT STD_LOGIC;
	o_sclk: OUT STD_LOGIC;
	io_dq: INOUT STD_LOGIC_VECTOR(3 downto 0);
	o_ss: OUT STD_LOGIC
);

END Top_PmodSF3Driver;

ARCHITECTURE Behavioral of Top_PmodSF3Driver is

------------------------------------------------------------------------
-- Component Declarations
------------------------------------------------------------------------

COMPONENT clk_wiz_0 
PORT(
    clk_out1: OUT STD_LOGIC;
    clk_in1: IN STD_LOGIC
);

END COMPONENT;

COMPONENT PmodSF3Driver is

GENERIC(
	sys_clock: INTEGER := 100_000_000;
	max_data_byte: INTEGER := 1
);

PORT(
	i_sys_clock: IN STD_LOGIC;
	i_reset: IN STD_LOGIC;
    i_start: IN STD_LOGIC;
    i_rw: IN STD_LOGIC;
    i_command: IN UNSIGNED(7 downto 0);
	i_addr_bytes: IN INTEGER range 0 to 4;
    i_addr: IN UNSIGNED(23 downto 0);
    i_data_bytes: IN INTEGER range 0 to max_data_byte;
	i_data: IN UNSIGNED((max_data_byte*8)-1 downto 0);
	o_data: OUT UNSIGNED((max_data_byte*8)-1 downto 0);
	o_data_ready: OUT STD_LOGIC;
    o_ready: OUT STD_LOGIC;
	o_reset: OUT STD_LOGIC;
	o_sclk: OUT STD_LOGIC;
	io_dq: INOUT STD_LOGIC_VECTOR(3 downto 0);
	o_ss: OUT STD_LOGIC;
	o_spi_using_sys_freq: OUT STD_LOGIC
);

END COMPONENT;

------------------------------------------------------------------------
-- Constant Declarations
------------------------------------------------------------------------
-- Pmod SF3 Driver Read/Write Mode
constant PMOD_DRIVER_READ_MODE: STD_LOGIC := '1';

-- Pmod SF3 Driver Max Data Bytes
constant PMOD_DRIVER_MAX_DATA_BYTES: INTEGER := 1;

-- Pmod SF3 Read Volatile Dummy Cycles
constant READ_VOLATILE_DC_COMMAND: UNSIGNED(7 downto 0) := x"85";

------------------------------------------------------------------------
-- Signal Declarations
------------------------------------------------------------------------
-- Top Pmod SF3 Driver States
TYPE topPmodPSF3State is (  IDLE,
                            CONFIG_READ_VOLATILE_DC, START_READ_VOLATILE_DC, READ_VOLATILE_DC,
                            COMPLETED);
signal state: topPmodPSF3State := IDLE;
signal next_state: topPmodPSF3State;

-- Pmod SF3 System Clock
signal pmod_sys_clock: STD_LOGIC := '0';

-- Pmod SF3 Driver Reset
signal pmod_driver_reset: STD_LOGIC := '0';

-- Pmod SF3 Driver Start
signal pmod_driver_start: STD_LOGIC := '0';

-- Pmod SF3 Driver Read/Write Mode
signal pmod_driver_rw: STD_LOGIC := '0';

-- Pmod SF3 Driver Command Byte
signal pmod_driver_command: UNSIGNED(7 downto 0) := (others => '0');

-- Pmod SF3 Driver Address
signal pmod_driver_addr_bytes: INTEGER range 0 to 4 := 0;
signal pmod_driver_addr: UNSIGNED(23 downto 0) := (others => '0');

-- Pmod SF3 Driver Data
signal pmod_driver_data_bytes: INTEGER range 0 to PMOD_DRIVER_MAX_DATA_BYTES := 0;
signal pmod_driver_data_in: UNSIGNED((PMOD_DRIVER_MAX_DATA_BYTES*8)-1 downto 0) := (others => '0');
signal pmod_driver_data_out: UNSIGNED((PMOD_DRIVER_MAX_DATA_BYTES*8)-1 downto 0) := (others => '0');
signal pmod_driver_data_out_ready: STD_LOGIC := '0';

-- Pmod SF3 Driver Ready
signal pmod_driver_ready: STD_LOGIC := '0';

-- Pmod SF3 Driver SPI using Sys Clock
signal pmod_driver_spi_using_sys_clock: STD_LOGIC := '0';

-- Data from Memory Register
signal data_from_mem: UNSIGNED((PMOD_DRIVER_MAX_DATA_BYTES*8)-1 downto 0) := (others => '0');

------------------------------------------------------------------------
-- Module Implementation
------------------------------------------------------------------------
begin

    --------------------------------------
	-- Top Pmod SF3 Driver System Clock --
	--------------------------------------
    inst_clk_wiz_0: clk_wiz_0 port map(clk_out1 => pmod_sys_clock, clk_in1 => i_sys_clock);

	---------------------------------------
	-- Top Pmod SF3 Driver State Machine --
	---------------------------------------
	-- Top Pmod SF3 State
	process(pmod_sys_clock)
	begin
		if rising_edge(pmod_sys_clock) then

			-- Reset
			if (i_reset = '1') then
				state <= IDLE;
			else
				state <= next_state;
			end if;
			
		end if;
	end process;

	-- Top Pmod SF3 Next State
	process(state, i_start, pmod_driver_ready)
	begin
		case state is
			-- IDLE
			when IDLE =>	if (i_start = '1') then
								next_state <= CONFIG_READ_VOLATILE_DC;
							else
								next_state <= IDLE;
							end if;

            -- Config Read Volatile Dummy Cycles
            when CONFIG_READ_VOLATILE_DC => next_state <= START_READ_VOLATILE_DC;

			-- Start Read Volatile Dummy Cycles
			when START_READ_VOLATILE_DC =>
                            if (pmod_driver_ready = '0') then
								next_state <= READ_VOLATILE_DC;
							else
								next_state <= START_READ_VOLATILE_DC;
							end if;

			-- Read Volatile Dummy Cycles
			when READ_VOLATILE_DC =>
                            if (pmod_driver_ready = '1') then
								next_state <= COMPLETED;
							else
								next_state <= READ_VOLATILE_DC;
							end if;
			
			-- Completed
			when others => next_state <= COMPLETED;
		end case;
	end process;

    ---------------------------
	-- Pmod SF3 Driver Reset --
	---------------------------
	process(pmod_sys_clock)
	begin
		if rising_edge(pmod_sys_clock) then

			-- Start Pmod SF3 Driver
			if (state = IDLE) then
				pmod_driver_reset <= '1';
			else
                pmod_driver_reset <= '0';
			end if;
		end if;
	end process;

	---------------------------
	-- Pmod SF3 Driver Start --
	---------------------------
	process(pmod_sys_clock)
	begin
		if rising_edge(pmod_sys_clock) then

			-- Start Pmod SF3 Driver
			if (state = START_READ_VOLATILE_DC) then
				pmod_driver_start <= '1';
			else
                pmod_driver_start <= '0';
			end if;
		end if;
	end process;

	-------------------------------------
	-- Pmod SF3 Driver Read/Write Mode --
	-------------------------------------
	process(pmod_sys_clock)
	begin
		if rising_edge(pmod_sys_clock) then

			-- Start Pmod SF3 Driver
			if (state = CONFIG_READ_VOLATILE_DC) then
				pmod_driver_rw <= PMOD_DRIVER_READ_MODE;
			end if;
		end if;
	end process;

	-----------------------------
	-- Pmod SF3 Driver Command --
	-----------------------------
	process(pmod_sys_clock)
	begin
		if rising_edge(pmod_sys_clock) then

			-- Pmod SF3 Read Volatile Dummy Cycles Command
			if (state = CONFIG_READ_VOLATILE_DC) then
				pmod_driver_command <= READ_VOLATILE_DC_COMMAND;
			end if;
		end if;
	end process;

	-----------------------------
	-- Pmod SF3 Driver Address --
	-----------------------------
	process(pmod_sys_clock)
	begin
		if rising_edge(pmod_sys_clock) then

			-- Pmod SF3 Read Volatile Dummy Cycles Address
			if (state = CONFIG_READ_VOLATILE_DC) then
				pmod_driver_addr_bytes <= 0;
                pmod_driver_addr <= (others => '0');
			end if;
		end if;
	end process;

    -------------------------------
	-- Pmod SF3 Driver Data Byte --
	-------------------------------
	process(pmod_sys_clock)
	begin
		if rising_edge(pmod_sys_clock) then

			-- Pmod SF3 Read Volatile Dummy Cycles Data Byte
			if (state = CONFIG_READ_VOLATILE_DC) then
				pmod_driver_data_bytes <= 1;
			end if;
		end if;
	end process;

	--------------------------------
	-- Pmod SF3 Driver Data Input --
	--------------------------------
	process(pmod_sys_clock)
	begin
		if rising_edge(pmod_sys_clock) then

			-- Pmod SF3 Read Volatile Dummy Cycles Data Input
			if (state = CONFIG_READ_VOLATILE_DC) then
                pmod_driver_data_in <= (others => '0');
			end if;
		end if;
	end process;

	---------------------------------
	-- Pmod SF3 Driver Data Output --
	---------------------------------
	process(pmod_sys_clock)
	begin
		if rising_edge(pmod_sys_clock) then

            -- Reset
            if (state = IDLE) then
                data_from_mem <= (others => '0');
			
            -- Pmod SF3 Read Volatile Dummy Cycles Data Output
			elsif (state = COMPLETED) and (pmod_driver_data_out_ready = '1') then
                data_from_mem <= pmod_driver_data_out;
			end if;
		end if;
	end process;

	---------------------
	-- Pmod SF3 Driver --
	---------------------
	inst_PmodSF3Driver: PmodSF3Driver
        GENERIC map (
            sys_clock => 24_000_000,
            max_data_byte => PMOD_DRIVER_MAX_DATA_BYTES)

		PORT map (
			i_sys_clock => pmod_sys_clock,
			i_reset => pmod_driver_reset,
			i_start => pmod_driver_start,
            i_rw => pmod_driver_rw,
            i_command => pmod_driver_command,
            i_addr_bytes => pmod_driver_addr_bytes,
            i_addr => pmod_driver_addr,
            i_data_bytes => pmod_driver_data_bytes,
            i_data => pmod_driver_data_in,
            o_data => pmod_driver_data_out,
            o_data_ready => pmod_driver_data_out_ready,
            o_ready => pmod_driver_ready,
            o_reset => o_reset,
            o_sclk => o_sclk,
            io_dq => io_dq,
            o_ss => o_ss,
            o_spi_using_sys_freq => pmod_driver_spi_using_sys_clock);            

	-----------------
	-- LEDs Output --
	-----------------
    o_led(7 downto 0) <= data_from_mem;
    o_led(8 downto 8) <= (others => '0');
    o_led(9) <= i_start;
    o_led(10) <= pmod_driver_ready;
    o_led(11) <= '1' when state = IDLE else '0';
    o_led(12) <= '1' when state = CONFIG_READ_VOLATILE_DC else '0';
    o_led(13) <= '1' when state = START_READ_VOLATILE_DC else '0';
    o_led(14) <= '1' when state = READ_VOLATILE_DC else '0';
    o_led(15) <= '1' when state = COMPLETED else '0';

end Behavioral;