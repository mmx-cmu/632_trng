`default_nettype none

module oscillator
  #(parameter MAX_N = 35)
  (input  logic [$clog2(MAX_N)-1:0] n,
   input  logic                     reset_n,
   output logic                     out);

  logic [MAX_N-1:0] invs /* synthesis keep */;
  logic [MAX_N-1:0] invs_internal /* synthesis keep */;

  genvar i;
  generate
    for (i = 0; i < MAX_N-1; i++) begin : inverters
      /* put two inverters at a time so invs[i] = invs[i+1] always
       * (modulo the delay) */
      not #5 gate1(invs_internal[i], invs[i]);
      not #5 gate2(invs[i+1], invs_internal[i]);
    end
  endgenerate

  /* the final inverter is taken by getting the nth pairing */
  assign #5 invs[0] = reset_n ? ~invs[n] : 1'b0;

  /* the output is the same as the value coming in */
  assign out = invs[0];

endmodule : oscillator

module trng_device
  #(parameter MAX_N_A = 35, MAX_N_B = 1750)
  (input  logic [$clog2(MAX_N_A)-1:0] nA,
   input  logic [$clog2(MAX_N_B)-1:0] nB,
   input   logic                      reset_n,
   output logic                       out
  );

  logic ff_clk, ff_d, ff_q;
 
  oscillator #(.MAX_N(MAX_N_A)) hf(.n(nA), .out(ff_d), .*);

  oscillator #(.MAX_N(MAX_N_B)) lf(.n(nB), .out(ff_clk), .*);

  always_ff @(posedge ff_clk, negedge reset_n) begin
    if (~reset_n) begin
      ff_q <= 1'b0;
    end else begin
      ff_q <= ff_d;
    end
  end

  assign out = ff_q;

endmodule : trng_device

module clk_div(input logic fclk, output logic sclk, input logic reset_n);

  logic [3:0] div;

  always_ff @(posedge fclk, negedge reset_n) begin
    if (~reset_n) begin
      div <= 4'd1;
    end else begin
      div <= {div[2:0], div[3]};
    end
  end

  assign sclk = div[3];
endmodule : clk_div

module trng_control
  #(parameter MAX_N_A = 35, MAX_N_B = 1750, NUM_BITS = 8)
  (input logic                       clk, reset_n,
   input logic [$clog2(MAX_N_A)-1:0] nA,
   input logic [$clog2(MAX_N_B)-1:0] nB,
   input logic                       go,
   output logic                      ready,
   output logic       [NUM_BITS-1:0] rng,
   input  logic                      trng_out
  );

  /* the single-bit trng */
  // logic trng_out;
  //trng_device #(.MAX_N_A(MAX_N_A),
  //              .MAX_N_B(MAX_N_B)) trng(.nA, .nB, .out(trng_out), .reset_n);

  /* shift register + counter for NUM_BITS bits */
  logic sr_en;
  logic [$clog2(NUM_BITS):0] bits_generated;
  always_ff @(posedge clk, negedge reset_n) begin
    if (~reset_n) begin
      rng <= {NUM_BITS{1'b0}};
      bits_generated <= {$clog2(NUM_BITS){1'b0}};
    end else if (sr_en) begin
      rng <= {rng[NUM_BITS-2:0], trng_out};
      bits_generated <= bits_generated + 1;
    end
  end

  // Automatically generated by ferris highroller on 2/20/2023, 7:35:53 PM
  enum logic [1:0] {
    WAIT_GO,
    GEN_BITS,
    DONE
  } cstate, nstate;
  
  always_comb begin
    nstate = cstate;
    sr_en = 1'b0;
    ready = 1'b0;
    
    case (cstate)
      WAIT_GO: begin
        if (go) begin
          nstate = GEN_BITS;
        end
      end
      GEN_BITS: begin
        sr_en = 1'b1;
        if (bits_generated == NUM_BITS) begin
          nstate = DONE;
        end
      end
      DONE: begin
        ready = 1'b1;
        if (~go) begin
          nstate = WAIT_GO;
        end
      end
    endcase
  end
  always_ff @(posedge clk, negedge reset_n) begin
    if (!reset_n) cstate <= WAIT_GO;
    else cstate <= nstate;
  end

endmodule : trng_control

`ifndef SIMULATION
// simple binary value to seven segment display (assuming low = on)
module BinValtoSevenSegment
  (input  logic [3:0] val,
   output logic [6:0] segment);

  // case statement is probably the easiest way to do this
  always_comb
    unique case (val)
      // 0 has 6 off, everything else on
      4'd00: segment = 7'b100_0000;
      // 1 has only 1 and 2 on, everything else off
      4'd01: segment = 7'b111_1001;
      // 2 has 5 and 2 off, everything else on
      4'd02: segment = 7'b010_0100;
      // 3 has 5 and 4 off, everything else on
      4'd03: segment = 7'b011_0000;
      // 4 has 0, 4, and 3 off, everything else on
      4'd04: segment = 7'b001_1001;
      // 5 has 1 and 4 off, everything else on
      4'd05: segment = 7'b001_0010;
      // 6 has 1 off, everything else on
      4'd06: segment = 7'b000_0010;
      // 7 has only 0, 1, and 2 on, everything else off
      4'd07: segment = 7'b111_1000;
      // 8 has everything on
      4'd08: segment = 7'b000_0000;
      // 9 has 4 off, everything else on
      4'd09: segment = 7'b001_0000;
      // A has 3 off, everything else on
      4'ha: segment = 7'b000_1000;
      // B has 0 and 1 off, everything else on
      4'hb: segment = 7'b000_0011;
      // C has 1, 2, and 6 off, everything else on
      4'hc: segment = 7'b100_0110;
      // D has 0 and 5 off, everything else on
      4'hd: segment = 7'b010_0001;
      // E has 1 and 2 off, everything else on
      4'he: segment = 7'b000_0110;
      // F has 1, 2, and 3 off, everything else on
      4'hf: segment = 7'b000_1110;
    endcase

