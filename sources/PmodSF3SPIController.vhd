------------------------------------------------------------------------
-- Engineer:    Dalmasso Loic
-- Create Date: 19/02/2025
-- Module Name: PmodSF3SPIController
-- Description:
--      Pmod SF3 SPI Controller for the 32 MB NOR Flash Memory MT25QL256ABA.
--		Supports Single, Dual and Quad SPI Modes:
--		| i_spi_dual_enable | i_spi_single_enable | SPI Mode
--		|   	   0 		|   	   1 		  | Single
--		|   	   1 		|   	   1 		  | Single
--		|   	   1 		|   	   0 		  | Dual
--		|   	   0 		|   	   1 		  | Quad
--
--		The 'o_ready' signal indicates this module is ready to start new SPI transmission.
--		The 'i_start' signal starts the SPI communication, according to the mode (Read or Write memory), command/address/data bytes.
--		In Write operation, when the 'o_next_data_w' is set to '1', the MSB of the 'i_data_w' is loaded.
--		In Read operation, when the 'o_data_ready', data from memory is available in 'o_data_r' signal.
--
-- Ports
--		Input 	-	i_sys_clock: System Input Clock
--		Input 	-	i_sys_clock_en: System Input Clock Enable
--		Input	-	i_reset: System Input Reset ('0': No Reset, '1': Reset)
--		Input	-	i_start: Start SPI Transmission ('0': No Start, '1': Start)
--		Input	-	i_spi_single_enable: Enable SPI Single Mode ('0': Disable, '1': Enable)
--		Input	-	i_spi_dual_enable: Enable SPI Dual Mode ('0': Disable, '1': Enable)
--		Input	-	i_mode: Set Memory Operation Mode ('0': Write, '1': Mode)
--		Input 	-	i_command: Command Byte
--		Input 	-	i_addr_bytes: Number of Address Bytes to use (0 to 3 bytes)
--		Input 	-	i_addr: Address Bytes
--		Input 	-	i_dummy_cycles: Number of Dummy Cycles (0 to 15 cycles)
--		Input 	-	i_data_bytes: Number of Data Bytes to write
--		Input 	-	i_data_w: Data Bytes to write
--		Output 	-	o_next_data_w: Next bit of Data Bytes trigger ('0': Disable, '1': Enable)
--		Output 	-	o_data_r: Data Bytes read from Memory
--		Output 	-	o_data_ready: Data Bytes read from Memory Ready ('0': NOT Ready, '1': Ready)
--		Output 	-	o_ready: System Ready for transmission
--		Output 	-	o_reset: Memory Reset ('0': Reset, '1': No Reset)
--		Output 	-	o_sclk: SPI Serial Clock
--		In/Out 	-	io_dq: SPI Serial Data
--		Output 	-	o_ss: SPI Slave Select Line ('0': Enable, '1': Disable)
------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY PmodSF3SPIController is

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

END PmodSF3SPIController;

ARCHITECTURE Behavioral of PmodSF3SPIController is

------------------------------------------------------------------------
-- Constant Declarations
------------------------------------------------------------------------
-- SPI Write Register Length: Command (1 Byte) + Address (3 Bytes) + Data (1 Byte)
constant SPI_WRITE_REGISTER_LENGTH: INTEGER := 40;

-- SPI Write Register Indexes
constant SPI_WRITE_REGISTER_CMD_MSB: INTEGER := SPI_WRITE_REGISTER_LENGTH-1;
constant SPI_WRITE_REGISTER_CMD_LSB: INTEGER := SPI_WRITE_REGISTER_LENGTH-8;
constant SPI_WRITE_REGISTER_ADDR_DATA_MSB: INTEGER := SPI_WRITE_REGISTER_LENGTH-9;

-- SPI Empty Write Bits
constant EMPTY_WRITE_BITS: UNSIGNED(SPI_WRITE_REGISTER_ADDR_DATA_MSB-8 downto 0) := (others => '0');

-- SPI SCLK IDLE Bit
constant SPI_SCLK_IDLE: STD_LOGIC := '1';

-- SPI DQ IDLE Bit
constant SPI_DQ_IDLE: STD_LOGIC := 'Z';

-- SPI Disable Slave Select Bit
constant DISABLE_SS_BIT: STD_LOGIC := '1';

