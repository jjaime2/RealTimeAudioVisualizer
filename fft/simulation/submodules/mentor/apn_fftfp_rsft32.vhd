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
--***   APN_FFTFP_RSFT32                          ***
--***                                             ***
--***   Function: 32 bit signed right shift       ***
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

ENTITY apn_fftfp_rsft32 IS 
PORT (
      inbus : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
      shift : IN STD_LOGIC_VECTOR (5 DOWNTO 1);

	   outbus : OUT STD_LOGIC_VECTOR (32 DOWNTO 1)
	  );
END apn_fftfp_rsft32;

ARCHITECTURE rtl OF apn_fftfp_rsft32 IS
  
  signal levzip, levone, levtwo, levthr : STD_LOGIC_VECTOR (32 DOWNTO 1);
    
BEGIN
        
  levzip <= inbus;
  
  -- shift by 0,1,2,3
  gaa: FOR k IN 1 TO 29 GENERATE
    levone(k) <= (levzip(k)   AND NOT(shift(2)) AND NOT(shift(1))) OR
                 (levzip(k+1) AND NOT(shift(2)) AND     shift(1)) OR
                 (levzip(k+2) AND     shift(2)  AND NOT(shift(1))) OR
                 (levzip(k+3) AND     shift(2)  AND     shift(1)); 
  END GENERATE;
  levone(30) <=  (levzip(30) AND NOT(shift(2)) AND NOT(shift(1))) OR
                 (levzip(31) AND NOT(shift(2)) AND     shift(1)) OR
                 (levzip(32) AND     shift(2));
  levone(31) <=  (levzip(31) AND NOT(shift(2)) AND NOT(shift(1))) OR
                 (levzip(32) AND   ((shift(2)) OR     shift(1)));
  levone(32) <= levzip(32);
                              
  -- shift by 0,4,8,12
  gba: FOR k IN 1 TO 20 GENERATE
    levtwo(k) <= (levone(k)    AND NOT(shift(4)) AND NOT(shift(3))) OR
                 (levone(k+4)  AND NOT(shift(4)) AND     shift(3)) OR
                 (levone(k+8)  AND     shift(4)  AND NOT(shift(3))) OR
                 (levone(k+12) AND     shift(4)  AND     shift(3)); 
  END GENERATE;
  gbb: FOR k IN 21 TO 24 GENERATE
    levtwo(k) <= (levone(k)    AND NOT(shift(4)) AND NOT(shift(3))) OR
                 (levone(k+4)  AND NOT(shift(4)) AND     shift(3)) OR
                 (levone(k+8)  AND     shift(4)  AND NOT(shift(3))) OR
                 (levone(32)   AND     shift(4)  AND     shift(3));
  END GENERATE;
  gbc: FOR k IN 25 TO 28 GENERATE
    levtwo(k) <= (levone(k)    AND NOT(shift(4)) AND NOT(shift(3))) OR
                 (levone(k+4)  AND NOT(shift(4)) AND     shift(3)) OR
                 (levone(32)   AND     shift(4));
  END GENERATE;
  gbd: FOR k IN 29 TO 31 GENERATE
    levtwo(k) <= (levone(k)    AND NOT(shift(4)) AND NOT(shift(3))) OR
                 (levone(32)   AND    (shift(4) OR shift(3)));
  END GENERATE;
  levtwo(32) <= levone(32);

  gca: FOR k IN 1 TO 16 GENERATE
    levthr(k) <= (levtwo(k)    AND NOT(shift(5))) OR
                 (levtwo(k+16) AND     shift(5));
  END GENERATE;
  gcb: FOR k IN 17 TO 31 GENERATE
    levthr(k) <= (levtwo(k)    AND NOT(shift(5))) OR
                 (levtwo(32)   AND     shift(5));
  END GENERATE;
  levthr(32) <= levtwo(32);
  
  outbus <= levthr;
  
END rtl;

