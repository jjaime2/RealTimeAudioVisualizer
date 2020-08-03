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
--***   APN_FFTFP_DFT4                            ***
--***                                             ***
--***   Function: perform DFT on pre processed    ***
--***   internal format numbers, used for last    ***
--***   stage in fft                              ***
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

ENTITY apn_fftfp_dft4 IS 
PORT (
      sysclk : IN STD_LOGIC;
      reset : IN STD_LOGIC;
      enable : IN STD_LOGIC;
      startin : IN STD_LOGIC;
      realina : IN STD_LOGIC_VECTOR (40 DOWNTO 1);
      imagina : IN STD_LOGIC_VECTOR (40 DOWNTO 1);
      realinb : IN STD_LOGIC_VECTOR (40 DOWNTO 1);
      imaginb : IN STD_LOGIC_VECTOR (40 DOWNTO 1);
      realinc : IN STD_LOGIC_VECTOR (40 DOWNTO 1);
      imaginc : IN STD_LOGIC_VECTOR (40 DOWNTO 1);
      realind : IN STD_LOGIC_VECTOR (40 DOWNTO 1);
      imagind : IN STD_LOGIC_VECTOR (40 DOWNTO 1);
      
      startout : OUT STD_LOGIC;
      realout : OUT STD_LOGIC_VECTOR (32 DOWNTO 1);
      imagout : OUT STD_LOGIC_VECTOR (32 DOWNTO 1)
		);
END apn_fftfp_dft4;

ARCHITECTURE rtl OF apn_fftfp_dft4 IS

  signal realina_exponent : STD_LOGIC_VECTOR (10 DOWNTO 1);
  signal realinb_exponent : STD_LOGIC_VECTOR (10 DOWNTO 1);
  signal realinc_exponent : STD_LOGIC_VECTOR (10 DOWNTO 1);
  signal realind_exponent : STD_LOGIC_VECTOR (10 DOWNTO 1);
  signal imagina_exponent : STD_LOGIC_VECTOR (10 DOWNTO 1);
  signal imaginb_exponent : STD_LOGIC_VECTOR (10 DOWNTO 1);
  signal imaginc_exponent : STD_LOGIC_VECTOR (10 DOWNTO 1);
  signal imagind_exponent : STD_LOGIC_VECTOR (10 DOWNTO 1);
  
  signal realmantissaone : STD_LOGIC_VECTOR (32 DOWNTO 1);
  signal realmantissatwo : STD_LOGIC_VECTOR (32 DOWNTO 1);
  signal realmantissathr : STD_LOGIC_VECTOR (32 DOWNTO 1);
  signal realexponentone : STD_LOGIC_VECTOR (10 DOWNTO 1);
  signal realexponenttwo : STD_LOGIC_VECTOR (10 DOWNTO 1);
  signal realexponentthr : STD_LOGIC_VECTOR (10 DOWNTO 1);
  
  signal imagmantissaone : STD_LOGIC_VECTOR (32 DOWNTO 1);
  signal imagmantissatwo : STD_LOGIC_VECTOR (32 DOWNTO 1);
  signal imagmantissathr : STD_LOGIC_VECTOR (32 DOWNTO 1);
  signal imagexponentone : STD_LOGIC_VECTOR (10 DOWNTO 1);
  signal imagexponenttwo : STD_LOGIC_VECTOR (10 DOWNTO 1);
  signal imagexponentthr : STD_LOGIC_VECTOR (10 DOWNTO 1);

  signal realmantissaabsff : STD_LOGIC_VECTOR (32 DOWNTO 1);
  signal imagmantissaabsff : STD_LOGIC_VECTOR (32 DOWNTO 1);
  signal realexponentabsff : STD_LOGIC_VECTOR (10 DOWNTO 1);
  signal imagexponentabsff : STD_LOGIC_VECTOR (10 DOWNTO 1);
  signal realsignoutff, imagsignoutff : STD_LOGIC_VECTOR (4 DOWNTO 1);
  signal realmantissaabsnode : STD_LOGIC_VECTOR (32 DOWNTO 1);
  signal imagmantissaabsnode : STD_LOGIC_VECTOR (32 DOWNTO 1);  

  signal realmantissaout : STD_LOGIC_VECTOR (32 DOWNTO 1);
  signal realexponentout : STD_LOGIC_VECTOR (10 DOWNTO 1);
   
  signal imagmantissaout : STD_LOGIC_VECTOR (32 DOWNTO 1);
  signal imagexponentout : STD_LOGIC_VECTOR (10 DOWNTO 1);

  signal realmantissaff : STD_LOGIC_VECTOR (23 DOWNTO 1);
  signal realexponentff : STD_LOGIC_VECTOR (8 DOWNTO 1);
  signal imagmantissaff : STD_LOGIC_VECTOR (23 DOWNTO 1);
  signal imagexponentff : STD_LOGIC_VECTOR (8 DOWNTO 1);
  
  signal startff : STD_LOGIC_VECTOR (10 DOWNTO 1);
      
  component apn_fftfp_add IS 
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
	end component;

  component apn_fftfp_unorm
  PORT (
        sysclk : IN STD_LOGIC;
        reset : IN STD_LOGIC;
        enable : IN STD_LOGIC;
        aamantissa : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
        aaexponent : IN STD_LOGIC_VECTOR (10 DOWNTO 1);
      
		    ccmantissa : OUT STD_LOGIC_VECTOR (32 DOWNTO 1);
        ccexponent : OUT STD_LOGIC_VECTOR (10 DOWNTO 1)
		  );
	end component; 
		
