//============================================================================
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM (USE_FB=1 in qsf)
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;  

//assign VGA_SL = 0;
assign VGA_F1 = 0;
assign VGA_SCALER = 0;
assign HDMI_FREEZE = 0;

assign AUDIO_MIX = 0;

assign LED_DISK = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;

//////////////////////////////////////////////////////////////////

assign LED_USER  = ioctl_download;

wire [1:0] ar = status[9:8];

assign VIDEO_ARX = (!ar) ? 12'd282 : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? 12'd241 : 12'd0;

`include "build_id.v" 
localparam CONF_STR = {
	"A.INFERNO;;",
	"-;",
	"H0O89,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"-;",
	"OD,P1 Controls,Run+Aim Single,Dual Analog;",
	"OE,P2 Controls,Run+Aim Single,Dual Analog;",
	"-;",
	"OA,Advance,Off,On;",
	"OB,Auto Up,Off,On;",
	"OC,High Score Reset,Off,On;",
	"-;",
	"R0,Reset;",
	"J1,Trigger,Start,Coin;",
	"jn,R,Start,Select;",
	"V,v",`BUILD_DATE 
};

wire        forced_scandoubler;
wire        direct_video;
wire [21:0] gamma_bus;
wire        video_rotated;

wire        ioctl_download;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire [ 7:0] ioctl_dout;
wire [15:0] ioctl_index;

wire [ 1:0] buttons;
wire [31:0] status;
wire [10:0] ps2_key;

wire [15:0] joy1, joy2;
wire [15:0] joy = joy1 | joy2;

wire [15:0] joyL1, joyR1, joyL2, joyR2;

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),
	.EXT_BUS(),

	.buttons(buttons),
	.status(status),
	.status_menumask({direct_video}),

	.forced_scandoubler(forced_scandoubler),
	.video_rotated(video_rotated),
	.gamma_bus(gamma_bus),
	.direct_video(direct_video),

	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_index(ioctl_index),

	.joystick_0(joy1),
	.joystick_1(joy2),

	.joystick_l_analog_0(joyL1),
	.joystick_r_analog_0(joyR1),

	.joystick_l_analog_1(joyL2),
	.joystick_r_analog_1(joyR2)
);

///////////////////////   CLOCKS   ///////////////////////////////

wire clk_sys;
wire pll_locked;
wire clk_48,clk_12;
assign clk_sys=clk_12;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_48),
	.outclk_1(clk_12),
	.locked(pll_locked)
);

wire reset = RESET | status[0] | buttons[1];

///////////////////////   INPUTS   ////////////////////////////////

// Inputs for this core are a little weird, conditional assignments required to suit
// the different kinds of playstyles and controllers.

// Final input wire for willams2 ports
reg [3:0] m_run1;
reg [3:0] m_run2;
reg [3:0] m_aim1;
reg [3:0] m_aim2;

// Player 1 Directional Inputs
wire m_right1  = joy1[0];
wire m_left1   = joy1[1];
wire m_down1   = joy1[2];
wire m_up1     = joy1[3];

// run with dual analog p1 status[13]
wire m_rightA1 = joyL1[0];
wire m_leftA1  = joyL1[1];
wire m_downA1  = joyL1[2];
wire m_upA1    = joyL1[3];

// combined aim+run p1 ~status[13]
wire m_aimR1   = m_right1;
wire m_aimL1   = m_left1;
wire m_aimD1   = m_down1;
wire m_aimU1   = m_up1;

// aim with dual analog p1 status[13]
wire m_aimAR1  = joyR1[0];
wire m_aimAL1  = joyR1[1];
wire m_aimAD1  = joyR1[2];
wire m_aimAU1  = joyR1[3];

// Player 2 Directional Inputs
wire m_right2  = joy2[0];
wire m_left2   = joy2[1];
wire m_down2   = joy2[2];
wire m_up2     = joy2[3];

// run with dual analog p2 [status][14]
wire m_rightA2 = joyL2[0];
wire m_leftA2  = joyL2[1];
wire m_downA2  = joyL2[2];
wire m_upA2    = joyL2[3];

