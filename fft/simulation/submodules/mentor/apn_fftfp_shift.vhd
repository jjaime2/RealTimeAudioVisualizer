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
USE ieee.std_logic_unsigned.all;
USE ieee.std_logic_arith.all; 

LIBRARY altera_mf;
USE altera_mf.all;

--***************************************************
--***                                             ***
--***   ALTERA SINGLE PRECISION FFT CORE          ***
--***                                             ***
--***   APN_fftfp_shift                           ***
--***                                             ***
--***   Function: Delay Chain with Half Point     ***
--***   Output (for R2/R4 switch)                 ***
--***                                             ***
--***   29/11/09 ML                               ***
--***                                             ***
--***   (c) 2009 Altera Corporation               ***
--***                                             ***
--***   Change History                            ***
--***                                             ***
--***                                             ***
--***                                             ***
--***                                             ***
--***                                             ***
--***************************************************

ENTITY apn_fftfp_shift IS
GENERIC (
         delay : positive := 64;
         datawidth : positive := 18
        );
PORT (
      sysclk : IN STD_LOGIC;
      enable : IN STD_LOGIC;
      datain : IN STD_LOGIC_VECTOR (datawidth DOWNTO 1);
      dataouthalf, dataoutfull : OUT STD_LOGIC_VECTOR (datawidth DOWNTO 1);
      dataouthalfnode : BUFFER STD_LOGIC_VECTOR (2*datawidth DOWNTO 1)
     );
END apn_fftfp_shift;

ARCHITECTURE rtl OF apn_fftfp_shift IS

  constant halfdelay : positive := delay/2;
  
	COMPONENT altshift_taps
	GENERIC (
		lpm_hint		: STRING;
		lpm_type		: STRING;
		number_of_taps		: NATURAL;
		tap_distance		: NATURAL;
		width		: NATURAL
	);
	PORT (
			taps	: OUT STD_LOGIC_VECTOR (2*datawidth-1 DOWNTO 0);
			clken	: IN STD_LOGIC ;
			clock	: IN STD_LOGIC ;
			shiftout	: OUT STD_LOGIC_VECTOR (datawidth-1 DOWNTO 0);
			shiftin	: IN STD_LOGIC_VECTOR (datawidth-1 DOWNTO 0)
	);
	END COMPONENT;
	    
BEGIN
    
	csr : altshift_taps
	GENERIC MAP (
		lpm_hint => "RAM_BLOCK_TYPE=AUTO",
		lpm_type => "altshift_taps",
		number_of_taps => 2,
		tap_distance => halfdelay,
		width => datawidth
	)
	PORT MAP (
		clock => sysclk,
		clken =>enable,
		shiftin => datain,
		taps => dataouthalfnode,
		shiftout => dataoutfull
	);
	
	dataouthalf <= dataouthalfnode(datawidth DOWNTO 1);
    
END rtl;

