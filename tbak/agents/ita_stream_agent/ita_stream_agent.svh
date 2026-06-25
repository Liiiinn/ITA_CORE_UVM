`ifndef ITA_STREAM_AGENT_SVH
`define ITA_STREAM_AGENT_SVH

class ita_stream_agent extends uvm_agent;
    `uvm_component_utils(ita_stream_agent)

    ita_stream_config cfg;
    ita_stream_sequencer sqr;
    ita_stream_driver drv;
    ita_stream_monitor mon;
    uvm_analysis_port #(ita_stream_item) ap;
    // Stage 3-5: use ap for monitored accepted beats after stream_monitor sampling works.
    // Stage 7: use issued_ap for optional source logging after source driver behavior is stable.

    function new(string name = "ita_stream_agent", uvm_component parent = null);
        super.new(name, parent);
        ap = new("ap", this);
        // Stage 3-7: keep ports allocated; implement forwarding in connect_phase when each source/sink path is exercised.
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(ita_stream_config)::get(this, "", "cfg", cfg)) begin
            `uvm_fatal("STR_AGT_CFG", "ita_stream_config was not set")
        end

        uvm_config_db#(ita_stream_config)::set(this, "mon", "cfg", cfg);
        mon = ita_stream_monitor::type_id::create("mon", this);

        if (cfg.is_active == UVM_ACTIVE) begin
            uvm_config_db#(ita_stream_config)::set(this, "drv", "cfg", cfg);
            sqr = ita_stream_sequencer::type_id::create("sqr", this);
            drv = ita_stream_driver::type_id::create("drv", this);
        end
    endfunction : build_phase

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // Stage 3-5: connect mon.ap to this agent ap after accepted-beat sampling is implemented.
        mon.ap.connect(ap);

        if (cfg.is_active == UVM_ACTIVE) begin
            drv.seq_item_port.connect(sqr.seq_item_export);
        end
    endfunction : connect_phase

endclass : ita_stream_agent

`endif // ITA_STREAM_AGENT_SVH
