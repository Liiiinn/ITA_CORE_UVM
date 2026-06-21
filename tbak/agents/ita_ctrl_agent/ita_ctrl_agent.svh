`ifndef ITA_CTRL_AGENT_SVH
`define ITA_CTRL_AGENT_SVH

class ita_ctrl_agent extends uvm_agent;
    `uvm_component_utils(ita_ctrl_agent)

    ita_ctrl_config cfg;
    ita_ctrl_sequencer sqr;
    ita_ctrl_driver drv;
    ita_ctrl_monitor mon;
    uvm_analysis_port #(ita_ctrl_item) ap;
    // TODO Stage 2: expose monitored ctrl transactions through this analysis port after ctrl_monitor sampling works.

    function new(string name = "ita_ctrl_agent", uvm_component parent = null);
        super.new(name, parent);
        ap = new("ap", this);
        // TODO Stage 2: keep the port allocated; implement forwarding in connect_phase when monitor output is meaningful.
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(ita_ctrl_config)::get(this, "", "cfg", cfg)) begin
            `uvm_fatal("CTRL_AGT_CFG", "ita_ctrl_config was not set")
        end

        uvm_config_db#(ita_ctrl_config)::set(this, "mon", "cfg", cfg);
        mon = ita_ctrl_monitor::type_id::create("mon", this);

        if (cfg.is_active == UVM_ACTIVE) begin
            uvm_config_db#(ita_ctrl_config)::set(this, "drv", "cfg", cfg);
            sqr = ita_ctrl_sequencer::type_id::create("sqr", this);
            drv = ita_ctrl_driver::type_id::create("drv", this);
        end
    endfunction : build_phase

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // TODO Stage 2: connect mon.ap to this agent ap after ctrl_monitor publishes sampled ctrl items.

        if (cfg.is_active == UVM_ACTIVE) begin
            drv.seq_item_port.connect(sqr.seq_item_export);
        end
    endfunction : connect_phase

endclass : ita_ctrl_agent

`endif // ITA_CTRL_AGENT_SVH
