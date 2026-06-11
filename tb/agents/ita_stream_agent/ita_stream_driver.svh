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
    endtask : drive_idle

    task drive_sink_ready();
        forever begin
            @(posedge cfg.vif.clk_i);
            case (cfg.kind)
                ITA_STREAM_HEAD_OUTPUT: cfg.vif.per_head_ready_i[cfg.head_id] <= 1'b1;
                ITA_STREAM_SUM_OUTPUT:  cfg.vif.sum_ready_i <= 1'b1;
                ITA_STREAM_FF_OUTPUT:   cfg.vif.ff_ready_i <= 1'b1;
                default: ;
            endcase
        end
    endtask : drive_sink_ready

    task drive_source_item(ita_stream_item tr);
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
    endtask : drive_source_item

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
