`ifndef ITA_STREAM_MONITOR_SVH
`define ITA_STREAM_MONITOR_SVH

class ita_stream_monitor extends uvm_monitor;
    `uvm_component_utils(ita_stream_monitor)

    ita_stream_config cfg;
    uvm_analysis_port #(ita_stream_item) ap;
    int unsigned sample_count;

    function new(string name = "ita_stream_monitor", uvm_component parent = null);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(ita_stream_config)::get(this, "", "cfg", cfg)) begin
            `uvm_fatal("STR_MON_CFG", "ita_stream_config was not set")
        end
    endfunction : build_phase

    task run_phase(uvm_phase phase);
        forever begin
            @(posedge cfg.vif.clk_i);
            if (cfg.vif.rst_ni && is_handshake()) begin
                sample_item();
            end
        end
    endtask : run_phase

    function bit is_handshake();
        // TODO Stage 3: return input valid/ready for head0 input stream.
        // TODO Stage 4: add weight and bias valid/ready checks.
        // TODO Stage 5: add head0 output valid/ready check.
        // TODO Stage 11: add heads 1-7, sum, and feed-forward handshake checks.
        return 1'b0;
    endfunction : is_handshake

    function void sample_item();
        ita_stream_item tr;

        tr = ita_stream_item::type_id::create("tr");
        tr.kind = cfg.kind;
        tr.head_id = cfg.head_id;
        tr.beat_id = sample_count;
        // TODO Stage 3-5: sample the payload selected by cfg.kind and cfg.head_id.
        // TODO Stage 7: write sampled output transactions to logger through ap.
        // TODO Stage 8: send sampled transactions to the smoke scoreboard.

        sample_count++;
    endfunction : sample_item

endclass : ita_stream_monitor

`endif // ITA_STREAM_MONITOR_SVH
