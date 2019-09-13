GHDL = ghdl
TARGET_001 = I2C_worker_TB_001_ideal
TARGET_002 = I2C_worker_TB_002_noisy_scl

RM = rm -rf
SIM_DIR = ./sim
MKDIR_P = mkdir -p

all: mkdir_and_copy target_001 target_002

mkdir_and_copy:
	$(MKDIR_P) $(SIM_DIR)
	cp *.vhd $(SIM_DIR)

target_001: $(TARGET_001).vhd
	cd $(SIM_DIR) && $(GHDL) -i *.vhd && $(GHDL) -m $(TARGET_001) ; \
		$(GHDL) -r  $(TARGET_001) --stop-delta=10 --wave=./$(TARGET_001).ghw ;

target_002: $(TARGET_002).vhd
	cd $(SIM_DIR) && $(GHDL) -i *.vhd && $(GHDL) -m $(TARGET_002) ; \
		$(GHDL) -r  $(TARGET_002) --stop-delta=50 --wave=./$(TARGET_002).ghw ;

.PHONY: clean
clean:
	$(RM) $(SIM_DIR)/*.vhd
	$(RM) $(SIM_DIR)/*.ghw
	$(RM) $(SIM_DIR)/*.cf
