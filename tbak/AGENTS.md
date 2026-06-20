## UVM package-based architecture

- UVM agents live under `tb/agents/<agent_name>/`.
- Each agent has one `<agent_name>_pkg.sv`.
- Each UVM class is placed in a separate `.svh` file.
- The package includes class files in dependency order:
  1. item
  2. config
  3. sequencer
  4. driver
  5. monitor
  6. agent
- Test, sequence, scoreboard, coverage, and environment code follow the same package-plus-svh pattern.

## Expected UVM structure for generated DV code

Use a package-based UVM structure. SystemVerilog `.sv` files should be used only for packages, interfaces, and top-level modules. UVM classes and components must be written as `.svh` files and included from the appropriate package.

When Codex creates a new UVM environment or agent, use this structure unless the existing repository already uses a different convention:

```text
tb/
  if/
    <block>_if.sv

  agents/
    <agent_name>/
      <agent_name>_pkg.sv
      <agent_name>_item.svh
      <agent_name>_config.svh
      <agent_name>_sequencer.svh
      <agent_name>_driver.svh
      <agent_name>_monitor.svh
      <agent_name>_agent.svh

  env/
    <block>_env_pkg.sv
    <block>_env_config.svh
    <block>_env.svh

  top/
    <block>_tb_top.sv

  seq/
      <block>_seq_pkg.sv
      <block>_base_seq.svh
      <block>_directed_seq.svh
      <block>_random_seq.svh

  scb/
      <block>_scb_pkg.sv
      <block>_ref_model.svh
      <block>_scoreboard.svh

  cov/
      <block>_cov_pkg.sv
      <block>_coverage.svh

  tests/
      <block>_test_pkg.sv
      <block>_base_test.svh
      <block>_smoke_test.svh
      <block>_directed_test.svh
      <block>_random_test.svh

sim/
    Makefile
    filelist.f
    filelist.f.bak
    caselist.txt
    scripts/
        compile.ps1
        smoke.ps1
        regression.ps1
        clean.ps1
```

## Package and include rules

* Do not compile UVM class `.svh` files directly.
* Compile only package `.sv` files, interfaces, top modules, RTL, and bind/assertion modules.
* Each package must include its own `.svh` class files in dependency order.
* Use include guards in every `.svh` file.
* Keep one primary UVM class per `.svh` file unless the existing codebase uses a different style.
* Do not place package declarations inside `.svh` files.
* Do not place UVM component class definitions directly in filelist entries.
* Update the relevant package and filelist whenever adding a new UVM class.

## Recommended package ordering

Compile packages in this order unless the repository already defines a different order:

1. Interface files
2. Agent packages
3. Scoreboard/reference-model packages
4. Coverage packages
5. Environment package
6. Sequence package
7. Test package
8. Top-level testbench module

## Example agent package pattern

```systemverilog
package <agent_name>_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  `include "<agent_name>_item.svh"
  `include "<agent_name>_config.svh"
  `include "<agent_name>_sequencer.svh"
  `include "<agent_name>_driver.svh"
  `include "<agent_name>_monitor.svh"
  `include "<agent_name>_agent.svh"

endpackage
```

## Example filelist pattern

```text
+incdir+/tb/agents/<agent_name>
+incdir+/tb/env
+incdir+/seq
+incdir+/scb
+incdir+/cov
+incdir+/tests

+incdir+/tb/if

tb/agents/<agent_name>/<agent_name>_pkg.sv
scb/<block>_sb_pkg.sv
cov/<block>_cov_pkg.sv
tb/env/<block>_env_pkg.sv
seq/<block>_seq_pkg.sv
tests/<block>_test_pkg.sv

tb/top/<block>_tb_top.sv
```

## Makefile and PowerShell script patterns
* For Questa UVM simulation tasks, use the Makefile as the unified entry point and use PS1 scripts only as Windows/Questa execution helpers.
* For Questa UVM simulation tasks, make sure PS1 scriptsplace all generated outputs, including cov, logs, work, covhtmlreport, transcript, WLF, and debug databases, under the block-local sim/output directory.

## Generated file rules

* New UVM class files must use `.svh`.
* New UVM package files must use `.sv`.
* New interfaces and top modules must use `.sv`.
* Never add `.svh` files directly to simulator filelists unless the existing repository explicitly does so.
* Prefer package imports over global includes.
* Avoid circular package dependencies. If two packages depend on each other, refactor shared types into a lower-level common package.
* If shared transaction types are needed by multiple agents or scoreboards, create a dedicated common package instead of importing a higher-level environment package.
