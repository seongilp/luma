const std = @import("std");
const c = @cImport({
    @cInclude("raylib.h");
});

pub fn main() void {
    const screen_w = 1024;
    const screen_h = 768;

    c.InitWindow(screen_w, screen_h, "zig_photo");
    defer c.CloseWindow();
    c.SetTargetFPS(60);

    while (!c.WindowShouldClose()) {
        c.BeginDrawing();
        c.ClearBackground(c.RAYWHITE);
        c.DrawText("zig_photo: walking skeleton", 40, 40, 24, c.DARKGRAY);
        c.EndDrawing();
    }
}
