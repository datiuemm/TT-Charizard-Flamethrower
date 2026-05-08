LIB=/home/datiuemm/tt-char/vn-demo/sky130_fd_sc_hd__tt_025C_1v80.lib

yosys -p "
read_verilog $*;
hierarchy -top tt_um_datdt_charizard;
synth -top tt_um_datdt_charizard;
flatten;
opt -full;
opt_clean;
freduce;
dfflibmap -liberty $LIB;
abc -liberty $LIB;
clean;
opt -full;
abc -liberty $LIB;
stat -liberty $LIB;
write_verilog reduced_sky130.v
"
