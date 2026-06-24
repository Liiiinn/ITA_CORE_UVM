# ITA_CORE_UVM/tbak Exercise Skeleton

`tbak` is the learning version of the ITA/MHA8 UVM testbench. It should compile and start UVM, but important behavior is intentionally left as `TODO Stage N` exercises. Use `tb` as the reference implementation and do not edit it while working in `tbak`.

## Ground Rules

- Keep the DUT target as `ita_mha8`; learn through head0 first.
- Preserve names and package style from `tb` where practical.
- Do not add `tbak/seq`, `tbak/scb`, or `tbak/log` to the active filelist until their stage.
- Add code directly below the matching TODO instead of replacing the whole skeleton.
- After each stage, run dry-run first, then smoke.

## Stage Order

1. Baseline smoke shell
   - Files: `top/ita_mha8_tb_top.sv`, `if/ita_mha8_if.sv`, `env/ita_mha8_env.svh`, `tests/ita_mha8_base_test.svh`.
   - Goal: compile and start `ita_base_test` with no real sequence.

2. Shared MHA8 ctrl path
   - Files: `agents/ita_ctrl_agent/ita_ctrl_item.svh`, `ita_ctrl_driver.svh`, `ita_ctrl_monitor.svh`, `tests/ita_mha8_base_test.svh`.
   - Goal: create one ctrl item, drive `ctrl_i` and a one-cycle `start` pulse, and monitor the transaction.
   - Start here before stream, logger, or scoreboard work.

3. Head0 input stream
   - Files: `agents/ita_stream_agent/ita_stream_item.svh`, `ita_stream_driver.svh`, `ita_stream_monitor.svh`, `env/ita_mha8_env_config.svh`.
   - Goal: drive and monitor only `input_agt[0]`.

4. Head0 weight/bias streams
   - Files: same stream agent files plus test stimulus.
   - Goal: reuse the same stream agent for `weight_agt[0]` and `bias_agt[0]`.

5. Head0 output stream
   - Files: `ita_stream_driver.svh`, `ita_stream_monitor.svh`, `env/ita_mha8_env.svh`.
   - Goal: drive output ready and sample `per_head_valid_o[0] && per_head_ready_i[0]`.

6. Core-level transaction
   - File: `common/ita_mha8_core_item.svh`.
   - Goal: describe layer, activation, tile parameters, payloads, and compare paths, then split into ctrl + stream items.

7. Logger
   - Files: env connect phase and a logger component restored or created under `tbak/log`.
   - Goal: passively dump actual output from head0 first.

8. Smoke scoreboard and early assertions
   - Files: interface assertion hooks, scoreboard skeleton, env connect phase.
   - Goal: check count, X/Z, timeout, valid-ready, and backpressure stability.

9. Linear directed testcase
   - Files: tests, core item, ctrl/stream sequences.
   - Goal: run a small manually checkable Linear testcase on head0.

10. Phase 2 compare path
    - Files: common item, logger, test flow, scripts if needed.
    - Goal: connect actual output to Python compare.

11. Full MHA8 expansion
    - Files: env config, stream config, logger, scoreboard, reference model.
    - Goal: enable heads 1-7, sum path, feed-forward path, and full golden compare.

## Verification Commands

List TODOs:

```powershell
Select-String -Path ITA_CORE_UVM\tbak\**\*.sv,ITA_CORE_UVM\tbak\**\*.svh,ITA_CORE_UVM\tbak\AGENTS.md -Pattern "TODO Stage"
```

Check that complex packages are not active:

```powershell
Select-String -Path ITA_CORE_UVM\sim\filelist.f,ITA_CORE_UVM\tbak\env\*.sv,ITA_CORE_UVM\tbak\tests\*.sv -Pattern "ita_mha8_scb_pkg|ita_mha8_seq_pkg|ref_model|scoreboard|transaction_logger"
```

Dry-run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ITA_CORE_UVM\sim\scripts\smoke.ps1 -DryRun
```

Smoke:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ITA_CORE_UVM\sim\scripts\smoke.ps1
```

## MHA8 Ready/Valid Notes

Use this section as the protocol reference for Stage 3-5 work.

### Per-head input, weight, and bias streams

The MHA8 wrapper instantiates one independent `ita` core per head. The stream ports are per-head:

```systemverilog
inp_valid_i[h]         // TB -> DUT
inp_ready_o[h]         // DUT -> TB
inp_weight_valid_i[h]  // TB -> DUT
inp_weight_ready_o[h]  // DUT -> TB
inp_bias_valid_i[h]    // TB -> DUT
inp_bias_ready_o[h]    // DUT -> TB
```

Each head connects directly to one `ita` instance:

```systemverilog
.inp_valid_i       (inp_valid_i[h])
.inp_ready_o       (inp_ready_o[h])
.inp_weight_valid_i(inp_weight_valid_i[h])
.inp_weight_ready_o(inp_weight_ready_o[h])
.inp_bias_valid_i  (inp_bias_valid_i[h])
.inp_bias_ready_o  (inp_bias_ready_o[h])
```

