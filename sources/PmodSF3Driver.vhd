------------------------------------------------------------------------
-- Engineer:    Dalmasso Loic
-- Create Date: 04/03/2025
-- Module Name: PmodSF3Driver
-- Description:
--      Pmod SF3 Driver for the 32 MB NOR Flash memory MT25QL256ABA.
--		The communication with the Flash uses the SPI protocol (Simple, Dual or Quad SPI modes, dynamically configurable).
--      User specifies the System Input Clock and the Pmod SF3 Driver dynamically computes the SPI Serial Clock Frequency according to the actual Dummy Cycles
--		User specifies the maximum bytes buffer used for data read & write.
--		For each read/write operation, user specifies the number of expected address and data bytes, 'i_addr_bytes' and 'i_data_bytes' respectively.
--
-- Usage:
--		The 'o_ready' signal indicates this module is ready to start new SPI transmission.
--		The 'i_start' signal starts the SPI communication, according to the mode 'i_rw' (Read or Write memory), command/address/data bytes and the expected number of bytes.
--		In Read operation, when the 'o_data_ready', data from memory is available in 'o_data' signal.
--
-- Generics
--		sys_clock: System Input Clock Frequency (Hz)
-- Ports
--		Input 	-	i_sys_clock: System Input Clock
--		Input 	-	i_reset: Module Reset ('0': No Reset, '1': Reset)
--		Input	-	i_start: Start SPI Transmission ('0': No Start, '1': Start)
--		Input 	-	i_rw: Read / Write Mode ('0': Write, '1': Read)
--		Input 	-	i_command: FLASH Command Byte
--		Input 	-	i_addr_bytes: Number of Address Bytes
--		Input 	-	i_addr: FLASH Address Bytes
--		Input 	-	i_data_bytes: Number of Data Bytes to Read/Write
--		Input 	-	i_data: FLASH Data Bytes to Write
--		Output 	-	o_data: Read FLASH Data Bytes
--		Output 	-	o_data_ready: FLASH Data Output Ready (Read Mode) ('0': NOT Ready, '1': Ready)
--		Output 	-	o_ready: Module Ready ('0': NOT Ready, '1': Ready)
--		Output 	-	o_reset: FLASH Reset ('0': Reset, '1': No Reset)
--		Output 	-	o_sclk: SPI Serial Clock
--		Output 	-	io_dq: SPI Data Lines (Simple, Dual or Quad Modes)
--		Output 	-	o_ss: SPI Slave Select Line ('0': Enable, '1': Disable)
--		Output 	-	o_using_sys_freq: System Input Clock as SPI Serial Clock Frequency ('0': Disable, '1': Enable)
------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY PmodSF3Driver is

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

END PmodSF3Driver;

ARCHITECTURE Behavioral of PmodSF3Driver is

------------------------------------------------------------------------
-- Component Declarations
------------------------------------------------------------------------

COMPONENT PmodSF3SPIController is

PORT(
	-- Module Control
	i_sys_clock: IN STD_LOGIC;
	i_sys_clock_en: IN STD_LOGIC;
	i_reset: IN STD_LOGIC;
	i_start: IN STD_LOGIC;
	-- SPI Mode Config (Single, Dual or Quad)
	i_spi_single_enable: IN STD_LOGIC;
	i_spi_dual_enable: IN STD_LOGIC;
	-- Memory Command/Addr/Data
	i_mode: IN STD_LOGIC;
	i_command: IN UNSIGNED(7 downto 0);
	i_addr_bytes: IN INTEGER range 0 to 3;
	i_addr: IN UNSIGNED(23 downto 0);
	i_dummy_cycles: IN INTEGER range 0 to 15;
	i_data_bytes: IN INTEGER;
	i_data_w: IN UNSIGNED(7 downto 0);
	o_next_data_w: OUT STD_LOGIC;
	o_data_r: OUT UNSIGNED(7 downto 0);
	o_data_ready: OUT STD_LOGIC;
	-- Module Outputs
	o_ready: OUT STD_LOGIC;
	o_reset: OUT STD_LOGIC;
	o_sclk: OUT STD_LOGIC;
	io_dq: INOUT STD_LOGIC_VECTOR(3 downto 0);
	o_ss: OUT STD_LOGIC
);

END COMPONENT;

COMPONENT PmodSF3SPIFrequencyGenerator is

GENERIC(
    sys_clock: INTEGER := 100_000_000
);

