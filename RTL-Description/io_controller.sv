/* Name: Raad Khan
   Student ID: 26751157
   Purpose: To implement the link io controller */

// opcode[8:5] encoding
`define app_activate    4'b1000 // input from app to activate the io controller
`define app_hibernate   4'b0100 // input from app to hibernate the io controller
`define timer_sleep     4'b0010 // input from sleep timer to sleep the io controller
`define charger_charge  4'b0001 // input from charger to charge the io controller
`define any_idle        4'b0000 // input from anything to idle the io controller

// opcode[4:0] encoding
`define io_ok           5'b10000 // input from io pipe for ok response to the io controller
`define afe_ok          5'b01000 // input from afe for ok response to the io controller
`define a2d_ok          5'b00100 // input from a2d for ok response to the io controller
`define dsp_ok          5'b00010 // input from dsp for ok response to the io controller
`define blem_ok         5'b00001 // input from blem for ok response to the io controller
`define any_notok       5'b00000 // input from io pipe for not ok response to the io controller
`define any_dontcare    5'b????? // dont care about any inputs from io pipe to the io controller

package typedefs;
    /* numerical representation of io controller states:
       Idle, Activate, StreamEEG, ProcessEEG, InterpretEEG,
       BuildBLEcmd, PublishBLEcmd, Hibernate, Sleep, Charge,
       ResetWatchDog */
    typedef enum logic[3:0] {
                Idle, Activ, Stream, Proc, Interp,
                Build, Publ, Hibern, Sleep, Charge,
                ResetWD, Error
            } state_t;

    /* numerical representation of io controller outputs:
       idle, activate, hibernate, sleep, charge
       stream_eeg, process_eeg, interpet_eeg,
       build_ble_cmd, publish_ble_cmd,
       reset_wd */
    typedef enum logic[9:0] {
                idle =            10'b10_0000_0000, // output to the io pipe to idle the io pipe
                activate =        10'b01_0000_0000, // output to the io pipe to activate the io pipe
                hibernate =       10'b00_1000_0000, // output to the io pipe to hibernate the io pipe
                sleep =           10'b00_0100_0000, // output to the io pipe to sleep the io pipe
                charge =          10'b00_0010_0000, // output to the io pipe to charge the io pipe
                stream_eeg =      10'b00_0001_0000, // output to the afe to stream eeg signals
                process_eeg =     10'b00_0000_1000, // output to the a2d to process eeg stream packets
                interpret_eeg =   10'b00_0000_0100, // output to the dsp to interpret eeg data packets
                build_ble_cmd =   10'b00_0000_0010, // output to the ble to build ble cmd
                publish_ble_cmd = 10'b00_0000_0001, // output to the ble to publish a ble cmd
                reset_wd =        10'b00_0000_0000, // output to the watchdog timer to reset the watchdog timer
                garbage =         10'bxx_xxxx_xxxx  // output garbage to signify error
            } output_t;
endpackage

