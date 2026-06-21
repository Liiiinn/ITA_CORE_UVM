`ifndef ITA_STREAM_DRIVER_SVH
`define ITA_STREAM_DRIVER_SVH

class ita_stream_driver extends uvm_driver #(ita_stream_item);
    `uvm_component_utils(ita_stream_driver)

    ita_stream_config cfg;
    uvm_analysis_port #(ita_stream_item) issued_ap;

    function new(string name = "ita_stream_driver", uvm_component parent = null);
        super.new(name, parent);
        issued_ap = new("issued_ap", this);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(ita_stream_config)::get(this, "", "cfg", cfg)) begin
            `uvm_fatal("STR_DRV_CFG", "ita_stream_config was not set")
        end
    endfunction : build_phase

    task run_phase(uvm_phase phase);
        ita_stream_item tr;

        drive_idle();
        wait (cfg.vif.rst_ni === 1'b1);

        if (cfg.is_sink()) begin
            drive_sink_ready();
        end else begin
            forever begin
                seq_item_port.get_next_item(tr);
                drive_source_item(tr);
                seq_item_port.item_done();
            end
        end
    endtask : run_phase

    task drive_idle();
        case (cfg.kind)
            ITA_STREAM_HEAD_INPUT: begin
                cfg.vif.inp_valid_i[cfg.head_id] <= 1'b0;
                cfg.vif.inp_i[cfg.head_id] <= '0;
            end
            ITA_STREAM_HEAD_WEIGHT: begin
                cfg.vif.inp_weight_valid_i[cfg.head_id] <= 1'b0;
                cfg.vif.inp_weight_i[cfg.head_id] <= '0;
            end
            ITA_STREAM_HEAD_BIAS: begin
                cfg.vif.inp_bias_valid_i[cfg.head_id] <= 1'b0;
                cfg.vif.inp_bias_i[cfg.head_id] <= '0;
            end
            ITA_STREAM_HEAD_OUTPUT: begin
                cfg.vif.per_head_ready_i[cfg.head_id] <= 1'b0;
            end
            ITA_STREAM_SUM_OUTPUT: begin
                cfg.vif.sum_ready_i <= 1'b0;
            end
            ITA_STREAM_FF_INPUT: begin
                cfg.vif.ff_inp_valid_i <= 1'b0;
                cfg.vif.ff_inp_i <= '0;
            end
            ITA_STREAM_FF_WEIGHT: begin
                cfg.vif.ff_inp_weight_valid_i <= 1'b0;
                cfg.vif.ff_inp_weight_i <= '0;
            end
            ITA_STREAM_FF_BIAS: begin
                cfg.vif.ff_inp_bias_valid_i <= 1'b0;
                cfg.vif.ff_inp_bias_i <= '0;
            end
            ITA_STREAM_FF_OUTPUT: begin
                cfg.vif.ff_ready_i <= 1'b0;
            end
            default: ;
        endcase
        // TODO Stage 1: keep non-target streams idle during baseline smoke.
    endtask : drive_idle

    task drive_sink_ready();
        forever begin
            @(posedge cfg.vif.clk_i);
            case (cfg.kind)
                ITA_STREAM_HEAD_OUTPUT: cfg.vif.per_head_ready_i[cfg.head_id] <= sink_ready_value();
                ITA_STREAM_SUM_OUTPUT:  cfg.vif.sum_ready_i <= sink_ready_value();
                ITA_STREAM_FF_OUTPUT:   cfg.vif.ff_ready_i <= sink_ready_value();
                default: ;
            endcase
        end
        // TODO Stage 5: start with deterministic ready on head_output_agt[0], then add backpressure cases.
    endtask : drive_sink_ready

    function bit sink_ready_value();
        if (!cfg.enable_random_stall) begin
            return 1'b1;
        end
        return ($urandom_range(cfg.max_stall_cycles + 1, 0) == 0);
    endfunction : sink_ready_value

    task drive_source_item(ita_stream_item tr);
        tr.kind = cfg.kind;
        tr.head_id = cfg.head_id;
        issued_ap.write(tr);
        apply_source_metadata(tr);
        wait_source_prestall();

        case (cfg.kind)
            ITA_STREAM_HEAD_INPUT:  drive_head_input(tr);
            ITA_STREAM_HEAD_WEIGHT: drive_head_weight(tr);
            ITA_STREAM_HEAD_BIAS:   drive_head_bias(tr);
            ITA_STREAM_FF_INPUT:    drive_ff_input(tr);
            ITA_STREAM_FF_WEIGHT:   drive_ff_weight(tr);
            ITA_STREAM_FF_BIAS:     drive_ff_bias(tr);
            default: begin
                `uvm_error("STR_DRV_KIND", "Unsupported source stream kind")
            end
        endcase
        // TODO Stage 3-4: drive head0 input first, then weight/bias, before enabling ff source paths.
    endtask : drive_source_item

    task wait_source_prestall();
        int unsigned stall_cycles;

        stall_cycles = cfg.next_stall_cycles();
        repeat (stall_cycles) begin
            @(posedge cfg.vif.clk_i);
        end
    endtask : wait_source_prestall

    task apply_source_metadata(ita_stream_item tr);
        case (cfg.kind)
            ITA_STREAM_HEAD_INPUT: begin
                cfg.vif.inp_step_dbg[cfg.head_id] = tr.step;
                cfg.vif.inp_tile_id_dbg[cfg.head_id] = tr.tile_id;
                cfg.vif.inp_inner_id_dbg[cfg.head_id] = tr.inner_tile_id;
                cfg.vif.inp_beat_id_dbg[cfg.head_id] = tr.beat_id;
                cfg.vif.inp_lockstep_dbg[cfg.head_id] = tr.is_lockstep;
            end
            ITA_STREAM_HEAD_WEIGHT: begin
                cfg.vif.inp_weight_step_dbg[cfg.head_id] = tr.step;
                cfg.vif.inp_weight_tile_id_dbg[cfg.head_id] = tr.tile_id;
                cfg.vif.inp_weight_inner_id_dbg[cfg.head_id] = tr.inner_tile_id;
                cfg.vif.inp_weight_beat_id_dbg[cfg.head_id] = tr.beat_id;
                cfg.vif.inp_weight_lockstep_dbg[cfg.head_id] = tr.is_lockstep;
            end
            ITA_STREAM_HEAD_BIAS: begin
                cfg.vif.inp_bias_step_dbg[cfg.head_id] = tr.step;
                cfg.vif.inp_bias_tile_id_dbg[cfg.head_id] = tr.tile_id;
                cfg.vif.inp_bias_inner_id_dbg[cfg.head_id] = tr.inner_tile_id;
                cfg.vif.inp_bias_beat_id_dbg[cfg.head_id] = tr.beat_id;
                cfg.vif.inp_bias_lockstep_dbg[cfg.head_id] = tr.is_lockstep;
            end
            ITA_STREAM_FF_INPUT: begin
                cfg.vif.ff_inp_step_dbg = tr.step;
                cfg.vif.ff_inp_tile_id_dbg = tr.tile_id;
                cfg.vif.ff_inp_inner_id_dbg = tr.inner_tile_id;
                cfg.vif.ff_inp_beat_id_dbg = tr.beat_id;
                cfg.vif.ff_inp_lockstep_dbg = tr.is_lockstep;
            end
            ITA_STREAM_FF_WEIGHT: begin
                cfg.vif.ff_inp_weight_step_dbg = tr.step;
                cfg.vif.ff_inp_weight_tile_id_dbg = tr.tile_id;
                cfg.vif.ff_inp_weight_inner_id_dbg = tr.inner_tile_id;
                cfg.vif.ff_inp_weight_beat_id_dbg = tr.beat_id;
                cfg.vif.ff_inp_weight_lockstep_dbg = tr.is_lockstep;
            end
            ITA_STREAM_FF_BIAS: begin
                cfg.vif.ff_inp_bias_step_dbg = tr.step;
                cfg.vif.ff_inp_bias_tile_id_dbg = tr.tile_id;
                cfg.vif.ff_inp_bias_inner_id_dbg = tr.inner_tile_id;
                cfg.vif.ff_inp_bias_beat_id_dbg = tr.beat_id;
                cfg.vif.ff_inp_bias_lockstep_dbg = tr.is_lockstep;
            end
            default: ;
        endcase
        // TODO Stage 7-8: keep metadata stable for logger and smoke scoreboard attribution.
    endtask : apply_source_metadata

    task drive_head_input(ita_stream_item tr);
        cfg.vif.inp_i[cfg.head_id] <= tr.inp;
        cfg.vif.inp_valid_i[cfg.head_id] <= 1'b1;
        do begin
            @(posedge cfg.vif.clk_i);
        end while (!cfg.vif.inp_ready_o[cfg.head_id]);
        cfg.vif.inp_valid_i[cfg.head_id] <= 1'b0;
        // TODO Stage 3: use this path for input_agt[0] before any other source stream.
    endtask : drive_head_input

    task drive_head_weight(ita_stream_item tr);
        cfg.vif.inp_weight_i[cfg.head_id] <= tr.weight;
        cfg.vif.inp_weight_valid_i[cfg.head_id] <= 1'b1;
        do begin
            @(posedge cfg.vif.clk_i);
        end while (!cfg.vif.inp_weight_ready_o[cfg.head_id]);
        cfg.vif.inp_weight_valid_i[cfg.head_id] <= 1'b0;
        // TODO Stage 4: add weight payload ordering for head0 Linear directed testcase.
    endtask : drive_head_weight

    task drive_head_bias(ita_stream_item tr);
        cfg.vif.inp_bias_i[cfg.head_id] <= tr.bias;
        cfg.vif.inp_bias_valid_i[cfg.head_id] <= 1'b1;
        do begin
            @(posedge cfg.vif.clk_i);
        end while (!cfg.vif.inp_bias_ready_o[cfg.head_id]);
        cfg.vif.inp_bias_valid_i[cfg.head_id] <= 1'b0;
        // TODO Stage 4: add bias payload ordering for head0 Linear directed testcase.
    endtask : drive_head_bias

    task drive_ff_input(ita_stream_item tr);
        cfg.vif.ff_inp_i <= tr.inp;
        cfg.vif.ff_inp_valid_i <= 1'b1;
        do begin
            @(posedge cfg.vif.clk_i);
        end while (!cfg.vif.ff_inp_ready_o);
        cfg.vif.ff_inp_valid_i <= 1'b0;
    endtask : drive_ff_input

    task drive_ff_weight(ita_stream_item tr);
        cfg.vif.ff_inp_weight_i <= tr.weight;
        cfg.vif.ff_inp_weight_valid_i <= 1'b1;
        do begin
            @(posedge cfg.vif.clk_i);
        end while (!cfg.vif.ff_inp_weight_ready_o);
        cfg.vif.ff_inp_weight_valid_i <= 1'b0;
    endtask : drive_ff_weight

    task drive_ff_bias(ita_stream_item tr);
        cfg.vif.ff_inp_bias_i <= tr.bias;
        cfg.vif.ff_inp_bias_valid_i <= 1'b1;
        do begin
            @(posedge cfg.vif.clk_i);
        end while (!cfg.vif.ff_inp_bias_ready_o);
        cfg.vif.ff_inp_bias_valid_i <= 1'b0;
    endtask : drive_ff_bias

endclass : ita_stream_driver

`endif // ITA_STREAM_DRIVER_SVH
