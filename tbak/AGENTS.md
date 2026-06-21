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