module opcode_encoder(
        input logic app_activate, app_hibernate,
        timer_sleep,
        charger_charge,
        afe_ok, a2d_ok, dsp_ok, blem_ok,
        output logic[8:0] opcode
    );
    assign opcode[8:5] = {app_activate, app_hibernate,
                          timer_sleep,
                          charger_charge};

    assign opcode[4:0] = (afe_ok && a2d_ok && dsp_ok && blem_ok) ? `io_ok : {afe_ok, a2d_ok, dsp_ok, blem_ok};
endmodule

module io_controller import typedefs::*;(
        input logic clk,
        input logic wd_rst,

        /* concatenation of single bit inputs from
           app, sleep timer, charger, io pipe:
           {app_activate, app_hibernate,
            timer_sleep,
            charger_charge,
            io_ok, afe_ok, a2d_ok, dsp_ok, blem_ok} */
        input logic[8:0] opcode,

        /* concatenation of single bit state outputs to io pipe:
           {idle, activate, hibernate, sleep, charge,
            stream_eeg, process_eeg, interpret_eeg,
            build_ble_cmd, publish_ble_cmd} */
        output output_t io_pipe_req
    );

    state_t present_state, next_state;

    // state logic with synchronous reset from watchdog timer
    always_ff @(posedge clk)
    begin
        case(wd_rst)
            1'b0:
                present_state = next_state;
            1'b1:
                present_state = Idle;
            default:
                present_state = Idle; // ResetWD; // under construction
        endcase
    end

    // state output and transition logic
    always_comb
    begin
        casez(present_state)
            Idle:
            begin
                io_pipe_req = idle;
                casez(opcode)
                    {`app_activate, `any_dontcare}:
                        next_state = Activ;
                    {`app_hibernate, `any_dontcare}:
                        next_state = Hibern;
                    {`timer_sleep, `any_dontcare}:
                        next_state = Sleep;
                    {`charger_charge, `any_dontcare}:
                        next_state = Charge;
                    default:
                        next_state = Idle; // remain in Idle
                endcase
            end
            Activ:
            begin
                io_pipe_req = activate;
                casez(opcode)
                    {`app_activate, `io_ok}:
                        next_state = Stream;
                    // this can happen for events like app stopped or terminated,
                    // if so then watchdog timer will detect and reset back to Idle
                    default:
                        next_state = Activ; // remain in Activate
                endcase
            end
            Stream:
            begin
                io_pipe_req = stream_eeg;
                casez(opcode)
                    {`app_activate, `afe_ok}:
                        next_state = Proc;
                    // this can happen for events like app stopped or terminated,
                    // if so then watchdog timer will detect and reset back to Idle
                    default:
                        next_state = Stream; // remain in StreamEEG
                endcase
            end

            Proc:
            begin
                io_pipe_req = process_eeg;
                casez(opcode)
                    {`app_activate, `a2d_ok}:
                        next_state = Interp;
                    // this can happen for events like app stopped or terminated,
                    // if so then watchdog timer will detect and reset back to Idle
                    default:
                        next_state = Proc; // remain in ProcessEEG
                endcase
            end
            Interp:
            begin
                io_pipe_req = interpret_eeg;
                casez(opcode)
                    // dsp successfully classified to a recognized command
                    // - build the ble command
                    {`app_activate, `dsp_ok}:
                        next_state = Build;
                    // in this context, dsp failed to classify to a recognized command
                    // - publish the default retry command
                    {`app_activate, `any_notok}:
                        next_state = Publ;
                    // this can happen for events like app stopped or terminated,
                    // if so then watchdog timer will detect and reset back to Idle
                    default:
                        next_state = Interp; // remain in InterpretEEG
                endcase
            end
            Build:
            begin
                io_pipe_req = build_ble_cmd;
                casez(opcode)
                    {`app_activate, `blem_ok}:
                        next_state = Publ;
                    // this can happen for events like app stopped or terminated,
                    // if so then watchdog timer will detect and reset back to Idle
                    default:
                        next_state = Build; // remain in BuildBLEcmd
                endcase
            end
            Publ:
            begin
                io_pipe_req = publish_ble_cmd;
                casez(opcode)
                    {`app_activate, `blem_ok}:
                        next_state = Stream;
                    // this can happen for events like terminated or stopped running,
                    // if so then watchdog timer will detect and reset back to Idle
                    default:
                        next_state = Publ; // remain in PublishBLEcmd
                endcase
            end
            Hibern:
            begin
                io_pipe_req = hibernate;
                casez(opcode)
                    {`app_activate, `any_dontcare}:
                        next_state = Activ;
                    // in this context, user is interacting with the Link via app,
                    // so input from app to idle the io controller,
                    {`any_idle, `any_dontcare}:
                        next_state = Idle;
                    default:
                        next_state = Hibern; // remain in Hibernate
                endcase
            end
            Sleep:
            begin
                io_pipe_req = sleep;
                casez(opcode)
                    {`app_activate, `any_dontcare}:
                        next_state = Activ;
                    // in this context, user is interacting with The Link via app,
                    // so input from app to idle the io controller,
                    {`any_idle, `any_dontcare}:
                        next_state = Idle;
                    default:
                        next_state = Sleep; // remain in Sleep
                endcase
            end
            Charge:
            begin
                io_pipe_req = charge;
                casez(opcode)
                    {`app_activate, `any_dontcare}:
                        next_state = Activ;
                    // in this context, charger disconnected or charging completed,
                    // so input from charger to idle the io controller
                    {`any_idle, `any_dontcare}:
                        next_state = Idle;
                    default:
                        next_state = Charge; // remain in Charge
                endcase
            end
            /* under construction
            ResetWD: begin
                io_pipe_req = reset_wd;
                next_state = ResetWD; // remain in ResetWatchDog
            end
            */
            default:
            begin
                // the io controller should never transition to here,
                // but if it does output garbage to notify
                io_pipe_req = garbage;
                next_state = Error; // remain in Error
            end
        endcase
    end
endmodule

module io_pipe_req_decoder import typedefs::*;(
        input output_t io_pipe_req,
        output logic idle_o, activate_o, hibernate_o, sleep_o, charge_o,
        stream_eeg_o, process_eeg_o, interpret_eeg_o,
        build_ble_cmd_o, publish_ble_cmd_o
    );
    assign {idle_o, activate_o, hibernate_o, sleep_o, charge_o,
            stream_eeg_o, process_eeg_o, interpret_eeg_o,
            build_ble_cmd_o, publish_ble_cmd_o} = io_pipe_req;
endmodule
