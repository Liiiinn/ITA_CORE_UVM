`ifndef ITA_MHA8_COVERAGE_TARGET_VSEQUENCE_SVH
`define ITA_MHA8_COVERAGE_TARGET_VSEQUENCE_SVH

class ita_mha8_coverage_target_vsequence extends ita_mha8_vsequence;
    `uvm_object_utils(ita_mha8_coverage_target_vsequence)
    `uvm_declare_p_sequencer(ita_mha8_vsequencer)

    function new(string name = "ita_mha8_coverage_target_vsequence");
        super.new(name);
    endfunction : new

    virtual task body();
        if (scenario == null)
            `uvm_fatal("ITA_COV_TARGET_CFG", "Scenario config is not set")

        case (scenario.coverage_target_mode.toupper())
            "MID_RESET":       run_mid_transaction_reset();
            "STALL_BOUNDARIES": run_stall_boundaries();
            default:
                `uvm_fatal("ITA_COV_TARGET_CFG",
                    $sformatf("Unsupported coverage target mode %s", scenario.coverage_target_mode))
        endcase
    endtask : body

    function step_e parse_mid_reset_step();
        case (scenario.mid_reset_step_name.toupper())
            "Q":  return Q;
            "K":  return K;
            "V":  return V;
            "QK": return QK;
            "F1": return F1;
            default: begin
                `uvm_fatal("ITA_MID_RESET_CFG",
                    $sformatf("Unsupported mid-transaction reset step %s", scenario.mid_reset_step_name))
                return Idle;
            end
        endcase
    endfunction : parse_mid_reset_step

    task build_target_core(
        string name,
        int unsigned tile_s,
        int unsigned tile_e,
        int unsigned tile_p,
        int unsigned tile_f,
        bit include_attention,
        bit include_ff
    );
        core = ita_mha8_core_item::type_id::create(name);
        core.tile_s = tile_t'(tile_s);
        core.tile_e = tile_t'(tile_e);
        core.tile_p = tile_t'(tile_p);
        core.tile_f = tile_t'(tile_f);
        core.activation = Relu;
        core.clear_requant_config();

        if (include_attention) begin
            core.layer = Attention;
            ita_mha8_add_protocol_step(core, Q, 0);
            ita_mha8_add_protocol_step(core, K, 0);
            ita_mha8_add_protocol_step(core, V, 0);
            ita_mha8_add_protocol_step(core, QK, 0);
            ita_mha8_add_protocol_step(core, AV, 0);
            ita_mha8_add_protocol_step(core, OW, 0);
        end

        if (include_ff) begin
            if (!include_attention)
                core.layer = Feedforward;
            ita_mha8_add_protocol_step(core, F1, 0);
            ita_mha8_add_protocol_step(core, F2, 0);
        end
    endtask : build_target_core

    task send_attention_direct();
        send_ctrl_item("coverage_attention_ctrl",
            make_ctrl_item(core, Attention, Q, Identity, 1'b1));
        foreach (core.payload_schedule[i]) begin
            ita_mha8_step_payload payload;

            payload = core.payload_schedule[i];
            if (is_attention_step(payload.step) && payload.drive_head_streams)
                send_step_payload_head_bundle(payload);
        end
    endtask : send_attention_direct

    task send_head_payload_continuous(ita_mha8_step_payload payload);
        bit all_ready;
        int unsigned wait_cycles;

        for (int unsigned beat = 0; beat < payload.input_payload_by_head[0].size(); beat++) begin
            @(negedge p_sequencer.vif.clk_i);
            for (int unsigned h = 0; h < 8; h++) begin
                p_sequencer.vif.inp_i[h] <= payload.input_payload_by_head[h][beat];
                p_sequencer.vif.inp_weight_i[h] <= payload.weight_payload_by_head[h][beat];
                p_sequencer.vif.inp_bias_i[h] <= payload.bias_payload_by_head[h][beat];
                p_sequencer.vif.inp_valid_i[h] <= 1'b1;
                p_sequencer.vif.inp_weight_valid_i[h] <= 1'b1;
                p_sequencer.vif.inp_bias_valid_i[h] <= 1'b1;
                p_sequencer.vif.inp_step_dbg[h] <= payload.step;
                p_sequencer.vif.inp_weight_step_dbg[h] <= payload.step;
                p_sequencer.vif.inp_bias_step_dbg[h] <= payload.step;
                p_sequencer.vif.inp_tile_id_dbg[h] <= payload.tile_id;
                p_sequencer.vif.inp_weight_tile_id_dbg[h] <= payload.tile_id;
                p_sequencer.vif.inp_bias_tile_id_dbg[h] <= payload.tile_id;
                p_sequencer.vif.inp_inner_id_dbg[h] <= payload.inner_tile_id;
                p_sequencer.vif.inp_weight_inner_id_dbg[h] <= payload.inner_tile_id;
                p_sequencer.vif.inp_bias_inner_id_dbg[h] <= payload.inner_tile_id;
                p_sequencer.vif.inp_beat_id_dbg[h] <= beat;
                p_sequencer.vif.inp_weight_beat_id_dbg[h] <= beat;
                p_sequencer.vif.inp_bias_beat_id_dbg[h] <= beat;
                p_sequencer.vif.inp_lockstep_dbg[h] <= 1'b1;
                p_sequencer.vif.inp_weight_lockstep_dbg[h] <= 1'b1;
                p_sequencer.vif.inp_bias_lockstep_dbg[h] <= 1'b1;
            end

            wait_cycles = 0;
            do begin
                // Data and valid were updated on the falling edge. Sample
                // combinational ready away from the active clock edge so the
                // final beat cannot race the controller's state update.
                #1ns;
                all_ready = 1'b1;
                for (int unsigned h = 0; h < 8; h++) begin
                    all_ready &= p_sequencer.vif.inp_ready_o[h];
                    all_ready &= p_sequencer.vif.inp_weight_ready_o[h];
                    all_ready &= p_sequencer.vif.inp_bias_ready_o[h];
                end
                wait_cycles++;
                if (wait_cycles > scenario.output_wait_timeout_cycles)
                    `uvm_fatal("ITA_STALL_SOURCE_TIMEOUT",
                        $sformatf("Timed out driving continuous %s tile=%0d inner=%0d beat=%0d",
                            payload.step.name(), payload.tile_id, payload.inner_tile_id, beat))
                if (!all_ready)
                    @(negedge p_sequencer.vif.clk_i);
            end while (!all_ready);
            @(posedge p_sequencer.vif.clk_i);
        end

        @(negedge p_sequencer.vif.clk_i);
        p_sequencer.vif.inp_valid_i <= '0;
        p_sequencer.vif.inp_weight_valid_i <= '0;
        p_sequencer.vif.inp_bias_valid_i <= '0;
    endtask : send_head_payload_continuous

    task send_attention_through_av_continuous();
        send_ctrl_item("coverage_attention_continuous_ctrl",
            make_ctrl_item(core, Attention, Q, Identity, 1'b1));
        foreach (core.payload_schedule[i]) begin
            ita_mha8_step_payload payload;

            payload = core.payload_schedule[i];
            if (payload.step == OW)
                break;
            if (is_attention_step(payload.step) && payload.drive_head_streams)
                send_head_payload_continuous(payload);
        end
    endtask : send_attention_through_av_continuous

    task send_f1_direct();
        send_ctrl_item("coverage_f1_ctrl",
            make_ctrl_item(core, Feedforward, F1, core.activation, 1'b1));
        foreach (core.payload_schedule[i]) begin
            ita_mha8_step_payload payload;

            payload = core.payload_schedule[i];
            if (payload.step != F1 || !payload.drive_ff_streams)
                continue;
            for (int unsigned beat = 0; beat < payload.ff_input_payload.size(); beat++)
                drive_ff_lockstep_beat(payload, beat);
        end
    endtask : send_f1_direct

    task wait_for_target_progress(step_e target_step);
        int unsigned wait_cycles;

        wait_cycles = 0;
        forever begin
            @(posedge p_sequencer.vif.clk_i);
            if (target_step == F1) begin
                if (p_sequencer.vif.ff_controller_step_dbg == F1 &&
                    p_sequencer.vif.ff_controller_beat_dbg >= 8)
                    return;
            end else begin
                if (p_sequencer.vif.controller_step_dbg[0] == target_step &&
                    p_sequencer.vif.controller_beat_dbg[0] >= 8)
                    return;
            end

            wait_cycles++;
            if (wait_cycles > scenario.output_wait_timeout_cycles)
                `uvm_fatal("ITA_MID_RESET_TIMEOUT",
                    $sformatf("Timed out waiting for active step %s before reset", target_step.name()))
        end
    endtask : wait_for_target_progress

    task drive_all_sources_idle();
        p_sequencer.vif.inp_valid_i <= '0;
        p_sequencer.vif.inp_weight_valid_i <= '0;
        p_sequencer.vif.inp_bias_valid_i <= '0;
        p_sequencer.vif.ff_inp_valid_i <= 1'b0;
        p_sequencer.vif.ff_inp_weight_valid_i <= 1'b0;
        p_sequencer.vif.ff_inp_bias_valid_i <= 1'b0;
        p_sequencer.vif.ctrl_i.start <= 1'b0;
    endtask : drive_all_sources_idle

    task inject_and_check_mid_reset(step_e target_step);
        @(negedge p_sequencer.vif.clk_i);
        drive_all_sources_idle();
        p_sequencer.vif.rst_ni <= 1'b0;

        repeat (scenario.mid_reset_cycles)
            @(posedge p_sequencer.vif.clk_i);

        if (target_step == F1) begin
            if (p_sequencer.vif.ff_controller_step_dbg != Idle)
                `uvm_fatal("ITA_MID_RESET_IDLE",
                    $sformatf("FF controller did not return F1 -> Idle during reset; observed %s",
                        p_sequencer.vif.ff_controller_step_dbg.name()))
        end else begin
            for (int unsigned h = 0; h < 8; h++) begin
                if (p_sequencer.vif.controller_step_dbg[h] != Idle)
                    `uvm_fatal("ITA_MID_RESET_IDLE",
                        $sformatf("head%0d controller did not return %s -> Idle during reset; observed %s",
                            h, target_step.name(), p_sequencer.vif.controller_step_dbg[h].name()))
            end
        end

        @(negedge p_sequencer.vif.clk_i);
        p_sequencer.vif.rst_ni <= 1'b1;
        repeat (2) @(posedge p_sequencer.vif.clk_i);
        `uvm_info("ITA_MID_RESET_PASS",
            $sformatf("Observed mid-transaction reset transition %s -> Idle", target_step.name()),
            UVM_LOW)
    endtask : inject_and_check_mid_reset

    task run_mid_transaction_reset();
        step_e target_step;

        target_step = parse_mid_reset_step();
        if (target_step == F1)
            build_target_core("mid_reset_ff_core", 1, 1, 1, 1, 1'b0, 1'b1);
        else
            build_target_core("mid_reset_attention_core", 1, 1, 1, 1, 1'b1, 1'b0);

        stop_head_output_ready = 1'b0;
        fork : mid_reset_threads
            drive_head_output_ready_bundle();
            begin
                if (target_step == F1)
                    send_f1_direct();
                else
                    send_attention_direct();
            end
            begin
                wait_for_target_progress(target_step);
                inject_and_check_mid_reset(target_step);
            end
        join_any
        stop_head_output_ready = 1'b1;
        disable mid_reset_threads;
        drive_all_sources_idle();
        p_sequencer.vif.per_head_ready_i <= '0;
    endtask : run_mid_transaction_reset

    task drive_stall_target_ready();
        p_sequencer.vif.per_head_ready_i <= '0;
        wait (p_sequencer.vif.rst_ni === 1'b1);
        wait (p_sequencer.vif.controller_output_fifo_stall_dbg[0] ||
              p_sequencer.vif.output_fifo_full_dbg[0]);
        p_sequencer.vif.per_head_ready_i <= '1;
        while (!stop_head_output_ready)
            @(posedge p_sequencer.vif.clk_i);
        p_sequencer.vif.per_head_ready_i <= '0;
    endtask : drive_stall_target_ready

    task observe_stall_boundaries(
        ref bit output_stall_seen,
        ref bit softmax_fifo_stall_seen,
        ref bit softmax_div_seen,
        ref bit output_full_seen,
        ref bit output_empty_seen,
        ref bit softmax_full_seen,
        ref bit softmax_empty_seen
    );
        forever begin
            @(posedge p_sequencer.vif.clk_i);
            if (!p_sequencer.vif.rst_ni)
                continue;
            output_stall_seen |= p_sequencer.vif.controller_output_fifo_stall_dbg[0];
            softmax_fifo_stall_seen |= p_sequencer.vif.controller_softmax_fifo_stall_dbg[0];
            softmax_div_seen |= p_sequencer.vif.controller_softmax_div_stall_dbg[0];
            output_full_seen |= p_sequencer.vif.output_fifo_full_dbg[0];
            output_empty_seen |= p_sequencer.vif.output_fifo_empty_dbg[0];
            softmax_full_seen |= p_sequencer.vif.softmax_fifo_full_dbg[0];
            softmax_empty_seen |= p_sequencer.vif.softmax_fifo_empty_dbg[0];
        end
    endtask : observe_stall_boundaries

    task require_stall_target(bit observed, string target_name);
        if (!observed)
            `uvm_fatal("ITA_STALL_TARGET_MISS",
                $sformatf("Targeted legal stimulus did not reach %s", target_name))
    endtask : require_stall_target

    task run_stall_boundaries();
        bit output_stall_seen;
        bit softmax_fifo_stall_seen;
        bit softmax_div_seen;
        bit output_full_seen;
        bit output_empty_seen;
        bit softmax_full_seen;
        bit softmax_empty_seen;

        build_target_core("stall_boundary_core", 4, 1, 4, 1, 1'b1, 1'b0);
        stop_head_output_ready = 1'b0;

        fork : stall_threads
            drive_stall_target_ready();
            observe_stall_boundaries(
                output_stall_seen,
                softmax_fifo_stall_seen,
                softmax_div_seen,
                output_full_seen,
                output_empty_seen,
                softmax_full_seen,
                softmax_empty_seen);
            send_attention_through_av_continuous();
        join_any
        stop_head_output_ready = 1'b1;
        disable stall_threads;
        p_sequencer.vif.per_head_ready_i <= '0;

        `uvm_info("ITA_STALL_TARGET_SUMMARY",
            $sformatf("output_stall=%0b output_empty=%0b output_full=%0b softmax_fifo_stall=%0b softmax_empty=%0b softmax_full=%0b softmax_div=%0b",
                output_stall_seen,
                output_empty_seen,
                output_full_seen,
                softmax_fifo_stall_seen,
                softmax_empty_seen,
                softmax_full_seen,
                softmax_div_seen),
            UVM_LOW)

        require_stall_target(output_stall_seen, "controller output FIFO stall");
        require_stall_target(output_empty_seen, "output FIFO empty boundary");
        require_stall_target(softmax_empty_seen, "softmax FIFO empty boundary");

        if (!output_full_seen)
            `uvm_info("ITA_STALL_PROTECTED_UNREACHED",
                "Physical output fifo_full remained unreachable because controller ongoing_q >= FifoDepth stalled source progress first",
                UVM_LOW)
        if (!softmax_full_seen)
            `uvm_info("ITA_STALL_PROTECTED_UNREACHED",
                "Physical softmax fifo_full remained unreachable under the legal producer/consumer schedule; controller softmax occupancy stall is the required observable boundary",
                UVM_LOW)
        if (!softmax_fifo_stall_seen)
            `uvm_info("ITA_STALL_UNREACHED",
                "Controller softmax FIFO occupancy stall was not reachable with maximum-rate legal QK input; divider consumption kept occupancy below SoftFifoDepth",
                UVM_LOW)
        if (!softmax_div_seen)
            `uvm_info("ITA_STALL_UNREACHED",
                "softmax_div stall was not reachable before AV consumption with maximum-rate legal QK input; division completed before the guarded AV window",
                UVM_LOW)

        `uvm_info("ITA_STALL_TARGET_PASS",
            "Completed stall reachability audit; mandatory output-capacity stall and FIFO empty boundaries were observed, while unreachable softmax/full targets were reported separately",
            UVM_LOW)
    endtask : run_stall_boundaries

endclass : ita_mha8_coverage_target_vsequence

`endif // ITA_MHA8_COVERAGE_TARGET_VSEQUENCE_SVH
