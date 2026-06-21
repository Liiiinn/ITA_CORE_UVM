`ifndef ITA_CTRL_MONITOR_SVH
`define ITA_CTRL_MONITOR_SVH

class ita_ctrl_monitor extends uvm_monitor;
    `uvm_component_utils(ita_ctrl_monitor)

    ita_ctrl_config cfg;
    uvm_analysis_port #(ita_ctrl_item) ap;

    function new(string name = "ita_ctrl_monitor", uvm_component parent = null);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(ita_ctrl_config)::get(this, "", "cfg", cfg)) begin
            `uvm_fatal("CTRL_MON_CFG", "ita_ctrl_config was not set")
        end
    endfunction : build_phase

    task run_phase(uvm_phase phase);
        forever begin
            @(posedge cfg.vif.clk_i);
            if (cfg.vif.rst_ni) begin
                // TODO Stage 2: sample cfg.vif.ctrl_i when start is observed and publish it on ap.
                // TODO Stage 7-8: connect this analysis port to logger/scoreboard once those components exist.
            end
        end
    endtask : run_phase

endclass : ita_ctrl_monitor

`endif // ITA_CTRL_MONITOR_SVH
