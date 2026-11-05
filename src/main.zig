const rl = @import("raylib");
const std = @import("std");

const config = @import("config.zig");

pub fn main() anyerror!void {
        rl.initWindow(config.window_width, config.window_height, config.window_title);
        defer rl.closeWindow(); // Close window and OpenGL context

        rl.setTargetFPS(config.target_fps); // Set our game to run at 60 frames-per-second

        // Main game loop
        while (!rl.windowShouldClose()) { // Detect window close button or ESC key

        // Draw
        //----------------------------------------------------------------------------------
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.black);

        rl.drawText("making game logic first.", 190, 200, 20, .light_gray);
        //----------------------------------------------------------------------------------
        }
}
