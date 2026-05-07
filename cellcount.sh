LIB=/home/datiuemm/tt-char/vn-demo/sky130_fd_sc_hd__tt_025C_1v80.lib

yosys -p "read_verilog $*; flatten; synth; opt -full; opt_clean; dfflibmap -liberty $LIB; abc -liberty $LIB; clean; opt -full; abc -liberty $LIB; ltp; stat"
