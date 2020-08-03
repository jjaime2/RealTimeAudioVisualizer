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

library work;
use work.auk_dspip_math_pkg.all;
USE work.auk_fft_pkg.all;

--***************************************************
--***                                             ***
--***   ALTERA SINGLE PRECISION FFT CORE          ***
--***                                             ***
--***   APN_FFTFP_LASTSTAGE                       ***
--***                                             ***
--***   Function: last R4/R2 stage for streaming  ***
--***   FFT                                       ***
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

ENTITY apn_fftfp_laststage IS
GENERIC(
         device_family: string;
         dsp      : integer := 0
);
PORT (
      sysclk  : IN STD_LOGIC;
      reset   : IN STD_LOGIC;
      enable  : IN STD_LOGIC;
      startin : IN STD_LOGIC;
      radix   : IN STD_LOGIC;
      realin, imagin : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
      
      realout, imagout : OUT STD_LOGIC_VECTOR (32 DOWNTO 1);
      startout : OUT STD_LOGIC
     );
END apn_fftfp_laststage;

ARCHITECTURE rtl OF apn_fftfp_laststage IS
  constant internal_data_width : integer := get_internal_data_width(dsp, device_family);
  type delayfftype IS ARRAY (7 DOWNTO 1) OF STD_LOGIC_VECTOR (32 DOWNTO 1);
  type muxfftype IS ARRAY (4 DOWNTO 1) OF STD_LOGIC_VECTOR (internal_data_width DOWNTO 1);
  type expmuxtype IS ARRAY (4 DOWNTO 1) OF STD_LOGIC_VECTOR (8 DOWNTO 1);
  type manmuxtype IS ARRAY (4 DOWNTO 1) OF STD_LOGIC_VECTOR (23 DOWNTO 1);
  type mannodetype IS ARRAY (4 DOWNTO 1) OF STD_LOGIC_VECTOR (32 DOWNTO 1);
    
  type exptesttype  IS ARRAY (4 DOWNTO 1) OF STD_LOGIC_VECTOR (8 DOWNTO 1);
  type mantesttype  IS ARRAY (4 DOWNTO 1) OF STD_LOGIC_VECTOR (23 DOWNTO 1);
  
  signal startff : STD_LOGIC_VECTOR (19 DOWNTO 1);
  signal countff : STD_LOGIC_VECTOR (2 DOWNTO 1);
  signal realff, imagff : delayfftype;
  signal realmuxff, imagmuxff : muxfftype;
  signal selone, seltwo, selthr, selfor : STD_LOGIC; 
  signal seloneff, seltwoff, selthrff, selforff : STD_LOGIC; 
  signal realoutnode, imagoutnode : STD_LOGIC_VECTOR (32 DOWNTO 1);
    
  signal realsignmux, imagsignmux : STD_LOGIC_VECTOR (4 DOWNTO 1);
  signal realexpmux, imagexpmux : expmuxtype;
  signal realmanmux, imagmanmux : manmuxtype;
  
  --signal rsin, isin : STD_LOGIC_VECTOR (4 DOWNTO 1);
  --signal rxin, ixin : exptesttype;
  --signal rmin, imin : mantesttype;
  --signal rsout, isout : STD_LOGIC;
  --signal rxout, ixout : STD_LOGIC_VECTOR (8 DOWNTO 1);
  --signal rmout, imout : STD_LOGIC_VECTOR (23 DOWNTO 1);

  component apn_fftfp_dft4
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
   end component;
  component apn_fftfp_dft4_hdfp
  PORT (
        sysclk : IN STD_LOGIC;
        reset : IN STD_LOGIC;
        enable : IN STD_LOGIC;
        startin : IN STD_LOGIC;
        realina : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
        imagina : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
        realinb : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
        imaginb : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
        realinc : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
        imaginc : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
        realind : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
        imagind : IN STD_LOGIC_VECTOR (32 DOWNTO 1);

        startout : OUT STD_LOGIC;
        realout : OUT STD_LOGIC_VECTOR (32 DOWNTO 1);
        imagout : OUT STD_LOGIC_VECTOR (32 DOWNTO 1)
       );
   end component;
    