-- SPI Bit Counter Increment
constant SPI_BIT_COUNTER_END: UNSIGNED(2 downto 0) := "111";
constant SPI_BIT_COUNTER_INCREMENT_1: UNSIGNED(2 downto 0) := "001";
constant SPI_BIT_COUNTER_INCREMENT_2: UNSIGNED(2 downto 0) := "010";
constant SPI_BIT_COUNTER_INCREMENT_4: UNSIGNED(2 downto 0) := "100";

-- Memory Read Mode
constant MEM_READ_MODE: STD_LOGIC := '1';
constant MEM_WRITE_MODE: STD_LOGIC := '0';

------------------------------------------------------------------------
-- Signal Declarations
------------------------------------------------------------------------
-- SPI Controller States
TYPE spiState is (IDLE, WRITE_CMD, WRITE_ADDR, DUMMY_CYCLES, BYTES_TXRX, STOP_TX);
signal state: spiState := IDLE;
signal next_state: spiState;

-- SPI Modes
signal spi_single_enable_reg: STD_LOGIC := '0';
signal spi_dual_enable_reg: STD_LOGIC := '0';

-- Memory Operation Mode
signal mem_mode_reg: STD_LOGIC := '0';

-- Address & Data Byte Number
signal addr_bytes_reg: INTEGER range 0 to 3 := 0;
signal data_bytes_reg: INTEGER := 0;

-- Data to Memory
signal data_w_reg: UNSIGNED(SPI_WRITE_REGISTER_LENGTH-1 downto 0) := (others => '0');

-- Number of Dummy Cycles
signal dummy_cycles_reg: INTEGER range 0 to 15 := 0;

-- Data from Memory
signal data_r_reg: UNSIGNED(7 downto 0) := (others => '0');
signal data_r_ready_reg: STD_LOGIC := '0';

-- SPI Transmission Bit Counter
signal bit_counter: UNSIGNED(2 downto 0) := (others => '0');
signal bit_counter_increment: UNSIGNED(2 downto 0) := (others => '0');
signal bit_counter_end: STD_LOGIC := '0';

-- SPI SCLK
signal sclk_reg: STD_LOGIC := '0';
signal sclk_edge_reg0: STD_LOGIC := '0';
signal sclk_edge_reg1: STD_LOGIC := '0';
signal sclk_rising_edge: STD_LOGIC := '0';
signal sclk_falling_edge: STD_LOGIC := '0';

