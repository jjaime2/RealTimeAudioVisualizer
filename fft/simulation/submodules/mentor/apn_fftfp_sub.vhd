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
--***   APN_FFTFP_SUB                             ***
--***                                             ***
--***   Function: subtract internal format        ***
--***   floating point number                     ***
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

ENTITY apn_fftfp_sub IS 
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
END apn_fftfp_sub;

ARCHITECTURE rtl OF apn_fftfp_sub IS
  
  type exponentbasefftype IS ARRAY (3 DOWNTO 1) OF STD_LOGIC_VECTOR (10 DOWNTO 1);
 
  signal bbmantissanode : STD_LOGIC_VECTOR (32 DOWNTO 1);
  signal mantissaleftff, mantissarightff : STD_LOGIC_VECTOR (32 DOWNTO 1);
  signal aluleftff, alurightff, aluff : STD_LOGIC_VECTOR (32 DOWNTO 1);
  signal alurightbus : STD_LOGIC_VECTOR (32 DOWNTO 1);
  signal shiftff : STD_LOGIC_VECTOR (10 DOWNTO 1); 
  signal zerorightbus : STD_LOGIC;
  signal exponentzerocheck : STD_LOGIC_VECTOR (10 DOWNTO 1);
  signal exponentbaseff : exponentbasefftype;
  signal exponentone, exponenttwo : STD_LOGIC_VECTOR (10 DOWNTO 1);
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
        mantissaleftff(k) <= '0';
        mantissarightff(k) <= '0';
        aluleftff(k) <= '0';
        alurightff(k) <= '0';
        aluff(k) <= '0';
      END LOOP; 
      FOR k IN 1 TO 5 LOOP
        shiftff(k) <= '0';
      END LOOP; 
      FOR k IN 1 TO 3 LOOP
        FOR j IN 1 TO 10 LOOP
          exponentbaseff(k)(j) <= '0';
        END LOOP;
      END LOOP;
         
    ELSIF (rising_edge(sysclk)) THEN
            
      IF (enable = '1') THEN
          
        --*** LEVEL 1 ***
        FOR k IN 1 TO 32 LOOP
          mantissaleftff(k) <= (aamantissa(k) AND NOT(switch)) OR (bbmantissanode(k) AND switch);
          mantissarightff(k) <= (bbmantissanode(k) AND NOT(switch)) OR (aamantissa(k) AND switch);
        END LOOP;
 
        FOR k IN 1 TO 10 LOOP
          shiftff(k) <= (exponentone(k) AND NOT(switch)) OR (exponenttwo(k) AND switch);
        END LOOP;

        --*** LEVEL 1,2,3 ***
        FOR k IN 1 TO 10 LOOP
          exponentbaseff(1)(k) <= (aaexponent(k) AND NOT(switch)) OR (bbexponent(k) AND switch); 
        END LOOP;
        FOR k IN 2 TO 3 LOOP
          exponentbaseff(k)(10 DOWNTO 1) <= exponentbaseff(k-1)(10 DOWNTO 1); 
        END LOOP;
        
        --*** LEVEL 2 ***
        aluleftff <= mantissaleftff;
        FOR k IN 1 TO 32 LOOP
          alurightff(k) <= alurightbus(k) AND NOT(zerorightbus);
        END LOOP;

        -- +1 just estimate, correct is bb is larger
        -- need sticky bit handling here for accuracy
        aluff <= aluleftff + alurightff + 1;
      
      END IF;
        
    END IF;
      
  END PROCESS;
  
  gma: FOR k IN 1 TO 32 GENERATE
    bbmantissanode(k) <= NOT(bbmantissa(k));
  END GENERATE;

  exponentone <= aaexponent - bbexponent;
  exponenttwo <= bbexponent - aaexponent;
  switch <= exponentone(9);

  zerorightbus <= shiftff(10) OR shiftff(9) OR shiftff(8) OR shiftff(7) OR shiftff(6);
  
  cbs: apn_fftfp_rsft32 
  PORT MAP (inbus=>mantissarightff,shift=>shiftff(5 DOWNTO 1),
            outbus=>alurightbus);

  --*** OUTPUTS ***
	ccmantissa <= aluff;
  ccexponent <= exponentbaseff(3)(10 DOWNTO 1);   
   
END rtl;

