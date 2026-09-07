    // This file is included inside ita_mha8_scoreboard. Structural checks remain
    // independent from the online numerical comparison.
    ita_mha8_ref_model ref_model;

    uvm_analysis_export #(ita_stream_item)   expected_export;
    uvm_tlm_analysis_fifo #(ita_stream_item) expected_fifo;

    ita_stream_item expected_pending[string];
    ita_stream_item actual_pending[string];
    bit             expected_seen[string];
    bit             actual_seen[string];

    bit           numeric_canceled[int unsigned];
    ita_ctrl_item job_configs[int unsigned];

    int unsigned numeric_matched;
    int unsigned numeric_failed;
    int unsigned numeric_uncovered;
    int unsigned numeric_canceled_jobs;
    bit          input_done;

    function string numeric_key(ita_stream_item transaction);
        return $sformatf(
            "j%0d:k%0d:s%0d:h%0d:t%0d:i%0d:b%0d",
            transaction.job_id,
            transaction.kind,
            transaction.step,
            transaction.head_id,
            transaction.tile_id,
            transaction.inner_tile_id,
            transaction.beat_id
        );
    endfunction : numeric_key

    function void numeric_error(string id, string message);
        numeric_failed++;
        `uvm_error(id, message)
    endfunction : numeric_error

    function void accept_numeric(
        ita_stream_item transaction,
        bit             is_expected
    );
        string          key;
        ita_stream_item snapshot;
        ita_stream_item expected;
        ita_stream_item actual;
        bit             mismatch;

        if ((ref_model == null) || numeric_canceled.exists(transaction.job_id)) begin
            return;
        end

        if (!ita_mha8_ref_model::supported(transaction.step)) begin
            if (!is_expected) begin
                numeric_uncovered++;
            end
            return;
        end

        key = numeric_key(transaction);
        if ((is_expected && expected_seen.exists(key)) ||
            (!is_expected && actual_seen.exists(key))) begin
            numeric_error("ITA_SCB_NUM_DUP", key);
            return;
        end

        snapshot = ita_stream_item::type_id::create("numeric_snapshot");
        snapshot.copy(transaction);
        if (is_expected) begin
            expected_seen[key]    = 1'b1;
            expected_pending[key] = snapshot;
        end
        else begin
            actual_seen[key]    = 1'b1;
            actual_pending[key] = snapshot;
        end

        if (!expected_pending.exists(key) || !actual_pending.exists(key)) begin
            return;
        end

        expected = expected_pending[key];
        actual   = actual_pending[key];
        mismatch = 1'b0;
        for (int unsigned lane = 0; lane < N; lane++) begin
            if (expected.oup[lane] !== actual.oup[lane]) begin
                mismatch = 1'b1;
                if (numeric_failed < 128) begin
                    `uvm_error(
                        "ITA_SCB_NUM_MISMATCH",
                        $sformatf(
                            "%s lane=%0d expected=%0d actual=%0d",
                            key,
                            lane,
                            $signed(expected.oup[lane]),
                            $signed(actual.oup[lane])
                        )
                    )
                end
            end
        end

        if (mismatch) begin
            numeric_failed++;
        end
        else begin
            numeric_matched++;
        end
        expected_pending.delete(key);
        actual_pending.delete(key);
    endfunction : accept_numeric

    task process_expected_fifo();
        ita_stream_item transaction;

        forever begin
            expected_fifo.get(transaction);
            accept_numeric(transaction, 1'b1);
        end
    endtask : process_expected_fifo

    function void cancel_numeric(int unsigned job_id);
        if ((ref_model == null) || numeric_canceled.exists(job_id)) begin
            return;
        end

        numeric_canceled[job_id] = 1'b1;
        numeric_canceled_jobs++;
        ref_model.abort_job(job_id);

        foreach (expected_pending[key]) begin
            if (expected_pending[key].job_id == job_id) begin
                expected_pending.delete(key);
            end
        end
        foreach (actual_pending[key]) begin
            if (actual_pending[key].job_id == job_id) begin
                actual_pending.delete(key);
            end
        end
    endfunction : cancel_numeric

    // Reapply the immutable job snapshot for legacy structural helpers.
    function void select_job(int unsigned job_id);
        ita_ctrl_item job_config;

        if (!job_configs.exists(job_id)) begin
            return;
        end

        job_config        = job_configs[job_id];
        current_job_id    = job_id;
        active_layer      = job_config.ctrl.layer;
        active_activation = job_config.ctrl.activation;
        tile_s            = job_config.ctrl.tile_s;
        tile_e            = job_config.ctrl.tile_e;
        tile_p            = job_config.ctrl.tile_p;
        tile_f            = job_config.ctrl.tile_f;

        pred.tile_s            = tile_s;
        pred.tile_e            = tile_e;
        pred.tile_p            = tile_p;
        pred.tile_f            = tile_f;
        pred.active_layer      = active_layer;
        pred.active_activation = active_activation;
    endfunction : select_job

    function void notify_input_done();
        input_done = 1'b1;
    endfunction : notify_input_done

    function string numerical_status();
        if ((numeric_failed != 0) || (ref_model.errors != 0)) begin
            return "FAIL";
        end
        if ((numeric_matched == 0) && (numeric_canceled_jobs != 0)) begin
            return "CANCELED";
        end
        if (numeric_matched == 0) begin
            return "EMPTY";
        end
        if (numeric_uncovered != 0) begin
            return "PASS_WITH_UNCOVERED_STEPS";
        end
        return "PASS";
    endfunction : numerical_status

    function bit numerical_idle();
        return input_done &&
               (source_fifo.used() == 0) &&
               (output_fifo.used() == 0) &&
               (ctrl_fifo.used() == 0) &&
               (expected_fifo.used() == 0) &&
               !ref_model.pending() &&
               (expected_pending.num() == 0) &&
               (actual_pending.num() == 0) &&
               !(|vif.per_head_busy_o) &&
               !vif.ff_busy_o;
    endfunction : numerical_idle

    task wait_for_drain(int unsigned timeout_cycles);
        if (ref_model == null) begin
            return;
        end

        for (int unsigned cycle = 0; cycle < timeout_cycles; cycle++) begin
            @(negedge vif.clk_i);
            if (numerical_idle()) begin
                return;
            end
        end

        numeric_error(
            "ITA_SCB_NUM_TIMEOUT",
            $sformatf(
                {"input_done=%0b expected_pending=%0d actual_pending=%0d ",
                 "model_pending=%0b source/output/expected FIFO=%0d/%0d/%0d"},
                input_done,
                expected_pending.num(),
                actual_pending.num(),
                ref_model.pending(),
                source_fifo.used(),
                output_fifo.used(),
                expected_fifo.used()
            )
        );
    endtask : wait_for_drain

    function void check_phase(uvm_phase phase);
        super.check_phase(phase);
        if (ref_model == null) begin
            return;
        end

        if (!input_done) begin
            numeric_error(
                "ITA_SCB_NUM_INPUT_END",
                "Input completion was not notified"
            );
        end
        if (ref_model.pending()) begin
            numeric_error(
                "ITA_SCB_NUM_SOURCE_MISSING",
                "Incomplete input tile or missing OW head"
            );
        end
        if (expected_pending.num() != 0) begin
            numeric_error(
                "ITA_SCB_NUM_MISSING",
                $sformatf("Missing %0d actual beats", expected_pending.num())
            );
        end
        if (actual_pending.num() != 0) begin
            numeric_error(
                "ITA_SCB_NUM_EXTRA",
                $sformatf("Unmatched %0d actual beats", actual_pending.num())
            );
        end

        if ((numeric_matched == 0) && (numeric_canceled_jobs == 0)) begin
            numeric_error(
                "ITA_SCB_NUM_EMPTY",
                "Zero matched beats: numerical validation did not pass"
            );
        end
        else if (numeric_matched == 0) begin
            `uvm_info(
                "ITA_SCB_NUM_CANCELED_ONLY",
                "All observed jobs were canceled; no numerical pass is claimed",
                UVM_LOW
            )
        end

        if ((source_fifo.used() + output_fifo.used() + ctrl_fifo.used() +
             expected_fifo.used()) != 0) begin
            numeric_error(
                "ITA_SCB_NUM_FIFO",
                "Unconsumed transactions at end of test"
            );
        end
    endfunction : check_phase
