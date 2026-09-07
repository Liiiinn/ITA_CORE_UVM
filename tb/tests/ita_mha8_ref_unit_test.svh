// Replay PyITA vectors directly into the model, and independent golden outputs
// into the actual side before predictions. No DUT data is used in this test.
class ita_ref_expected_error extends uvm_report_catcher;
    string mode;
    int    hits;

    function new(string name = "ita_ref_expected_error");
        super.new(name);
    endfunction : new

    function action_e catch();
        bit expected_error;

        expected_error = 1'b0;
        case (mode)
            "lane": begin
                expected_error = (get_id() == "ITA_SCB_NUM_MISMATCH");
            end
            "duplicate": begin
                expected_error = (get_id() == "ITA_SCB_NUM_DUP");
            end
            "missing": begin
                expected_error = get_id() inside {
                    "ITA_SCB_NUM_MISSING",
                    "ITA_SCB_NUM_TIMEOUT"
                };
            end
            "source",
            "step": begin
                expected_error = get_id() inside {
                    "ITA_SCB_NUM_SOURCE_MISSING",
                    "ITA_SCB_NUM_EXTRA",
                    "ITA_SCB_NUM_TIMEOUT"
                };
            end
            "extra": begin
                expected_error = get_id() inside {
                    "ITA_SCB_NUM_EXTRA",
                    "ITA_SCB_NUM_TIMEOUT"
                };
            end
        endcase

        if (expected_error && (get_severity() == UVM_ERROR)) begin
            hits++;
            set_severity(UVM_INFO);
        end
        return THROW;
    endfunction : catch
endclass : ita_ref_expected_error


