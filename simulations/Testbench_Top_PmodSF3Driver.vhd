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
--		Output 	-	io_dq: Pmod SF3SPI Data Lines (Simple, Dual or Quad Modes)
--		Output 	-	o_ss: Pmod SF3 SPI Slave Select Line ('0': Enable, '1': Disable)
------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY Testbench_Top_PmodSF3Driver is
END Testbench_Top_PmodSF3Driver;

ARCHITECTURE Behavioral of Testbench_Top_PmodSF3Driver is

COMPONENT Top_PmodSF3Driver is

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

END COMPONENT;

signal sys_clock: STD_LOGIC := '0';
signal reset: STD_LOGIC := '0';
signal start: STD_LOGIC := '0';
signal led: UNSIGNED(15 downto 0) := (others => '0');
signal reset_mem: STD_LOGIC := '0';
signal sclk: STD_LOGIC := '0';
signal dq: STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
signal ss: STD_LOGIC := '1';

begin

-- Clock 100 MHz
sys_clock <= not(sys_clock) after 5 ns;

-- Reset
reset <= '1', '0' after 4800 ns;

-- Start
start <= '0',
        -- SPI Single Mode --
        -- Read Volatile Dummy Cycles
        '1' after 5000 ns, '0' after 5326 ns;

-- SPI DQ[3:0]
dq <=   (others => 'Z'),
        -- SPI Single Mode --
        -- Read Volatile Dummy Cycles
        -- 1 Byte (0xFB)
        "0010" after 5225 ns,
        "0010" after 5245 ns,
        "0010" after 5265 ns,
        "0010" after 5285 ns,
        "0010" after 5305 ns,
        "0000" after 5325 ns,
        "0010" after 5345 ns,
        "0010" after 5365 ns,
        (others => 'Z') after 5385 ns;

uut: Top_PmodSF3Driver
    PORT map(
        i_sys_clock => sys_clock,
        i_reset => reset,
        i_start => start,
        o_led => led,
        o_reset => reset_mem,
        o_sclk => sclk,
        io_dq => dq,
        o_ss => ss);

end Behavioral;