BEGIN

  pda: PROCESS (sysclk, reset) 
  BEGIN
  
    IF (reset = '1') THEN
        
      countff <= "00";
      FOR k IN 1 TO 19 LOOP
        startff(k) <= '0';
      END LOOP;
      seloneff <= '0';
      seltwoff <= '0';
      selthrff <= '0';
      selforff <= '0';
            
    ELSIF (rising_edge(sysclk)) THEN

      IF (enable = '1') THEN
          
        startff(1) <= startin;
        FOR k IN 2 TO 19 LOOP
          startff(k) <= startff(k-1);
        END LOOP;

        --IF (startff(4) = '1') THEN
        IF (startff(3) = '1') THEN
          countff <= countff + 1;
        END IF;
                
        realff(1)(32 DOWNTO 1) <= realin;
        imagff(1)(32 DOWNTO 1) <= imagin;
        FOR k IN 2 TO 7 LOOP
          realff(k)(32 DOWNTO 1) <= realff(k-1)(32 DOWNTO 1);
          imagff(k)(32 DOWNTO 1) <= imagff(k-1)(32 DOWNTO 1);
        END LOOP;
        
        seloneff <= selone;
        seltwoff <= seltwo;
        selthrff <= selthr;
        selforff <= selfor;
   

      END IF;
  
    END IF;
      
  END PROCESS;

  -- {1,1,1,1)
  realsignmux(1) <= (realff(4)(32) AND seloneff) OR 
                    (realff(5)(32) AND seltwoff) OR
                    (realff(6)(32) AND selthrff) OR
                    (realff(7)(32) AND selforff);
  imagsignmux(1) <= (imagff(4)(32) AND seloneff) OR 
                    (imagff(5)(32) AND seltwoff) OR
                    (imagff(6)(32) AND selthrff) OR
                    (imagff(7)(32) AND selforff);
  gmxone: FOR k IN 1 TO 8 GENERATE
    realexpmux(1)(k) <= (realff(4)(k+23) AND seloneff) OR 
                        (realff(5)(k+23) AND seltwoff) OR
                        (realff(6)(k+23) AND selthrff) OR
                        (realff(7)(k+23) AND selforff);
    imagexpmux(1)(k) <= (imagff(4)(k+23) AND seloneff) OR 
                        (imagff(5)(k+23) AND seltwoff) OR
                        (imagff(6)(k+23) AND selthrff) OR
                        (imagff(7)(k+23) AND selforff);
  END GENERATE;
  gmmone: FOR k IN 1 TO 23 GENERATE
    realmanmux(1)(k) <= (realff(4)(k) AND seloneff) OR 
                        (realff(5)(k) AND seltwoff) OR
                        (realff(6)(k) AND selthrff) OR
                        (realff(7)(k) AND selforff);
    imagmanmux(1)(k) <= (imagff(4)(k) AND seloneff) OR 
                        (imagff(5)(k) AND seltwoff) OR
                        (imagff(6)(k) AND selthrff) OR
                        (imagff(7)(k) AND selforff);
  END GENERATE;
  


  -- {1,-j,-1,j}
  realsignmux(2) <= (realff(3)(32)      AND seloneff) OR
                    (imagff(4)(32)      AND seltwoff AND NOT(radix)) OR
                    (NOT(realff(4)(32)) AND seltwoff AND     radix) OR
                    (NOT(realff(5)(32)) AND selthrff) OR
                    (NOT(imagff(6)(32)) AND selforff);
  imagsignmux(2) <= (imagff(3)(32)      AND seloneff) OR
                    (NOT(realff(4)(32)) AND seltwoff AND NOT(radix)) OR
                    (NOT(imagff(4)(32)) AND seltwoff AND     radix) OR
                    (NOT(imagff(5)(32)) AND selthrff) OR
                    (realff(6)(32)      AND selforff);
  gmxtwo: FOR k IN 1 TO 8 GENERATE
    realexpmux(2)(k) <= (realff(3)(k+23) AND seloneff) OR
                        (imagff(4)(k+23) AND seltwoff AND NOT(radix)) OR
                        (realff(4)(k+23) AND seltwoff AND     radix) OR
                        (realff(5)(k+23) AND selthrff) OR
                        (imagff(6)(k+23) AND selforff);
    imagexpmux(2)(k) <= (imagff(3)(k+23) AND seloneff) OR
                        (realff(4)(k+23) AND seltwoff AND NOT(radix)) OR
                        (imagff(4)(k+23) AND seltwoff AND     radix) OR
                        (imagff(5)(k+23) AND selthrff) OR
                        (realff(6)(k+23) AND selforff);
  END GENERATE;
  gmmtwo: FOR k IN 1 TO 23 GENERATE
    realmanmux(2)(k) <= (realff(3)(k) AND seloneff) OR
                        (imagff(4)(k) AND seltwoff AND NOT(radix)) OR
                        (realff(4)(k) AND seltwoff AND     radix) OR
                        (realff(5)(k) AND selthrff) OR
                        (imagff(6)(k) AND selforff);
    imagmanmux(2)(k) <= (imagff(3)(k) AND seloneff) OR
                        (realff(4)(k) AND seltwoff AND NOT(radix)) OR
                        (imagff(4)(k) AND seltwoff AND     radix) OR
                        (imagff(5)(k) AND selthrff) OR
                        (realff(6)(k) AND selforff);
  END GENERATE;


    
  --{1,-1,1,-1}
  realsignmux(3) <= ((realff(2)(32)      AND seloneff) OR
                     (NOT(realff(3)(32)) AND seltwoff) OR
                     (realff(4)(32)      AND selthrff) OR
                     (NOT(realff(5)(32)) AND selforff)) AND NOT(radix);
  imagsignmux(3) <= ((imagff(2)(32)      AND seloneff) OR
                     (NOT(imagff(3)(32)) AND seltwoff) OR
                     (imagff(4)(32)      AND selthrff) OR
                     (NOT(imagff(5)(32)) AND selforff)) AND NOT(radix);
  gmxthr: FOR k IN 1 TO 8 GENERATE
    realexpmux(3)(k) <= ((realff(2)(k+23) AND seloneff) OR
                         (realff(3)(k+23) AND seltwoff) OR
                         (realff(4)(k+23) AND selthrff) OR
                         (realff(5)(k+23) AND selforff)) AND NOT(radix);
    imagexpmux(3)(k) <= ((imagff(2)(k+23) AND seloneff) OR
                         (imagff(3)(k+23) AND seltwoff) OR
                         (imagff(4)(k+23) AND selthrff) OR
                         (imagff(5)(k+23) AND selforff)) AND NOT(radix);
  END GENERATE;
  gmmthr: FOR k IN 1 TO 23 GENERATE
    realmanmux(3)(k) <= ((realff(2)(k) AND seloneff) OR
                         (realff(3)(k) AND seltwoff) OR
                         (realff(4)(k) AND selthrff) OR
                         (realff(5)(k) AND selforff)) AND NOT(radix);
    imagmanmux(3)(k) <= ((imagff(2)(k) AND seloneff) OR
                         (imagff(3)(k) AND seltwoff) OR
                         (imagff(4)(k) AND selthrff) OR
                         (imagff(5)(k) AND selforff)) AND NOT(radix);
  END GENERATE;
  

                      
  -- {1,j,-1,-j}       
  realsignmux(4) <= ((realff(1)(32)      AND seloneff) OR
                     (NOT(imagff(2)(32)) AND seltwoff) OR
                     (NOT(realff(3)(32)) AND selthrff) OR
                     (imagff(4)(32)      AND selforff)) AND NOT(radix);
  imagsignmux(4) <= ((imagff(1)(32)      AND seloneff) OR
                     (realff(2)(32)      AND seltwoff) OR
                     (NOT(imagff(3)(32)) AND selthrff) OR
                     (NOT(realff(4)(32)) AND selforff)) AND NOT(radix);                      
  gmxfor: FOR k IN 1 TO 8 GENERATE                       
    realexpmux(4)(k) <= ((realff(1)(k+23) AND seloneff) OR
                         (imagff(2)(k+23) AND seltwoff) OR
                         (realff(3)(k+23) AND selthrff) OR
                         (imagff(4)(k+23) AND selforff)) AND NOT(radix);
    imagexpmux(4)(k) <= ((imagff(1)(k+23) AND seloneff) OR
                         (realff(2)(k+23) AND seltwoff) OR
                         (imagff(3)(k+23) AND selthrff) OR
                         (realff(4)(k+23) AND selforff)) AND NOT(radix);
  END GENERATE;
  gmmfor: FOR k IN 1 TO 23 GENERATE
    realmanmux(4)(k) <= ((realff(1)(k) AND seloneff) OR
                         (imagff(2)(k) AND seltwoff) OR
                         (realff(3)(k) AND selthrff) OR
                         (imagff(4)(k) AND selforff)) AND NOT(radix);
    imagmanmux(4)(k) <= ((imagff(1)(k) AND seloneff) OR
                         (realff(2)(k) AND seltwoff) OR
                         (imagff(3)(k) AND selthrff) OR
                         (realff(4)(k) AND selforff)) AND NOT(radix);
  END GENERATE;



  selone <= (NOT(countff(2)) AND NOT(countff(1)) AND NOT(radix)) OR
            (NOT(countff(1)) AND radix);
  seltwo <= (NOT(countff(2)) AND     countff(1)  AND NOT(radix)) OR
            (    countff(1)  AND radix);
  selthr <= (    countff(2)  AND NOT(countff(1)) AND NOT(radix));
  selfor <= (    countff(2)  AND     countff(1)  AND NOT(radix)); 
  
  --rsin(1) <= realmuxff(1)(32);
  --rxin(1)(8 DOWNTO 1) <= realmuxff(1)(31 DOWNTO 24);
  --rmin(1)(23 DOWNTO 1) <= realmuxff(1)(23 DOWNTO 1);
  --isin(1) <= imagmuxff(1)(32);
  --ixin(1)(8 DOWNTO 1) <= imagmuxff(1)(31 DOWNTO 24);
  --imin(1)(23 DOWNTO 1) <= imagmuxff(1)(23 DOWNTO 1);
            
  --rsin(2) <= realmuxff(2)(32);
  --rxin(2)(8 DOWNTO 1) <= realmuxff(2)(31 DOWNTO 24);
  --rmin(2)(23 DOWNTO 1) <= realmuxff(2)(23 DOWNTO 1);
  --isin(2) <= imagmuxff(2)(32);
  --ixin(2)(8 DOWNTO 1) <= imagmuxff(2)(31 DOWNTO 24);
  --imin(2)(23 DOWNTO 1) <= imagmuxff(2)(23 DOWNTO 1);
            
  --rsin(3) <= realmuxff(3)(32);
  --rxin(3)(8 DOWNTO 1) <= realmuxff(3)(31 DOWNTO 24);
  --rmin(3)(23 DOWNTO 1) <= realmuxff(3)(23 DOWNTO 1);
  --isin(3) <= imagmuxff(3)(32);
  --ixin(3)(8 DOWNTO 1) <= imagmuxff(3)(31 DOWNTO 24);
  --imin(3)(23 DOWNTO 1) <= imagmuxff(3)(23 DOWNTO 1);
            
  --rsin(4) <= realmuxff(4)(32);
  --rxin(4)(8 DOWNTO 1) <= realmuxff(4)(31 DOWNTO 24);
  --rmin(4)(23 DOWNTO 1) <= realmuxff(4)(23 DOWNTO 1);
  --isin(4) <= imagmuxff(4)(32);
  --ixin(4)(8 DOWNTO 1) <= imagmuxff(4)(31 DOWNTO 24);
  --imin(4)(23 DOWNTO 1) <= imagmuxff(4)(23 DOWNTO 1);
  

            
  --rsout <= realoutnode(32);
  --rxout <= realoutnode(31 DOWNTO 24);
  --rmout <= realoutnode(23 DOWNTO 1);          
  --isout <= imagoutnode(32);
  --ixout <= imagoutnode(31 DOWNTO 24);
  --imout <= imagoutnode(23 DOWNTO 1);
 
  realout <= realoutnode;
  imagout <= imagoutnode;
   


  custom_width_adaptor:  IF not(dsp = 3) GENERATE

  signal realsignmuxff, imagsignmuxff : STD_LOGIC_VECTOR (4 DOWNTO 1);
  signal realexpmuxff, imagexpmuxff : expmuxtype;
  signal realmanmuxff, imagmanmuxff : manmuxtype;
  signal realmangennode, imagmangennode : mannodetype;
  signal realmanprenode, imagmanprenode : mannodetype;
  signal realmannode, imagmannode : mannodetype;

  BEGIN
       --Convert from Single floating point to magic 40 bit type

      conv_proc: PROCESS (sysclk, reset) 
      BEGIN
    
      IF (reset = '1') THEN
          
        FOR k IN 1 TO 4 LOOP
          realsignmuxff(k) <= '0';
          imagsignmuxff(k) <= '0';
          FOR j IN 1 TO 8 LOOP
            realexpmuxff(k)(j) <= '0';
            imagexpmuxff(k)(j) <= '0';
          END LOOP;
          FOR j IN 1 TO 23 LOOP
            realmanmuxff(k)(j) <= '0';
            imagmanmuxff(k)(j) <= '0';
          END LOOP;
        END LOOP;
        FOR k IN 1 TO 4 LOOP
          FOR j IN 1 TO 40 LOOP
            realmuxff(k)(j) <= '0';
            imagmuxff(k)(j) <= '0';
          END LOOP;
        END LOOP;
              
      ELSIF (rising_edge(sysclk)) THEN

        IF (enable = '1') THEN
               
          realsignmuxff <= realsignmux;
          imagsignmuxff <= imagsignmux;
          FOR k IN 1 TO 4 LOOP
            realexpmuxff(k) <= realexpmux(k);
            imagexpmuxff(k) <= imagexpmux(k);
          END LOOP;
          FOR k IN 1 TO 4 LOOP
            realmanmuxff(k) <= realmanmux(k);
            imagmanmuxff(k) <= imagmanmux(k);
          END LOOP;
          
          FOR i IN 1 TO 4 LOOP
          realmuxff(i) <= realmannode(i) & realexpmuxff(i);
          imagmuxff(i) <= imagmannode(i) & imagexpmuxff(i);
          END LOOP;

        END IF;
    
      END IF;
        
    END PROCESS;

    conv: FOR i IN 1 TO 4 GENERATE
      realmangennode(i)(32 DOWNTO 28) <= "00000";
      realmangennode(i)(27) <= or_reduce(realexpmuxff(i));
      realmangennode(i)(26 DOWNTO 4) <= realmanmuxff(i)(23 DOWNTO 1);
      realmangennode(i)(3 DOWNTO 1) <= "000";
      grma: FOR k IN 1 TO 32 GENERATE
        realmanprenode(i)(k) <= realmangennode(i)(k) XOR realsignmuxff(i);
      END GENERATE;
      realmannode(i)(32 DOWNTO 1) <= realmanprenode(i)(32 DOWNTO 1) + realsignmuxff(i);
      
      imagmangennode(i)(32 DOWNTO 28) <= "00000";
      imagmangennode(i)(27) <= or_reduce(imagexpmuxff(i));
      imagmangennode(i)(26 DOWNTO 4) <= imagmanmuxff(i)(23 DOWNTO 1);
      imagmangennode(i)(3 DOWNTO 1) <= "000";
      gima: FOR k IN 1 TO 32 GENERATE
        imagmanprenode(i)(k) <= imagmangennode(i)(k) XOR imagsignmuxff(i);
      END GENERATE;
      imagmannode(i)(32 DOWNTO 1) <= imagmanprenode(i)(32 DOWNTO 1) + imagsignmuxff(i);               
    END GENERATE;
    --end conversion


  core: apn_fftfp_dft4
  PORT MAP (sysclk=>sysclk,reset=>reset,enable=>enable,
            startin=>startff(6),
            realina=>realmuxff(1),imagina=>imagmuxff(1),
            realinb=>realmuxff(2),imaginb=>imagmuxff(2),
            realinc=>realmuxff(3),imaginc=>imagmuxff(3),
            realind=>realmuxff(4),imagind=>imagmuxff(4),
            
            startout=>startout,
            realout=>realoutnode,imagout=>imagoutnode);


  END GENERATE;

  single_width:  IF dsp = 3 GENERATE
  signal realmux, imagmux : mannodetype;
  begin
    conv_proc: PROCESS (sysclk, reset) 
    BEGIN
    
      IF (reset = '1') THEN
      
            realmux <= (others=>(others=>'0'));
            imagmux <= (others=>(others=>'0'));
       
            realmuxff <= (others=>(others=>'0'));
            imagmuxff <= (others=>(others=>'0'));
    
      ELSIF (rising_edge(sysclk)) THEN

        IF (enable = '1') THEN

          FOR k IN 1 TO 4 LOOP
            realmux(k) <= realsignmux(k) & realexpmux(k) & realmanmux(k);
            imagmux(k) <= imagsignmux(k) & imagexpmux(k) & imagmanmux(k);
          END LOOP;

        
          FOR k IN 1 TO 4 LOOP
            realmuxff(k) <= realmux(k);
            imagmuxff(k) <= imagmux(k);
          END LOOP;

        END IF;
        
      END IF;
        
    END PROCESS;
    
  core_hd: apn_fftfp_dft4_hdfp
  PORT MAP (sysclk=>sysclk,reset=>reset,enable=>enable,
            startin=>startff(6),
            realina=>realmuxff(1),imagina=>imagmuxff(1),
            realinb=>realmuxff(2),imaginb=>imagmuxff(2),
            realinc=>realmuxff(3),imaginc=>imagmuxff(3),
            realind=>realmuxff(4),imagind=>imagmuxff(4),
            
            startout=>startout,
            realout=>realoutnode,imagout=>imagoutnode);

  END GENERATE;


END rtl;

