`ifndef ITA_STREAM_AGENT_SVH
`define ITA_STREAM_AGENT_SVH

class ita_stream_agent extends uvm_agent;
    `uvm_component_utils(ita_stream_agent)

    ita_stream_config cfg;
    ita_stream_sequencer sqr;
    ita_stream_driver drv;
    ita_stream_monitor mon;
    uvm_analysis_port #(ita_stream_item) ap;
    uvm_analysis_port #(ita_stream_item) issued_ap;

    function new(string name = "ita_stream_agent", uvm_component parent = null);
        super.new(name, parent);
        ap = new("ap", this);
        issued_ap = new("issued_ap", this);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(ita_stream_config)::get(this, "", "cfg", cfg)) begin
            `uvm_fatal("STR_AGT_CFG", "ita_stream_config was not set")
        end

        uvm_config_db#(ita_stream_config)::set(this, "mon", "cfg", cfg);
        mon = ita_stream_monitor::type_id::create("mon", this);
        // TODO Stage 3-5: keep monitor always present so passive heads can still be observed.

        if (cfg.is_active == UVM_ACTIVE) begin
            uvm_config_db#(ita_stream_config)::set(this, "drv", "cfg", cfg);
            sqr = ita_stream_sequencer::type_id::create("sqr", this);
            drv = ita_stream_driver::type_id::create("drv", this);
            // TODO Stage 11: make heads 1-7 active only when expanding beyond head0.
        end
    endfunction : build_phase

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        mon.ap.connect(ap);
        // TODO Stage 7-8: connect this agent-level ap to logger/scoreboard in env.

        if (cfg.is_active == UVM_ACTIVE) begin
            drv.seq_item_port.connect(sqr.seq_item_export);
            drv.issued_ap.connect(issued_ap);
            // TODO Stage 8: use issued_ap for expected transaction counting before numeric compare.
        end
    endfunction : connect_phase

endclass : ita_stream_agent

`endif // ITA_STREAM_AGENT_SVH