endmodule : BinValtoSevenSegment

module trng
  (output logic [9:0]   LEDR,
   input  logic         CLOCK_50,
	 input  logic [2:0]   KEY,
	 input  logic [7:0]   SW,
	 output logic [6:0]   HEX3, HEX2, HEX1, HEX0,
	 inout  logic [27:26] GPIO_0
	);
  logic go, ready, send, done;
  logic [7:0] rng;
  logic clk_slower;
  always_ff @(posedge CLOCK_50) begin
	clk_slower <= ~clk_slower;
  end
  trng_control trng_ctrl(.clk(clk_slower), .reset_n(1'b1), .nA('d9), .nB('d47), .go,
                         .ready, .rng, .trng_out(pin));

  BinValtoSevenSegment bvss0(.val(rng[3:0]), .segment(HEX0)),
                       bvss1(.val(rng[7:4]), .segment(HEX1));

  logic kb3, kb4, pin;
  // old: 9 and 47
  trng_device DUT (.nA('d17), .nB('d853), .out(pin), .reset_n(1'b1));
  logic [7:0] data;
  always_ff @(posedge CLOCK_50) begin
    kb3 <= KEY[1];
    kb4 <= kb3;
    if (kb4) begin
      data[7:1] <= data[6:0];
      data[0] <= pin;
    end
  end

  assign LEDR[7:0] = data[7:0];
  BinValtoSevenSegment bvss2(.val(data[3:0]), .segment(HEX2)),
                       bvss3(.val(data[7:4]), .segment(HEX3));

  // TODO: uart RX
  assign GPIO_0[27] = 1'bz;
  uart_ctl uart_module(.clk(CLOCK_50), .reset_n(1'b1), .bits(rng),
                       .TX(GPIO_0[26]), .done, .send);

  // Automatically generated by ferris highroller on 2/21/2023, 10:28:08 PM
  enum logic [0:0] {
    WAIT_TRNG = 1'b0,
    SEND_DATA = 1'b1
  } cstate, nstate;

  always_comb begin
    nstate = cstate;
    go = 1'b0;
    send = 1'b0;
    
    case (cstate)
      WAIT_TRNG: begin
        go = 1'b1;
        if (ready) begin
          nstate = SEND_DATA;
        end
      end
      SEND_DATA: begin
        send = 1'b1;
        if (done) begin
          nstate = WAIT_TRNG;
        end
      end
    endcase
  end
  always_ff @(posedge CLOCK_50) begin
    cstate <= nstate;
  end

endmodule: trng
`else
module trng();
  logic clock, rst_n;

  logic go, ready, trng_out;
  logic [7:0] rng;
  trng_control trng_ctrl(.clk(clock), .reset_n(rst_n), .nA('d9), .nB('d47),
                         .go, .ready, .rng, .trng_out);

  initial begin
    clock = 1'b0;
    forever #4730 clock = ~clock;
  end

  initial begin
    rst_n = 1'b0;
    go = 1'b0;
    #1000 rst_n = 1'b1;
    #1000 go = 1'b1;
    @(posedge ready);
    go = 1'b0;
    $display(rng);
    #1000
    $finish();
  end

endmodule: trng
`endif
