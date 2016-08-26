GHDL = ghdl
TARGET = I2C_slave_TB

RM = rm -rf
mainEntity = $(TARGET)
SIM_DIR = ./sim
MKDIR_P = mkdir -p

all: $(TARGET).vhd
	$(MKDIR_P) $(SIM_DIR)
	cp *.vhd $(SIM_DIR)
	cd $(SIM_DIR) && $(GHDL) -i *.vhd && $(GHDL) -m $(mainEntity) ; \
	   $(GHDL) -r $(TARGET)  --stop-delta=10 --wave=./$(TARGET).ghw ; 

.PHONY: clean
clean:
	$(RM) $(SIM_DIR)/*.vhd
	$(RM) $(SIM_DIR)/*.ghw
	$(RM) $(SIM_DIR)/*.cf
