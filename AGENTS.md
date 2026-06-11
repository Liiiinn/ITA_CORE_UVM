# AGENTS.md

## Project scope

This repository contains synthesizable RTL and UVM/SystemVerilog DV code. If a required path does not exist for the requested task, create it using the project structure below. Use the `uvm-dv` skill if applicable.

## Project startup behavior

Before making changes, Codex must inspect the repository structure and relevant project instructions.

Every task must start with a planning gate:

* Do not write code, generate source files, edit files, or run repair loops immediately.
* Enter Plan Mode first. If the current environment cannot literally switch modes, behave as a read-only planning phase and tell the user that edits are waiting for confirmation.
* Use only read-only inspection while preparing the plan.
* Produce a task-specific plan based on the user's request and the inspected project context.
* Wait for the user to confirm the plan before editing files, generating code, running compile-fix iterations, or making other source changes.
* If the user changes the request before confirming, revise the plan and wait for confirmation again.

At the start of a new task, inspect:

* root `AGENTS.md`
* nested `AGENTS.md` files
* `.agents/skills/`
* `dut/` RTL structure
* `tb/` UVM testbench structure
* `sim/` Makefile, filelists, scripts, and generated-output layout
* Questa, PowerShell, and shell simulation scripts
* SystemVerilog packages
* top-level testbench files

Before editing files, summarize:

1. detected project structure
2. active testbench root
3. compile, smoke, regression, and clean commands
4. package and filelist organization
5. missing or ambiguous setup items

Do not generate or edit files until the structure and intended next task are clear.
Do not generate or edit files until the task-specific plan has also been confirmed by the user.

## Repository layout

* `dut/`: synthesizable RTL source files.
* `tb/`: UVM/SystemVerilog verification source code.
* `tb/if/`: testbench interfaces.
* `tb/agents/`: reusable UVM agents.
* `tb/env/`: block-level UVM environment and environment configuration.
* `tb/top/`: top-level testbench module.
* `tb/seq/`: reusable UVM sequences and virtual sequences.
* `tb/scb/`: scoreboards and reference models.
* `tb/cov/`: functional coverage models.
* `tb/tests/`: UVM tests.
* `sim/`: Questa simulation entry point, Makefile, filelists, case lists, scripts, logs, work libraries, coverage output, waves, and generated simulation artifacts.
* `sim/scripts/`: OS-specific execution helpers for compile, smoke, regression, and clean flows.
* `docs/`: human-readable verification documentation.
* `.agents/skills/`: Codex task-specific skills.

## Required behavior for Codex

* Start every task in Plan Mode or an equivalent read-only planning phase, then wait for user confirmation before source edits.
* Do not modify RTL under `dut/` unless the user explicitly asks.
* For verification tasks, prefer adding or editing files under `tb/` and `sim/`.
* Before generating UVM code, inspect the DUT ports, clocking, reset behavior, interface timing, packages, top-level testbench, and existing `sim/filelist.f`.
* After creating a UVM framework, run only one base test to check for basic framework issues. Do not run a full regression unless the user explicitly asks.
* Reuse existing project conventions before creating new structure.
* Never claim verification success unless compile, simulation, or regression logs were actually run and inspected.
* If a command cannot be run, state that explicitly.

## Build and test commands

Keep `sim/Makefile` as the portable Linux-oriented build entry point.

* Linux compile: `make -C sim compile`
* Linux base-test check for a newly-created framework: `make -C sim smoke` or the repository's configured base-test target
* Linux smoke test: `make -C sim smoke`
* Linux regression: `make -C sim regression`
* Linux clean: `make -C sim clean`
* Windows compile, smoke, regression, and clean flows should use the generated `.ps1` scripts that call Questa directly.

## Questa execution rules

* Always keep `sim/Makefile` when generating or updating simulation flow.
* Before generating simulation scripts, determine the target execution environment. 
* If the user explicitly specifies the environment, use the specified environment directly. 
* If the user does not specify one, detect the current environment first and then choose the appropriate script style.
* For Windows environments, generate PowerShell scripts under `sim/scripts/`.
* Windows `.ps1` scripts must call Questa commands such as `vlib`, `vmap`, `vlog`, `vopt`, `vsim`, and `vcover` directly.
* Windows `.ps1` scripts must not call or depend on `make`, `make -C sim`, or `sim/Makefile`.
* For Linux environments, generate shell scripts under `sim/scripts/`.
* Linux `.sh` scripts should invoke the corresponding `sim/Makefile` targets, such as `make -C sim compile`, `make -C sim smoke`, `make -C sim regression`, and `make -C sim clean`.
* Place all Questa-generated outputs under `sim/`.
* Questa-generated outputs include `cov/`, `logs/`, `work/`, `covhtmlreport/`, `transcript`, WLF files, debug databases, and temporary simulation artifacts.
* Do not place generated Questa outputs under `tb/` or `dut/`.
* For Questa waveform debug, enable WLF output only when explicitly requested.
* When waveform output is requested, use `vsim -wlf sim/output/waves/<test>_<seed>.wlf` and record signals with `log -r /*` or `do wave.do`.
* Store all WLF files under `sim/output/waves/`.
* Do not enable full waveform dumping by default for regression unless the user explicitly requests waveform debug.
* When generating `sim/scripts/regression.ps1`, collect only coverage UCDB files for coverage merging.
* The generated regression script must merge coverage UCDBs into one integrated UCDB with `vcover merge`.
* After merging UCDBs, generate one integrated detailed HTML coverage report from the merged UCDB with `vcover report -html -details`.
* Write the merged UCDB under `sim/cov/` and the integrated HTML report under `sim/covhtmlreport/`.
* Do not generate separate final HTML coverage reports from individual test UCDBs unless the user explicitly asks.

