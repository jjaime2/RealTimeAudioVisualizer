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

LIBRARY work;
USE work.auk_dspip_math_pkg.all;


--***************************************************
--***                                             ***
--***   ALTERA SINGLE PRECISION FFT CORE          ***
--***                                             ***
--***   APN_FFTFP_RVS                             ***
--***                                             ***
--***   Function: index reversal core             ***
--***                                             ***
--***   01/09/10 KHP                              ***
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


--
--This block converts digit-reversed to natural order with a single memory.
--It writes a full frame of data and then reads that frame
--in digit reversed order. The second frame of data is written
--to the same address locations as the reads of the first frame.
--As the memory is set to OLD_DATA mode we can read the first
--frame in lock step with the writes of the second frame.
--The moment writes stop after a full frame the module 
--allows reads to continue even if no writes are happening.
--This is done to flush the last frame or any frame where there 
--are gaps between frames.
--If we have a gap between frames, and then when writes restart
--after allowing reads to run ahead we cannot use the current 
--read address to write into, we must write from the begining of 
--the read sequence. So we need two address generators here rather than
--the single one previously used.
--
--Reads of first frame can run ahead of writes of second frame, but
--when the reads get to the end of first frame they must wait until
--the second frame is complete.
--
--This block must write all data that it's given into memory, it has
--no way of backpressuring.
--
--We can provide one item of output after out_stall goes high, but no more.
--
--The out_stall signal that's fed into this block is also fed to the 
--fft core that feeds this block. So the enable input must not stay high
--for longer than a cycle after out_stall goes low.
--
--
ENTITY apn_fftfp_rvs IS
GENERIC (
         device_family : string; 
         points : positive := 256
        );
PORT (
      clk      : IN STD_LOGIC;
      reset    : IN STD_LOGIC;
      enable   : IN STD_LOGIC;
      radix    : IN STD_LOGIC;
      length   : IN STD_LOGIC_VECTOR (log2_ceil(points)+1 DOWNTO 1);
      in_valid : IN STD_LOGIC;
      real_in, imag_in : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
      real_out, imag_out : OUT STD_LOGIC_VECTOR (32 DOWNTO 1);
      out_valid  : OUT STD_LOGIC;
      processing : OUT STD_LOGIC;
      out_stall  : IN  STD_LOGIC
);
END apn_fftfp_rvs;

ARCHITECTURE rtl OF apn_fftfp_rvs IS

  constant pointswidth : positive := log2_ceil(points);
  
  signal wr_addr          : STD_LOGIC_VECTOR(pointswidth DOWNTO 1);
  signal rd_addr          : STD_LOGIC_VECTOR(pointswidth DOWNTO 1);
  signal ram_system_enable: STD_LOGIC;
  signal rd_enable        : STD_LOGIC;
  signal wr_enable        : STD_LOGIC;
  signal between_datasets : STD_LOGIC;
  signal out_stall_d      : STD_LOGIC;
  signal rd_valid         : std_logic;
  signal rd_valid_d       : STD_LOGIC;
  signal rd_valid_dd      : STD_LOGIC;
  signal processing_while_write : STD_LOGIC;

  signal wr_enable_reg, rd_enable_reg : STD_LOGIC;
  signal real_in_reg, imag_in_reg : STD_LOGIC_VECTOR (32 DOWNTO 1);
  signal wr_addr_reg : STD_LOGIC_VECTOR(pointswidth DOWNTO 1);


  component apn_fftfp_rvsctl
  GENERIC (
           pointswidth : positive := 8;
           read_addr_gen : boolean := false
          );
  PORT (
        sysclk  : IN STD_LOGIC;
        reset   : IN STD_LOGIC;
        enable  : IN STD_LOGIC;
        validin : IN STD_LOGIC;
        length  : IN STD_LOGIC_VECTOR (pointswidth+1 DOWNTO 1);
        address : OUT STD_LOGIC_VECTOR (pointswidth DOWNTO 1)
       );
  end component;
      
  component apn_fftfp_ram 
  GENERIC (
            device_family : string; 
            addwidth : positive := 4
          );
  PORT
	  ( 
      sysclk       : IN STD_LOGIC;
      read         : IN STD_LOGIC;
      readaddress  : IN STD_LOGIC_VECTOR (addwidth DOWNTO 1);
      writeaddress : IN STD_LOGIC_VECTOR (addwidth DOWNTO 1);    
      write        : IN STD_LOGIC;
      system_enable: IN STD_LOGIC;
      real_in, imag_in : IN STD_LOGIC_VECTOR (32 DOWNTO 1);
      real_out, imag_out : OUT STD_LOGIC_VECTOR (32 DOWNTO 1)    
	  );
  end component;
	    