PORT(
	i_sys_clock: IN STD_LOGIC;
	i_reset: IN STD_LOGIC;
	i_spi_single_enable: IN STD_LOGIC;
	i_spi_dual_enable: IN STD_LOGIC;
	i_dummy_cycles: IN INTEGER range 0 to 15;
	o_spi_freq: OUT STD_LOGIC;
	o_using_sys_freq: OUT STD_LOGIC
);

END COMPONENT;

COMPONENT PmodSF3DummyCycles is

PORT(
	i_sys_clock: IN STD_LOGIC;
    i_command: IN UNSIGNED(7 downto 0);
	i_new_data_to_mem: IN STD_LOGIC;
    i_data_to_mem: IN UNSIGNED(7 downto 0);
	i_data_from_mem_ready: IN STD_LOGIC;
    i_data_from_mem: IN UNSIGNED(7 downto 0);
    o_dummy_cycles: OUT INTEGER range 0 to 15
);

END COMPONENT;

COMPONENT PmodSF3SPIModes is

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

END COMPONENT;

------------------------------------------------------------------------
-- Constant Declarations
------------------------------------------------------------------------
-- Memory Read Mode
constant MEM_READ_MODE: STD_LOGIC := '1';

-- Data Write MSB/LSB Indexes
constant DATA_HIGH_BIT_MSB : INTEGER := (max_data_byte*8)-1;
constant DATA_HIGH_BIT_LSB : INTEGER := (max_data_byte*8)-8;

-- Data Write Unused Bit
constant DATA_BIT_UNUSED: STD_LOGIC := '0';

------------------------------------------------------------------------
-- Signal Declarations
------------------------------------------------------------------------
-- Pmod SF3 Driver States
TYPE pmodPSF3State is (IDLE, START, IN_PROGRESS, COMPLETED);
signal state: pmodPSF3State := IDLE;
signal next_state: pmodPSF3State;

-- Memory Write Mode
signal mem_mode_reg: STD_LOGIC := '0';

-- Data Write & Read Registers
signal data_w_reg: UNSIGNED((max_data_byte*8)-1 downto 0) := (others => '0');
signal next_data_sig: STD_LOGIC := '0';
signal data_r_reg: UNSIGNED((max_data_byte*8)-1 downto 0) := (others => '0');
signal data_r_byte: UNSIGNED(7 downto 0) := (others => '0');
signal data_ready_sig: STD_LOGIC := '0';

-- Data Read Ready
signal data_ready_reg: STD_LOGIC := '0';

-- Dummy Cycles
signal dummy_cycles: INTEGER range 0 to 15 := 0;

-- SPI Controller Ready
signal spi_ready: STD_LOGIC := '0';

-- SPI Modes
signal spi_single_enable: STD_LOGIC := '0';
signal spi_dual_enable: STD_LOGIC := '0';
signal spi_quad_enable: STD_LOGIC := '0'; 

-- SPI Frequency
signal spi_freq: STD_LOGIC := '0';

