# ITA MHA8 UVM learning skeleton

This directory is intentionally minimal. It is a learning copy of `tb`, not the
full MHA8 verification environment.

## Current scope

- Keep only the basic UVM hierarchy: top, interface, test, env, ctrl agent, and
  reusable stream agent instances.
- Keep `ita_mha8` as the DUT target. Do not switch this learning skeleton to the
  single-core `ita` DUT unless the learning goal changes.
- Do not add a reference model, coverage, virtual sequence, or full MHA8
  multi-head expansion until the previous learning stage is clear.
- Compile only package `.sv` files, interfaces, top modules, and RTL. Do not add
  `.svh` files directly to `sim/filelist.f`.

## Growth path

1. Stage 1: Build-only smoke
   - Keep `ita_mha8_tb_top` instantiating the MHA8 DUT and `ita_mha8_if`.
   - Keep `ita_base_test` as a build-only test that creates `ita_mha8_env`.
   - Confirm the hierarchy contains `ctrl_agt`, `input_stream_agt`,
     `weight_stream_agt`, `bias_stream_agt`, and `output_stream_agt`.
   - Acceptance: compile and run with zero UVM errors or fatals.

2. Stage 2: Minimal ctrl sequence
   - Add one ctrl sequence item with `layer`, `activation`, and tile fields.
   - Drive `ctrl_i` through `ctrl_agt`.
   - Keep all stream agents idle.
   - Acceptance: test can drive ctrl after reset without changing DUT outputs.

3. Stage 3: One head-0 stream transaction
   - Use the reusable `ita_stream_agent` implementation for input, weight, and
     bias.
   - Drive only `head_id == 0`.
   - Keep heads 1-7 tied off.
   - Acceptance: input, weight, and bias monitors observe valid-ready handshakes
     on head 0.

4. Stage 4: Output stream monitor and ready driver
   - Use `output_stream_agt` as a sink agent for `per_head_ready_i[0]`.
   - Monitor `per_head_valid_o[0] && per_head_ready_i[0]`.
   - Capture `per_head_oup_o[0]` and `per_head_step_o[0]`.
   - Acceptance: output samples can be observed without adding a scoreboard.

5. Stage 5: Logger and smoke scoreboard
   - Add a small logger that dumps actual output samples to a deterministic
     path.
   - Add a smoke scoreboard for transaction counts, X/Z checks, timeout, and
     valid-ready protocol checks.
   - Do not add numeric golden comparison here.
   - Acceptance: protocol mistakes are reported as UVM errors.

6. Stage 6: Linear directed testcase
   - Implement `ita_linear_directed_test`.
   - Use a small, manually checkable Linear case on head 0.
   - Drive ctrl, input, weight, bias, and output ready through existing agents.
   - Acceptance: the test produces an actual output dump and passes smoke
     scoreboard checks.

7. Stage 7: Phase 2 compare path
   - Pass expected, actual, and compare paths through the core transaction or
     test config.
   - Reuse the Python compare flow after simulation.
   - Keep compare integration outside the basic smoke scoreboard.
   - Acceptance: the Linear directed testcase can run simulation and compare in
     one scripted flow.

8. Stage 8: Expand from head 0 to MHA8
   - Replicate stream agent configs across all 8 heads.
   - Add per-head attribution in monitor, logger, and scoreboard reports.
   - Add coverage only after the protocol and compare path are stable.
   - Acceptance: a mismatch clearly identifies stream kind, head id, step, and
     beat.

9. Stage 9: MHA8-specific reference or golden comparison
   - Add the MHA8 reference model or golden compare only after the directed
     Linear path is stable.
   - Include attention, sum, and feed-forward paths incrementally.
   - Acceptance: the environment can distinguish protocol failures from numeric
     mismatches.

## Suggested TODO workflow

1. Pick the next TODO from the current stage only.
   - Prefer the lowest stage number that is not complete.
   - Do not jump to scoreboard, compare, coverage, or 8-head expansion while
     ctrl and one head-0 stream path are still unproven.

2. Add the smallest useful code block directly below the matching TODO.
   - Keep edits local to the file named by the TODO.
   - If a change needs a new package, class, or filelist entry, stop and update
     this path first so the dependency is explicit.
   - Leave the TODO in place until the stage acceptance criteria passes.

