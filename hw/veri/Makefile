include verilate_ips.mk
include verilate_rtl.mk

run: verilated/Vsim_ibex
	cd verilated; HWPE_TB_STIM_INSTR=../../../build/sw/tb_hwpe.c/stim_instr.txt HWPE_TB_STIM_DATA=../../../build/sw/tb_hwpe.c/stim_data.txt ./Vsim_ibex; cd -

all: verilated/Vsim_ibex

verilated/Vsim_ibex: verilated/Vsim_ibex.mk
	make OPT_FAST="-O3 -fno-stack-protector" OPT_SLOW="-O2 -fno-stack-protector" -C verilated -f Vsim_ibex.mk Vsim_ibex

verilated/Vsim_ibex.mk:
	verilator -O3 -cc -Wno-fatal --exe ../sim_main.cpp --Mdir verilated \
        --trace --trace-structs --trace-params \
        --autoflush \
        --Wno-width \
        --Wno-stmtdly \
        --Wno-unoptflat \
        --top-module sim_ibex -Wno-BLKANDNBLK \
        ${INC_IPS} \
        ${INC_RTL} \
        ${SRC_IPS} \
        ${SRC_RTL}

clean:
	rm -rf verilated

