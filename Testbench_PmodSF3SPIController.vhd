------------------------------------------------------------------------
-- Engineer:    Dalmasso Loic
-- Create Date: 19/02/2025
-- Module Name: PmodSF3SPIController
-- Description:
--      Pmod SF3 SPI Controller for the 32 MB NOR Flash Memory MT25QL256ABA.
--	Supports Single, Dual and Quad SPI Modes:
--	| i_spi_dual_enable | i_spi_single_enable | SPI Mode
--	|   	   0 	    |          1          | Single
--	|   	   1 	    |          1   	  | Single
--	|   	   1 	    |          0 	  | Dual
--	|   	   0 	    |          1	  | Quad
--
--	The 'o_ready' signal indicates this module is ready to start new SPI transmission.
--	The 'i_start' signal starts the SPI communication, according to the mode (Read or Write memory), command/address/data bytes.
--	In Write operation, when the 'o_next_data_w' is set to '1', the MSB of the 'i_data_w' is loaded.
--	In Read operation, when the 'o_data_ready', data from memory is available in 'o_data_r' signal.
--
-- Ports
--	Input 	-   i_sys_clock: System Input Clock
--	Input 	-   i_sys_clock_en: System Input Clock Enable
--	Input	-   i_reset: System Input Reset ('0': No Reset, '1': Reset)
--	Input	-   i_start: Start SPI Transmission ('0': No Start, '1': Start)
--	Input	-   i_spi_single_enable: Enable SPI Single Mode ('0': Disable, '1': Enable)
--	Input	-   i_spi_dual_enable: Enable SPI Dual Mode ('0': Disable, '1': Enable)
--	Input	-   i_mode: Set Memory Operation Mode ('0': Write, '1': Mode)
--	Input 	-   i_command: Command Byte
--	Input 	-   i_addr_bytes: Number of Address Bytes to use (0 to 3 bytes)
--	Input 	-   i_addr: Address Bytes
--	Input 	-   i_dummy_cycles: Number of Dummy Cycles (0 to 14 cycles)
--	Input 	-   i_data_bytes: Number of Data Bytes to write
--	Input 	-   i_data_w: Data Bytes to write
--	Output 	-   o_next_data_w: Next bit of Data Bytes trigger ('0': Disable, '1': Enable)
--	Output 	-   o_data_r: Data Bytes read from Memory
--	Output 	-   o_data_ready: Data Bytes read from Memory Ready ('0': NOT Ready, '1': Ready)
--	Output 	-   o_ready: System Ready for transmission
--	Output 	-   o_reset: Memory Reset ('0': Reset, '1': No Reset)
--	Output 	-   o_sclk: SPI Serial Clock
--	In/Out 	-   io_dq: SPI Serial Data
--	Output 	-   o_ss: SPI Slave Select Line ('0': Enable, '1': Disable)
------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY Testbench_PmodSF3SPIController is
END Testbench_PmodSF3SPIController;

ARCHITECTURE Behavioral of Testbench_PmodSF3SPIController is

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

signal sys_clock: STD_LOGIC := '0';
signal sys_clock_en: STD_LOGIC := '0';
signal reset: STD_LOGIC := '0';
signal start: STD_LOGIC := '0';

signal spi_single_enable: STD_LOGIC := '0';
signal spi_dual_enable: STD_LOGIC := '0';

signal mode: STD_LOGIC := '0';
signal command: UNSIGNED(7 downto 0) := (others => '0');
signal addr_bytes: INTEGER range 0 to 3 := 0;
signal addr: UNSIGNED(23 downto 0):= (others => '0');
signal dummy_cycles: INTEGER range 0 to 15 := 0;
signal data_bytes: INTEGER := 0;
signal data_w: UNSIGNED(7 downto 0):= (others => '0');
signal next_data_w: STD_LOGIC := '0';
signal data_r: UNSIGNED(7 downto 0):= (others => '0');
signal data_ready: STD_LOGIC := '0';

signal ready: STD_LOGIC := '0';
signal reset_mem: STD_LOGIC := '0';
signal sclk: STD_LOGIC := '0';
signal dq: STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
signal ss: STD_LOGIC := '1';

begin

-- Clock 100 MHz
sys_clock <= not(sys_clock) after 5 ns;

-- Clock Enable
sys_clock_en <= not(sys_clock) after 5 ns;

-- Reset
reset <= '1', '0' after 145 ns;

-- Start
start <= '0',
        -- Read then Write Cycles (SPI Single Mode)
        '1' after 200 ns, '0' after 326 ns,
        '1' after 2505 ns, '0' after 2631 ns,
        -- Read then Write Cycles (SPI Dual Mode)
        '1' after 5000 ns, '0' after 5150 ns,
        '1' after 6000 ns, '0' after 6150 ns,
        -- Read then Write Cycles (SPI Dual Mode)
        '1' after 8000 ns, '0' after 8150 ns,
        '1' after 9000 ns, '0' after 9150 ns;

-- SPI Modes (Single, then Dual, then Quad)
spi_single_enable <= '1', '0' after 4950 ns, '0' after 7950 ns;
spi_dual_enable <= '0', '1' after 4950 ns, '0' after 7950 ns;

-- Memory Operation Mode (Read then Write)
mode <= -- SPI Single Mode
        '1', '0' after 500 ns,
        -- SPI Dual Mode
        '1' after 4950 ns, '0' after 5150 ns,
        -- SPI Quad Mode
        '1' after 7950 ns, '0' after 8150 ns;

-- Command
command <= x"A2";

-- Address Bytes
addr_bytes <= 3;

-- Address
addr <= x"123456";

-- Dummy Cycles
dummy_cycles <= 1;

-- Data Bytes
data_bytes <= 1;

-- Data to Write
data_w <= x"8B";

-- SPI DQ[3:0]
dq <= (others => 'Z'),
        -- Read (0xAD) then Write (SPI Single Mode)
        "0010" after 875 ns,
        "0000" after 895 ns,
        "0010" after 915 ns,
        "0000" after 935 ns,
        "0010" after 955 ns,
        "0010" after 975 ns,
        "0000" after 995 ns,
        "0010" after 1015 ns,
        (others => 'Z') after 1035 ns,

        -- Read (0x9C) then Write (SPI Dual Mode)
        "0010" after 5355 ns,
        "0001" after 5375 ns,
        "0011" after 5395 ns,
        "0000" after 5415 ns,
        (others => 'Z') after 5435 ns,

        -- Read (0xD5) then Write (SPI Quad Mode)
        "1101" after 8195 ns,
        "0101" after 8215 ns,
        (others => 'Z') after 8235 ns;

uut: PmodSF3SPIController
    PORT map(
        i_sys_clock => sys_clock,
        i_sys_clock_en => sys_clock_en,
        i_reset => reset,
        i_start => start,
        i_spi_single_enable => spi_single_enable,
        i_spi_dual_enable => spi_dual_enable,
        i_mode => mode,
        i_command => command,
        i_addr_bytes => addr_bytes,
        i_addr => addr,
        i_dummy_cycles => dummy_cycles,
        i_data_bytes => data_bytes,
        i_data_w => data_w,
        o_next_data_w => next_data_w,
        o_data_r => data_r,
        o_data_ready => data_ready,
        o_ready => ready,
        o_reset => reset_mem,
        o_sclk => sclk,
        io_dq => dq,
        o_ss => ss);

end Behavioral;