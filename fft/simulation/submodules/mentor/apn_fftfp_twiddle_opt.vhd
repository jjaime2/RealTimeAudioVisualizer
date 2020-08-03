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

library work;
use work.auk_dspip_math_pkg.all;

--***************************************************
--***                                             ***
--***   ALTERA SINGLE PRECISION FFT CORE          ***
--***                                             ***
--***   APN_FFTFP_TWIDDLE_OPT                     ***
--***                                             ***
--***   Function: complex twiddles generated from ***
--***   cos 1/4 wave table                        ***
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

LIBRARY altera_mf;
USE altera_mf.all;

ENTITY apn_fftfp_twiddle_opt IS
  GENERIC (
           device_family : string := "Arria 10";
           addwidth : positive := 6;
           twidfile : string := "twqfp1.hex";
           data_width : integer := 40

          );
PORT (
      sysclk : IN STD_LOGIC;
      enable : IN STD_LOGIC;
      twiddle_address : IN STD_LOGIC_VECTOR (addwidth DOWNTO 1);       
      
      real_twiddle : OUT STD_LOGIC_VECTOR (data_width DOWNTO 1); 
      imag_twiddle : OUT STD_LOGIC_VECTOR (data_width DOWNTO 1);  
      neg_imag_twiddle : OUT STD_LOGIC_VECTOR (data_width DOWNTO 1)  
     );
END apn_fftfp_twiddle_opt;

ARCHITECTURE rtl of apn_fftfp_twiddle_opt IS

  constant twidwords : positive := (2**addwidth)*1/4;

  signal zerovec : STD_LOGIC_VECTOR (32 DOWNTO 1);
  
  signal zeroadd : STD_LOGIC_VECTOR (addwidth-2 DOWNTO 1);
  signal twiddle_addressff : STD_LOGIC_VECTOR (addwidth DOWNTO 1);
  signal quadrant_one, quadrant_two, quadrant_thr : STD_LOGIC;
  signal zero_cosnode, zero_sinnode : STD_LOGIC;
  signal neg_cosnode, neg_sinnode : STD_LOGIC;
  signal flip_address : STD_LOGIC_VECTOR (addwidth DOWNTO 1);
  signal cos_addressff, sin_addressff : STD_LOGIC_VECTOR (addwidth-2 DOWNTO 1);
  signal zero_cosff, zero_sinff : STD_LOGIC_VECTOR (3 DOWNTO 1);
  signal neg_cosff, neg_sinff : STD_LOGIC_VECTOR (3 DOWNTO 1);
  signal cos_data, sin_data : STD_LOGIC_VECTOR (32 DOWNTO 1);
  signal real_twiddleff, imag_twiddleff : STD_LOGIC_VECTOR (data_width DOWNTO 1);
  signal neg_imag_twiddleff : STD_LOGIC_VECTOR (data_width DOWNTO 1);
  
  signal realtwiddlegennode, imagtwiddlegennode : STD_LOGIC_VECTOR (32 DOWNTO 1);
  signal realtwiddleprenode, imagtwiddleprenode : STD_LOGIC_VECTOR (32 DOWNTO 1);
  signal realtwiddlemannode, imagtwiddlemannode : STD_LOGIC_VECTOR (32 DOWNTO 1);
  signal negimagtwiddlemannode : STD_LOGIC_VECTOR (32 DOWNTO 1);

  component altera_fft_dual_port_rom
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
        aclr0     : in std_logic;
        clock0    : in std_logic;
        address_a : in std_logic_vector(addr_width-1 downto 0);
        address_b : in std_logic_vector(addr_width-1 downto 0);
        q_a       : out std_logic_vector(data_width-1 downto 0);
        q_b       : out std_logic_vector(data_width-1 downto 0) 
     );
  end component;
                
