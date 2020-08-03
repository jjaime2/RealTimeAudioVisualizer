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
--***   APN_FFTFP_DEL                             ***
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

ENTITY apn_fftfp_del IS
GENERIC (
         delay : positive := 64;
         datawidth : positive := 18
        );
PORT (
      sysclk : IN STD_LOGIC;
      enable : IN STD_LOGIC;
      datain : IN STD_LOGIC_VECTOR (datawidth DOWNTO 1);
      dataouthalf, dataoutfull : OUT STD_LOGIC_VECTOR (datawidth DOWNTO 1)
     );
END apn_fftfp_del;

ARCHITECTURE rtl OF apn_fftfp_del IS
    
  constant halfdelay : positive := delay / 2;
  
  type delayfftype IS ARRAY (halfdelay DOWNTO 1) OF STD_LOGIC_VECTOR (datawidth DOWNTO 1);
  
  signal frontff, backff : delayfftype;
    
BEGIN
    
  pda: PROCESS (sysclk) 
  BEGIN
  
    IF (rising_edge(sysclk)) THEN
        
      IF (enable = '1') THEN
    
        frontff(1)(datawidth DOWNTO 1) <= datain;
        FOR k IN 2 TO halfdelay LOOP
          frontff(k)(datawidth DOWNTO 1) <= frontff(k-1)(datawidth DOWNTO 1);
        END LOOP;
    
        backff(1)(datawidth DOWNTO 1) <= frontff(halfdelay)(datawidth DOWNTO 1);
        FOR k IN 2 TO halfdelay LOOP
          backff(k)(datawidth DOWNTO 1) <= backff(k-1)(datawidth DOWNTO 1);
        END LOOP;

      END IF;
  
    END IF;
      
  END PROCESS;
  
  dataouthalf <= frontff(halfdelay)(datawidth DOWNTO 1);
  dataoutfull <= backff(halfdelay)(datawidth DOWNTO 1);
    
END rtl;

