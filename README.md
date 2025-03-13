# PmodSF3Driver

Pmod SF3 Driver for the 32 MB NOR Flash memory MT25QL256ABA. The communication with the Flash uses the SPI protocol (Simple, Dual or Quad SPI modes, dynamically configurable).

User specifies the System Input Clock and the Pmod SF3 Driver dynamically computes the SPI Serial Clock Frequency according to the actual Dummy Cycles.

User specifies the maximum bytes buffer used for data read & write.

For each read/write operation, user specifies the number of expected address and data bytes.

## Usage

The 'o_ready' signal indicates this module is ready to start new SPI transmission. 
For each read/write operation, user specifies the number of expected address and data bytes, 'i_addr_bytes' and 'i_data_bytes' respectively.
The 'i_start' signal starts the SPI communication, according to the mode 'i_rw' (Read or Write memory), command/address/data bytes and the expected number of bytes.  
In Read operation, when the 'o_data_ready', data from memory is available in 'o_data' signal.

## Pin Description

### Generics

| Name | Description |
| ---- | ----------- |
| sys_clock | System Input Clock Frequency (Hz) |
| max_data_byte | Maximum number of Data Bytes in the driver |

### Ports

| Name | Type | Description |
| ---- | ---- | ----------- |
| i_sys_clock | Input | System Input Clock |
| i_reset | Input | Module Reset ('0': No Reset, '1': Reset) |
| i_start | Input | Start SPI Transmission ('0': No Start, '1': Start) |
| i_rw | Input | Read / Write Mode ('0': Write, '1': Read) |
| i_command | Input | FLASH Command Byte |
| i_addr_bytes | Input | Number of Address Bytes |
| i_addr | Input | FLASH Address Bytes |
| i_data_bytes | Input | Number of Data Bytes to Read/Write |
| i_data | Input | FLASH Data Bytes to Write |
| o_data | Output | Read FLASH Data Bytes |
| o_data_ready | Output | FLASH Data Output Ready (Read Mode) ('0': NOT Ready, '1': Ready) |
| o_ready | Output | Module Ready ('0': NOT Ready, '1': Ready) |
| o_reset | Output | FLASH Reset ('0': Reset, '1': No Reset) |
| o_sclk | Output | SPI Serial Clock |
| io_dq | In/Out | SPI Data Lines (Simple, Dual or Quad Modes) |
| o_ss | Output | SPI Slave Select Line ('0': Enable, '1': Disable) |
| o_using_sys_freq | Output | System Input Clock as SPI Serial Clock Frequency ('0': Disable, '1': Enable) |