------------------------------------------------------------------------
-- Module Implementation
------------------------------------------------------------------------
begin

	-----------------------------------
	-- Pmod SF3 Driver State Machine --
	-----------------------------------
	-- Pmod SF3 State
	process(i_sys_clock)
	begin
		if rising_edge(i_sys_clock) then

			-- Reset
			if (i_reset = '1') then
				state <= IDLE;

			else
				state <= next_state;
			end if;
			
		end if;
	end process;

	-- Pmod SF3 Next State
	process(state, i_start, spi_ready)
	begin
		case state is
			-- IDLE
			when IDLE =>	if (i_start = '1') then
								next_state <= START;
							else
								next_state <= IDLE;
							end if;

			-- Start
			when START =>	if (spi_ready = '0') then
								next_state <= IN_PROGRESS;
							else
								next_state <= START;
							end if;

			-- In Progress
			when IN_PROGRESS =>	if (spi_ready = '1') then
									next_state <= COMPLETED;
								else
									next_state <= IN_PROGRESS;
								end if;
			
			-- Completed
			when others => next_state <= IDLE;
		end case;
	end process;

	-------------------------
	-- Memory Mode Handler --
	-------------------------
	process(i_sys_clock)
	begin
		if rising_edge(i_sys_clock) then

			-- Load Memory Mode Input
			if (state = IDLE) then
				mem_mode_reg <= i_rw;
			end if;
		end if;
	end process;

	------------------------
	-- Data Write Handler --
	------------------------
	process(i_sys_clock)
	begin
		if rising_edge(i_sys_clock) then

			-- Load Data Write
			if (state = IDLE) then
				data_w_reg <= i_data;

			-- Data Write Left-Shift
			elsif (state = IN_PROGRESS) and (next_data_sig = '1') then
				data_w_reg <= data_w_reg(DATA_HIGH_BIT_MSB-1 downto 0) & DATA_BIT_UNUSED;
			end if;
			
		end if;
	end process;

	-----------------------
	-- Data Read Handler --
	-----------------------
	process(i_sys_clock)
	begin
		if rising_edge(i_sys_clock) then

			-- Data Read Left-Shift
			if (state = IN_PROGRESS) and (data_ready_sig = '1') then
				
				-- Data Read on 1-Byte
				if (max_data_byte = 1) then
					data_r_reg <= data_r_byte;
				
				-- Data Read on n-Bytes
				else
					data_r_reg <= data_r_reg(DATA_HIGH_BIT_LSB-1 downto 0) & data_r_byte;
				end if;
			end if;			
		end if;
	end process;
	o_data <= data_r_reg;

	-----------------------------
	-- Data Read Ready Handler --
	-----------------------------
	process(i_sys_clock)
	begin
		if rising_edge(i_sys_clock) then

			-- Enable Read Data Valid (End of Read Cycle)
			if (mem_mode_reg = MEM_READ_MODE) and (state = COMPLETED) then
				data_ready_reg <= '1';

			-- Disable Read Data Valid (New cycle)
			elsif (state = START) then
				data_ready_reg <= '0';
			end if;

		end if;
	end process;
	o_data_ready <= data_ready_reg;
	
	---------------------------
	-- Pmod SF3 Ready Status --
	---------------------------
	o_ready <= '1' when state = IDLE else '0';

	--------------------------------------
	-- Pmod SF3 SPI Frequency Generator --
	--------------------------------------
	inst_PmodSF3SPIFrequencyGenerator: PmodSF3SPIFrequencyGenerator
		GENERIC map (
			sys_clock => sys_clock)
		
		PORT map (
			i_sys_clock => i_sys_clock,
			i_reset => i_reset,
			i_spi_single_enable => spi_single_enable,
			i_spi_dual_enable => spi_dual_enable,
			i_dummy_cycles => dummy_cycles,
			o_spi_freq => spi_freq,
			o_using_sys_freq => o_spi_using_sys_freq);

	--------------------------------------
	-- Pmod SF3 Dummy Cycles Controller --
	--------------------------------------
	inst_PmodSF3DummyCycles: PmodSF3DummyCycles
		PORT map (
			i_sys_clock => i_sys_clock,
			i_command => i_command,
			i_new_data_to_mem => next_data_sig,
			i_data_to_mem => data_w_reg(DATA_HIGH_BIT_MSB downto DATA_HIGH_BIT_LSB),
			i_data_from_mem_ready => data_ready_sig,
			i_data_from_mem => data_r_byte,
			o_dummy_cycles => dummy_cycles);

	------------------------
	-- Pmod SF3 SPI Modes --
	------------------------
	inst_PmodSF3SPIModes: PmodSF3SPIModes
		PORT map (
			i_sys_clock => i_sys_clock,
			i_reset => i_reset,
			i_command => i_command,
			i_new_data_to_mem => next_data_sig,
			i_data_to_mem => data_w_reg(DATA_HIGH_BIT_MSB downto DATA_HIGH_BIT_LSB),
			i_data_from_mem_ready => data_ready_sig,
			i_data_from_mem => data_r_byte,
			o_spi_single_enable => spi_single_enable,
			o_spi_dual_enable => spi_dual_enable,
			o_spi_quad_enable => spi_quad_enable);

	-----------------------------
	-- Pmod SF3 SPI Controller --
	-----------------------------
	inst_PmodSF3SPIController: PmodSF3SPIController
		PORT map (
			i_sys_clock => i_sys_clock,
			i_sys_clock_en => spi_freq,
			i_reset => i_reset,
			i_start => i_start,
			i_spi_single_enable => spi_single_enable,
			i_spi_dual_enable => spi_dual_enable,
			i_mode => i_rw,
			i_command => i_command,
			i_addr_bytes => i_addr_bytes,
			i_addr => i_addr,
			i_dummy_cycles => dummy_cycles,
			i_data_bytes => i_data_bytes,
			i_data_w => data_w_reg(DATA_HIGH_BIT_MSB downto DATA_HIGH_BIT_LSB),
			o_next_data_w => next_data_sig,
			o_data_r => data_r_byte,
			o_data_ready => data_ready_sig,
			o_ready => spi_ready,
			o_reset => o_reset,
			o_sclk => o_sclk,
			io_dq => io_dq,
			o_ss => o_ss);

end Behavioral;