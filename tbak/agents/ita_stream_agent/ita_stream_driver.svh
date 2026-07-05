`ifndef ITA_STREAM_DRIVER_SVH
`define ITA_STREAM_DRIVER_SVH

class ita_stream_driver extends uvm_driver #(ita_stream_item);
    `uvm_component_utils(ita_stream_driver)

    ita_stream_config cfg;

    function new(string name = "ita_stream_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(ita_stream_config)::get(this, "", "cfg", cfg)) begin
            `uvm_fatal("STR_DRV_CFG", "ita_stream_config was not set")
        end
    endfunction : build_phase

    task run_phase(uvm_phase phase);
        ita_stream_item tr;
        int unsigned wait_cycles;

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

        wait_cycles = 0;
        while (!cfg.vif.inp_ready_o[cfg.head_id] || ! cfg.vif.inp_weight_ready_o[cfg.head_id] || !cfg.vif.inp_bias_ready_o[cfg.head_id]) begin
            @ (posedge cfg.vif.clk_i);
            wait_cycles ++;
            if (wait_cycles > 10000) begin
                `uvm_fatal("STREAM DRV", "Timeout wait for ready out");
            end
        end
    endtask : run_phase

    task drive_idle();
        // Stage 3: idle head0 input stream pins before source driving is implemented.
        // Stage 4: idle head0 weight/bias stream pins before those sources are implemented.
        // Stage 5: idle head0 output ready before sink driving is implemented.
        // Stage 11: idle sum and feed-forward pins before those paths are implemented.
        case(cfg.kind)
            ITA_STREAM_HEAD_INPUT:
            begin
                cfg.vif.inp_valid_i[cfg.head_id] <= 1'b0;
                cfg.vif.inp_i[cfg.head_id] <= '0;
            end
            ITA_STREAM_HEAD_WEIGHT:
            begin
                cfg.vif.inp_weight_valid_i[cfg.head_id] <= 1'b0;
                cfg.vif.inp_weight_i[cfg.head_id] <= '0;
            end
            ITA_STREAM_HEAD_BIAS:
            begin
                cfg.vif.inp_bias_valid_i[cfg.head_id] <= 1'b0;
                cfg.vif.inp_bias_i[cfg.head_id] <= '0;
            end
            ITA_STREAM_HEAD_OUTPUT:
            begin
                cfg.vif.per_head_ready_i[cfg.head_id] <= 1'b0;
            end
            ITA_STREAM_SUM_OUTPUT:
            begin
                cfg.vif.sum_ready_i <= 1'b0;
            end
            ITA_STREAM_FF_OUTPUT:
            begin
                cfg.vif.ff_ready_i <= 1'b0;
            end
            ITA_STREAM_FF_INPUT:
            begin
                cfg.vif.ff_inp_valid_i <= 1'b0;
                cfg.vif.ff_inp_i <= '0;
            end
            ITA_STREAM_FF_WEIGHT:
            begin
                cfg.vif.ff_inp_weight_valid_i <= 1'b0;
                cfg.vif.ff_inp_weight_i <= '0;
            end
            ITA_STREAM_FF_BIAS:
            begin
                cfg.vif.ff_inp_bias_valid_i <= 1'b0;
                cfg.vif.ff_inp_bias_i <= '0;
            end
        endcase
    endtask : drive_idle

    task drive_sink_ready();
        int unsigned high_cycles;
        int unsigned low_cycles;

        drive_sink_ready_value(1'b0);

        wait (cfg.vif.rst_ni == 1'b1);
        forever begin
            high_cycles = cfg.next_ready_high_cycles();
            repeat (high_cycles) begin
                @(posedge cfg.vif.clk_i);
                drive_sink_ready_value(1'b1);
            end

            low_cycles = cfg.next_ready_low_cycles();
            repeat (low_cycles) begin
                @(posedge cfg.vif.clk_i);
                drive_sink_ready_value(1'b0);
            end
        end
    endtask : drive_sink_ready

    task drive_sink_ready_value(bit ready_value);
        case (cfg.kind)
            ITA_STREAM_HEAD_OUTPUT:
                cfg.vif.per_head_ready_i[cfg.head_id] <= ready_value;
            ITA_STREAM_SUM_OUTPUT:
                cfg.vif.sum_ready_i <= ready_value;
            ITA_STREAM_FF_OUTPUT:
                cfg.vif.ff_ready_i <= ready_value;
            default:
                `uvm_error("STREAM DRV", "drive_sink_ready_value called for non-output stream")
        endcase
    endtask : drive_sink_ready_value

    task wait_source_gap();
        int unsigned gap_cycles;

        gap_cycles = cfg.next_source_gap_cycles();
        repeat (gap_cycles) begin
            @(posedge cfg.vif.clk_i);
        end
    endtask : wait_source_gap

    task drive_source_item(ita_stream_item tr);
        if (tr.kind != cfg.kind || tr.head_id != cfg.head_id)
            `uvm_error("STREAM_DRV", "item kind/head_id doesn't match with driver config!")
        // Stage 3: implement head0 input source driving.
        // Stage 4: implement head0 weight and bias source driving.

        case (cfg.kind)
            ITA_STREAM_HEAD_INPUT:  drive_head_input(tr);
            ITA_STREAM_HEAD_WEIGHT: drive_head_weight(tr);
            ITA_STREAM_HEAD_BIAS:   drive_head_bias(tr);
            ITA_STREAM_FF_INPUT:    drive_ff_input(tr);
            ITA_STREAM_FF_WEIGHT:   drive_ff_weight(tr);
            ITA_STREAM_FF_BIAS:     drive_ff_bias(tr);
            default: 
                `uvm_error("STREAM DRV", $sformatf("Unsupporetd source stream kind %s", cfg.kind.name()))
        endcase
    endtask : drive_source_item

    task drive_head_input(ita_stream_item tr);
        int unsigned wait_cycles;

        wait_source_gap();
        @(posedge cfg.vif.clk_i);
        // Stage 3: drive inp_i/inp_valid_i for head0 and wait for inp_ready_o.
        cfg.vif.inp_i[cfg.head_id] <= tr.inp;
        cfg.vif.inp_valid_i[cfg.head_id] <= 1'b1;
        cfg.vif.inp_step_dbg[cfg.head_id] <= tr.step;
        cfg.vif.inp_tile_id_dbg[cfg.head_id] <= tr.tile_id;
        cfg.vif.inp_inner_id_dbg[cfg.head_id] <= tr.inner_tile_id;
        cfg.vif.inp_beat_id_dbg[cfg.head_id] <= tr.beat_id;
        cfg.vif.inp_lockstep_dbg[cfg.head_id] <= tr.is_lockstep;

        wait_cycles = 0;
        do begin
            @(posedge cfg.vif.clk_i);
            wait_cycles++;
            if (wait_cycles > 10000)
                `uvm_fatal("STREAM_DRV", "timeout waiting for inp_ready_o")
        end while (!cfg.vif.inp_ready_o[cfg.head_id]);

        cfg.vif.inp_valid_i[cfg.head_id] <= 1'b0;
        // do begin
        //     @(posedge cfg.vif.clk_i);
        // end while (!cfg.vif.inp_ready_o[cfg.head_id]);
        // cfg.vif.inp_valid_i[cfg.head_id] <= 1'b0;
    endtask : drive_head_input

    task drive_head_weight(ita_stream_item tr);
        int unsigned wait_cycles;
        wait_source_gap();
        @(posedge cfg.vif.clk_i);
        // Stage 4: drive inp_weight_i/inp_weight_valid_i for head0 and wait for inp_weight_ready_o.
        cfg.vif.inp_weight_i[cfg.head_id] <= tr.weight;
        cfg.vif.inp_weight_valid_i[cfg.head_id] <= 1'b1;
        cfg.vif.inp_weight_step_dbg[cfg.head_id] <= tr.step;
        cfg.vif.inp_weight_tile_id_dbg[cfg.head_id] <= tr.tile_id;
        cfg.vif.inp_weight_inner_id_dbg[cfg.head_id] <= tr.inner_tile_id;
        cfg.vif.inp_weight_beat_id_dbg[cfg.head_id] <= tr.beat_id;
        cfg.vif.inp_weight_lockstep_dbg[cfg.head_id] <= tr.is_lockstep;

        wait_cycles = 0;
        do begin
            @(posedge cfg.vif.clk_i);
            wait_cycles++;
            if (wait_cycles > 10000)
                `uvm_fatal("STREAM_DRV", "timeout waiting for inp_weight_ready_o")
        end while (!cfg.vif.inp_weight_ready_o[cfg.head_id]);

        cfg.vif.inp_weight_valid_i[cfg.head_id] <= 1'b0;

        // do begin
        //     @ (posedge cfg.vif.clk_i);
        // end while (!cfg.vif.inp_weight_ready_o[cfg.head_id]);
        // cfg.vif.inp_weight_valid_i[cfg.head_id] <= 1'b0;
    endtask : drive_head_weight

    task drive_head_bias(ita_stream_item tr);
        int unsigned wait_cycles;
        wait_source_gap();
        @(posedge cfg.vif.clk_i);
        // Stage 4: drive inp_bias_i/inp_bias_valid_i for head0 and wait for inp_bias_ready_o.
        cfg.vif.inp_bias_i[cfg.head_id] <= tr.bias;
        cfg.vif.inp_bias_valid_i[cfg.head_id] <= 1'b1;
        cfg.vif.inp_bias_step_dbg[cfg.head_id] <= tr.step;
        cfg.vif.inp_bias_tile_id_dbg[cfg.head_id] <= tr.tile_id;
        cfg.vif.inp_bias_inner_id_dbg[cfg.head_id] <= tr.inner_tile_id;
        cfg.vif.inp_bias_beat_id_dbg[cfg.head_id] <= tr.beat_id;
        cfg.vif.inp_bias_lockstep_dbg[cfg.head_id] <= tr.is_lockstep;

        wait_cycles = 0;
        do begin
            @(posedge cfg.vif.clk_i);
            wait_cycles++;
            if (wait_cycles > 10000)
                `uvm_fatal("STREAM_DRV", "timeout waiting for inp_bias_ready_o")
        end while (!cfg.vif.inp_bias_ready_o[cfg.head_id]);
        // do begin
        //     @ (posedge cfg.vif.clk_i);
        // end while (!cfg.vif.inp_bias_ready_o[cfg.head_id]);
        cfg.vif.inp_bias_valid_i[cfg.head_id] <= 1'b0;
    endtask : drive_head_bias

    task drive_ff_input(ita_stream_item tr);
        int unsigned wait_cycles;
        wait_source_gap();
        @(posedge cfg.vif.clk_i);
        // Stage 11: drive feed-forward input stream after the head0 MHA path is complete.
        cfg.vif.ff_inp_i <= tr.inp;
        cfg.vif.ff_inp_valid_i <= 1'b1;
        cfg.vif.ff_inp_step_dbg <= tr.step;
        cfg.vif.ff_inp_tile_id_dbg <= tr.tile_id;
        cfg.vif.ff_inp_inner_id_dbg <= tr.inner_tile_id;
        cfg.vif.ff_inp_beat_id_dbg <= tr.beat_id;
        cfg.vif.ff_inp_lockstep_dbg <= tr.is_lockstep;

        wait_cycles = 0;
        do begin
            @(posedge cfg.vif.clk_i);
            wait_cycles++;
            if (wait_cycles > 10000)
                `uvm_fatal("STREAM_DRV", "timeout waiting for ff_inp_ready_o")
        end while (!cfg.vif.ff_inp_ready_o);
        cfg.vif.ff_inp_valid_i <= 1'b0;
    endtask : drive_ff_input

    task drive_ff_weight(ita_stream_item tr);
        int unsigned wait_cycles;
        wait_source_gap();
        @(posedge cfg.vif.clk_i);
        // Stage 11: drive feed-forward weight stream after the head0 MHA path is complete.
        cfg.vif.ff_inp_weight_i <= tr.weight;
        cfg.vif.ff_inp_weight_valid_i <= 1'b1;
        cfg.vif.ff_inp_weight_step_dbg <= tr.step;
        cfg.vif.ff_inp_weight_tile_id_dbg <= tr.tile_id;
        cfg.vif.ff_inp_weight_inner_id_dbg <= tr.inner_tile_id;
        cfg.vif.ff_inp_weight_beat_id_dbg <= tr.beat_id;
        cfg.vif.ff_inp_weight_lockstep_dbg <= tr.is_lockstep;

        wait_cycles = 0;
        do begin
            @(posedge cfg.vif.clk_i);
            wait_cycles++;
            if (wait_cycles > 10000)
                `uvm_fatal("STREAM_DRV", "timeout waiting for ff_inp__weight_ready_o")
        end while (!cfg.vif.ff_inp_weight_ready_o);
        cfg.vif.ff_inp_weight_valid_i <= 1'b0;
    endtask : drive_ff_weight

    task drive_ff_bias(ita_stream_item tr);
        int unsigned wait_cycles;
        wait_source_gap();
        @(posedge cfg.vif.clk_i);
        // Stage 11: drive feed-forward bias stream after the head0 MHA path is complete.
        cfg.vif.ff_inp_bias_i <= tr.bias;
        cfg.vif.ff_inp_bias_valid_i <= 1'b1;
        cfg.vif.ff_inp_bias_step_dbg <= tr.step;
        cfg.vif.ff_inp_bias_tile_id_dbg <= tr.tile_id;
        cfg.vif.ff_inp_bias_inner_id_dbg <= tr.inner_tile_id;
        cfg.vif.ff_inp_bias_beat_id_dbg <= tr.beat_id;
        cfg.vif.ff_inp_bias_lockstep_dbg <= tr.is_lockstep;

        wait_cycles = 0;
        do begin
            @(posedge cfg.vif.clk_i);
            wait_cycles++;
            if (wait_cycles > 10000)
                `uvm_fatal("STREAM_DRV", "timeout waiting for ff_inp_bias_ready_o")
        end while (!cfg.vif.ff_inp_bias_ready_o);
        cfg.vif.ff_inp_bias_valid_i <= 1'b0;
    endtask : drive_ff_bias

endclass : ita_stream_driver

`endif // ITA_STREAM_DRIVER_SVH