BEGIN

  ram_system_enable <= rd_enable OR wr_enable_reg;
  wr_enable  <= enable AND in_valid;
  rd_enable <= enable and in_valid when (between_datasets = '0' or (in_valid = '1' and unsigned(wr_addr) = 0)) else
               not out_stall_d;
  --the code below works as well, but has an fmax penalty 
  --rd_enable  <= enable AND in_valid WHEN (between_datasets = '0' or (unsigned(wr_addr) = 0 and in_valid = '1')) ELSE
  --              NOT out_stall_d;

  process (clk)
  begin
    if rising_edge(clk) then
      rd_enable_reg <= rd_enable;
      wr_enable_reg <= wr_enable;
      wr_addr_reg <= wr_addr;
      real_in_reg <= real_in;
      imag_in_reg <= imag_in;
    end if;
  end process;

  out_valid <= (wr_enable_reg and rd_valid_dd) when between_datasets = '0' or in_valid = '1' else
               (rd_enable_reg and rd_valid_dd);

  processing <= processing_while_write OR rd_valid;

  between_datasets_p : PROCESS (clk, reset)
  BEGIN
    IF reset = '1' THEN
      between_datasets <= '0';
    ELSIF rising_edge(clk) THEN
      IF wr_enable = '1' THEN
        IF (unsigned(wr_addr) = unsigned(length) - 1) AND in_valid = '1' THEN
          between_datasets <= '1';
        ELSIF in_valid = '1' THEN
          between_datasets <= '0';
        END IF;
      END IF;
    END IF;
  END PROCESS between_datasets_p;

  rd_valid_p : process (clk, reset)
  begin 
    if reset = '1' then
      rd_valid <= '0';
    elsif rising_edge(clk) then
      if wr_enable = '1' then
        if unsigned(wr_addr) = unsigned(length) - 1 then
          rd_valid <= '1';
        end if;
      end if;
      if rd_enable = '1' then
        if unsigned(rd_addr) = unsigned(length) - 1 and
          unsigned(wr_addr) /= unsigned(length) - 1 then
          rd_valid <= '0';
        end if;
      end if;
    end if;
  end process rd_valid_p;


  delay_p : PROCESS (clk, reset)
  BEGIN
    IF reset = '1' THEN
      out_stall_d <= '0';
      rd_valid_d  <= '0';
      rd_valid_dd <= '0';
    ELSIF rising_edge(clk) THEN
      out_stall_d <= out_stall;
      IF rd_enable = '1' THEN
        rd_valid_d  <= rd_valid;
        rd_valid_dd <= rd_valid_d;
      END IF;
    END IF;
  END PROCESS delay_p;

  write_processing_p : PROCESS (clk, reset)
  BEGIN  
    IF reset = '1' THEN
      processing_while_write <= '0';
    ELSIF rising_edge(clk) THEN
      IF wr_enable = '1' THEN
        IF unsigned(wr_addr) = unsigned(length) - 1 THEN
          processing_while_write <= '0';
        ELSE
          processing_while_write <= '1';
        END IF;
      END IF;
    END IF;
  END PROCESS write_processing_p;


  rvsct_rd: apn_fftfp_rvsctl
  GENERIC MAP (pointswidth=>pointswidth,read_addr_gen=>true)
  PORT MAP (sysclk=>clk,reset=>reset,enable=>rd_enable,
            validin=>rd_valid,
            length=>length,
            address=>rd_addr);

  rvsct_wr: apn_fftfp_rvsctl
  GENERIC MAP (pointswidth=>pointswidth)
  PORT MAP (sysclk=>clk,reset=>reset,enable=>wr_enable,
            validin=>in_valid,
            length=>length,
            address=>wr_addr);
            
  rvsram: apn_fftfp_ram 
  GENERIC MAP (device_family=>device_family, addwidth=>pointswidth)
  PORT MAP (sysclk=>clk,
            read=>rd_enable,
            readaddress=>rd_addr,
            writeaddress=>wr_addr_reg,
            write=>wr_enable_reg,
            system_enable=>ram_system_enable,
            real_in=>real_in_reg,imag_in=>imag_in_reg,    
            real_out=>real_out,imag_out=>imag_out);

END rtl;

