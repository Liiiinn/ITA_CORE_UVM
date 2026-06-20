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

        forever begin
            seq_item_port.get_next_item(tr);
            if (cfg.direction == ITA_STREAM_SINK) begin
                drive_sink_item(tr);
            end else begin
                drive_source_item(tr);
            end
            seq_item_port.item_done();
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
                cfg.vif.per_head_ready_i[cfg.head_id] <= 1'b1;
            end
            default: ;
        endcase
    endtask : drive_idle

    task drive_source_item(ita_stream_item tr);
        tr.kind = cfg.kind;
        tr.head_id = cfg.head_id;
        issued_ap.write(tr);
        apply_source_metadata(tr);
        wait_stream_prestall();

        case (cfg.kind)
            ITA_STREAM_HEAD_INPUT:  drive_head_input(tr);
            ITA_STREAM_HEAD_WEIGHT: drive_head_weight(tr);
            ITA_STREAM_HEAD_BIAS:   drive_head_bias(tr);
            default: begin
                `uvm_error("STR_DRV_KIND", "Unsupported source stream kind")
            end
        endcase
    endtask : drive_source_item

    task drive_sink_item(ita_stream_item tr);
        tr.kind = cfg.kind;
        tr.head_id = cfg.head_id;
        issued_ap.write(tr);
        wait_stream_prestall();

        if (cfg.kind != ITA_STREAM_HEAD_OUTPUT) begin
            `uvm_error("STR_DRV_KIND", "Sink stream direction is only supported for head output")
            return;
        end

        cfg.vif.per_head_ready_i[cfg.head_id] <= 1'b1;
        @(posedge cfg.vif.clk_i);
    endtask : drive_sink_item

    task wait_stream_prestall();
        int unsigned stall_cycles;

        stall_cycles = cfg.next_stall_cycles();
        repeat (stall_cycles) begin
            @(posedge cfg.vif.clk_i);
        end
    endtask : wait_stream_prestall

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
            default: ;
        endcase
    endtask : apply_source_metadata

    task drive_head_input(ita_stream_item tr);
        cfg.vif.inp_i[cfg.head_id] <= tr.inp;
        cfg.vif.inp_valid_i[cfg.head_id] <= 1'b1;
        do begin
            @(posedge cfg.vif.clk_i);
        end while (!cfg.vif.inp_ready_o[cfg.head_id]);
        cfg.vif.inp_valid_i[cfg.head_id] <= 1'b0;
    endtask : drive_head_input

    task drive_head_weight(ita_stream_item tr);
        cfg.vif.inp_weight_i[cfg.head_id] <= tr.weight;
        cfg.vif.inp_weight_valid_i[cfg.head_id] <= 1'b1;
        do begin
            @(posedge cfg.vif.clk_i);
        end while (!cfg.vif.inp_weight_ready_o[cfg.head_id]);
        cfg.vif.inp_weight_valid_i[cfg.head_id] <= 1'b0;
    endtask : drive_head_weight

    task drive_head_bias(ita_stream_item tr);
        cfg.vif.inp_bias_i[cfg.head_id] <= tr.bias;
        cfg.vif.inp_bias_valid_i[cfg.head_id] <= 1'b1;
        do begin
            @(posedge cfg.vif.clk_i);
        end while (!cfg.vif.inp_bias_ready_o[cfg.head_id]);
        cfg.vif.inp_bias_valid_i[cfg.head_id] <= 1'b0;
    endtask : drive_head_bias

endclass : ita_stream_driver

`endif // ITA_STREAM_DRIVER_SVH
