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
--		In/Out 	-	io_dq: SPI Data Lines (Simple, Dual or Quad Modes)
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
        -- SPI Single Mode --
        -- Read Volatile Dummy Cycles
        '1' after 200 ns, '0' after 326 ns,
        -- Read Volatile SPI Mode
        '1' after 2000 ns, '0' after 2300 ns,
        -- Write Data
        '1' after 3000 ns, '0' after 3300 ns,
        -- Write Volatile Dummy Cycles (2)
        '1' after 5000 ns, '0' after 5300 ns,
        -- Write Volatile SPI Mode (Dual)
        '1' after 7000 ns, '0' after 7300 ns,

        -- SPI Dual Mode --
        -- Read Volatile Dummy Cycles (2)
        '1' after 8000 ns, '0' after 8050 ns,
        -- Read Volatile SPI Mode (Dual)
        '1' after 9000 ns, '0' after 9050 ns,
        -- Write Data
        '1' after 10000 ns, '0' after 10300 ns,
        -- Write Volatile Dummy Cycles (0)
        '1' after 11000 ns, '0' after 11050 ns,
        -- Write Volatile SPI Mode (Quad)
        '1' after 12000 ns, '0' after 12050 ns,
    
        -- SPI Quad Mode --
        -- Read Volatile Dummy Cycles (0)
        '1' after 13000 ns, '0' after 13025 ns,
        -- Read Volatile SPI Mode (Quad)
        '1' after 14000 ns, '0' after 14025 ns,
        -- Write Data
        '1' after 15000 ns, '0' after 15025 ns,

        -- Write Volatile Dummy Cycles (5)
        '1' after 16000 ns, '0' after 16025 ns,
        -- Read Data
        '1' after 17000 ns, '0' after 17025 ns;

-- Memory Operation Mode (Read then Write)
mode <= -- SPI Single Mode --
        -- Read Volatile Dummy Cycles & Read Volatile SPI Mode
        '1',
        -- Write Data, Write Volatile Dummy Cycles (2), Write Volatile SPI Mode (Dual)
        '0' after 2500 ns,

        -- SPI Dual Mode --
        -- Read Volatile Dummy Cycles (2) & Read Volatile SPI Mode Dual)
        '1' after 7800 ns,
        -- Write Data, Write Volatile Dummy Cycles (0), Write Volatile SPI Mode (Quad)
        '0' after 9800 ns,
    
        -- SPI Quad Mode --
        -- Read Volatile Dummy Cycles (0) & Read Volatile SPI Mode (Quad)
        '1' after 12800 ns,
        -- Write Data
        '0' after 14800 ns,
        -- Read Data
        '1' after 16800 ns;

-- Command
command <=  
        -- SPI Single Mode --
        -- Read Volatile Dummy Cycles
        x"85" after 180 ns,
        -- Read Volatile SPI Mode
        x"65" after 1800 ns,
        -- Write Data
        x"AB" after 2800 ns,
        -- Write Volatile Dummy Cycles (2)
        x"81" after 4800 ns,
        -- Write Volatile SPI Mode (Dual)
        x"61" after 6800 ns,

        -- SPI Dual Mode --
        -- Read Volatile Dummy Cycles (2)
        x"85" after 7800 ns,
        -- Read Volatile SPI Mode (Dual)
        x"65" after 8800 ns,
        -- Write Data
        x"AB" after 9800 ns,
        -- Write Volatile Dummy Cycles (0)
        x"81" after 10800 ns,
        -- Write Volatile SPI Mode (Quad)
        x"61" after 11800 ns,
    
        -- SPI Quad Mode --
        -- Read Volatile Dummy Cycles (0)
        x"85" after 12800 ns,
        -- Read Volatile SPI Mode (Quad)
        x"65" after 13800 ns,
        -- Write Data
        x"AB" after 14800 ns,

        -- Write Volatile Dummy Cycles (5)
        x"81" after 15800 ns,
        -- Read Data
        x"AB" after 16800 ns;

-- Address Bytes
addr_bytes <=
        -- SPI Single Mode --
        -- Read Volatile Dummy Cycles
        0 after 180 ns,
        -- Read Volatile SPI Mode
        0 after 1800 ns,
        -- Write Data
        3 after 2800 ns,
        -- Write Volatile Dummy Cycles (2) & Write Volatile SPI Mode (Dual)
        0 after 4800 ns,

        -- SPI Dual Mode --
        -- Read Volatile Dummy Cycles (2)
        0 after 7800 ns,
        -- Read Volatile SPI Mode (Dual)
        0 after 8800 ns,
        -- Write Data
        3 after 9800 ns,
        -- Write Volatile Dummy Cycles (0)
        0 after 10800 ns,
        -- Write Volatile SPI Mode (Quad)
        0 after 11800 ns,
    
        -- SPI Quad Mode --
        -- Read Volatile Dummy Cycles (0)
        0 after 12800 ns,
        -- Read Volatile SPI Mode (Quad)
        0 after 13800 ns,
        -- Write Data
        1 after 14800 ns,

        -- Write Volatile Dummy Cycles (5)
        0 after 15800 ns,
        -- Read Data
        3 after 16800 ns;

