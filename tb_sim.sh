SIM_DIR=./sim

# if the file doesn't exist, try to create folder
if [ ! -f $SIM_DIR ] ; then
    mkdir -p $SIM_DIR
fi

cd $SIM_DIR
rm *.vhd *.o *.cf

## Getting proper files from the main directory
cp ../*.vhd .

## Analyzing all vhdl files
ghdl -i *.vhd

## Simulating I2C_slave_TB
ghdl -m I2C_slave_TB
## Verilog structures only
##ghdl -r I2C_slave_TB --vcd=./I2C_slave.vcd
# Uncomment the following line if you want to see
# VHDL structures (arrays, states, etc.)
ghdl -r I2C_slave_TB --wave=./I2C_slave.ghw 
