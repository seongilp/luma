const std = @import("std");
const c = @import("c.zig").ray;
const Library = @import("library.zig").Library;
const gallery = @import("gallery.zig");
const Viewer = @import("viewer.zig").Viewer;

const Mode = enum { grid, viewer };

/// 폴더 경로 결정: 첫 인자가 있으면 그것, 없으면 $HOME/Pictures, 그것도 없으면 ".".
fn resolveRoot(arena: std.mem.Allocator, argv: []const [:0]const u8) []const u8 {
    if (argv.len >= 2 and argv[1].len > 0) return argv[1];
    if (std.c.getenv("HOME")) |home| {
        const h = std.mem.span(home);
        return std.fs.path.join(arena, &.{ h, "Pictures" }) catch ".";
    }
    return ".";
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;
    const arena = init.arena.allocator();

    const argv = try init.minimal.args.toSlice(arena);
    const root = resolveRoot(arena, argv);

    var lib = Library.init(io, gpa, root) catch |err| {
        std.log.err("폴더 스캔 실패 '{s}': {s}", .{ root, @errorName(err) });
        return err;
    };
    defer lib.deinit();
    std.log.info("'{s}' 에서 이미지 {d}장 발견", .{ root, lib.count() });

    c.SetConfigFlags(c.FLAG_WINDOW_RESIZABLE);
    c.InitWindow(1024, 768, "zig_photo");
    defer c.CloseWindow();
    c.SetTargetFPS(60);

    var mode: Mode = .grid;
    var scroll_y: f32 = 0;
    var viewer = Viewer{};
    defer viewer.close();

    // 상단 바 높이(그리드는 이 아래로 그려진다고 가정하되 MVP는 간단히 오버레이)
    const top_bar: f32 = 0;

    while (!c.WindowShouldClose()) {
        const sw = c.GetScreenWidth();
        const sh = c.GetScreenHeight();
        const swf: f32 = @floatFromInt(sw);
        const shf: f32 = @floatFromInt(sh);

        switch (mode) {
            .grid => {
                const grid = gallery.Grid.init(swf);
                const view_h = shf - top_bar;

                // 스크롤 입력
                const wheel = c.GetMouseWheelMove();
                if (wheel != 0) scroll_y -= wheel * 60.0;
                const content_h = grid.contentHeight(lib.count());
                const max_scroll = @max(0.0, content_h - view_h);
                if (scroll_y < 0) scroll_y = 0;
                if (scroll_y > max_scroll) scroll_y = max_scroll;

                // 호버/클릭
                const mp = c.GetMousePosition();
                const hovered = grid.indexAt(mp.x, mp.y - top_bar, scroll_y, lib.count());
                if (hovered != null and c.IsMouseButtonPressed(c.MOUSE_BUTTON_LEFT)) {
                    viewer.open(hovered.?);
                    mode = .viewer;
                }

                // 지연 로딩 + 캐시 퇴출
                const range = grid.visibleRange(scroll_y, view_h, lib.count());
                lib.loadVisible(range.start, range.end);
                lib.evictFarFrom(range.start, range.end, grid.cols * 3);

                c.BeginDrawing();
                c.ClearBackground(.{ .r = 30, .g = 30, .b = 34, .a = 255 });
                gallery.draw(grid, lib.photos, scroll_y, view_h, hovered);
                drawTopBar(root, lib.count());
                c.EndDrawing();
            },
            .viewer => {
                if (c.IsKeyPressed(c.KEY_RIGHT)) viewer.move(1, lib.count());
                if (c.IsKeyPressed(c.KEY_LEFT)) viewer.move(-1, lib.count());
                if (c.IsKeyPressed(c.KEY_ESCAPE) or c.IsMouseButtonPressed(c.MOUSE_BUTTON_RIGHT)) {
                    viewer.close();
                    mode = .grid;
                }

                c.BeginDrawing();
                viewer.draw(lib.photos, sw, sh);
                c.EndDrawing();
            },
        }
    }
}

fn drawTopBar(root: []const u8, count: usize) void {
    c.DrawRectangle(0, 0, c.GetScreenWidth(), 28, .{ .r = 0, .g = 0, .b = 0, .a = 160 });
    var buf: [512]u8 = undefined;
    const base = std.fs.path.basename(root);
    const text = std.fmt.bufPrintZ(&buf, "zig_photo  -  {s}  ({d} images)  [click: view]", .{ base, count }) catch "zig_photo";
    c.DrawText(text.ptr, 10, 6, 18, c.RAYWHITE);
    if (count == 0) {
        c.DrawText("No JPEG/PNG images found. Run with a folder path: zig_photo <folder>", 20, 60, 20, c.LIGHTGRAY);
    }
}