-- Address
addr <= x"123456";

-- Data Bytes
data_bytes <=
        -- SPI Single Mode --
        -- Read Volatile Dummy Cycles
        1 after 180 ns,
        -- Read Volatile SPI Mode
        1 after 1800 ns,
        -- Write Data
        2 after 2800 ns,
        -- Write Volatile Dummy Cycles (2) & Write Volatile SPI Mode (Dual)
        1 after 4800 ns,

        -- SPI Dual Mode --
        -- Read Volatile Dummy Cycles (2)
        1 after 7800 ns,
        -- Read Volatile SPI Mode (Dual)
        1 after 8800 ns,
        -- Write Data
        3 after 9800 ns,
        -- Write Volatile Dummy Cycles (0)
        1 after 10800 ns,
        -- Write Volatile SPI Mode (Quad)
        1 after 11800 ns,
    
        -- SPI Quad Mode --
        -- Read Volatile Dummy Cycles (0)
        1 after 12800 ns,
        -- Read Volatile SPI Mode (Quad)
        1 after 13800 ns,
        -- Write Data
        1 after 14800 ns,

        -- Write Volatile Dummy Cycles (5)
        1 after 15800 ns,
        -- Read Data
        1 after 16800 ns;

-- Data to Write
data_w <=
        -- SPI Single Mode --
        -- Read Volatile Dummy Cycles
        (others => '0') after 180 ns,
        -- Read Volatile SPI Mode
        (others => '0') after 1800 ns,
        -- Write Data
        x"8B" after 2800 ns,
        -- Write Volatile Dummy Cycles (2)
        "00101011" after 4800 ns,
        -- Write Volatile SPI Mode (Dual)
        "10111111" after 6800 ns,

        -- SPI Dual Mode --
        -- Read Volatile Dummy Cycles (2) & Read Volatile SPI Mode (Dual)
        (others => '0') after 7800 ns,
        -- Write Data
        x"98" after 9800 ns,
        -- Write Volatile Dummy Cycles (0)
        "11111011" after 10800 ns,
        -- Write Volatile SPI Mode (Quad)
        "01111111" after 11800 ns,
    
        -- SPI Quad Mode --
        -- Read Volatile Dummy Cycles (0)
        (others => '0') after 12800 ns,
        -- Read Volatile SPI Mode (Quad)
        (others => '0') after 13800 ns,
        -- Write Data
        x"CD" after 14800 ns,

        -- Write Volatile Dummy Cycles (5)
        "01011011" after 15800 ns,

        -- Read Data
        (others => '0') after 16800 ns;

-- SPI DQ[3:0]
dq <=   (others => 'Z'),
        -- SPI Single Mode --
        -- Read Volatile Dummy Cycles
        -- 1 Byte (0xFB)
        "0010" after 405 ns,
        "0010" after 425 ns,
        "0010" after 445 ns,
        "0010" after 465 ns,
        "0010" after 485 ns,
        "0000" after 505 ns,
        "0010" after 525 ns,
        "0010" after 545 ns,
        (others => 'Z') after 565 ns,

        -- Read Volatile SPI Mode
        -- 1 Byte (0xFF)
        "0010" after 2205 ns,
        "0010" after 2225 ns,
        "0010" after 2245 ns,
        "0010" after 2265 ns,
        "0010" after 2285 ns,
        "0010" after 2305 ns,
        "0010" after 2325 ns,
        "0010" after 2345 ns,
        -- Write Data, Write Volatile Dummy Cycles (2), Write Volatile SPI Mode (Dual)
        (others => 'Z') after 2365 ns,

        -- SPI Dual Mode --
        -- Read Volatile Dummy Cycles (2)
        -- 1 Byte (0x2B)
        "0000" after 8125 ns,
        "0010" after 8145 ns,
        "0010" after 8165 ns,
        "0011" after 8185 ns,
        (others => 'Z') after 8205 ns,

        -- Read Volatile SPI Mode (Dual)
        -- 1 Byte (0xBF)
        "0010" after 9125 ns,
        "0011" after 9145 ns,
        "0011" after 9165 ns,
        "0011" after 9185 ns,
        (others => 'Z') after 9205 ns,

        -- Write Data, Write Volatile Dummy Cycles (0), Write Volatile SPI Mode (Quad)
        (others => 'Z') after 9800 ns,
    
        -- SPI Quad Mode --
        -- Read Volatile Dummy Cycles (0)
        -- 1 Byte (0xFB)
        "1111" after 13085 ns,
        "1011" after 13105 ns,
        (others => 'Z') after 13125 ns,
        -- Read Volatile SPI Mode (Quad)
        -- 1 Byte (0x7F)
        "0111" after 14085 ns,
        "1111" after 14105 ns,
        (others => 'Z') after 14125 ns,

        -- Read Data
        -- 1 Byte (0xC1)
        "1100" after 17305 ns,
        "0001" after 17325 ns,
        (others => 'Z') after 17345 ns;

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