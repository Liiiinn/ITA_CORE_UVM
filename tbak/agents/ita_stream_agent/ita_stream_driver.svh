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
        // TODO Stage 3-5: keep all stream pins idle until each stream exercise is implemented.
    endtask : drive_idle

    task drive_sink_ready();
        forever begin
            @(posedge cfg.vif.clk_i);
            // TODO Stage 5: drive head0 output ready, then add deterministic and random backpressure modes.
        end
    endtask : drive_sink_ready

    task drive_source_item(ita_stream_item tr);
        tr.kind = cfg.kind;
        tr.head_id = cfg.head_id;
        // TODO Stage 7: publish issued_ap only after the source transaction format is stable.
        // TODO Stage 3: implement head0 input source driving.
        // TODO Stage 4: implement head0 weight and bias source driving.

        case (cfg.kind)
            ITA_STREAM_HEAD_INPUT:  drive_head_input(tr);
            ITA_STREAM_HEAD_WEIGHT: drive_head_weight(tr);
            ITA_STREAM_HEAD_BIAS:   drive_head_bias(tr);
            ITA_STREAM_FF_INPUT:    drive_ff_input(tr);
            ITA_STREAM_FF_WEIGHT:   drive_ff_weight(tr);
            ITA_STREAM_FF_BIAS:     drive_ff_bias(tr);
            default: ;
        endcase
    endtask : drive_source_item

    task drive_head_input(ita_stream_item tr);
        @(posedge cfg.vif.clk_i);
        // TODO Stage 3: drive inp_i/inp_valid_i for head0 and wait for inp_ready_o.
    endtask : drive_head_input

    task drive_head_weight(ita_stream_item tr);
        @(posedge cfg.vif.clk_i);
        // TODO Stage 4: drive inp_weight_i/inp_weight_valid_i for head0 and wait for inp_weight_ready_o.
    endtask : drive_head_weight

    task drive_head_bias(ita_stream_item tr);
        @(posedge cfg.vif.clk_i);
        // TODO Stage 4: drive inp_bias_i/inp_bias_valid_i for head0 and wait for inp_bias_ready_o.
    endtask : drive_head_bias

    task drive_ff_input(ita_stream_item tr);
        @(posedge cfg.vif.clk_i);
        // TODO Stage 11: drive feed-forward input stream after the head0 MHA path is complete.
    endtask : drive_ff_input

    task drive_ff_weight(ita_stream_item tr);
        @(posedge cfg.vif.clk_i);
        // TODO Stage 11: drive feed-forward weight stream after the head0 MHA path is complete.
    endtask : drive_ff_weight

    task drive_ff_bias(ita_stream_item tr);
        @(posedge cfg.vif.clk_i);
        // TODO Stage 11: drive feed-forward bias stream after the head0 MHA path is complete.
    endtask : drive_ff_bias

endclass : ita_stream_driver

`endif // ITA_STREAM_DRIVER_SVH
