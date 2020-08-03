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

--***************************************************
--***                                             ***
--***   ALTERA SINGLE PRECISION FFT CORE          ***
--***                                             ***
--***   APN_FFTFP_UNORM                           ***
--***                                             ***
--***   Function: normalize unsigned mantissa     ***
--***   internal format number                    ***
--***                                             ***
--***   20/01/10 ML                               ***
--***                                             ***
--***   (c) 2010 Altera Corporation               ***
--***                                             ***
--***   Change History                            ***
--***                                             ***
--***   27/01/10 - if mantissa 0, exponent zeroed ***
--***                                             ***
--***                                             ***
--***                                             ***
--***************************************************

ENTITY apn_fftfp_unorm IS 
PORT (
      sysclk : IN STD_LOGIC;
      reset : IN STD_LOGIC;
      enable : IN STD_LOGIC;
      aamantissa : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
      aaexponent : IN STD_LOGIC_VECTOR (10 DOWNTO 1);
      
		  ccmantissa : OUT STD_LOGIC_VECTOR (32 DOWNTO 1);
      ccexponent : OUT STD_LOGIC_VECTOR (10 DOWNTO 1)
		);
END apn_fftfp_unorm;

ARCHITECTURE rtl OF apn_fftfp_unorm IS
 
  signal aamantissaff, ccmantissaff : STD_LOGIC_VECTOR (32 DOWNTO 1);
  signal mantissabus : STD_LOGIC_VECTOR (32 DOWNTO 1);
  signal count, countff : STD_LOGIC_VECTOR (6 DOWNTO 1);
  signal zerocount, zerocountff : STD_LOGIC;
  signal underflow, underflowff : STD_LOGIC;
  signal ccexponentnode : STD_LOGIC_VECTOR (10 DOWNTO 1);
  signal aaexponentff, ccexponentff : STD_LOGIC_VECTOR (10 DOWNTO 1);
     
  component apn_hcc_cntusgn32 
  PORT (
        frac : IN STD_LOGIC_VECTOR (32 DOWNTO 1);

		    count : OUT STD_LOGIC_VECTOR (6 DOWNTO 1)
		   );
  end component;
   
  component apn_fftfp_lsft32 
  PORT (
        inbus : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
        shift : IN STD_LOGIC_VECTOR (5 DOWNTO 1);

	     outbus : OUT STD_LOGIC_VECTOR (32 DOWNTO 1)
	    );
  end component;
    
BEGIN
     
  paa: PROCESS (sysclk, reset)
  BEGIN
      
    IF (reset = '1') THEN

      FOR k IN 1 TO 32 LOOP
        aamantissaff(k) <= '0';
        ccmantissaff(k) <= '0';
      END LOOP; 
      FOR k IN 1 TO 6 LOOP
        countff(k) <= '0';
      END LOOP; 
      FOR k IN 1 TO 10 LOOP
        aaexponentff(k) <= '0';
        ccexponentff(k) <= '0';
      END LOOP;
         
    ELSIF (rising_edge(sysclk)) THEN
            
      IF (enable = '1') THEN
        
        aamantissaff <= aamantissa;  
        countff <= count;
        zerocountff <= zerocount;
        underflowff <= underflow;
        ccmantissaff <= mantissabus;
        
        aaexponentff <= aaexponent;
        FOR k IN 1 TO 10 LOOP
          ccexponentff(k) <= ccexponentnode(k) AND zerocountff AND NOT(underflow);
        END LOOP;
      
      END IF;
        
    END IF;
      
  END PROCESS;
  
  -- cntusgn32 only looks at [31:1] - not a problem for the fft, as '1'
  -- can never get to [32] position, just need to adjust ccexponentff by -1
  cclz: apn_hcc_cntusgn32 
  PORT MAP (frac=>aamantissa,
            count=>count);
            
  -- if count = 0 and msb = 0, zero exponent, of if exponent negative
  zerocount <= count(6) OR count(5) OR count(4) OR count(3) OR count(2) OR count(1) OR 
               aamantissa(31);
  underflow <= ccexponentnode(10);
  
  ccexponentnode <= aaexponentff + 4 - ("00" & countff);

  clsa: apn_fftfp_lsft32 
  PORT MAP (inbus=>aamantissaff,shift=>countff(5 DOWNTO 1),
            outbus=>mantissabus);
  
  --*** OUTPUTS ***
	ccmantissa <= ccmantissaff;
  ccexponent <= ccexponentff;   
   
END rtl;