BEGIN
 
  realina_exponent <= "00" & realina(8 DOWNTO 1);
  realinb_exponent <= "00" & realinb(8 DOWNTO 1);
  realinc_exponent <= "00" & realinc(8 DOWNTO 1);
  realind_exponent <= "00" & realind(8 DOWNTO 1);
  
  imagina_exponent <= "00" & imagina(8 DOWNTO 1);
  imaginb_exponent <= "00" & imaginb(8 DOWNTO 1);
  imaginc_exponent <= "00" & imaginc(8 DOWNTO 1);
  imagind_exponent <= "00" & imagind(8 DOWNTO 1);
    
  psa: PROCESS (sysclk,reset)
  BEGIN
    IF (reset = '1') THEN
      FOR k IN 1 TO 10 LOOP
        startff(k) <= '0';
      END LOOP;
    ELSIF (rising_edge(sysclk)) THEN
      IF (enable = '1') THEN
        startff(1) <= startin;
        FOR k IN 2 TO 10 LOOP
          startff(k) <= startff(k-1);
        END LOOP;
      END IF;
    END IF;
  END PROCESS;

  craone: apn_fftfp_add 
  PORT MAP (sysclk=>sysclk,reset=>reset,enable=>enable,
            aamantissa=>realina(40 DOWNTO 9),
            aaexponent=>realina_exponent,
            bbmantissa=>realinb(40 DOWNTO 9),
            bbexponent=>realinb_exponent,
            ccmantissa=>realmantissaone,
            ccexponent=>realexponentone);

  cratwo: apn_fftfp_add
  PORT MAP (sysclk=>sysclk,reset=>reset,enable=>enable,
            aamantissa=>realinc(40 DOWNTO 9),
            aaexponent=>realinc_exponent,
            bbmantissa=>realind(40 DOWNTO 9),
            bbexponent=>realind_exponent,
            ccmantissa=>realmantissatwo,
            ccexponent=>realexponenttwo);  
  
  crathr: apn_fftfp_add 
  PORT MAP (sysclk=>sysclk,reset=>reset,enable=>enable,
            aamantissa=>realmantissaone,
            aaexponent=>realexponentone,
            bbmantissa=>realmantissatwo,
            bbexponent=>realexponenttwo,
            ccmantissa=>realmantissathr,
            ccexponent=>realexponentthr);    

  ciaone: apn_fftfp_add 
  PORT MAP (sysclk=>sysclk,reset=>reset,enable=>enable,
            aamantissa=>imagina(40 DOWNTO 9),
            aaexponent=>imagina_exponent,
            bbmantissa=>imaginb(40 DOWNTO 9),
            bbexponent=>imaginb_exponent,
            ccmantissa=>imagmantissaone,
            ccexponent=>imagexponentone);

  ciatwo: apn_fftfp_add 
  PORT MAP (sysclk=>sysclk,reset=>reset,enable=>enable,
            aamantissa=>imaginc(40 DOWNTO 9),
            aaexponent=>imaginc_exponent,
            bbmantissa=>imagind(40 DOWNTO 9),
            bbexponent=>imagind_exponent,
            ccmantissa=>imagmantissatwo,
            ccexponent=>imagexponenttwo);  
  
  ciathr: apn_fftfp_add 
  PORT MAP (sysclk=>sysclk,reset=>reset,enable=>enable,
            aamantissa=>imagmantissaone,
            aaexponent=>imagexponentone,
            bbmantissa=>imagmantissatwo,
            bbexponent=>imagexponenttwo,
            ccmantissa=>imagmantissathr,
            ccexponent=>imagexponentthr);    

  poa: PROCESS (sysclk,reset)
  BEGIN
    
    IF (reset = '1') THEN
      
      FOR k IN 1 TO 32 LOOP
        realmantissaabsff(k) <= '0';
        imagmantissaabsff(k) <= '0';
      END LOOP;
      FOR k IN 1 TO 10 LOOP
        realexponentabsff(k) <= '0';
        imagexponentabsff(k) <= '0';
      END LOOP;
      FOR k IN 1 TO 4 LOOP
        realsignoutff(k) <= '0';
        imagsignoutff(k) <= '0';
      END LOOP;
        
    ELSIF (rising_edge(sysclk)) THEN
    
      IF (enable = '1') THEN
      
        realmantissaabsff <= realmantissaabsnode;
        imagmantissaabsff <= imagmantissaabsnode;
        
        realexponentabsff <= realexponentthr;
        imagexponentabsff <= imagexponentthr;
        
        realsignoutff(1) <= realmantissathr(32);
        imagsignoutff(1) <= imagmantissathr(32);
        FOR k IN 2 TO 4 LOOP
          realsignoutff(k) <= realsignoutff(k-1);
          imagsignoutff(k) <= imagsignoutff(k-1);
        END LOOP;
          
      END IF;
        
    END IF;
  
  END PROCESS;
  
  gaba: FOR k IN 1 TO 32 GENERATE
    realmantissaabsnode(k) <= realmantissathr(k) XOR realmantissathr(32);
    imagmantissaabsnode(k) <= imagmantissathr(k) XOR imagmantissathr(32);
  END GENERATE;
  
  cnro: apn_fftfp_unorm
  PORT MAP (sysclk=>sysclk,reset=>reset,enable=>enable,
            aamantissa=>realmantissaabsff,
            aaexponent=>realexponentabsff,
            ccmantissa=>realmantissaout,
            ccexponent=>realexponentout);
            
  cnio: apn_fftfp_unorm
  PORT MAP (sysclk=>sysclk,reset=>reset,enable=>enable,
            aamantissa=>imagmantissaabsff,
            aaexponent=>imagexponentabsff,
            ccmantissa=>imagmantissaout,
            ccexponent=>imagexponentout);

  pro: PROCESS (sysclk,reset)
  BEGIN
    
    IF (reset = '1') THEN
      
      FOR k IN 1 TO 23 LOOP
        realmantissaff(k) <= '0';
        imagmantissaff(k) <= '0';
      END LOOP;
      FOR k IN 1 TO 8 LOOP
        realexponentff(k) <= '0';
        imagexponentff(k) <= '0';
      END LOOP;
        
    ELSIF (rising_edge(sysclk)) THEN
    
      IF (enable = '1') THEN
        --removing rounding see case:77456 
        realmantissaff <= realmantissaout(30 DOWNTO 8);
        imagmantissaff <= imagmantissaout(30 DOWNTO 8);
        --realmantissaff <= realmantissaout(30 DOWNTO 8) + realmantissaout(7);
        --imagmantissaff <= imagmantissaout(30 DOWNTO 8) + imagmantissaout(7);
        
        realexponentff <= realexponentout(8 DOWNTO 1);
        imagexponentff <= imagexponentout(8 DOWNTO 1);
          
      END IF;
        
    END IF;
  
  END PROCESS;
  
  --*** OUTPUTS ***
	realout <= realsignoutff(4) & realexponentff & realmantissaff;
	imagout <= imagsignoutff(4) & imagexponentff & imagmantissaff;
	startout <= startff(10);

END rtl;

