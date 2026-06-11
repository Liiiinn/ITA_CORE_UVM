---
name: uvm-dv
description: "Use for SystemVerilog UVM design verification tasks: generating UVM agents, environments, sequences, scoreboards, coverage, testplans, compile fixes, and regression triage. Do not use for RTL implementation unless explicitly requested."
---

# UVM DV Skill

## Purpose

Create, modify, review, and debug UVM/SystemVerilog verification code using the repository's package-based `.sv`/`.svh` architecture.

## Required workflow

### 0. Start in Plan Mode

For every UVM/DV task, do not begin coding immediately.

- Enter Plan Mode first. If the environment cannot literally switch modes, perform an equivalent read-only planning phase.
- Inspect only the files and project context needed to understand the request.
- Produce a task-specific plan that names the intended files, dependency order, commands to run, assumptions, and open questions.
- Wait for the user to confirm the plan before editing files, generating UVM code, updating filelists, or starting compile-fix iterations.
- If the user revises the request before confirming, update the plan and wait for confirmation again.

### 1. Inspect before editing

Before writing UVM code:

- Read the DUT module ports.
- Identify clocks, resets, valid/ready or request/ack handshakes.
- Locate existing interfaces, agents, packages, tests, filelists, and build targets.
- Check existing naming conventions before creating new files.
- Do not assume protocol timing if it is not present in RTL, documentation, or existing tests.

### 2. Produce a short verification plan

Before generating large UVM code, include a compact verification plan in the user-confirmed plan containing:

- DUT or interface under verification
- transaction fields
- legal stimulus
- illegal or error stimulus
- reset behavior
- monitor sampling rule
- scoreboard comparison rule
- functional coverage points
- initial directed tests
- assumptions and open questions

### 3. Generate code incrementally

Only after the user confirms the plan, generate files in dependency order:

1. interface
2. sequence item
3. config object
4. sequencer
5. driver
6. monitor
7. agent
8. reference model
9. scoreboard
10. coverage collector
11. environment
12. base sequence
13. directed/random sequences
14. base test
15. specific tests
16. top-level testbench
17. filelist updates

### 4. Follow package-based architecture

- UVM classes must be `.svh`.
- Packages must be `.sv`.
- Interfaces and top modules must be `.sv`.
- Do not compile `.svh` files directly.
- Include `.svh` class files from package `.sv` files.
- Add include guards to every `.svh`.
- Update package include order when adding a class.
- Update filelists when adding package, interface, assertion, top, or RTL files.

### 5. Code readability and formatting rules

- Generate SystemVerilog and UVM code with 4-space indentation only.
- Do not use tabs or 2-space indentation in generated source files.
- Prefer readable line breaks over compact one-line code.
- Do not place multiple statements on one line.
- Expand compact constructors such as `function new(...); super.new(...); endfunction` into separate lines.
- Write `if`, `begin/end`, factory `create`, `connect`, `uvm_config_db`, and UVM report calls in a readable expanded style.
- Do not use compact multi-statement blocks such as `begin stmt1; stmt2; end`.
- Use named scope endings for generated functions, tasks, classes, sequences, and components, such as `endfunction : build_phase` and `endclass : spi_apb_env`.
- In `build_phase`, set child configuration through `uvm_config_db::set` before creating the corresponding agent or component.
- Use the build order: get environment config, set or dispatch child configs, create agents and components, then create scoreboard, coverage, reference model, or other environment-level components.
- Do not generate compact UVM component implementations.
- Prefer the readable expanded style shown in the recommended templates, while preserving the same functional behavior.
- Keep source files concise. Use short comments to describe component responsibilities and connection relationships, but do not insert large tutorial-style comments into source code.
- Do not insert large separator comment blocks between UVM phases, such as repeated `//--------------------------------------------------------------------------` banners before every constructor, `build_phase`, or `connect_phase`.
- Full code templates and formatting examples should be maintained in this guideline or a dedicated template file rather than duplicated in every source file.
- When generating a new agent, environment, scoreboard, coverage component, sequence, or sequence item, follow the same naming, indentation, phase structure, `uvm_config_db` usage, factory creation style, and TLM connection style across the verification environment.

Recommended short agent header comment format:

```systemverilog
// APB Master Agent
//
// Components:
//   - apb_master_sequencer
//   - apb_master_driver
//   - apb_master_monitor
//
// Active mode:
//   - Builds sequencer, driver, and monitor
//   - Connects sequencer to driver
//
// Passive mode:
//   - Builds monitor only
//
// Analysis:
//   - Monitor publishes observed APB transactions through the analysis port
```

Recommended agent template:

