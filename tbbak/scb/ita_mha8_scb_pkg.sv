package ita_mha8_scb_pkg;

    import uvm_pkg::*;
    import ita_package::*;
    import ita_ctrl_agent_pkg::*;
    import ita_stream_agent_pkg::*;
    `include "uvm_macros.svh"

    `uvm_analysis_imp_decl(_ctrl)
    `uvm_analysis_imp_decl(_stream)
    `uvm_analysis_imp_decl(_source)

    `include "ita_mha8_ref_model.svh"
    `include "ita_mha8_scoreboard.svh"
    `include "ita_mha8_transaction_logger.svh"

endpackage : ita_mha8_scb_pkg