BEGIN

  gza: FOR k IN 1 TO 32 GENERATE
    zerovec(k) <= '0';
  END GENERATE;
  
  paa: PROCESS (sysclk)
  BEGIN
    
    IF (rising_edge(sysclk)) THEN
      
      IF (enable = '1') THEN
        
        twiddle_addressff <= twiddle_address;
        
        FOR k IN 1 TO addwidth-2 LOOP
          cos_addressff(k) <= (twiddle_addressff(k) AND quadrant_one) OR
                              (flip_address(k) AND quadrant_two) OR
                              (twiddle_addressff(k) AND quadrant_thr);
          sin_addressff(k) <= (flip_address(k) AND quadrant_one) OR
                              (twiddle_addressff(k) AND quadrant_two) OR
                              (flip_address(k) AND quadrant_thr);
        END LOOP;
        
        zero_cosff(1) <= zero_cosnode;
        zero_sinff(1) <= zero_sinnode;
        neg_cosff(1) <= neg_cosnode;
        neg_sinff(1) <= neg_sinnode;
        FOR k IN 2 TO 3 LOOP
          zero_cosff(k) <= zero_cosff(k-1);
          zero_sinff(k) <= zero_sinff(k-1);
          neg_cosff(k) <= neg_cosff(k-1);
          neg_sinff(k) <= neg_sinff(k-1);
        END LOOP;
        
        
      END IF;
      
    END IF;
    
  END PROCESS;

  zeroadd(1) <= twiddle_addressff(1);
  gtza: FOR k IN 2 TO addwidth-2 GENERATE
    zeroadd(k) <= zeroadd(k-1) OR twiddle_addressff(k);
  END GENERATE;
  
  quadrant_one <= NOT(twiddle_addressff(addwidth)) AND NOT(twiddle_addressff(addwidth-1));
  quadrant_two <= NOT(twiddle_addressff(addwidth)) AND     twiddle_addressff(addwidth-1);
  quadrant_thr <=     twiddle_addressff(addwidth)  AND NOT(twiddle_addressff(addwidth-1));
  
  zero_cosnode <= quadrant_two AND NOT(zeroadd(addwidth-2));  
  zero_sinnode <= (quadrant_one OR quadrant_thr) AND NOT(zeroadd(addwidth-2)); 
  
  neg_cosnode <= quadrant_two OR quadrant_thr; 
  neg_sinnode <= quadrant_one OR quadrant_two; 
  
  flip_address <= ("01" & zerovec(addwidth-2 DOWNTO 1)) - ("00" & twiddle_addressff(addwidth-2 DOWNTO 1));
  

    
	ctw : altera_fft_dual_port_rom
	GENERIC MAP (
		init_file => twidfile,
      selected_device_family => device_family,
		numwords => twidwords,
		addr_width => addwidth-2,
		data_width => 32
	)
	PORT MAP (
		clocken0 => enable,
      aclr0 => '0',
		clock0 => sysclk,
		address_a => cos_addressff,
		address_b => sin_addressff,
		q_a => cos_data,
		q_b => sin_data
	);

  custom_width_adaptor:  IF data_width = 40 GENERATE
  custom_conv: PROCESS (sysclk)
  BEGIN
    
    IF (rising_edge(sysclk)) THEN
      
      IF (enable = '1') THEN
        
        real_twiddleff(40 DOWNTO 9) <= realtwiddlemannode + realtwiddlegennode(32);
        imag_twiddleff(40 DOWNTO 9) <= imagtwiddlemannode + imagtwiddlegennode(32);
        neg_imag_twiddleff(40 DOWNTO 9) <= negimagtwiddlemannode + NOT(imagtwiddlegennode(32));
        real_twiddleff(8 DOWNTO 1) <= realtwiddlegennode(31 DOWNTO 24);
        imag_twiddleff(8 DOWNTO 1) <= imagtwiddlegennode(31 DOWNTO 24);
        neg_imag_twiddleff(8 DOWNTO 1) <= imagtwiddlegennode(31 DOWNTO 24);
        
      END IF;
      
    END IF;
    
  END PROCESS;


    realtwiddlegennode(32) <= cos_data(32) XOR neg_cosff(3);
    imagtwiddlegennode(32) <= sin_data(32) XOR neg_sinff(3);
    gtna: FOR k IN 1 TO 31 GENERATE
      realtwiddlegennode(k) <= cos_data(k) AND NOT(zero_cosff(3));
      imagtwiddlegennode(k) <= sin_data(k) AND NOT(zero_sinff(3));
    END GENERATE;
    realtwiddleprenode <= "0" & or_reduce(realtwiddlegennode(31 DOWNTO 24)) & realtwiddlegennode(23 DOWNTO 1) & "0000000";
    imagtwiddleprenode <= "0" & or_reduce(imagtwiddlegennode(31 DOWNTO 24)) & imagtwiddlegennode(23 DOWNTO 1) & "0000000";
    gtnb: FOR k IN 1 TO 32 GENERATE
      realtwiddlemannode(k) <= realtwiddleprenode(k) XOR realtwiddlegennode(32);
      imagtwiddlemannode(k) <= imagtwiddleprenode(k) XOR imagtwiddlegennode(32);
      negimagtwiddlemannode(k) <= imagtwiddleprenode(k) XOR NOT(imagtwiddlegennode(32));
    END GENERATE;

  END GENERATE;

  single_width:  IF data_width = 32 GENERATE

  reg_data: PROCESS (sysclk)
  BEGIN
    
    IF (rising_edge(sysclk)) THEN
      
      IF (enable = '1') THEN
        zero_gen: FOR k IN 1 TO 31 loop
            real_twiddleff(k) <= cos_data(k) AND NOT(zero_cosff(3));
            imag_twiddleff(k) <= sin_data(k) AND NOT(zero_sinff(3));
            neg_imag_twiddleff(k) <= sin_data(k) AND NOT(zero_sinff(3));
        end loop;
          real_twiddleff(32) <= cos_data(32) XOR neg_cosff(3);
          imag_twiddleff(32) <= sin_data(32) XOR neg_sinff(3);
          neg_imag_twiddleff(32) <= NOT(sin_data(32) XOR neg_sinff(3));

      END IF;
      
    END IF;
    
  END PROCESS;
  END GENERATE;


    
  real_twiddle <= real_twiddleff;
  imag_twiddle <= imag_twiddleff;
  neg_imag_twiddle <= neg_imag_twiddleff;
  
END rtl;

