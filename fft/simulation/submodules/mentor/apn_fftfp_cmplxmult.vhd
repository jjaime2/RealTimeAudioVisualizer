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
--***   APN_FFTFP_CMPLXMULT                       ***
--***                                             ***
--***   Function: complex multiplication          ***
--***   internal format floating point number     ***
--***                                             ***
--***   14/12/11 sssahori                         ***
--***                                             ***
--***   (c) 2011 Altera Corporation               ***
--***                                             ***
--***   Change History                            ***
--***                                             ***
--***                                             ***
--***                                             ***
--***                                             ***
--***************************************************

ENTITY apn_fftfp_cmplxmult IS 
  GENERIC (
    dsp           : natural := 0;
    device_family : string
  );
  PORT (
      sysclk      : IN STD_LOGIC;
      reset       : IN STD_LOGIC;
      enable      : IN STD_LOGIC;

      realmantissanorm  : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
      realexponentnorm  : IN STD_LOGIC_VECTOR (10 DOWNTO 1);
      imagmantissanorm  : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
      imagexponentnorm  : IN STD_LOGIC_VECTOR (10 DOWNTO 1);

      realtwidmantissa  : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
      realtwidexponent  : IN STD_LOGIC_VECTOR (10 DOWNTO 1);
      imagtwidmantissa  : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
      imagtwidexponent  : IN STD_LOGIC_VECTOR (10 DOWNTO 1);
      
		  realmantissasub   : OUT STD_LOGIC_VECTOR (32 DOWNTO 1);
      realexponentsub   : OUT STD_LOGIC_VECTOR (10 DOWNTO 1);
      imagmantissaadd   : OUT STD_LOGIC_VECTOR (32 DOWNTO 1);
      imagexponentadd   : OUT STD_LOGIC_VECTOR (10 DOWNTO 1)
		);
END apn_fftfp_cmplxmult;

ARCHITECTURE rtl OF apn_fftfp_cmplxmult IS

	component apn_fftfp_mul IS 
    generic (
        device_family : STRING
    );
    port (
        sysclk      : IN STD_LOGIC;
        reset       : IN STD_LOGIC;
        enable      : IN STD_LOGIC;
        aamantissa  : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
        aaexponent  : IN STD_LOGIC_VECTOR (10 DOWNTO 1);
        bbmantissa  : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
        bbexponent  : IN STD_LOGIC_VECTOR (10 DOWNTO 1);
      
		    ccmantissa  : OUT STD_LOGIC_VECTOR (32 DOWNTO 1);
        ccexponent  : OUT STD_LOGIC_VECTOR (10 DOWNTO 1)
		  );  
	end component;

  component apn_fftfp_mul_2727 IS 
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

  component apn_fftfp_sub IS 
    port (
        sysclk      : IN STD_LOGIC;
        reset       : IN STD_LOGIC;
        enable      : IN STD_LOGIC;
        aamantissa  : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
        aaexponent  : IN STD_LOGIC_VECTOR (10 DOWNTO 1);
        bbmantissa  : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
        bbexponent  : IN STD_LOGIC_VECTOR (10 DOWNTO 1);
      
		    ccmantissa  : OUT STD_LOGIC_VECTOR (32 DOWNTO 1);
        ccexponent  : OUT STD_LOGIC_VECTOR (10 DOWNTO 1)
		  );
	end component;

  component apn_fftfp_add IS 
    port (
        sysclk      : IN STD_LOGIC;
        reset       : IN STD_LOGIC;
        enable      : IN STD_LOGIC;
        aamantissa  : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
        aaexponent  : IN STD_LOGIC_VECTOR (10 DOWNTO 1);
        bbmantissa  : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
        bbexponent  : IN STD_LOGIC_VECTOR (10 DOWNTO 1);
      
		    ccmantissa  : OUT STD_LOGIC_VECTOR (32 DOWNTO 1);
        ccexponent  : OUT STD_LOGIC_VECTOR (10 DOWNTO 1)
		  );
	end component;

  signal mulonemantissa : STD_LOGIC_VECTOR (32 DOWNTO 1);
  signal muloneexponent : STD_LOGIC_VECTOR (10 DOWNTO 1);
  signal multwomantissa : STD_LOGIC_VECTOR (32 DOWNTO 1);
  signal multwoexponent : STD_LOGIC_VECTOR (10 DOWNTO 1);
  signal multhrmantissa : STD_LOGIC_VECTOR (32 DOWNTO 1);
  signal multhrexponent : STD_LOGIC_VECTOR (10 DOWNTO 1);
  signal mulformantissa : STD_LOGIC_VECTOR (32 DOWNTO 1);
  signal mulforexponent : STD_LOGIC_VECTOR (10 DOWNTO 1);
  
