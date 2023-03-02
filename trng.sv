`default_nettype none

module oscillator
  #(parameter MAX_N = 3500)
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
  #(parameter MAX_N_A = 70, MAX_N_B = 3500, numSources = 1) //numFreqs count includes sample freq
  (input  logic [$clog2(MAX_N_B)-1:0] sampleLength,
   input logic [numSources-1:0][$clog2(MAX_N_A)-1:0] sourceLength,
   input   logic                      reset_n,
   output logic                       out
  );

  logic ff_clk, ff_d, ff_q;

  //ffVal should be one bit when numFreqs = 2
  logic [numSources-1:0] ffVal;
 
  // source oscillators (short chain of inverters)
  genvar osc_i;
  generate
  for (osc_i = 0; osc_i < numSources; osc_i ++) begin : gen_oscs
    oscillator #(.MAX_N(MAX_N_A)) (.n(sourceLength[osc_i]), .out(ffVal[osc_i]), .*);
  end
  endgenerate

  // slow oscillator (long chain of inverters)
  oscillator #(.MAX_N(MAX_N_B)) lf(.n(sampleLength), .out(ff_clk), .*);
 
  assign ff_d = ffVal;

  //FF for sampling
  always_ff @(posedge ff_clk, negedge reset_n) begin
    if (~reset_n) begin
      ff_q <= 1'b0;
    end else begin
      ff_q <= ff_d;
    end
  end

  assign out = ff_q;

endmodule : trng_device

//pretty much divides the fclk by 4
module clk_div(input logic fclk, output logic sclk, input logic reset_n);

  logic [3:0] div;

  always_ff @(posedge fclk, negedge reset_n) begin
    if (~reset_n) begin
      div <= 4'd1;
    end 
    else begin
      div <= {div[2:0], div[3]};
    end
  end

  assign sclk = div[3];

endmodule : clk_div


module byte_gen_ctrl
  #(parameter NUM_BITS = 8)
  (input logic                       clk, reset_n,
   input  logic                      trng_out, 
   input logic                       valid,

   output logic                      ready,
   output logic       [NUM_BITS-1:0] rng_byte_out
  );

  /* shift register enable signal + counter for NUM_BITS bits */
  logic sr_en;
  logic [$clog2(NUM_BITS):0] bits_generated;
  
  logic last_bit;

  always_ff @(posedge clk, negedge reset_n) begin
    if (~reset_n) begin
      rng_byte_out <= {NUM_BITS{1'b0}};
      bits_generated <= {$clog2(NUM_BITS){1'b0}};
		last_bit <= 1'b1;
    end 
    else if (sr_en) begin
		/*
		if (last_bit != trng_out) begin
			//left direction shift, so save lower-seven bits of rng_byte_out
			rng_byte_out <= {rng_byte_out[NUM_BITS-2:0], last_bit};
			bits_generated <= bits_generated + 1;
		end
		
		last_bit <= trng_out;
		*/
		
		
		rng_byte_out <= {rng_byte_out[NUM_BITS-2:0], trng_out};
		bits_generated <= bits_generated + 1;
		
		
    end
  end

  //this FSM waits for valid to be asserted
  //once valid is asserted, 1 bit of output from trng will be stored into shift register
  //after 8 bits have been saved in the register, assert ready so that it can be
  //displayed on the seven-segment displays, and transmitted over UART
  enum logic [1:0] {
    WAIT_VALID,
    GEN_BITS,
    DONE
  } cstate, nstate;
 
  always_comb begin
    nstate = cstate;
    sr_en = 1'b0;
    ready = 1'b0;
   
    case (cstate)
      WAIT_VALID: begin
        if (valid) begin
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
        if (~valid) begin
          nstate = WAIT_VALID;
        end
      end
    endcase
  end

  always_ff @(posedge clk, negedge reset_n) begin
    if (!reset_n) 
      cstate <= WAIT_VALID;
    else 
      cstate <= nstate;
  end

endmodule : byte_gen_ctrl

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
  (output logic [7:0]   LEDR,
   input  logic         CLOCK_50,
   input  logic [2:0]   KEY,
   input  logic [7:0]   SW,
   output logic [6:0]   HEX3, HEX2, HEX1, HEX0,
   inout  logic [27:26] GPIO_0
);
  logic valid, ready, send, done;
  logic [7:0] rng_byte_out;
  logic clk_slower, clk_slower2, clk_slower3;

  //CLK slower is 25 MHz
  
  always_ff @(posedge CLOCK_50) begin
    clk_slower <= ~clk_slower;
  end
  
  always_ff @(posedge clk_slower) begin
    clk_slower2 <= ~clk_slower2;
  end
  
  always_ff @(posedge clk_slower2) begin
    clk_slower3 <= ~clk_slower3;
  end
  
  
  //clk_div (.fclk(CLOCK_50), .sclk(clk_slower), .reset_n(1'b1));

  byte_gen_ctrl byte_gen(.clk(clk_slower3), .reset_n(1'b1), .valid, .trng_out(pin),
                          .ready, .rng_byte_out);

  //these displays will show you the last generated byte, in hex form
  BinValtoSevenSegment bvss0(.val(rng_byte_out[3:0]), .segment(HEX0)),
                       bvss1(.val(rng_byte_out[7:4]), .segment(HEX1));

  logic kb3, kb4, pin;
 
  localparam numSources = 1;
  
  //ALWAYS KEEP THE MAXES AT LEAST 1 ABOVE THE SOURCE AND SAMPLE LENGTH
  localparam MAX_SOURCE_LENGTH = 22;
  localparam MAX_SAMPLE_LENGTH = 51;
  
  logic [6:0] sourceLength;
  logic [12:0] sampleLength;
  
  assign sourceLength = 21;
  assign sampleLength = 517;
  
  //CREATE DUT
  trng_device #(.numSources(1), .MAX_N_A(MAX_SOURCE_LENGTH), .MAX_N_B(MAX_SAMPLE_LENGTH)) 
					DUT (.sourceLength(sourceLength), .sampleLength(sampleLength), .out(pin), .reset_n(1'b1));

  logic [7:0] data;
  always_ff @(posedge CLOCK_50) begin
    //double FF for debouncing
    kb3 <= KEY[1];
    kb4 <= kb3;
    if (kb4) begin
      data[7:1] <= data[6:0];
      data[0] <= pin;
    end
  end

  assign LEDR[7:0] = data[7:0];
  //random bits are constantly generated, but if you press KEY1
  //you can save the current bit onto HEX2 and HEX3
  BinValtoSevenSegment bvss2(.val(data[3:0]), .segment(HEX2)),
                       bvss3(.val(data[7:4]), .segment(HEX3));

  // TODO: uart RX
  //GPIO_O[27] is FPGA RX pin
  assign GPIO_0[27] = 1'bz;

  //GPI_0[26] is FPGA TX pin
  uart_ctl uart_module(.clk(CLOCK_50), .reset_n(1'b1), .bits(rng_byte_out),
                       .TX(GPIO_0[26]), .done, .send);

  //this FSM waits for the assertion of the ready signal
  //when the ready signal is asserted, this means that 8 bits from the trng were sampled
  //in the SEND_DATA state, we are sending the 8 bits over UART until the UART module asserts done
  enum logic [0:0] {
    WAIT_TRNG = 1'b0,
    SEND_DATA = 1'b1
  } cstate, nstate;

  always_comb begin
    nstate = cstate;
    valid = 1'b0;
    send = 1'b0;
   
    case (cstate)
      WAIT_TRNG: begin
        valid = 1'b1;
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

  logic valid, ready, trng_out;
  logic [7:0] rng_byte_out;
  byte_gen_ctrl byte_gen(.clk(clock), .reset_n(rst_n), .valid, .trng_out,
                          .ready, .rng_byte_out);

  initial begin
    clock = 1'b0;
    forever #4730 clock = ~clock;
  end

  initial begin
    rst_n = 1'b0;
    valid = 1'b0;
    #1000 rst_n = 1'b1;
    #1000 valid = 1'b1;
    @(posedge ready);
    valid = 1'b0;
    $display(rng);
    #1000
    $finish();
  end

endmodule: trng
`endif
