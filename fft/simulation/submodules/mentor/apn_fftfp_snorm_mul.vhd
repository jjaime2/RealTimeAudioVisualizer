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
--***   APN_FFTFP_SNORM_MUL                       ***
--***                                             ***
--***   Function: normalize signed mantissa       ***
--***   internal format number coarsely (0,6,12)  ***
--***   bit shift                                 ***
--***                                             ***
--***   20/01/10 ML                               ***
--***                                             ***
--***   (c) 2010 Altera Corporation               ***
--***                                             ***
--***   Change History                            ***
--***                                             ***
--***   27/01/10 - change exponent to 10 bits     ***
--***   (underflow issues)                        ***
--***                                             ***
--***                                             ***
--***                                             ***
--***************************************************

ENTITY apn_fftfp_snorm_mul IS 
PORT (
      sysclk : IN STD_LOGIC;
      reset : IN STD_LOGIC;
      enable : IN STD_LOGIC;
      aamantissa : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
      aaexponent : IN STD_LOGIC_VECTOR (10 DOWNTO 1);
      
		  ccmantissa : OUT STD_LOGIC_VECTOR (32 DOWNTO 1);
      ccexponent : OUT STD_LOGIC_VECTOR (10 DOWNTO 1)
		);
END apn_fftfp_snorm_mul;

ARCHITECTURE rtl OF apn_fftfp_snorm_mul IS

  signal aamantissaff, ccmantissaff : STD_LOGIC_VECTOR (32 DOWNTO 1);
  signal mantissabus : STD_LOGIC_VECTOR (32 DOWNTO 1);
  signal lead_positive, lead_negative : STD_LOGIC_VECTOR (2 DOWNTO 1);
  signal shift : STD_LOGIC_VECTOR (2 DOWNTO 1);
  signal five, ten, adjust : STD_LOGIC_VECTOR (10 DOWNTO 1);
  signal aaexponentff, ccexponentff : STD_LOGIC_VECTOR (10 DOWNTO 1);
    
BEGIN
     
  paa: PROCESS (sysclk, reset)
  BEGIN
      
    IF (reset = '1') THEN

      FOR k IN 1 TO 32 LOOP
        aamantissaff(k) <= '0';
        ccmantissaff(k) <= '0';
      END LOOP; 
      FOR k IN 1 TO 10 LOOP
        aaexponentff(k) <= '0';
        ccexponentff(k) <= '0';
      END LOOP;
         
    ELSIF (rising_edge(sysclk)) THEN
            
      IF (enable = '1') THEN
        
        aamantissaff <= aamantissa;
        ccmantissaff <= mantissabus;
        
        aaexponentff <= aaexponent;
        ccexponentff <= aaexponentff - adjust;
        
      END IF;
        
    END IF;
      
  END PROCESS;
  
  lead_positive(1) <= NOT(aamantissaff(32) OR aamantissaff(31) OR aamantissaff(30) OR 
                           aamantissaff(29) OR aamantissaff(28) OR aamantissaff(27));
  lead_positive(2) <= NOT(aamantissaff(26) OR aamantissaff(25) OR aamantissaff(24) OR 
                           aamantissaff(23) OR aamantissaff(22) OR aamantissaff(21));
  lead_negative(1) <= (aamantissaff(32) AND aamantissaff(31) AND aamantissaff(30) AND 
                       aamantissaff(29) AND aamantissaff(28) AND aamantissaff(27));
  lead_negative(2) <= (aamantissaff(26) AND aamantissaff(25) AND aamantissaff(24) AND 
                       aamantissaff(23) AND aamantissaff(22) AND aamantissaff(21));
  
  shift(1) <= (NOT(aamantissaff(32)) AND (lead_positive(1) AND NOT(lead_positive(2)))) OR
              (    aamantissaff(32)  AND (lead_negative(1) AND NOT(lead_negative(2))));
  shift(2) <= (NOT(aamantissaff(32)) AND (lead_positive(1) AND lead_positive(2))) OR
              (    aamantissaff(32)  AND (lead_negative(1) AND lead_negative(2)));
  
  gsa: FOR k IN 13 TO 32 GENERATE
    mantissabus(k) <= (aamantissaff(k) AND NOT(shift(2)) AND NOT(shift(1))) OR
                      (aamantissaff(k-5) AND shift(1)) OR
                      (aamantissaff(k-10) AND shift(2));
  END GENERATE;
  gsb: FOR k IN 7 TO 12 GENERATE
    mantissabus(k) <= (aamantissaff(k) AND NOT(shift(2)) AND NOT(shift(1))) OR
                      (aamantissaff(k-5) AND shift(1));
  END GENERATE;
  gsc: FOR k IN 1 TO 6 GENERATE
    mantissabus(k) <= (aamantissaff(k) AND NOT(shift(2)) AND NOT(shift(1)));
  END GENERATE;

  five <= "0000000101";
  ten <= "0000001010";
  
  gxa: FOR k IN 1 TO 10 GENERATE
    adjust(k) <= (five(k) AND shift(1)) OR (ten(k) AND shift(2));
  END GENERATE;
  
  --*** OUTPUTS ***
	ccmantissa <= ccmantissaff;
  ccexponent <= ccexponentff;   
   
END rtl;

