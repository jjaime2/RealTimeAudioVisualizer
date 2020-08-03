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
LIBRARY work;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_signed.all;
USE ieee.std_logic_arith.all; 

LIBRARY altera_mf;
USE altera_mf.all;

library work;
use work.auk_dspip_math_pkg.all;

--***************************************************
--***                                             ***
--***   ALTERA SINGLE PRECISION FFT CORE          ***
--***                                             ***
--***   APN_FFTFP_TWIDDLE                         ***
--***                                             ***
--***   Function: complex twiddles generated from ***
--***   sin and cos full wave tables              ***
--***                                             ***
--***                                             ***
--***   20/01/10 ML                               ***
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

ENTITY apn_fftfp_twiddle IS
GENERIC (
          device_family : string;
          addwidth : positive := 4;
          realfile : string := "twrfp1.hex";
          imagfile : string := "twifp1.hex";
          data_width : integer := 40
        );
PORT (
      sysclk : IN STD_LOGIC;
      enable : IN STD_LOGIC;
      twiddle_address : IN STD_LOGIC_VECTOR (addwidth DOWNTO 1);       
      
      real_twiddle, imag_twiddle : OUT STD_LOGIC_VECTOR (data_width DOWNTO 1)    
     );
END apn_fftfp_twiddle;

ARCHITECTURE rtl of apn_fftfp_twiddle IS

  constant twidwords : positive := (2**addwidth)*3/4;
  
  signal realrom, imagrom : STD_LOGIC_VECTOR (32 DOWNTO 1);
  signal realgennode, imaggennode : STD_LOGIC_VECTOR (32 DOWNTO 1);
  signal realprenode, imagprenode : STD_LOGIC_VECTOR (32 DOWNTO 1);
  signal real_twiddleff, imag_twiddleff : STD_LOGIC_VECTOR (data_width DOWNTO 1);
  
  component altera_fft_single_port_rom
   generic (
      selected_device_family : string;
      ram_block_type         : string := "AUTO";
      init_file              : string;
      numwords               : natural;
      addr_width             : natural;
      data_width             : natural
           );
   port (
        clocken0  : in std_logic;
        clock0    : in std_logic;
        address_a : in std_logic_vector(addr_width-1 downto 0);
        q_a       : out std_logic_vector(32-1 downto 0)
     );
  end component;
                
BEGIN
  
  crtw : altera_fft_single_port_rom
  GENERIC MAP (
		         init_file => realfile,
               selected_device_family => device_family,
		         numwords => twidwords,
		         addr_width => addwidth,
		         data_width => 32
	           )
  PORT MAP (
		      clocken0 => enable,
		      clock0 => sysclk,
		      address_a => twiddle_address,
		      q_a => realrom
	        );
		
  citw : altera_fft_single_port_rom
  GENERIC MAP (
		         init_file => imagfile,
               selected_device_family => device_family,
		         numwords => twidwords,
		         addr_width => addwidth,
		         data_width => 32
	           )
  PORT MAP (
		      clocken0 => enable,
		      clock0 => sysclk,
		      address_a => twiddle_address,
		      q_a => imagrom
	        );
    
  custom_width_adaptor:  IF data_width = 40 GENERATE


    realgennode <= "0" & or_reduce(realrom(31 DOWNTO 24)) & realrom(23 DOWNTO 1) & "0000000";
    imaggennode <= "0" & or_reduce(imagrom(31 DOWNTO 24)) & imagrom(23 DOWNTO 1) & "0000000";
    gpa: FOR k IN 1 TO 32 GENERATE
      realprenode(k) <= realgennode(k) XOR realrom(32);
      imagprenode(k) <= imaggennode(k) XOR imagrom(32);
    END GENERATE;
    
    pta: PROCESS (sysclk)
    BEGIN
      
      IF (rising_edge(sysclk)) THEN
        
        IF (enable = '1') THEN
          
          real_twiddleff(40 DOWNTO 9) <= realprenode + realrom(32);
          imag_twiddleff(40 DOWNTO 9) <= imagprenode + imagrom(32);
          real_twiddleff(8 DOWNTO 1) <= realrom(31 DOWNTO 24);
          imag_twiddleff(8 DOWNTO 1) <= imagrom(31 DOWNTO 24);
          
        END IF;
        
      END IF;
      
    END PROCESS;

  END GENERATE;
  
  single_width:  IF data_width = 32 GENERATE

    reg_data: PROCESS (sysclk)
    BEGIN
      
      IF (rising_edge(sysclk)) THEN
        
        IF (enable = '1') THEN
          
          real_twiddleff <= realrom;
          imag_twiddleff <= imagrom;

        END IF;
        
      END IF;
      
    END PROCESS;

  END GENERATE;


  real_twiddle <= real_twiddleff;
  imag_twiddle <= imag_twiddleff;
  
END rtl;

