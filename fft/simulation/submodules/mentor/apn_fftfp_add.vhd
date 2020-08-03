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
--***   APN_FFTFP_ADD                             ***
--***                                             ***
--***   Function: add internal format floating    ***
--***   point number                              ***
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

ENTITY apn_fftfp_add IS 
PORT (
      sysclk : IN STD_LOGIC;
      reset : IN STD_LOGIC;
      enable : IN STD_LOGIC;
      aamantissa : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
      aaexponent : IN STD_LOGIC_VECTOR (10 DOWNTO 1);
      bbmantissa : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
      bbexponent : IN STD_LOGIC_VECTOR (10 DOWNTO 1);
      
		  ccmantissa : OUT STD_LOGIC_VECTOR (32 DOWNTO 1);
      ccexponent : OUT STD_LOGIC_VECTOR (10 DOWNTO 1)
		);
END apn_fftfp_add;

ARCHITECTURE rtl OF apn_fftfp_add IS
  
  type exponentbasefftype IS ARRAY (3 DOWNTO 2) OF STD_LOGIC_VECTOR (10 DOWNTO 1);
 
  signal mantissaright : STD_LOGIC_VECTOR (32 DOWNTO 1);
  signal aamantissaff, bbmantissaff : STD_LOGIC_VECTOR (32 DOWNTO 1);
  signal aluleftff, alurightff, aluff : STD_LOGIC_VECTOR (32 DOWNTO 1);
  signal alurightbus : STD_LOGIC_VECTOR (32 DOWNTO 1);
  signal shift : STD_LOGIC_VECTOR (10 DOWNTO 1); 
  signal zerorightbus : STD_LOGIC;
  signal exponentbaseff : exponentbasefftype;
  signal exponentone, exponenttwo : STD_LOGIC_VECTOR (10 DOWNTO 1);
  signal exponentoneff, exponenttwoff : STD_LOGIC_VECTOR (10 DOWNTO 1);
  signal aaexponentff, bbexponentff : STD_LOGIC_VECTOR (10 DOWNTO 1);
  signal switch : STD_LOGIC; 

  component apn_fftfp_rsft32 
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
        bbmantissaff(k) <= '0';
        aluleftff(k) <= '0';
        alurightff(k) <= '0';
        aluff(k) <= '0';
      END LOOP; 
      FOR k IN 1 TO 10 LOOP
        aaexponentff(k) <= '0';
        bbexponentff(k) <= '0';
        exponentoneff(k) <= '0';
        exponenttwoff(k) <= '0';
      END LOOP;
      FOR k IN 2 TO 3 LOOP
        FOR j IN 1 TO 10 LOOP
          exponentbaseff(k)(j) <= '0';
        END LOOP;
      END LOOP;
         
    ELSIF (rising_edge(sysclk)) THEN
            
      IF (enable = '1') THEN
          
        --*** LEVEL 1 ***
        aamantissaff(32 DOWNTO 1) <= aamantissa(32 DOWNTO 1);
        bbmantissaff(32 DOWNTO 1) <= bbmantissa(32 DOWNTO 1);
 
        --*** LEVEL 1,2,3 ***
        aaexponentff(10 DOWNTO 1) <= aaexponent(10 DOWNTO 1);
        bbexponentff(10 DOWNTO 1) <= bbexponent(10 DOWNTO 1); 
        
        FOR k IN 1 TO 10 LOOP
          exponentbaseff(2)(k) <= (aaexponentff(k) AND NOT(switch)) OR (bbexponentff(k) AND switch); 
        END LOOP;
        
        exponentbaseff(3)(10 DOWNTO 1) <= exponentbaseff(2)(10 DOWNTO 1); 
        
        --*** LEVEL 2 ***

        FOR k IN 1 TO 32 LOOP
          aluleftff(k) <= (aamantissaff(k) AND NOT(switch)) OR (bbmantissaff(k) AND switch);
          alurightff(k) <= alurightbus(k) AND NOT(zerorightbus);
        END LOOP;

        --*** LEVEL 3 ***
        aluff <= aluleftff + alurightff;

        --*** LEVEL 1 ***
        exponentoneff(10 DOWNTO 1) <= exponentone(10 DOWNTO 1);
        exponenttwoff(10 DOWNTO 1) <= exponenttwo(10 DOWNTO 1);
      
      END IF;
        
    END IF;
      
  END PROCESS;
  
  exponentone <= aaexponent - bbexponent;
  exponenttwo <= bbexponent - aaexponent;
  switch <= exponentoneff(10);
  
  test1: FOR k IN 1 TO 10 GENERATE  --level2
     shift(k) <= (exponentoneff(k) AND NOT(switch)) OR (exponenttwoff(k) AND switch);
  END GENERATE;
 
  zerorightbus <= shift(10) OR shift(9) OR shift(8) OR shift(7) OR shift(6);
  
  test2: FOR k IN 1 TO 32 GENERATE  --level2
      mantissaright(k) <= (bbmantissaff(k) AND NOT(switch)) OR (aamantissaff(k) AND switch);
  END GENERATE;

  cbs: apn_fftfp_rsft32 
  PORT MAP (inbus=>mantissaright,shift=>shift(5 DOWNTO 1),
            outbus=>alurightbus);

  --*** OUTPUTS ***
  ccmantissa <= aluff;
  ccexponent <= exponentbaseff(3)(10 DOWNTO 1);   
   
END rtl;

