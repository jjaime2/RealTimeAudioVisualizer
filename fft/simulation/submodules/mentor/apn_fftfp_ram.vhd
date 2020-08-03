-- (C) 2001-2017 Intel Corporation. All rights reserved.
-- Your use of Intel Corporation's design tools, logic functions and other 
-- software and tools, and its AMPP partner logic functions, and any output 
-- files any of the foregoing (including device programming or simulation 
-- files), and any associated documentation or information are expressly subject 
-- to the terms and conditions of the Intel Program License Subscription 
-- Agreement, Intel MegaCore Function License Agreement, or other applicable 
-- license agreement, including, without limitation, that your use is for the 
-- sole purpose of programming logic devices manufactured by Intel and sold by 
-- Intel or its authorized distributors.  Please refer to the applicable 
-- agreement for further details.


LIBRARY ieee;
USE ieee.std_logic_1164.all;

LIBRARY altera_mf;
USE altera_mf.all;

--***************************************************
--***                                             ***
--***   ALTERA SINGLE PRECISION FFT CORE          ***
--***                                             ***
--***   APN_FFTFP_RAM                             ***
--***                                             ***
--***   Function: memory storage for index        ***
--***   reversing                                 ***
--***                                             ***
--***   01/09/10 KHP                              ***
--***                                             ***
--***   (c) 2010 Altera Corporation               ***
--***                                             ***
--***   Change History                            ***
--***                                             ***
--***                                             ***
--***                                             ***
--***                                             ***
--***                                             ***
--***************************************************

ENTITY apn_fftfp_ram IS
GENERIC (
          device_family : string;
          addwidth : positive := 4
        );
PORT
	(
    sysclk       : IN STD_LOGIC;
    read         : IN STD_LOGIC;
    readaddress  : IN STD_LOGIC_VECTOR (addwidth DOWNTO 1);
    writeaddress : IN STD_LOGIC_VECTOR (addwidth DOWNTO 1);    
    write        : IN STD_LOGIC;   
    system_enable: IN STD_LOGIC;
    real_in, imag_in : IN STD_LOGIC_VECTOR (32 DOWNTO 1); 
    real_out, imag_out : OUT STD_LOGIC_VECTOR (32 DOWNTO 1)    
	);
END apn_fftfp_ram;

ARCHITECTURE SYN OF apn_fftfp_ram IS

  constant datawords : positive := 2**addwidth;

  component altera_fft_dual_port_ram
   generic (
      selected_device_family : string;
      ram_block_type         : string := "AUTO";
      read_during_write_mode_mixed_ports : string;
      numwords               : natural;
      addr_width             : natural;
      data_width             : natural
           );
   port (
        clocken0  : in std_logic;
        aclr0     : in std_logic;
        wren_a    : in std_logic;
        rden_b    : in std_logic;
        clock0    : in std_logic;
        address_a : in std_logic_vector(addr_width-1 downto 0);
        address_b : in std_logic_vector(addr_width-1 downto 0);
        data_a    : in std_logic_vector(data_width-1 downto 0);
        q_b       : out std_logic_vector(data_width-1 downto 0) 
        );
  end component;

BEGIN

	realram : altera_fft_dual_port_ram
	GENERIC MAP (
      selected_device_family => device_family,
		numwords => datawords,
		read_during_write_mode_mixed_ports => "OLD_DATA",
		addr_width => addwidth,
		data_width => 32
	)
	PORT MAP (
      clocken0 => system_enable,
      aclr0 => '0',
		wren_a => write,
                rden_b => read,
		clock0 => sysclk,
		address_a => writeaddress,
		address_b => readaddress,
		data_a => real_in,
		q_b => real_out
	);

	imagram : altera_fft_dual_port_ram
	GENERIC MAP (
      selected_device_family => device_family,
		numwords => datawords,
		read_during_write_mode_mixed_ports => "OLD_DATA",
		addr_width => addwidth,
		data_width => 32
	)
	PORT MAP (
      clocken0 => system_enable,
      aclr0 => '0',
		wren_a => write,
                rden_b => read,
		clock0 => sysclk,
		address_a => writeaddress,
		address_b => readaddress,
		data_a => imag_in,
		q_b => imag_out
	);

END SYN;