// combined aim+run p2 ~status[14]
wire m_aimR2   = m_right2;
wire m_aimL2   = m_left2;
wire m_aimD2   = m_down2;
wire m_aimU2   = m_up2;

// aim with dual analog p2 status[14]
wire m_aimAR2  = joyR2[0];
wire m_aimAL2  = joyR2[1];
wire m_aimAD2  = joyR2[2];
wire m_aimAU2  = joyR2[3];

// User decides if they want to combine run+aim or use dual analog joysticks
// Core checks for status then conditionally assigns inputs to appropriate reg depending on choice
always_comb begin : joyCondition
	m_run1 = 0;
	m_run2 = 0;
	m_aim1 = 0;
	m_aim2 = 0;
	m_run1 = status[13] ? {m_up1,   m_down1, m_left1, m_right1} : {m_upA1,   m_downA1, m_leftA1, m_rightA1};
	m_run2 = status[14] ? {m_up2,   m_down2, m_left2, m_right2} : {m_upA2,   m_downA2, m_leftA2, m_rightA2};
	m_aim1 = status[13] ? {m_aimU1, m_aimD1, m_aimL1, m_aimR1 } : {m_aimAU1, m_aimAD1, m_aimAL1, m_aimAR1 };
	m_aim2 = status[14] ? {m_aimU2, m_aimD2, m_aimL2, m_aimR2 } : {m_aimAU2, m_aimAD2, m_aimAL2, m_aimAR2 };
end

// Regular player buttons
wire m_fire1  = joy1[4];
wire m_start1 = joy1[5];

wire m_fire2  = joy2[4];
wire m_start2 = joy2[5];

// both players can press "coin"
wire m_coin   = joy[6];

///////////////////////   DISPLAY   ///////////////////////////////

wire hblank, vblank;
wire hs, vs;
wire [3:0] r,g,b,intensity;
wire [3:0] red,green,blue;
wire [7:0] ri,gi,bi;

assign ri = r*intensity;
assign gi = g*intensity;
assign bi = b*intensity;

assign red   = ri[7:4];
assign blue  = bi[7:4];
assign green = gi[7:4];

reg ce_pix;
always @(posedge clk_48) begin
	reg [2:0] div;
	div <= div + 1'd1;
	ce_pix <= !div;
end

arcade_video #(313,12,1) arcade_video
(
	.*,
	.clk_video(clk_48),

	.RGB_in({red,green,blue}),
	.HBlank(hblank),
	.VBlank(vblank),
	.HSync(~hs),
	.VSync(~vs),
	.fx(status[5:3])
);

wire [7:0] audio;
assign AUDIO_L = {audio, 6'd0};
assign AUDIO_R = AUDIO_L;
assign AUDIO_S = 0;

williams2 williams2
(
	.clock_12(clk_12),
	.reset(reset),

	.video_r(r),           	// [3:0]
	.video_g(g),           	// [3:0]
	.video_b(b),           	// [3:0]
	.video_i(intensity),   	// [3:0] Color Intensity options
	.video_hblank(hblank), 	// 48 <-> 1
	.video_vblank(vblank), 	// 504 <-> 262
	.video_hs(hs),
	.video_vs(vs),

	.audio_out(audio), 		// [7:0]

	.btn_advance(status[10]),
	.btn_auto_up(status[11]),
	.btn_high_score_reset(status[12]),

 	.btn_trigger_1	(m_fire1),
 	.btn_trigger_2	(m_fire2),
 	.btn_start_1    (m_start1),
 	.btn_start_2    (m_start2),
 	.btn_coin      	(m_coin),

 	.btn_run_1      (m_run1),
 	.btn_run_2      (m_run2),
 	.btn_aim_1      (m_aim1), // aim should use separate controls
 	.btn_aim_2      (m_aim2),

	.sw_coktail_table(),
	.seven_seg(),

	.dbg_out(),

	.dn_addr(ioctl_addr[17:0]),
	.dn_data(ioctl_dout),
	.dn_wr(ioctl_wr && ioctl_index==0)
);

endmodule
