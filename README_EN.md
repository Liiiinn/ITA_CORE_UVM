# ITA MHA8 UVM Verification

Chinese version: [README.md](README.md)

## Project Overview

This project provides a SystemVerilog/UVM verification environment for the ITA (Integer Transformer Accelerator) MHA8 top level. The DUT contains eight attention heads, a head-sum path, and a feed-forward path. Its main computation stages include:

- Q/K/V projection
- QK and softmax
- AV
- Output Weight projection (OW)
- Feed-forward F1/F2
- Linear/MatMul
- SingleAttention

The verification environment uses a layered strategy:

- **Online UVM** checks the valid-ready protocol, transaction metadata, segment/beat counts, ordering, duplicate or missing traffic, X/Z values, reset behavior, and timeouts.
- **SVA** checks cycle-level protocol behavior and the stability of valid, payload, and metadata under backpressure.
- **Offline Python/PyITA** generates tensors, weights, biases, requantization parameters, and expected outputs, then compares the RTL actual outputs against the golden results.
- **Coverage** collects functional and assertion coverage, with optional DUT RTL code coverage.

The active verification code is under `tb/`. `tbbak/` is a legacy backup and is not compiled by `sim/filelist.f`.

## Directory Structure

```text
ITA_CORE_UVM/
|-- dut/                         # ITA/MHA8 RTL
|-- tb/
|   |-- agents/                  # Control and reusable stream agents
|   |-- common/                  # Scenario, core item, and step payload
|   |-- cov/                     # Functional coverage
|   |-- env/                     # Environment, env config, virtual sequencer
|   |-- if/                      # DUT interface and SVA
|   |-- log/                     # Actual CSV logger
|   |-- pred/                    # Structural predictor
|   |-- scb/                     # Structural scoreboard
|   |-- seq/                     # Leaf sequences
|   |-- tests/                   # UVM tests
|   |-- tools/                   # Python case/vector/compare tools
|   |-- top/                     # Testbench top
|   `-- vseq/                    # Virtual sequences
|-- sim/
|   |-- cases/                   # Regression manifests
|   |-- coverage/                # Code-coverage waiver records
|   |-- scripts/                 # Compile/smoke/regression scripts
|   |-- logger/                  # Generated CSV files and manifests
|   `-- output/                  # Logs, UCDB files, and reports
`-- tbbak/                       # Legacy backup
```

### Scenario and Tests

`ita_mha8_scenario_cfg` is the unified source of testcase intent and plusarg configuration. It stores vector paths, layer, activation, tile configuration, protocol-random settings, backpressure, timeout, coverage-target, and negative-fault parameters.

The base test creates the scenario, environment configuration, and environment, and provides the common vseq startup flow. Derived tests retain only their scenario defaults, vseq type, and vector-loading differences.

### Agents and Virtual Sequences

`ita_ctrl_agent` handles control transactions. `ita_stream_agent` is reused for the input, weight, bias, and output channels of all eight heads, as well as the sum and feed-forward streams.

`ita_mha8_vsequencer` stores the sequencer handles from all agents. `ita_mha8_vsequence::execute_core_job()` provides the common layer dispatch, control updates, stream sequencing, output-ready policy, and completion waits.

The protocol-random vseq generates multiple deterministic mini-jobs in one simulation and reuses the common job execution entry point.

### Predictor, Scoreboard, and SVA

The structural predictor derives the expected segments, beats, and legal metadata ranges from the control and tile configuration.

The scoreboard checks:

- Step/head/tile/inner/beat metadata
- Source/output segment counts
- Missing, duplicate, discontinuous, or out-of-order beats
- X/Z values, bias rules, reset aborts, and timeouts

SVA checks cycle-level behavior such as valid-ready handshakes, backpressure stability, control, tile configuration, and reset.

The scoreboard does not duplicate the complete attention, softmax, GELU, or quantization numerical model. Numerical correctness remains the responsibility of PyITA and the offline comparison flow.

## Regression Cases

`sim/cases/` currently contains:

| Manifest | Cases | Purpose |
|---|---:|---|
| `random_mha8_cases.json` | 10 | Python numerical-random cases with offline comparison |
| `protocol_random_mha8_cases.json` | 4 | Multi-mini-job protocol/structural random cases |
| `protocol_directed_mha8_cases.json` | 15 | Backpressure, tile boundaries, computation modes, and targeted coverage |
| `numerical_corner_mha8_cases.json` | 12 | Requantization, bias, softmax, sparse, and zero corner cases |
| `negative_mha8_cases.json` | 19 | Valid-ready faults, illegal tile/metadata/beat cases, and output starvation |

Negative cases use XFAIL semantics: the simulation must exit with a nonzero status, and `vsim.log` must match the case-specific checker tag exactly before the runner reports `XFAIL_PASS`. Negative-case UCDB files are excluded from legal coverage merges.

## Environment Setup

The QuestaSim tools `vlib`, `vmap`, `vlog`, `vsim`, and `vcover` must be available through `PATH`, or their directory can be specified with `-QuestaBin`.

### ITA / PyITA Tensor Dependency

The original tensors and golden data used by numerical tests are **still generated by the [original ITA repository](https://github.com/pulp-platform/ITA/)**. ITA_CORE_UVM does not implement a separate tensor generator. The two repositories should be placed next to each other:

```text
workspace/
|-- ITA/
|   |-- testGenerator.py         # Original tensor/golden generation entry point
|   |-- PyITA/                   # Python numerical model
|   `-- simvectors/
|       `-- data_.../standalone/ # Input/weight/bias/requant/expected files
`-- ITA_CORE_UVM/
    |-- tb/tools/                # UVM vector adapters and case generators
    `-- sim/