------------------------------------------------------------------------
-- Module Implementation
------------------------------------------------------------------------
begin

	-----------------------
	-- SPI State Machine --
	-----------------------
	-- SPI State
	process(i_sys_clock)
	begin
		if rising_edge(i_sys_clock) then

			-- Reset
			if (i_reset = '1') then
				state <= IDLE;

			-- Clock Enable
			elsif (i_sys_clock_en = '1') then
				state <= next_state;
			end if;
			
		end if;
	end process;

	-- SPI Next State
	process(state, i_start, bit_counter_end, mem_mode_reg, addr_bytes_reg, dummy_cycles_reg, data_bytes_reg)
	begin
		case state is
			when IDLE =>	if (i_start = '1') then
								next_state <= WRITE_CMD;
							else
								next_state <= IDLE;
							end if;

			-- Write Command Byte
			when WRITE_CMD =>
							-- End of Write Command Byte
							if (bit_counter_end = '1') then

								-- Address Bytes
								if (addr_bytes_reg = 0) then
									next_state <= BYTES_TXRX;
								else
									next_state <= WRITE_ADDR;
								end if;

							-- Continue Write Command Byte
							else
								next_state <= WRITE_CMD;
							end if;

			-- Write Address Bytes
			when WRITE_ADDR =>
							-- End of Write Address Bytes
							if (bit_counter_end = '1') and (addr_bytes_reg <= 1) then

								-- Dummy Cycles
								if (mem_mode_reg = MEM_READ_MODE) and (dummy_cycles_reg /= 0) then
									next_state <= DUMMY_CYCLES;
								else
									next_state <= BYTES_TXRX;									
								end if;

							-- Continue Write Address Bytes
							else
								next_state <= WRITE_ADDR;
							end if;

			-- Dummy Cycles
			when DUMMY_CYCLES =>
							-- End of Dummy Cycles
							if (dummy_cycles_reg <= 1) then
								next_state <= BYTES_TXRX;

							-- Continue Waiting Dummy Cycles
							else
								next_state <= DUMMY_CYCLES;
							end if;

			-- Read/Write Data Bytes
			when BYTES_TXRX =>
							-- End of Write Data Byte
							if (bit_counter_end = '1') and (data_bytes_reg <= 1) then
								next_state <= STOP_TX;
							else
								next_state <= BYTES_TXRX;
							end if;

			-- End of Transmission
			when others => next_state <= IDLE;
		end case;
	end process;

	---------------------
	-- SPI SCLK Output --
	---------------------
	process(i_sys_clock)
	begin
		if rising_edge(i_sys_clock) then

			-- Clock Enable
			if (i_sys_clock_en = '1') then

				-- Reset SCLK
				if (state = IDLE) or (state = STOP_TX) then
					sclk_reg <= SPI_SCLK_IDLE;

				-- Generate SCLK
				else
					sclk_reg <= not(sclk_reg);
				end if;

			end if;
		end if;
	end process;
	o_sclk <= sclk_reg;

	-----------------------------
	-- SPI SCLK Edge Detection --
	-----------------------------
	process(i_sys_clock)
	begin
		if rising_edge(i_sys_clock) then

			-- SCLK Edge Detection
			sclk_edge_reg0 <= sclk_reg;
			sclk_edge_reg1 <= sclk_edge_reg0;
		end if;
	end process;
	sclk_rising_edge <= sclk_edge_reg0 and not(sclk_edge_reg1);
	sclk_falling_edge <= not(sclk_edge_reg0) and sclk_edge_reg1;

	----------------------
	-- SPI Mode Handler --
	----------------------
	process(i_sys_clock)
	begin
		if rising_edge(i_sys_clock) then

			-- Clock Enable
			if (i_sys_clock_en = '1') then

				-- Load SPI Mode Inputs
				if (state = IDLE) then
					spi_single_enable_reg <= i_spi_single_enable;
					spi_dual_enable_reg <= i_spi_dual_enable;
				end if;
			end if;
		end if;
	end process;

	-------------------------
	-- Memory Mode Handler --
	-------------------------
	process(i_sys_clock)
	begin
		if rising_edge(i_sys_clock) then

			-- Clock Enable
			if (i_sys_clock_en = '1') then

				-- Load Memory Mode Input
				if (state = IDLE) then
					mem_mode_reg <= i_mode;
				end if;
			end if;
		end if;
	end process;

	-------------------------------------
	-- Command, Address & Data Handler --
	-------------------------------------
	process(i_sys_clock)
	begin
		if rising_edge(i_sys_clock) then

			-- Clock Enable
			if (i_sys_clock_en = '1') then

				-- Load Inputs
				if (state = IDLE) then

					-- Command Byte
					data_w_reg(SPI_WRITE_REGISTER_CMD_MSB downto SPI_WRITE_REGISTER_CMD_LSB) <= i_command;

					-- Address & Data Bytes
					if (i_addr_bytes /= 0) then
						data_w_reg(SPI_WRITE_REGISTER_ADDR_DATA_MSB downto 0) <= i_addr & i_data_w;

					-- Data Byte only
					else
						data_w_reg(SPI_WRITE_REGISTER_ADDR_DATA_MSB downto 0) <= i_data_w & EMPTY_WRITE_BITS;
					end if;

				-- Handle Next Data to Write (Left-Shift Data Write Register & new Data Input)
				elsif (state = WRITE_CMD) or (state = WRITE_ADDR) or (state = BYTES_TXRX) then

					-- Next Data to Write on SCLK Falling Edge
					if (sclk_falling_edge = '1') and (addr_bytes_reg /= 0) and (data_bytes_reg /= 0) then

						-- Single SPI Mode: DQ0
						if (spi_single_enable_reg = '1') then
							data_w_reg <= data_w_reg(SPI_WRITE_REGISTER_LENGTH-2 downto 0) & i_data_w(7);
						
						-- Dual SPI Mode: DQ[1:0]
						elsif (spi_dual_enable_reg = '1') then
							data_w_reg <= data_w_reg(SPI_WRITE_REGISTER_LENGTH-3 downto 0) & i_data_w(7 downto 6);
						
						-- Quad SPI Mode: DQ[3:0]
						else
							data_w_reg <= data_w_reg(SPI_WRITE_REGISTER_LENGTH-5 downto 0) & i_data_w(7 downto 4);
						end if;
					end if;
				end if;
			end if;
		end if;
	end process;

	-----------------------------
	-- Next Write Data Trigger --
	-----------------------------
	o_next_data_w <= '1' when (mem_mode_reg = MEM_WRITE_MODE) and (sclk_falling_edge = '1') and ((state = WRITE_CMD) or (state = WRITE_ADDR) or (state = BYTES_TXRX)) else '0';

	---------------------------
	-- Address Bytes Handler --
	----------------------------
	process(i_sys_clock)
	begin
		if rising_edge(i_sys_clock) then

			-- Clock Enable
			if (i_sys_clock_en = '1') then

				-- Load Address Bytes Input
				if (state = IDLE) then
					addr_bytes_reg <= i_addr_bytes;

				-- Address Bytes State
				elsif (state = WRITE_ADDR) and (bit_counter_end = '1') then
					-- Decrement Address Bytes
					addr_bytes_reg <= addr_bytes_reg -1;
				end if;
			end if;
		end if;
	end process;

	--------------------------
	-- Dummy Cycles Handler --
	--------------------------
	process(i_sys_clock)
	begin
		if rising_edge(i_sys_clock) then

			-- Clock Enable
			if (i_sys_clock_en = '1') then

				-- Load Dummy Cycles Input
				if (state = IDLE) then
					dummy_cycles_reg <= i_dummy_cycles;

				-- Dummy Cycles State
				elsif (state = DUMMY_CYCLES) then
					-- Decrement Dummy Cycles
					dummy_cycles_reg <= dummy_cycles_reg -1;
				end if;
			end if;
		end if;
	end process;

	------------------------
	-- Data Bytes Handler --
	------------------------
	process(i_sys_clock)
	begin
		if rising_edge(i_sys_clock) then

			-- Clock Enable
			if (i_sys_clock_en = '1') then

				-- Load Data Bytes Input
				if (state = IDLE) then
					data_bytes_reg <= i_data_bytes;

				-- Data Bytes State
				elsif (state = BYTES_TXRX) and (bit_counter_end = '1') then
					-- Decrement Data Bytes
					data_bytes_reg <= data_bytes_reg -1;
				end if;
			end if;
		end if;
	end process;

	---------------------
	-- SPI Bit Counter --
	---------------------
	process(i_sys_clock)
	begin
		if rising_edge(i_sys_clock) then

			-- Clock Enable
			if (i_sys_clock_en = '1') then
				
				-- Bit Counter Increment
				if (state = IDLE) then

					-- Single SPI Mode
					if (spi_single_enable_reg = '1') then
						bit_counter_increment <= SPI_BIT_COUNTER_INCREMENT_1;

					-- Dual SPI Mode
					elsif (spi_dual_enable_reg = '1')  then
						bit_counter_increment <= SPI_BIT_COUNTER_INCREMENT_2;

					-- Quad SPI Mode
					else
						bit_counter_increment <= SPI_BIT_COUNTER_INCREMENT_4;
					end if;
				end if;

				-- Reset Bit Counter
				if (state = IDLE) or (state = DUMMY_CYCLES) then
					bit_counter <= (others => '0');
				
				-- Increment Bit Counter (only at SCLK Falling Edge)
				elsif (sclk_falling_edge = '1') then
					bit_counter <= bit_counter +bit_counter_increment;			
				end if;
			end if;
		end if;
	end process;

	-- Bit Counter End
	process(i_sys_clock)
	begin
		if rising_edge(i_sys_clock) then

			-- Clock Enable
			if (i_sys_clock_en = '1') then
				
				-- Bit Counter End Trigger (only at SCLK Rising Edge)
				if (sclk_rising_edge = '1') and (bit_counter = SPI_BIT_COUNTER_END) then
					bit_counter_end <= '1';
				
				-- Reset Bit Counter End
				else
					bit_counter_end <= '0';
				end if;
			end if;
		end if;
	end process;

	---------------------------
	-- SPI Write Data (MOSI) --
	---------------------------
	process(state, mem_mode_reg, spi_single_enable_reg, spi_dual_enable_reg, data_w_reg)
	begin
		if (state = WRITE_CMD) or (state = WRITE_ADDR) or ((state = BYTES_TXRX) and (mem_mode_reg = MEM_WRITE_MODE)) then
			
			-- Single SPI Mode: DQ0
			if (spi_single_enable_reg = '1') then
				io_dq(3) <= SPI_DQ_IDLE;
				io_dq(2) <= SPI_DQ_IDLE;
				io_dq(1) <= SPI_DQ_IDLE;
				io_dq(0) <= data_w_reg(SPI_WRITE_REGISTER_LENGTH-1);

			-- Dual SPI Mode: DQ[1:0]
			elsif (spi_dual_enable_reg = '1') then
				io_dq(3) <= SPI_DQ_IDLE;
				io_dq(2) <= SPI_DQ_IDLE;
				io_dq(1) <= data_w_reg(SPI_WRITE_REGISTER_LENGTH-1);
				io_dq(0) <= data_w_reg(SPI_WRITE_REGISTER_LENGTH-2);
			
			-- Quad SPI Mode: DQ[3:0]
			else
				io_dq(3) <= data_w_reg(SPI_WRITE_REGISTER_LENGTH-1);
				io_dq(2) <= data_w_reg(SPI_WRITE_REGISTER_LENGTH-2);
				io_dq(1) <= data_w_reg(SPI_WRITE_REGISTER_LENGTH-3);
				io_dq(0) <= data_w_reg(SPI_WRITE_REGISTER_LENGTH-4);
			end if;
		
		-- IDLE
		else
			io_dq <= (others => SPI_DQ_IDLE);
		end if;
	end process;

	--------------------------
	-- SPI Read Data (MISO) --
	--------------------------
	process(i_sys_clock)
	begin
		if rising_edge(i_sys_clock) then

			-- Sampling Read Data Enable
			if (i_sys_clock_en = '1') then
				
				-- Next Data to Write on SCLK Rising Edge (Left-Shift Data Read Register & new SPI Data Input)
				if (sclk_rising_edge = '1') and (mem_mode_reg = MEM_READ_MODE) and (state = BYTES_TXRX) then

					-- Check Last Byte Cycle					
					if (data_bytes_reg /= 1) or (bit_counter_end = '0') then

						-- Single SPI Mode: DQ1
						if (spi_single_enable_reg = '1') then
							data_r_reg(7 downto 1) <= data_r_reg(6 downto 0);
							data_r_reg(0) <= io_dq(1);

						-- Dual SPI Mode: DQ[1:0]
						elsif (spi_dual_enable_reg = '1')  then
							data_r_reg(7 downto 2) <= data_r_reg(5 downto 0);
							data_r_reg(1) <= io_dq(1);
							data_r_reg(0) <= io_dq(0);

						-- Quad SPI Mode: DQ[3:0]
						else
							data_r_reg(7 downto 4) <= data_r_reg(3 downto 0);
							data_r_reg(3) <= io_dq(3);
							data_r_reg(2) <= io_dq(2);
							data_r_reg(1) <= io_dq(1);
							data_r_reg(0) <= io_dq(0);
						end if;
					end if;
				end if;
			end if;
		end if;
	end process;
	o_data_r <= data_r_reg;

	-------------------------
	-- SPI Read Data Valid --
	-------------------------
	process(i_sys_clock)
	begin
		if rising_edge(i_sys_clock) then

			-- Clock Enable
			if (i_sys_clock_en = '1') then

				-- Data Read Ready
				if (mem_mode_reg = MEM_READ_MODE) and (state = BYTES_TXRX) and (bit_counter_end = '1') then
					data_r_ready_reg <= '1';

				-- Data Read NOT Ready
				else
					data_r_ready_reg <= '0';
				end if;
			end if;
		end if;
	end process;
	o_data_ready <= data_r_ready_reg;

	----------------------
	-- SPI Ready Status --
	----------------------
	o_ready <= '1' when state = IDLE else '0';

	------------------
	-- Reset Output --
	------------------
	o_reset <= not(i_reset);

	---------------------------
	-- SPI Slave Select Line --
	---------------------------
	o_ss <= DISABLE_SS_BIT when (state = IDLE) or (state = STOP_TX) else not(DISABLE_SS_BIT);

end Behavioral;