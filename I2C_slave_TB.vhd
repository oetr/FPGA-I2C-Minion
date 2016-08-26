-----------------------------------------------------------------------------
-- Title      : I2C_slave Testbench
-----------------------------------------------------------------------------
-- File       : I2C_slave_TB
-- Author     : Peter Samarin <peter.samarin@gmail.com>
-----------------------------------------------------------------------------
-- Copyright (c) 2016 Peter Samarin
-----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.txt_util.all;
use ieee.math_real.all;  -- using uniform(seed1,seed2,rand)
------------------------------------------------------------------------
entity I2C_slave_TB is
end I2C_slave_TB;
------------------------------------------------------------------------
architecture Testbench of I2C_slave_TB is
  constant T         : time    := 20 ns;   -- clk period
  constant T_spike   : time    := 1 ns;
  constant TH_I2C    : time    := 100 ns;  -- i2c clk quarter period(kbis)
  constant T_MUL     : integer := 2;  -- i2c clk quarter period(kbis)
  constant T_HALF    : integer := (TH_I2C*T_MUL*2) / T;  -- i2c halfclk period
  constant T_QUARTER : integer := (TH_I2C*T_MUL) / T;  -- i2c quarterclk period

  signal scl                  : std_logic                    := '1';
  signal sda                  : std_logic                    := '1';
  signal scl_pre_spike        : std_logic                    := '1';
  signal sda_pre_spike        : std_logic                    := '1';
  signal clk_test             : std_logic                    := '1';
  signal rst_test             : std_logic                    := '1';
  signal state_dbg            : integer                      := 0;
  signal received_data        : std_logic_vector(7 downto 0) := (others => '0');
  signal ack                  : std_logic                    := '0';
  signal read_req             : std_logic                    := '0';
  signal data_to_master       : std_logic_vector(7 downto 0) := (others => '0');
  signal data_valid           : std_logic                    := '0';
  signal data_from_master     : std_logic_vector(7 downto 0) := (others => '0');
  signal data_from_master_reg : std_logic_vector(7 downto 0) := (others => '0');

  -- random spike generation
  constant MAX_SPIKE_DURATION      : real      := 30000.0;  -- 50ns
  constant MAX_TIMEOUT_AFTER_SPIKE : real      := 10000.0;  -- 10ns
  constant P_SPIKE                 : real      := 0.02;
  signal spike                     : std_logic := '0';

  shared variable seed1                   : positive := 1000;
  shared variable seed2                   : positive := 2000;
  shared variable rand_scl, rand_sda      : real;  -- random real-number value in range 0 to 1.0  
  shared variable scl_spike_duration      : integer  := 0;
  shared variable timeout_after_scl_spike : integer  := 0;
  shared variable scl_spike_should_happen : real     := 0.0;
  shared variable sda_spike_duration      : integer  := 0;
  shared variable timeout_after_sda_spike : integer  := 0;
  shared variable sda_spike_should_happen : real     := 0.0;

  -- simulation control
  shared variable SCL_noise_on : boolean := false;
  shared variable SDA_noise_on : boolean := false;
  shared variable ENDSIM       : boolean := false;
begin

  ---- Design Under Verification -----------------------------------------
  DUV : entity work.I2C_slave
    generic map (
      SLAVE_ADDR => "0000011")
    port map (
      -- I2C
      scl              => scl,
      sda              => sda,
      -- default signals
      clk              => clk_test,
      rst              => rst_test,
      -- user interface
      read_req         => read_req,
      data_to_master   => data_to_master,
      data_valid       => data_valid,
      data_from_master => data_from_master);

  ---- DUT clock running forever ----------------------------
  process
  begin
    if ENDSIM = false then
      clk_test <= '0';
      wait for T/2;
      clk_test <= '1';
      wait for T/2;
    else
      wait;
    end if;
  end process;

  ---- Reset asserted for T/2 ------------------------------
  rst_test <= '1', '0' after T/2;


  ---- SCL spike generator -------------------------
  process
  begin
    if ENDSIM = false then
      uniform(seed1, seed2, rand_scl);  -- generate random number
      scl_spike_should_happen := rand_scl;
      uniform(seed1, seed2, rand_scl);  -- generate random number
      scl_spike_duration      := integer(rand_scl*MAX_SPIKE_DURATION);
      uniform(seed1, seed2, rand_scl);  -- generate random number
      timeout_after_scl_spike := integer(rand_scl*MAX_TIMEOUT_AFTER_SPIKE);
      if SCL_noise_on then
        if scl_spike_should_happen < P_spike then
          scl <= not scl_pre_spike;
        else
          scl <= scl_pre_spike;
        end if;
      end if;
      wait for scl_spike_duration * 1 ps;
      scl <= scl_pre_spike;
      wait for timeout_after_scl_spike * 1 ps;
    else
      wait;
    end if;
  end process;


  ---- SDA spike generator -------------------------
  process
  begin
    if ENDSIM = false then
      uniform(seed1, seed2, rand_sda);  -- generate random number
      sda_spike_should_happen := rand_sda;
      uniform(seed1, seed2, rand_sda);  -- generate random number
      sda_spike_duration      := integer(rand_sda*MAX_SPIKE_DURATION);
      uniform(seed1, seed2, rand_sda);  -- generate random number
      timeout_after_sda_spike := integer(rand_sda*MAX_TIMEOUT_AFTER_SPIKE);
      if SDA_noise_on then
        if sda_spike_should_happen < P_spike then
          if sda_pre_spike = '1' or sda_pre_spike = '0' then
            sda <= not sda_pre_spike;
          end if;
        else
          sda <= sda_pre_spike;
        end if;
      end if;
      wait for sda_spike_duration * 1 ps;
      sda <= sda_pre_spike;
      wait for timeout_after_sda_spike * 1 ps;
    else
      wait;
    end if;
  end process;