3. Run dry-run after every structural change.
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File ITA_CORE_UVM\sim\scripts\smoke.ps1 -DryRun
   ```
   - Dry-run only checks the command/filelist shape.
   - Dry-run does not compile SystemVerilog and does not run UVM.

4. Run real smoke after dry-run.
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File ITA_CORE_UVM\sim\scripts\smoke.ps1
   ```
   - Treat `UVM_ERROR` or `UVM_FATAL` as a failed step.
   - Existing DUT relaxed-port warnings are acceptable unless a new warning is
     tied to the files changed in this step.

5. Debug in this order.
   - Compile errors: check package include order, type visibility, class names,
     and whether a `.svh` was incorrectly added to `filelist.f`.
   - Build/connect errors: check `uvm_config_db` set/get names, agent instance
     names, and virtual interface propagation.
   - Runtime errors: check reset timing, sequencer start order, valid-ready
     handshake, and monitor sample conditions.
   - Protocol issues: add temporary `uvm_info` near the driver/monitor branch
     for the current stream kind and head id.

6. Commit the learning state mentally before moving on.
   - Record what passed in the stage acceptance line or keep a short note near
     the relevant TODO.
   - Remove or rewrite a TODO only when the code below it is stable and the next
     stage has a clearer action.

## TODO edit order

Use this file order when implementing a stage. Do not edit later files until the
current file compiles or the dependency is explicitly needed.

1. Interface first: `tbak/if/ita_mha8_if.sv`
   - Add or expose only the signals/assertion hooks needed by the current stage.
   - Keep unused MHA8, sum, and feed-forward signals tied off until their stage.
   - Run dry-run after changing interface ports or signal names.

2. Transaction/config second: `tbak/env/ita_mha8_core_item.svh` and
   `tbak/env/ita_mha8_env_config.svh`
   - Add fields to `ita_mha8_core_item` before using them in tests or drivers.
   - Add config knobs in `ita_mha8_env_config` before reading them in env/agents.
   - Keep defaults on `head_id == 0` until the directed head-0 path passes.

3. Agent config and item third: `tbak/agents/ita_stream_agent/ita_stream_config.svh`
   and `tbak/agents/ita_stream_agent/ita_stream_item.svh`
   - Add stream item fields before driver/monitor code uses them.
   - Add stream config fields before env config assigns them.
   - Keep source/sink behavior selected by config, not by hard-coded agent names.

4. Driver fourth: `tbak/agents/ita_ctrl_agent/ita_ctrl_driver.svh` and
   `tbak/agents/ita_stream_agent/ita_stream_driver.svh`
   - Implement ctrl driving before stream driving for a new testcase.
   - Implement input, weight, and bias source driving before output backpressure.
   - Keep each driver change small enough that compile errors identify one branch.

5. Monitor fifth: `tbak/agents/ita_ctrl_agent/ita_ctrl_monitor.svh` and
   `tbak/agents/ita_stream_agent/ita_stream_monitor.svh`
   - Sample only real handshakes.
   - Add metadata capture before connecting logger or scoreboard.
   - Do not put scoreboard policy inside the monitor.

6. Agent wrapper sixth: `tbak/agents/ita_ctrl_agent/ita_ctrl_agent.svh` and
   `tbak/agents/ita_stream_agent/ita_stream_agent.svh`
   - Connect sequencer, driver, monitor, and analysis ports after their leaf code
     compiles.
   - Keep analysis ports generic so logger and scoreboard can both subscribe.

7. Environment seventh: `tbak/env/ita_mha8_env.svh`
   - Create new components only after their packages compile.
   - Connect analysis ports in `connect_phase` after monitors expose the needed
     transaction fields.
   - Add logger/scoreboard handles here, not inside agents.

8. Test last: `tbak/tests/ita_mha8_base_test.svh`
   - Keep `ita_base_test` build-only.
   - Put active stimulus in a derived test such as `ita_linear_directed_test`.
   - Start ctrl sequence first, then source streams, then output ready/sink flow.

9. Package and filelist only when needed
   - Update `*_pkg.sv` when adding a new `.svh` include.
   - Update `sim/filelist.f` only for new package `.sv`, interface `.sv`, top
     module `.sv`, or RTL files.
   - Do not add ordinary class `.svh` files directly to `sim/filelist.f`.