```systemverilog
`ifndef XXX_AGENT_SVH
`define XXX_AGENT_SVH

class xxx_agent extends uvm_agent;
    `uvm_component_utils(xxx_agent)

    xxx_agent_config cfg;

    xxx_sequencer sqr;
    xxx_driver    drv;
    xxx_monitor   mon;

    function new(string name = "xxx_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(xxx_agent_config)::get(this, "", "cfg", cfg)) begin
            `uvm_fatal("AGT_CFG", "xxx_agent_config was not set")
        end

        mon = xxx_monitor::type_id::create("mon", this);

        if (cfg.is_active == UVM_ACTIVE) begin
            sqr = xxx_sequencer::type_id::create("sqr", this);
            drv = xxx_driver::type_id::create("drv", this);
        end
    endfunction : build_phase

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        if (cfg.is_active == UVM_ACTIVE) begin
            drv.seq_item_port.connect(sqr.seq_item_export);
        end
    endfunction : connect_phase
endclass : xxx_agent

`endif // XXX_AGENT_SVH
```

Recommended environment template:

```systemverilog
`ifndef XXX_ENV_SVH
`define XXX_ENV_SVH

class xxx_env extends uvm_env;
    `uvm_component_utils(xxx_env)

    xxx_env_config cfg;

    xxx_master_agent mst_agt;
    xxx_slave_agent  slv_agt;

    xxx_ref_model  ref_model;
    xxx_scoreboard scb;
    xxx_coverage   cov;

    function new(string name = "xxx_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(xxx_env_config)::get(this, "", "cfg", cfg)) begin
            `uvm_fatal("ENV_CFG", "xxx_env_config was not set")
        end

        uvm_config_db#(xxx_master_config)::set(this, "mst_agt", "cfg", cfg.mst_cfg);

        uvm_config_db#(xxx_slave_config)::set(this, "slv_agt", "cfg", cfg.slv_cfg);

        mst_agt = xxx_master_agent::type_id::create("mst_agt", this);
        slv_agt = xxx_slave_agent::type_id::create("slv_agt", this);

        ref_model = xxx_ref_model::type_id::create("ref_model", this);

        if (cfg.has_scoreboard) begin
            scb = xxx_scoreboard::type_id::create("scb", this);
        end

        if (cfg.has_coverage) begin
            cov = xxx_coverage::type_id::create("cov", this);
        end
    endfunction : build_phase

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        mst_agt.ap.connect(ref_model.mst_imp);

        if (scb != null) begin
            ref_model.expected_ap.connect(scb.expected_fifo.analysis_export);
            slv_agt.ap.connect(scb.actual_fifo.analysis_export);
        end

        if (cov != null) begin
            mst_agt.ap.connect(cov.mst_imp);
            slv_agt.ap.connect(cov.slv_imp);
        end
    endfunction : connect_phase
endclass : xxx_env

`endif // XXX_ENV_SVH
```

### 6. Driver rules

- Drive only through the virtual interface.
- Handle reset explicitly.
- Obey valid/ready or request/ack timing.
- Do not invent protocol timing.
- If timing is ambiguous, encode the assumption in comments and in the testplan.

### 7. Monitor rules

- Monitors must be passive.
- Sample only interface-visible behavior.
- Convert pin-level activity into transactions.
- Publish transactions through analysis ports.
- Do not depend on driver or sequence internals.

### 8. Scoreboard rules

- Keep reference-model logic separate from scoreboard plumbing.
- Implement the reference model as a separate UVM component, not as an internal object queried by the scoreboard.
- The reference model receives observed or input transactions through analysis connections.
- The reference model publishes expected transactions through its own analysis port, such as `expected_ap`.
- The scoreboard must not directly access, query, or depend on the reference model's internal state.
- The scoreboard must compare two independent analysis streams: expected transactions from the reference model and actual transactions from the DUT or output monitor.
- Prefer `uvm_tlm_analysis_fifo` for both scoreboard streams, such as `expected_fifo` and `actual_fifo`.
- Connect the reference model expected analysis port to `scoreboard.expected_fifo.analysis_export`.
- Connect the DUT or output monitor analysis port to `scoreboard.actual_fifo.analysis_export`.
- The scoreboard comparison loop should read from `expected_fifo` and `actual_fifo`, then compare transaction contents.
- Keep prediction logic inside the reference model.
- Keep comparison, mismatch reporting, and pass/fail accounting inside the scoreboard.
- Do not store a `ref_model` handle in the scoreboard unless it is only used for construction-time connectivity diagnostics and never for reading expected data.
- Report mismatches with expected value, actual value, transaction context, simulation time, test name, and seed when available.
- Do not suppress mismatches to make regressions pass.

### 9. Simulation script generation rules

- Always keep `sim/Makefile` when generating or updating simulation flow.
- Detect the target execution environment before generating simulation scripts.
- For Windows environments, generate PowerShell scripts under `sim/scripts/`.
- Windows `.ps1` scripts must call Questa commands such as `vlib`, `vmap`, `vlog`, `vopt`, `vsim`, and `vcover` directly.
- Windows `.ps1` scripts must not call or depend on `make`, `make -C sim`, or `sim/Makefile`.
- For Linux environments, generate shell scripts under `sim/scripts/`.
- Linux `.sh` scripts should invoke the corresponding `sim/Makefile` targets, such as `make -C sim compile`, `make -C sim smoke`, `make -C sim regression`, and `make -C sim clean`.
- When adding or changing simulation flow, update `sim/Makefile` and the relevant OS-specific scripts under `sim/scripts/`.
- For Questa waveform debug, enable WLF output only when explicitly requested.
- When waveform output is requested, use `vsim -wlf sim/output/waves/<test>_<seed>.wlf` and record signals with `log -r /*` or `do wave.do`.
- Store all WLF files under `sim/output/waves/`.
- Do not enable full waveform dumping by default for regression unless the user explicitly requests waveform debug.

Recommended Windows single-test PS1 template:

```powershell
param(
  [string]$Root = (Resolve-Path "$PSScriptRoot\..\..").Path,
  [string]$Test = "xxx_smoke_test",
  [int]$Seed = 1,
  [switch]$Wave
)

$sim = Join-Path $Root "sim"

$logRoot = Join-Path $sim "output\logs"
$waveRoot = Join-Path $sim "output\waves"
$covRunRoot = Join-Path $sim "cov\runs"

New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
New-Item -ItemType Directory -Force -Path $waveRoot | Out-Null
New-Item -ItemType Directory -Force -Path $covRunRoot | Out-Null

& (Join-Path $PSScriptRoot "compile.ps1") -Root $Root
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

Push-Location $sim
try {
  $caseName = "${Test}_${Seed}"

  $ucdb = "cov/runs/${caseName}.ucdb"
  $log  = Join-Path $logRoot "$caseName.log"
  $wlf  = Join-Path $waveRoot "$caseName.wlf"

  if ($Wave) {
    $doCmd = "log -r /*; coverage save -onexit $ucdb; run -all; quit -f"

    vsim -c -coverage work.xxx_tb_top `
      +UVM_TESTNAME=$Test `
      +UVM_NO_RELNOTES `
      -sv_seed $Seed `
      -wlf $wlf `
      -l $log `
      -do $doCmd
  }
  else {
    $doCmd = "coverage save -onexit $ucdb; run -all; quit -f"

    vsim -c -coverage work.xxx_tb_top `
      +UVM_TESTNAME=$Test `
      +UVM_NO_RELNOTES `
      -sv_seed $Seed `
      -l $log `
      -do $doCmd
  }

  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
}
finally {
  Pop-Location
}
```

- Replace `xxx_smoke_test` and `work.xxx_tb_top` with the generated project's base test and top-level testbench.
- Use this template for Windows base-test or smoke scripts; regression scripts may iterate over tests and seeds but should keep the same root, output directory, compile, `vsim`, log, optional wave, and per-case UCDB conventions.

### 10. Coverage rules

- Cover behavior defined by the testplan.
- Include reset, boundary, backpressure, error, and cross coverage when meaningful.
- Do not claim coverage closure without actual coverage reports.
- When generating sim/scripts/regression.ps1, save one UCDB per executed regression case.
- Place per-test regression UCDB files under sim/cov/runs/ or another clean per-run subdirectory under sim/cov/.
- Merge only the per-test UCDB files produced by the current regression run.
- Do not merge logs, HTML reports, work/, transcript files, WLF files, debug databases, stale UCDBs, or already merged UCDBs.
- Merge the current regression UCDB files into one integrated UCDB with vcover merge.
- Place the merged regression UCDB under sim/cov/, for example sim/cov/regression_merged.ucdb.
- Generate the integrated HTML coverage report from the merged UCDB with vcover report -html.
- Place the integrated HTML report under sim/covhtmlreport/.
- Do not generate separate final HTML reports from individual test UCDBs unless explicitly requested.

### 11. Compile and repair

After plan confirmation and editing:

- Run the narrowest available compile target.
- Fix syntax, import, package, include, factory, config_db, and filelist errors.
- After creating a new UVM framework, run exactly one base test to catch basic framework issues.
- On Windows, use the generated `.ps1` base-test or smoke script that calls Questa directly.
- On Linux, use the generated `.sh` script or `make -C sim smoke` only when that target is configured to run the base test; otherwise use the repository's base-test command.
- Do not run a full regression for initial framework validation unless the user explicitly asks.
- Summarize commands run and remaining risks.

## Prohibited behavior

- Do not silently modify RTL.
- Do not claim verification success without logs.
- Do not remove assertions, coverage, or scoreboard checks to make tests pass.
- Do not replace protocol-specific timing with generic UVM boilerplate.

