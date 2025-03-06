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

ENTITY Testbench_PmodSF3Driver is
END Testbench_PmodSF3Driver;

ARCHITECTURE Behavioral of Testbench_PmodSF3Driver is

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

signal sys_clock: STD_LOGIC := '0';
signal reset: STD_LOGIC := '0';
signal start: STD_LOGIC := '0';
signal mode: STD_LOGIC := '0';
signal command: UNSIGNED(7 downto 0) := (others => '0');
signal addr_bytes: INTEGER range 0 to 3 := 0;
signal addr: UNSIGNED(23 downto 0):= (others => '0');
signal data_bytes: INTEGER := 0;
signal data_w: UNSIGNED(7 downto 0):= (others => '0');
signal data_r: UNSIGNED(7 downto 0):= (others => '0');
signal data_ready: STD_LOGIC := '0';

signal ready: STD_LOGIC := '0';
signal reset_mem: STD_LOGIC := '0';
signal sclk: STD_LOGIC := '0';
signal dq: STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
signal ss: STD_LOGIC := '1';
signal spi_using_sys_freq: STD_LOGIC := '1';

begin

-- Clock 100 MHz
sys_clock <= not(sys_clock) after 5 ns;

-- Reset
reset <= '1', '0' after 145 ns;

-- Start
start <= '0',
        -- Read then Write Cycles (SPI Single Mode)
        '1' after 200 ns, '0' after 326 ns,
        '1' after 2505 ns, '0' after 2631 ns,
        -- 2 Dummy Cycles (Volatile)
        '1' after 5020 ns, '0' after 5100 ns;

-- Memory Operation Mode (Read then Write)
mode <= -- SPI Single Mode
        '1', '0' after 500 ns;

-- Command
command <=  x"A2",
            -- 2 Dummy Cycles (Volatile)
            x"81" after 5000 ns;


-- Address Bytes
addr_bytes <=   3,
                -- 2 Dummy Cycles (Volatile)
                0 after 5000 ns;
-- Address
addr <= x"123456";

-- Data Bytes
data_bytes <=   2,
                -- 2 Dummy Cycles (Volatile)
                1 after 5000 ns;

-- Data to Write
data_w <=   x"8B",
            -- 2 Dummy Cycles (Volatile)
            "00101011" after 5000 ns;

-- SPI DQ[3:0]
dq <= (others => 'Z'),
        -- Read then Write (SPI Single Mode)
        -- Byte 1 (0xAD)
        "0010" after 875 ns,
        "0000" after 895 ns,
        "0010" after 915 ns,
        "0000" after 935 ns,
        "0010" after 955 ns,
        "0010" after 975 ns,
        "0000" after 995 ns,
        "0010" after 1015 ns,
        -- Byte 2 (0xF1)
        "0010" after 1035 ns,
        "0010" after 1055 ns,
        "0010" after 1075 ns,
        "0010" after 1095 ns,
        "0000" after 1115 ns,
        "0000" after 1135 ns,
        "0000" after 1155 ns,
        "0010" after 1175 ns,
        (others => 'Z') after 1195 ns;

uut: PmodSF3Driver
    GENERIC map(
        sys_clock => 100_000_000,
        max_data_byte => 1)

    PORT map(
        i_sys_clock => sys_clock,
        i_reset => reset,
        i_start => start,
        i_rw => mode,
        i_command => command,
        i_addr_bytes => addr_bytes,
        i_addr => addr,
        i_data_bytes => data_bytes,
        i_data => data_w,
        o_data => data_r,
        o_data_ready => data_ready,
        o_ready => ready,
        o_reset => reset_mem,
        o_sclk => sclk,
        io_dq => dq,
        o_ss => ss,
        o_spi_using_sys_freq => spi_using_sys_freq);

end Behavioral;