BEGIN

  -- twiddle +1.0 mantissa is "0100...", effect is divide by 4, add 2 to exponent in apn_fftfp_mul
  grca: IF (dsp = 0) GENERATE
    cmone: apn_fftfp_mul
      GENERIC MAP (
        device_family => device_family
      )
      PORT MAP (
        sysclk      =>  sysclk,
        reset       =>  reset,
        enable      =>  enable,
        aamantissa  =>  realmantissanorm,
        aaexponent  =>  realexponentnorm,
        bbmantissa  =>  realtwidmantissa,
        bbexponent  =>  realtwidexponent,
        ccmantissa  =>  mulonemantissa,
        ccexponent  =>  muloneexponent
      );
    
    cmtwo: apn_fftfp_mul
      GENERIC MAP (
        device_family => device_family
      )
      PORT MAP (
        sysclk      =>  sysclk,
        reset       =>  reset,
        enable      =>  enable,
        aamantissa  =>  imagmantissanorm,
        aaexponent  =>  imagexponentnorm,
        bbmantissa  =>  imagtwidmantissa,
        bbexponent  =>  imagtwidexponent,
        ccmantissa  =>  multwomantissa,
        ccexponent  =>  multwoexponent
      );
  END GENERATE;

  grcb: IF (dsp = 1 or dsp = 2) GENERATE
    cmone: apn_fftfp_mul_2727
    PORT MAP (sysclk=>sysclk,reset=>reset,enable=>enable,
            aamantissa=>realmantissanorm,
            aaexponent=>realexponentnorm,
            bbmantissa=>realtwidmantissa,
            bbexponent=>realtwidexponent,
            ccmantissa=>mulonemantissa,
            ccexponent=>muloneexponent);
            
    cmtwo: apn_fftfp_mul_2727
    PORT MAP (sysclk=>sysclk,reset=>reset,enable=>enable,
            aamantissa=>imagmantissanorm,
            aaexponent=>imagexponentnorm,
            bbmantissa=>imagtwidmantissa,
            bbexponent=>imagtwidexponent,
            ccmantissa=>multwomantissa,
            ccexponent=>multwoexponent);
  END GENERATE;

  ccxr: apn_fftfp_sub
    PORT MAP (
      sysclk      =>  sysclk,
      reset       =>  reset,
      enable      =>  enable,
      aamantissa  =>  mulonemantissa,
      aaexponent  =>  muloneexponent,
      bbmantissa  =>  multwomantissa,
      bbexponent  =>  multwoexponent,
      ccmantissa  =>  realmantissasub,
      ccexponent  =>  realexponentsub
    ); 

  grcc: IF (dsp = 0) GENERATE
    cmthr: apn_fftfp_mul
      GENERIC MAP (
        device_family => device_family
      )
      PORT MAP (
        sysclk      =>  sysclk,
        reset       =>  reset,
        enable      =>  enable,
        aamantissa  =>  imagmantissanorm,
        aaexponent  =>  imagexponentnorm,
        bbmantissa  =>  realtwidmantissa,
        bbexponent  =>  realtwidexponent,
        ccmantissa  =>  multhrmantissa,
        ccexponent  =>  multhrexponent
      );
              
    cmfor: apn_fftfp_mul
      GENERIC MAP (
        device_family => device_family
      )
      PORT MAP (
        sysclk      =>  sysclk,
        reset       =>  reset,
        enable      =>  enable,
        aamantissa  =>  realmantissanorm,
        aaexponent  =>  realexponentnorm,
        bbmantissa  =>  imagtwidmantissa,
        bbexponent  =>  imagtwidexponent,
        ccmantissa  =>  mulformantissa,
        ccexponent  =>  mulforexponent
      );
  END GENERATE;

  grcd: IF (dsp = 1 or dsp = 2) GENERATE
    cmthr: apn_fftfp_mul_2727
    PORT MAP (sysclk=>sysclk,reset=>reset,enable=>enable,
            aamantissa=>imagmantissanorm,
            aaexponent=>imagexponentnorm,
            bbmantissa=>realtwidmantissa,
            bbexponent=>realtwidexponent,
            ccmantissa=>multhrmantissa,
            ccexponent=>multhrexponent);
            
    cmfor: apn_fftfp_mul_2727
    PORT MAP (sysclk=>sysclk,reset=>reset,enable=>enable,
            aamantissa=>realmantissanorm,
            aaexponent=>realexponentnorm,
            bbmantissa=>imagtwidmantissa,
            bbexponent=>imagtwidexponent,
            ccmantissa=>mulformantissa,
            ccexponent=>mulforexponent);
  END GENERATE;
    
  ccxi: apn_fftfp_add
    PORT MAP (
      sysclk      =>  sysclk,
      reset       =>  reset,
      enable      =>  enable,
      aamantissa  =>  multhrmantissa,
      aaexponent  =>  multhrexponent,
      bbmantissa  =>  mulformantissa,
      bbexponent  =>  mulforexponent,
      ccmantissa  =>  imagmantissaadd,
      ccexponent  =>  imagexponentadd
    ); 

END rtl;

