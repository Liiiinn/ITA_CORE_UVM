SHELL := /usr/bin/env bash

SIM_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
TEST ?= ita_mha8_base_test
OUTPUT_DIR ?= $(SIM_DIR)/output
WORK_DIR ?= $(OUTPUT_DIR)/work
LOG_DIR ?= $(OUTPUT_DIR)/logs
VLIB ?= vlib
VMAP ?= vmap
VLOG ?= vlog
VSIM ?= vsim

UVM_COMPILE_ARGS :=
ifneq ($(strip $(UVM_HOME)),)
UVM_COMPILE_ARGS += +incdir+$(UVM_HOME)/src $(UVM_HOME)/src/uvm_pkg.sv
endif

.PHONY: compile smoke clean

compile: $(WORK_DIR)
	@$(VLIB) $(WORK_DIR)
	@$(VMAP) work $(WORK_DIR)
	@cd $(SIM_DIR) && $(VLOG) -sv -work work +acc $(UVM_COMPILE_ARGS) -f filelist.f

smoke: compile $(LOG_DIR)
	@cd $(SIM_DIR) && $(VSIM) -c -lib work ita_mha8_tb_top \
		+UVM_TESTNAME=$(TEST) \
		-do "run -all; quit -f" \
		-l $(LOG_DIR)/$(TEST).log

clean:
	@rm -rf $(OUTPUT_DIR)

$(WORK_DIR):
	@mkdir -p $(WORK_DIR)

$(LOG_DIR):
	@mkdir -p $(LOG_DIR)
