# ITA MHA8 UVM learning skeleton

This directory is the learning copy of `tb`. It keeps the MHA8 wrapper as the
DUT target, but the learning flow starts with `head_id == 0` before expanding to
all heads, sum, feed-forward, logger, scoreboard, and golden compare.

## Current scope

- Keep the MHA8 wrapper naming and structure from `tb`.
- Keep `ctrl_i` as shared MHA8 control across all heads.
- Keep stream and output configuration shaped as MHA8 per-head arrays.
- Enable only head 0 first; heads 1-7, sum, and feed-forward remain later stages.
- Do not compile or instantiate `seq`, `scb`, reference model, or logger until
  their stage is reached.
- Compile only package `.sv` files, interfaces, top modules, and RTL. Do not add
  ordinary class `.svh` files directly to `sim/filelist.f`.

## Stage order

1. Stage 1: Baseline smoke
   - `ita_mha8_tb_top` instantiates `ita_mha8` and `ita_mha8_if`.
   - `ita_mha8_base_test` and `ita_base_test` build the env only.
   - No sequence starts in the base test.
   - Acceptance: compile/run with zero UVM errors or fatals.

2. Stage 2: Shared MHA8 ctrl
   - Add minimal ctrl defaults for layer, activation, and tile shape.
   - Drive shared `ctrl_i` through `ctrl_agt`.
   - Keep stream agents idle.
   - Acceptance: ctrl can be driven after reset without requiring stream data.

3. Stage 3: Head0 input stream
   - Use `input_agt[0]` only.
   - Keep the reusable stream agent implementation.
   - Acceptance: head0 input monitor observes a valid-ready handshake.

4. Stage 4: Head0 weight and bias streams
   - Use `weight_agt[0]` and `bias_agt[0]` only.
   - Keep heads 1-7 passive.
   - Acceptance: head0 input/weight/bias handshakes are observed.

5. Stage 5: Head0 output stream
   - Use `head_output_agt[0]` as the first output sink/monitor.
   - Capture `per_head_oup_o[0]` and `per_head_step_o[0]`.
   - Acceptance: output samples can be observed without scoreboard compare.

6. Stage 6: Core transaction
   - Use `ita_mha8_core_item` as the testcase-level transaction.
   - Split it into ctrl item and stream items.
   - Acceptance: directed testcase intent is represented in one common item.

7. Stage 7: Logger
   - Add actual-output dump after monitors are stable.
   - Do not add numeric golden compare here.
   - Acceptance: actual output is written to a deterministic path.

8. Stage 8: Smoke scoreboard and early assertions
   - Add transaction count, X/Z, timeout, valid-ready, and backpressure checks.
   - Keep checks protocol-focused.
   - Acceptance: protocol mistakes report UVM errors.

9. Stage 9: Linear directed testcase
   - Implement `ita_linear_directed_test` for a small head0 Linear case.
   - Drive ctrl, input, weight, bias, output ready, then dump actual output.
   - Acceptance: simulation completes and produces actual output.

10. Stage 10: Phase 2 compare path
    - Route expected, actual, and compare paths through config/core item.
    - Reuse the Python compare flow after simulation.
    - Acceptance: Linear directed simulation and compare run in one scripted flow.

11. Stage 11: Full MHA8 expansion
    - Enable heads 1-7 using the existing per-head config shape.
    - Add sum and feed-forward paths.
    - Add MHA8-specific reference/golden compare.
    - Acceptance: mismatch reports identify stream kind, head id, step, and beat.

## TODO edit order

1. Interface: `tbak/if/ita_mha8_if.sv`
   - Add only signal helpers/assertion hooks needed by the current stage.
   - Keep sum and feed-forward tied off until later stages.

2. Common transaction and config
   - `tbak/common/ita_mha8_core_item.svh`
   - `tbak/env/ita_mha8_env_config.svh`
   - Add fields before tests, drivers, or monitors read them.

3. Ctrl agent
   - `ita_ctrl_item.svh`
   - `ita_ctrl_driver.svh`
   - `ita_ctrl_monitor.svh`
   - Implement shared MHA8 ctrl before stream stimulus.

4. Stream agent
   - `ita_stream_common.svh`
   - `ita_stream_config.svh`
   - `ita_stream_item.svh`
   - `ita_stream_driver.svh`
   - `ita_stream_monitor.svh`
   - Implement head0 input, then weight/bias, then output.

5. Environment: `tbak/env/ita_mha8_env.svh`
   - Create/connect components only after leaf agents compile.
   - Add logger/scoreboard/reference-model handles here when their stages begin.

6. Tests: `tbak/tests/ita_mha8_base_test.svh`
   - Keep base test build-only.
   - Add active stimulus only in derived tests.

7. Package/filelist
   - Update `*_pkg.sv` only when adding a new include dependency.
   - Update `sim/filelist.f` only for package `.sv`, interface `.sv`, top `.sv`, or RTL.

## Verification workflow

1. Run dry-run after structural edits.
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File ITA_CORE_UVM\sim\scripts\smoke.ps1 -DryRun
   ```

2. Run real smoke after dry-run.
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File ITA_CORE_UVM\sim\scripts\smoke.ps1
   ```

3. Debug order:
   - Compile errors: package order, imports, class names, include paths.
   - Build/connect errors: `uvm_config_db`, instance names, virtual interface.
   - Runtime errors: reset timing, sequencer start order, valid-ready handshake.
   - Protocol errors: driver/monitor branch for stream kind and head id.