```

The complete numerical-vector flow is:

```text
ITA/testGenerator.py
  -> ITA/simvectors/data_.../standalone
  -> ITA_CORE_UVM/tb/tools/gen_mha8_pyita_vectors.py
  -> UVM stream CSV + requant CSV + comparison manifest
  -> UVM simulation
  -> actual CSV
  -> compare_mha8_manifest.py
```

- `gen_random_mha8_cases.py` and `gen_directed_mha8_cases.py` first check whether the required shape and pattern are available under `ITA/simvectors`.
- When a vector is missing and `--no-auto-generate` is not specified, the generator invokes `../ITA/testGenerator.py`.
- `smoke.ps1 -GenerateVectors` adapts the standalone data selected by `-PyitaDir` into UVM inputs. It does not recompute the original tensors or golden data.
- `protocol_random_mha8_cases.json` uses deterministic SystemVerilog payloads, does not require complete PyITA tensors, and does not run the offline numerical comparison.

For example, a basic MHA8 vector can be generated directly with the original ITA generator:

```powershell
python ..\ITA\testGenerator.py `
  --seed 0 `
  -S 64 -E 64 -P 64 -F 64 -H 8 `
  --activation relu
```

The case generator or `smoke.ps1` then invokes the UVM adapter. Under the normal flow, these two stages do not need to be executed manually.

Install the Python/PyITA dependencies required for numerical-vector generation:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r ..\ITA\requirements.txt
```

All commands should be run from the `ITA_CORE_UVM` root directory. Invoke Python generators with `python script.py` rather than relying on the Windows `.py` file association.

## Common Commands

### Compile

```powershell
.\sim\scripts\compile.ps1
```

Enable RTL code-coverage instrumentation:

```powershell
.\sim\scripts\compile.ps1 `
  -EnableCodeCoverage `
  -CodeCoverageSpec sbceft
```

### Minimal Protocol Smoke Test

```powershell
.\sim\scripts\smoke.ps1 `
  -TestName ita_mha8_protocol_random_test `
  -ProtocolNumJobs 1 `
  -ProtocolTileMin 1 `
  -ProtocolTileMax 1 `
  -ProtocolProjection ATTNFF `
  -NoGenerateVectors `
  -NoCompare
```

### Generate Cases

```powershell
# Numerical random
python .\tb\tools\gen_random_mha8_cases.py `
  --count 10 `
  --seed 7 `
  --shape-values 64,128,192,256 `
  --out .\sim\cases\random_mha8_cases.json

# Protocol random
python .\tb\tools\gen_protocol_random_mha8_cases.py `
  --count 4 `
  --jobs-min 8 `
  --jobs-max 16 `
  --tile-max 2 `
  --out .\sim\cases\protocol_random_mha8_cases.json

# Protocol directed / numerical corner / negative
python .\tb\tools\gen_directed_mha8_cases.py --suite protocol
python .\tb\tools\gen_directed_mha8_cases.py --suite numerical
python .\tb\tools\gen_directed_mha8_cases.py --suite negative
```

### Run a Regression

```powershell
.\sim\scripts\run_mha8_regression.ps1 `
  -CasesManifest .\sim\cases\protocol_random_mha8_cases.json `
  -StopOnFirstFail
```

Replace `-CasesManifest` to run another suite. Common options are:

- `-DryRun`: expand commands without running them
- `-OutDir <path>`: select the output directory
- `-Resume`: reuse validated PASS cases from the same output directory
- `-EnableCodeCoverage`: collect RTL code coverage
- `-CodeCoverageSpec sbceft`: select the code-coverage metrics

### Complete Legal Code-Coverage Flow

```powershell
.\sim\scripts\run_mha8_code_coverage.ps1 `
  -CodeCoverageSpec sbceft `
  -StopOnFirstFail
```

This script runs the protocol-directed, protocol-random, numerical-random, and numerical-corner suites in order. It verifies the DUT RTL fingerprint before merging the legal UCDB files.

## Output Files

Single smoke-test log:

```text
sim/output/logs/<test_name>.log
```

Main regression outputs:

```text
sim/output/random_regression/<timestamp>/
|-- 000_<case>/
|   |-- smoke_wrapper.log
|   |-- vsim.log
|   |-- case_result.json
|   `-- <case>.ucdb
|-- coverage/
|   |-- random_mha8_merged.ucdb
|   |-- coverage_report.txt
|   `-- coverage_html/
|-- regression_summary.json
`-- regression_summary.txt
```

Code-coverage closure output is written under:

```text
sim/output/code_coverage_closure/<timestamp>/coverage/
```

This directory contains the merged UCDB, functional/code-coverage text and HTML reports, and provenance data.

## Verification Boundaries

- Numerical golden data depends on PyITA and the offline comparison flow. A usable online full numerical reference model is not currently implemented.
- Functional, assertion, and code coverage are separate metrics. A single coverage percentage cannot prove complete verification closure.
- Legal protocol-random testing follows the DUT's current source-bundle contract. Illegal valid-ready behavior is tested separately in the negative suite.
- Some base and coverage-target paths still drive the VIF directly; not all driven signals have been consolidated under a single driver owner.
- Negative/XFAIL testing proves that a checker detects a specified fault. It does not prove functional recovery from illegal DUT inputs.
- Large shapes, toggle coverage, and full numerical regressions are expensive and should be selected according to the remaining coverage gaps.