## SystemVerilog file conventions

* Use `.sv` for RTL modules, packages, interfaces, top-level modules, assertions, and bind files.
* Use `.svh` for UVM classes and components.
* Do not compile `.svh` files directly.
* UVM class `.svh` files must be included from package `.sv` files.
* Update package include order and `sim/filelist.f` together.

## Code generation formatting rules

* Generate SystemVerilog and UVM code with 4-space indentation only.
* Do not use tabs or 2-space indentation in generated source files.
* Prefer readable line breaks over compact one-line code.
* Do not place multiple statements on one line.
* Expand compact constructors such as `function new(...); super.new(...); endfunction` into separate lines.
* Write `if`, `begin/end`, factory `create`, `connect`, `uvm_config_db`, and UVM report calls in a readable expanded style.
* Do not use compact multi-statement blocks such as `begin stmt1; stmt2; end`.
* Use named scope endings for generated functions, tasks, classes, sequences, and components, such as `endfunction : build_phase` and `endclass : spi_apb_env`.
* In `build_phase`, set child configuration through `uvm_config_db::set` before creating the corresponding agent or component.
* Use the build order: get environment config, set or dispatch child configs, create agents and components, then create scoreboard, coverage, reference model, or other environment-level components.
* Do not generate the compact style shown by `D:\UNI2\UVM\.v_uvm_spi_apb\tb\env\spi_apb_env.svh`.
* Prefer the readable expanded style shown by `D:\UNI2\UVM\.v_uvm_spi_apb\tb\env\spi_apb_env copy.svh`, while preserving the same functional behavior.

## UVM conventions

* Use `uvm_component_utils` for UVM components.
* Use `uvm_object_utils` for UVM objects and sequence items.
* Use `uvm_config_db` for virtual interface and configuration object passing.
* Keep drivers active and monitors passive.
* Prefer transaction-level scoreboarding through analysis ports.
* Do not use wildcard `uvm_config_db` paths unless already used consistently in this repository.

## Reference model and scoreboard architecture

* Implement the reference model as a separate UVM component.
* The scoreboard must not directly access, query, or depend on the reference model's internal state.
* The reference model must receive observed or input transactions through analysis connections.
* The reference model must publish expected transactions through its own analysis port.
* The scoreboard must compare two independent analysis streams: expected transactions from the reference model and actual transactions from the DUT or output monitor.
* Prefer `uvm_tlm_analysis_fifo` for both scoreboard streams, such as `expected_fifo` and `actual_fifo`.
* The scoreboard comparison loop should read one transaction from `expected_fifo` and one transaction from `actual_fifo`, then compare their contents.
* Keep prediction logic inside the reference model.
* Keep comparison, mismatch reporting, and pass/fail accounting inside the scoreboard.
* Do not store a `ref_model` handle in the scoreboard unless it is only used for construction-time connectivity diagnostics and never for reading expected data.

## Package and compile rules

* Compile package `.sv` files, interfaces, top modules, assertions, bind files, and RTL modules.
* Do not compile UVM class `.svh` files directly.
* Add include directories for folders containing `.svh` files.
* Add only package `.sv` files to `sim/filelist.f`.
* Keep package include order consistent with class dependencies.
* Avoid circular package dependencies.
* If shared transaction types are needed by multiple packages, create or reuse a lower-level common package instead of importing a higher-level environment or test package.

## Generated file rules

* Do not create duplicate agents, environments, scoreboards, coverage components, or tests if equivalent code already exists.
* Do not place generated output, logs, waves, work libraries, coverage databases, or build artifacts under source directories.
* Do not remove assertions, coverage, or scoreboard checks to make a test pass.
* Do not patch RTL to satisfy a DV failure unless the user explicitly asks for RTL debugging.
* When adding UVM source files, update the relevant package `.sv` file and `sim/filelist.f`.
* When adding or changing simulation flow, update `sim/Makefile` and the relevant OS-specific scripts under `sim/scripts/`.