The testbench stream driver should wait on the wrapper-level ready for the stream it owns:

```systemverilog
cfg.vif.inp_ready_o[cfg.head_id]
cfg.vif.inp_weight_ready_o[cfg.head_id]
cfg.vif.inp_bias_ready_o[cfg.head_id]
```

### Weight has an external and internal handshake

`inp_weight_valid_i/inp_weight_ready_o` is the external handshake used by the testbench to write weights into the DUT weight buffer.

Inside `ita`, the weight buffer exposes another handshake to the controller:

```systemverilog
weight_valid
weight_ready
```

These are connected as:

```systemverilog
ita_controller i_controller (
    .weight_valid_i(weight_valid),
    .weight_ready_o(weight_ready)
);

ita_weight_controller i_weight_controller (
    .inp_weight_valid_i(inp_weight_valid_i),
    .inp_weight_ready_o(inp_weight_ready_o),
    .weight_valid_o    (weight_valid),
    .weight_ready_i    (weight_ready)
);
```

So `inp_weight_ready_o` means the external weight stream can write into the DUT. `weight_valid/weight_ready` is the internal read side used by the controller.

### Input and bias ready depend on internal weight availability

In `ita_controller.sv`, during active non-idle steps, the key default handshake is:

```systemverilog
inp_ready_o    = weight_valid_i;
weight_ready_o = inp_valid_i;
bias_ready_o   = weight_valid_i;
```

A compute beat starts only when all three are valid at the controller level:

```systemverilog
if (inp_valid_i && weight_valid_i && bias_valid_i) begin
    calc_en_o = 1;
end
```

`weight_valid_i` here is the internal controller input from the weight buffer, not the external `inp_weight_valid_i` pin. This means `inp_ready_o` and `inp_bias_ready_o` may stay low until enough weight data has been accepted and the internal weight buffer can provide `weight_valid`.

For Stage 3, sending only input can legitimately timeout waiting for `inp_ready_o`. Stage 4 should add head0 weight and bias traffic before expecting the input path to make progress.

### Per-head output stream

Each `ita` core outputs:

```systemverilog
valid_o
ready_i
oup_o
oup_step_o
```

The MHA8 wrapper exposes these as:

```systemverilog
per_head_valid_o[h]  // DUT -> TB
per_head_ready_i[h]  // TB -> DUT
per_head_oup_o[h]
per_head_step_o[h]
```

For non-`OW` steps, the wrapper passes testbench ready through directly:

```systemverilog
head_ready[h] = per_head_ready_i[h];
```

Stage 5 should start with deterministic always-ready output sink behavior:

```systemverilog
per_head_ready_i[0] <= 1'b1;
```

Random ready stalls and backpressure checks belong later, after the always-ready path works.

### OW sum aggregation is special

For `OW` output, MHA8 does not let each head complete independently. The wrapper requires all heads to be valid and phase-aligned before sending data into `ita_head_sum`:

```systemverilog
all_head_valid     = &per_head_valid_o;
all_per_head_ready = &per_head_ready_i;
sum_valid          = all_head_valid && all_head_ow && !phase_mismatch_o;
sum_valid_to_sum   = sum_valid && all_per_head_ready;
```

When a head output is `OW`, ready is gated by the sum path:

```systemverilog
head_ready[h] = sum_valid_to_sum && sum_ready;
```

So a head0-only Attention test can stall at OW because the wrapper expects all 8 heads to participate. For early head0 learning, a small Linear testcase is usually easier than full Attention.

### Feed-forward path

Feed-forward uses the separate `i_ffn` `ita` instance and separate wrapper ports:

```systemverilog
ff_inp_valid_i
ff_inp_ready_o
ff_inp_weight_valid_i
ff_inp_weight_ready_o
ff_inp_bias_valid_i
ff_inp_bias_ready_o
ff_valid_o
ff_ready_i
```

The wrapper routes `ctrl_i.start` by layer:

```systemverilog
head_ctrl[h].start = ctrl_i.start && (ctrl_i.layer != Feedforward);
ff_ctrl.start      = ctrl_i.start && (ctrl_i.layer == Feedforward);
```

Do not mix per-head MHA traffic and feed-forward traffic in the early head0 stages.

### Stage implications

- Stage 3 only proves the input agent can drive and wait safely; it may timeout if weight is not available.
- Stage 4 should add head0 weight and bias source traffic, with timeout inside each per-stream driver task.
- Stage 5 should make head0 output ready always high and monitor `per_head_valid_o[0] && per_head_ready_i[0]`.
- Stage 8 should add assertions for X/Z, valid-ready stability, timeout, and output stability under backpressure.
- Stage 11 should handle heads 1-7, OW sum, feed-forward, and full MHA8 attribution.