class ita_mha8_ref_unit_test extends uvm_test;
    `uvm_component_utils(ita_mha8_ref_unit_test)

    ita_mha8_ref_model model;
    ita_mha8_scoreboard scb;
    ita_mha8_predictor  pred;

    virtual ita_mha8_if vif;

    ita_ref_expected_error catcher;
    string                 fault;
    string                 vectors;

    function new(
        string        name   = "ita_mha8_ref_unit_test",
        uvm_component parent = null
    );
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(virtual ita_mha8_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("UNIT_VIF", "Missing vif")
        end

        model = ita_mha8_ref_model::type_id::create("model", this);
        pred  = ita_mha8_predictor::type_id::create("pred", this);
        scb   = ita_mha8_scoreboard::type_id::create("scb", this);

        scb.pred      = pred;
        scb.ref_model = model;
        scb.vif       = vif;

        void'($value$plusargs("ITA_REF_UNIT_FAULT=%s", fault));
        if (!$value$plusargs("ITA_REF_UNIT_VECTORS=%s", vectors)) begin
            `uvm_fatal("UNIT_FILE", "Missing ITA_REF_UNIT_VECTORS")
        end

        catcher      = new;
        catcher.mode = fault;
        uvm_report_cb::add(null, catcher);
    endfunction : build_phase

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        model.expected_ap.connect(scb.expected_export);
    endfunction : connect_phase

    task run_phase(uvm_phase phase);
        int file_descriptor;
        int parsed_fields;
        int job_id;
        int stream_kind;
        int step;
        int head_id;
        int tile_id;
        int inner_tile_id;
        int beat_id;
        int activation;
        int tile_s;
        int tile_e;
        int tile_p;
        int tile_f;
        int gelu_b;
        int gelu_c;
        int activation_mult;
        int activation_shift;
        int activation_add;
        int sum_mult;
        int sum_shift;
        int sum_add;
        int requant_index;
        int multiplier;
        int right_shift;
        int addend;

        longint signed scalar_input;
        longint signed golden;
        longint signed actual;

        logic [511:0] payload;

        string line;
        string tag;

        ita_ctrl_item   control;
        ita_stream_item transaction;
        ita_stream_item transaction_copy;
        bit             injected;

        phase.raise_objection(this);

        file_descriptor = $fopen(vectors, "r");
        if (!file_descriptor) begin
            `uvm_fatal("UNIT_FILE", vectors)
        end

        while ($fgets(line, file_descriptor)) begin
            parsed_fields = $sscanf(line, "%s", tag);
            case (tag)
                "C": begin
                    parsed_fields = $sscanf(
                        line,
                        "C %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d",
                        job_id,
                        activation,
                        tile_s,
                        tile_e,
                        tile_p,
                        tile_f,
                        gelu_b,
                        gelu_c,
                        activation_mult,
                        activation_shift,
                        activation_add,
                        sum_mult,
                        sum_shift,
                        sum_add,
                        stream_kind
                    );
                    if (parsed_fields != 15) begin
                        `uvm_fatal("UNIT_PARSE", line)
                    end

                    control = ita_ctrl_item::type_id::create("control");
                    control.job_id = job_id;
                    control.ctrl.layer      = layer_e'(stream_kind);
                    control.ctrl.activation = activation_e'(activation);
                    control.ctrl.tile_s = tile_s;
                    control.ctrl.tile_e = tile_e;
                    control.ctrl.tile_p = tile_p;
                    control.ctrl.tile_f = tile_f;
                    control.ctrl.gelu_b = gelu_b;
                    control.ctrl.gelu_c = gelu_c;
                    control.ctrl.activation_requant_mult  = activation_mult;
                    control.ctrl.activation_requant_shift = activation_shift;
                    control.ctrl.activation_requant_add   = activation_add;
                    control.sum_eps_mult    = sum_mult;
                    control.sum_right_shift = sum_shift;
                    control.sum_add         = sum_add;
                end

                "R": begin
                    parsed_fields = $sscanf(
                        line,
                        "R %d %d %d %d %d",
                        head_id,
                        requant_index,
                        multiplier,
                        right_shift,
                        addend
                    );
                    if (parsed_fields != 5) begin
                        `uvm_fatal("UNIT_PARSE", line)
                    end

                    if (head_id == 8) begin
                        control.ff_eps_mult[requant_index]    = multiplier;
                        control.ff_right_shift[requant_index] = right_shift;
                        control.ff_add[requant_index]         = addend;
                    end
                    else begin
                        control.head_eps_mult[head_id][requant_index] = multiplier;
                        control.head_right_shift[head_id][requant_index] =
                            right_shift;
                        control.head_add[head_id][requant_index] = addend;
                    end
                end

                "G": begin
                    // Replay manifests contain the complete supported linear
                    // subset for the selected layer.
                    if (control.ctrl.layer == Feedforward) begin
                        control.expected_step_mask[F1] = 1'b1;
                        control.expected_step_mask[F2] = 1'b1;
                    end
                    else begin
                        control.expected_step_mask[Q]  = 1'b1;
                        control.expected_step_mask[K]  = 1'b1;
                        control.expected_step_mask[V]  = 1'b1;
                        control.expected_step_mask[OW] = 1'b1;
                    end
                    model.write_ref_ctrl(control);

                    // Exercise immutable control snapshots after publication.
                    control.ctrl.tile_e   = 99;
                    control.head_eps_mult = '{default: '0};
                end

                "A": begin
                    parsed_fields = $sscanf(
                        line,
                        "A %d %d %d %d %d",
                        scalar_input,
                        multiplier,
                        right_shift,
                        addend,
                        golden
                    );
                    actual = model.requant(
                        scalar_input,
                        multiplier,
                        right_shift,
                        addend
                    );
                    if (actual != golden) begin
                        `uvm_fatal(
                            "UNIT_ARITH",
                            $sformatf("%s got=%0d", line, actual)
                        )
                    end
                end

                "L": begin
                    parsed_fields = $sscanf(
                        line,
                        "L %d %d",
                        scalar_input,
                        golden
                    );
                    if (model.clip_acc(scalar_input) != golden) begin
                        `uvm_fatal("UNIT_CLIP", line)
                    end
                end

                "T": begin
                    parsed_fields = $sscanf(
                        line,
                        "T %d %d %d %d %d %d %d %d",
                        scalar_input,
                        activation,
                        gelu_b,
                        gelu_c,
                        multiplier,
                        right_shift,
                        addend,
                        golden
                    );
                    control = ita_ctrl_item::type_id::create("activation");
                    control.ctrl.activation = activation_e'(activation);
                    control.ctrl.gelu_b = gelu_b;
                    control.ctrl.gelu_c = gelu_c;
                    control.ctrl.activation_requant_mult  = multiplier;
                    control.ctrl.activation_requant_shift = right_shift;
                    control.ctrl.activation_requant_add   = addend;
                    if (model.activate(scalar_input, control.ctrl) != golden) begin
                        `uvm_fatal("UNIT_ACT", line)
                    end
                end

                "S",
                "E": begin
                    parsed_fields = $sscanf(
                        line,
                        "%s %d %d %d %d %d %d %d %h",
                        tag,
                        job_id,
                        stream_kind,
                        step,
                        head_id,
                        tile_id,
                        inner_tile_id,
                        beat_id,
                        payload
                    );
                    if (parsed_fields != 9) begin
                        `uvm_fatal("UNIT_PARSE", line)
                    end

                    transaction = ita_stream_item::type_id::create("transaction");
                    transaction.job_id       = job_id;
                    transaction.kind         = ita_stream_kind_e'(stream_kind);
                    transaction.step         = step_e'(step);
                    transaction.head_id      = head_id;
                    transaction.tile_id      = tile_id;
                    transaction.inner_tile_id = inner_tile_id;
                    transaction.beat_id      = beat_id;
                    transaction.inp          = inp_t'(payload);
                    transaction.weight       = inp_weight_t'(payload);
                    transaction.bias         = bias_t'(payload);
                    transaction.oup          = requant_oup_t'(payload);

                    if (tag == "E") begin
                        if (!injected && (fault == "lane")) begin
                            transaction.oup[0] ^= 1'b1;
                            injected = 1'b1;
                        end
                        if (!injected && (fault == "missing")) begin
                            injected = 1'b1;
                            continue;
                        end

                        scb.accept_numeric(transaction, 1'b0);
                        if (!injected && (fault == "duplicate")) begin
                            scb.accept_numeric(transaction, 1'b0);
                            injected = 1'b1;
                        end
                        if (!injected && (fault == "extra")) begin
                            transaction_copy =
                                ita_stream_item::type_id::create("extra");
                            transaction_copy.copy(transaction);
                            transaction_copy.beat_id = 999;
                            scb.accept_numeric(transaction_copy, 1'b0);
                            injected = 1'b1;
                        end
                    end
                    else begin
                        if ((fault == "step") && (step == int'(F2))) begin
                            continue;
                        end
                        if (!injected && (fault == "source") && (job_id != 99)) begin
                            injected = 1'b1;
                            continue;
                        end

                        model.write_ref_stream(transaction);

                        // Exercise source snapshot ownership too.
                        transaction.inp    = 'x;
                        transaction.weight = 'x;
                        transaction.bias   = 'x;
                    end
                end

                "X": begin
                    parsed_fields = $sscanf(line, "X %d", job_id);
                    scb.cancel_numeric(job_id);
                end

                default: begin
                    `uvm_fatal("UNIT_PARSE", line)
                end
            endcase
        end

        $fclose(file_descriptor);
        scb.notify_input_done();
        scb.wait_for_drain(10);
        phase.drop_objection(this);
    endtask : run_phase

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        if ((fault != "") && (catcher.hits == 0)) begin
            `uvm_error("UNIT_FAULT", "Requested fault was not detected")
        end
        `uvm_info(
            "UNIT_RESULT",
            $sformatf("fault=%s detections=%0d", fault, catcher.hits),
            UVM_LOW
        )
    endfunction : report_phase
endclass : ita_mha8_ref_unit_test