----------------------------------------------------------
-- Save data received from the master in a register
----------------------------------------------------------
  process (clk_test) is
  begin
    if rising_edge(clk_test) then
      if data_valid = '1' then
        data_from_master_reg <= data_from_master;
      end if;
    end if;
  end process;

----- Test vector generation -------------------------------------------
  TESTS : process is
    -- half clock
    procedure i2c_wait_half_clock is
    begin
      for i in 0 to T_HALF loop
        wait until rising_edge(clk_test);
      end loop;
    end procedure i2c_wait_half_clock;

    -- quarter clock
    procedure i2c_wait_quarter_clock is
    begin
      for i in 0 to T_QUARTER loop
        wait until rising_edge(clk_test);
      end loop;
    end procedure i2c_wait_quarter_clock;

    -- Write Bit
    procedure i2c_send_bit (
      constant a_bit : in std_logic) is
    begin
      scl_pre_spike <= '0';
      sda_pre_spike <= a_bit;
      i2c_wait_quarter_clock;
      scl_pre_spike <= '1';
      i2c_wait_half_clock;
      scl_pre_spike <= '0';
      i2c_wait_quarter_clock;
    end procedure i2c_send_bit;

    -- Read Bit
    procedure i2c_receive_bit (
      variable a_bit : out std_logic) is
    begin
      scl_pre_spike <= '0';
      sda_pre_spike <= 'Z';
      i2c_wait_quarter_clock;
      scl_pre_spike <= '1';
      i2c_wait_quarter_clock;
      a_bit         := sda;
      i2c_wait_quarter_clock;
      scl_pre_spike <= '0';
      i2c_wait_quarter_clock;
    end procedure i2c_receive_bit;

    -- Write Byte
    procedure i2c_send_byte (
      constant a_byte : in std_logic_vector(7 downto 0)) is
    begin
      for i in 7 downto 0 loop
        i2c_send_bit(a_byte(i));
      end loop;
    end procedure i2c_send_byte;

    -- Address
    procedure i2c_send_address (
      constant address : in std_logic_vector(6 downto 0)) is
    begin
      for i in 6 downto 0 loop
        i2c_send_bit(address(i));
      end loop;
    end procedure i2c_send_address;

    -- Read Byte
    procedure i2c_receive_byte (
      signal a_byte : out std_logic_vector(7 downto 0)) is
      variable a_bit : std_logic;
      variable accu  : std_logic_vector(7 downto 0) := (others => '0');
    begin
      for i in 7 downto 0 loop
        i2c_receive_bit(a_bit);
        accu(i) := a_bit;
      end loop;
      a_byte <= accu;
    end procedure i2c_receive_byte;

    -- START
    procedure i2c_start is
    begin
      scl_pre_spike <= '1';
      sda_pre_spike <= '0';
      i2c_wait_half_clock;
      scl_pre_spike <= '1';
      i2c_wait_quarter_clock;
      scl_pre_spike <= '0';
      i2c_wait_quarter_clock;
    end procedure i2c_start;

    -- STOP
    procedure i2c_stop is
    begin
      scl_pre_spike <= '0';
      sda_pre_spike <= '0';
      i2c_wait_quarter_clock;
      scl_pre_spike <= '1';
      i2c_wait_quarter_clock;
      sda_pre_spike <= '1';
      i2c_wait_half_clock;
      i2c_wait_half_clock;
    end procedure i2c_stop;

    -- send write
    procedure i2c_set_write is
    begin
      i2c_send_bit('0');
    end procedure i2c_set_write;

    -- send read
    procedure i2c_set_read is
    begin
      i2c_send_bit('1');
    end procedure i2c_set_read;

    -- read ACK
    procedure i2c_read_ack (signal ack : out std_logic) is
    begin
      scl_pre_spike <= '0';
      sda_pre_spike <= 'Z';
      i2c_wait_quarter_clock;
      scl_pre_spike <= '1';
      if sda = '0' then
        ack <= '1';
      else
        ack <= '0';
        assert false report "No ACK received: expected '0'" severity note;
      end if;
      i2c_wait_half_clock;
      scl_pre_spike <= '0';
      i2c_wait_quarter_clock;
    end procedure i2c_read_ack;

    -- write NACK
    procedure i2c_write_nack is
    begin
      scl_pre_spike <= '0';
      sda_pre_spike <= '1';
      i2c_wait_quarter_clock;
      scl_pre_spike <= '1';
      i2c_wait_half_clock;
      scl_pre_spike <= '0';
      i2c_wait_quarter_clock;
    end procedure i2c_write_nack;

    -- write ACK
    procedure i2c_write_ack is
    begin
      scl_pre_spike <= '0';
      sda_pre_spike <= '0';
      i2c_wait_quarter_clock;
      scl_pre_spike <= '1';
      i2c_wait_half_clock;
      scl_pre_spike <= '0';
      i2c_wait_quarter_clock;
    end procedure i2c_write_ack;

    -- write to I2C bus
    procedure i2c_write (
      constant address : in std_logic_vector(6 downto 0);
      constant data    : in std_logic_vector(7 downto 0)) is
    begin
      state_dbg <= 0;
      i2c_start;
      state_dbg <= 1;
      i2c_send_address(address);
      state_dbg <= 2;
      i2c_set_write;
      state_dbg <= 3;
      -- dummy read ACK--don't care, because we are testing
      -- I2C slave
      i2c_read_ack(ack);
      if ack = '0' then
        state_dbg <= 6;
        i2c_stop;
        ack       <= '0';
        return;
      end if;
      state_dbg <= 4;
      i2c_send_byte(data);
      state_dbg <= 5;
      i2c_read_ack(ack);
      state_dbg <= 6;
      i2c_stop;
    end procedure i2c_write;

    -- write to I2C bus
    procedure i2c_quick_write (
      constant address : in std_logic_vector(6 downto 0);
      constant data    : in std_logic_vector(7 downto 0)) is
    begin
      state_dbg <= 0;
      i2c_start;
      state_dbg <= 1;
      i2c_send_address(address);
      state_dbg <= 2;
      i2c_set_write;
      state_dbg <= 3;
      -- dummy read ACK--don't care, because we are testing
      -- I2C slave
      i2c_read_ack(ack);
      if ack = '0' then
        state_dbg <= 6;
        i2c_stop;
        ack       <= '0';
        return;
      end if;
      state_dbg     <= 4;
      i2c_send_byte(data);
      state_dbg     <= 5;
      i2c_read_ack(ack);
      scl_pre_spike <= '0';
      sda_pre_spike <= '0';
      i2c_wait_quarter_clock;
      scl_pre_spike <= '1';
      sda_pre_spike <= '1';
      i2c_wait_quarter_clock;
    end procedure i2c_quick_write;

    -- read I2C bus
    procedure i2c_write_bytes (
      constant address   : in std_logic_vector(6 downto 0);
      constant nof_bytes : in integer range 0 to 1023) is
      variable data : std_logic_vector(7 downto 0) := (others => '0');
    begin
      state_dbg <= 0;
      i2c_start;
      state_dbg <= 1;
      i2c_send_address(address);
      state_dbg <= 2;
      i2c_set_write;
      state_dbg <= 3;
      i2c_read_ack(ack);
      if ack = '0' then
        i2c_stop;
        return;
      end if;
      ack <= '0';
      for i in 0 to nof_bytes-1 loop
        state_dbg <= 4;
        i2c_send_byte(std_logic_vector(to_unsigned(i, 8)));
        state_dbg <= 5;
        i2c_read_ack(ack);
        if ack = '0' then
          i2c_stop;
          return;
        end if;
        ack <= '0';
      end loop;
      state_dbg <= 6;
      i2c_stop;
    end procedure i2c_write_bytes;

    -- read from I2C bus
    procedure i2c_read (
      constant address : in  std_logic_vector(6 downto 0);
      signal data      : out std_logic_vector(7 downto 0)) is
    begin
      state_dbg <= 0;
      i2c_start;
      state_dbg <= 1;
      i2c_send_address(address);
      state_dbg <= 2;
      i2c_set_read;
      state_dbg <= 3;
      -- dummy read ACK--don't care, because we are testing
      -- I2C slave
      i2c_read_ack(ack);
      if ack = '0' then
        state_dbg <= 6;
        i2c_stop;
        return;
      end if;
      ack       <= '0';
      state_dbg <= 4;
      i2c_receive_byte(data);
      state_dbg <= 5;
      i2c_write_nack;
      state_dbg <= 6;
      i2c_stop;
    end procedure i2c_read;

    -- read from I2C bus
    procedure i2c_quick_read (
      constant address : in  std_logic_vector(6 downto 0);
      signal data      : out std_logic_vector(7 downto 0)) is
    begin
      state_dbg <= 0;
      i2c_start;
      state_dbg <= 1;
      i2c_send_address(address);
      state_dbg <= 2;
      i2c_set_read;
      state_dbg <= 3;
      -- dummy read ACK--don't care, because we are testing
      -- I2C slave
      i2c_read_ack(ack);
      if ack = '0' then
        state_dbg <= 6;
        i2c_stop;
        return;
      end if;
      ack           <= '0';
      state_dbg     <= 4;
      i2c_receive_byte(data);
      state_dbg     <= 5;
      i2c_write_nack;
      scl_pre_spike <= '0';
      sda_pre_spike <= '0';
      i2c_wait_quarter_clock;
      scl_pre_spike <= '1';
      sda_pre_spike <= '1';
      i2c_wait_quarter_clock;
    end procedure i2c_quick_read;


    -- read I2C bus
    procedure i2c_read_bytes (
      constant address   : in  std_logic_vector(6 downto 0);
      constant nof_bytes : in  integer range 0 to 1023;
      signal data        : out std_logic_vector(7 downto 0)) is
    begin
      state_dbg <= 0;
      i2c_start;
      state_dbg <= 1;
      i2c_send_address(address);
      state_dbg <= 2;
      i2c_set_read;
      state_dbg <= 3;
      i2c_read_ack(ack);
      if ack = '0' then
        state_dbg <= 6;
        i2c_stop;
        return;
      end if;
      for i in 0 to nof_bytes-1 loop
        -- dummy read ACK--don't care, because we are testing
        -- I2C slave
        state_dbg <= 4;
        i2c_receive_byte(data);
        state_dbg <= 5;
        if i < nof_bytes-1 then
          i2c_write_ack;
        else
          i2c_write_nack;
        end if;
      end loop;
      state_dbg <= 6;
      i2c_stop;
    end procedure i2c_read_bytes;
  begin
    --------------------------------------------------------
    -- Turn on noise on SCL
    --------------------------------------------------------
    SCL_noise_on := true;

    scl_pre_spike <= '1';
    sda_pre_spike <= '1';

    print("----------------- Testing a single write ------------------");
    i2c_write("0000011", "11111111");
    assert data_from_master_reg = "11111111"
      report "test: 0 not passed"
      severity warning;

    print("----------------- Testing a single write ------------------");
    i2c_write("0000011", "11111010");
    assert data_from_master_reg = "11111010"
      report "test: 0 not passed"
      severity warning;

    print("----------------- Testing repeated writes -----------------");
    wait until rising_edge(clk_test);
    for i in 0 to 127 loop
      i2c_write("0000011", std_logic_vector(to_unsigned(i, 8)));
      assert i = to_integer(unsigned(data_from_master_reg))
        report "writing test: " & integer'image(i) & " not passed"
        severity warning;
    end loop;

    print("----------------- Testing repeated reads ------------------");
    for i in 0 to 127 loop
      data_to_master <= std_logic_vector(to_unsigned(i, 8));
      i2c_read("0000011", received_data);
      assert i = to_integer(unsigned(received_data))
        report "reading test: " & integer'image(i) & " not passed" & "test"
        severity warning;
    end loop;

    --------------------------------------------------------
    -- Quick read/write
    --------------------------------------------------------
    print("----------------- Testing quick write --------------------");
    i2c_quick_write("0000011", "10101010");
    i2c_quick_write("0000011", "10101011");
    i2c_quick_write("0000011", "10101111");
    data_to_master <= std_logic_vector(to_unsigned(255, 8));
    i2c_quick_read("0000011", received_data);
    state_dbg      <= 6;
    i2c_stop;

    --------------------------------------------------------
    -- Reads, writes from wrong slave addresses
    -- this should cause some assertion notes (needs manual
    -- confirmation)
    --------------------------------------------------------
    print("----------------- Testing wrong addresses -----------------");
    print("***************** These tests should all fail *************");
    i2c_write_bytes("1000011", 100);
    i2c_read ("0000001", received_data);
    i2c_read_bytes ("0000010", 300, received_data);

    wait until rising_edge(clk_test);

    ENDSIM := true;
    wait;
  end process;
end Testbench;
