const std = @import("std");
const c = @import("c.zig").ray;
const Library = @import("library.zig").Library;
const gallery = @import("gallery.zig");
const Viewer = @import("viewer.zig").Viewer;
const dialog = @import("dialog.zig");

const Mode = enum { grid, viewer };

/// 시작 시 폴더 결정: ① 인자가 있으면 그것 ② 없으면 네이티브 폴더 선택
/// ③ 취소하면 $HOME/Pictures ④ 그것도 없으면 ".". 반환은 gpa 소유.
fn resolveInitialRoot(gpa: std.mem.Allocator, argv: []const [:0]const u8) ![]u8 {
    if (argv.len >= 2 and argv[1].len > 0) return gpa.dupe(u8, argv[1]);
    if (try dialog.pickFolder(gpa, "사진 폴더를 선택하세요")) |p| return p;
    if (std.c.getenv("HOME")) |home| {
        return std.fs.path.join(gpa, &.{ std.mem.span(home), "Pictures" });
    }
    return gpa.dupe(u8, ".");
}

/// 폴더를 로드한다. 스캔 실패해도 빈 라이브러리로 돌려 창은 계속 띄운다.
fn openLibrary(io: std.Io, gpa: std.mem.Allocator, root: []const u8) Library {
    return Library.init(io, gpa, root) catch |err| {
        std.log.err("폴더 로드 실패 '{s}': {s}", .{ root, @errorName(err) });
        return .{ .allocator = gpa, .photos = &.{} };
    };
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;
    const arena = init.arena.allocator();

    const argv = try init.minimal.args.toSlice(arena);
    var root: []u8 = try resolveInitialRoot(gpa, argv);
    defer gpa.free(root);

    var lib = openLibrary(io, gpa, root);
    defer lib.deinit();
    std.log.info("'{s}' 에서 이미지 {d}장", .{ root, lib.count() });

    c.SetConfigFlags(c.FLAG_WINDOW_RESIZABLE);
    c.InitWindow(1100, 760, "zig_photo");
    defer c.CloseWindow();
    c.SetTargetFPS(60);
    c.SetExitKey(c.KEY_NULL); // ESC는 뷰어 닫기에 쓰므로 앱 종료 단축키 해제

    var mode: Mode = .grid;
    var scroll_y: f32 = 0;
    var viewer = Viewer{};
    defer viewer.close();

    // 검증용: ZIGPHOTO_SHOT 환경변수가 있으면 몇 프레임 뒤 스크린샷 저장 후 종료.
    const shot_path: ?[*:0]const u8 = std.c.getenv("ZIGPHOTO_SHOT");
    var frame: u32 = 0;

    const top_bar: f32 = 32;

    while (!c.WindowShouldClose()) {
        frame += 1;
        if (shot_path) |sp| {
            if (frame == 30) {
                c.TakeScreenshot(sp);
                std.log.info("스크린샷 저장: {s}", .{sp});
                break;
            }
        }

        const sw = c.GetScreenWidth();
        const sh = c.GetScreenHeight();
        const swf: f32 = @floatFromInt(sw);
        const shf: f32 = @floatFromInt(sh);

        // 어느 모드에서든 O 키로 폴더 다시 선택
        if (c.IsKeyPressed(c.KEY_O)) {
            if (try dialog.pickFolder(gpa, "사진 폴더를 선택하세요")) |new_root| {
                const new_lib = openLibrary(io, gpa, new_root);
                lib.deinit();
                lib = new_lib;
                gpa.free(root);
                root = new_root;
                scroll_y = 0;
                mode = .grid;
                viewer.close();
                std.log.info("'{s}' 에서 이미지 {d}장", .{ root, lib.count() });
            }
        }

        switch (mode) {
            .grid => {
                const grid = gallery.Grid.init(swf);
                const view_h = shf - top_bar;

                const wheel = c.GetMouseWheelMove();
                if (wheel != 0) scroll_y -= wheel * 60.0;
                const content_h = grid.contentHeight(lib.count());
                const max_scroll = @max(0.0, content_h - view_h);
                if (scroll_y < 0) scroll_y = 0;
                if (scroll_y > max_scroll) scroll_y = max_scroll;

                const mp = c.GetMousePosition();
                const in_grid = mp.y >= top_bar;
                const hovered = if (in_grid) grid.indexAt(mp.x, mp.y - top_bar, scroll_y, lib.count()) else null;
                if (hovered != null and c.IsMouseButtonPressed(c.MOUSE_BUTTON_LEFT)) {
                    viewer.open(hovered.?);
                    mode = .viewer;
                }

                const range = grid.visibleRange(scroll_y, view_h, lib.count());
                lib.loadVisible(range.start, range.end);
                lib.evictFarFrom(range.start, range.end, grid.cols * 3);

                c.BeginDrawing();
                c.ClearBackground(.{ .r = 24, .g = 24, .b = 27, .a = 255 });
                // 그리드는 상단바 아래 영역에 그린다 (스크롤 좌표를 top_bar만큼 평행이동)
                c.BeginScissorMode(0, @intFromFloat(top_bar), sw, @intFromFloat(view_h));
                gallery.draw(grid, lib.photos, scroll_y, top_bar, view_h, hovered);
                c.EndScissorMode();
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
    const w = c.GetScreenWidth();
    c.DrawRectangle(0, 0, w, 32, .{ .r = 16, .g = 16, .b = 18, .a = 255 });
    c.DrawRectangle(0, 31, w, 1, .{ .r = 60, .g = 60, .b = 66, .a = 255 });

    var buf: [512]u8 = undefined;
    const base = std.fs.path.basename(root);
    const text = std.fmt.bufPrintZ(&buf, "zig_photo   {s}  ({d})", .{ base, count }) catch "zig_photo";
    c.DrawText(text.ptr, 12, 8, 18, c.RAYWHITE);

    const hint = "[O] open folder    [click] view";
    const hw = c.MeasureText(hint, 16);
    c.DrawText(hint, w - hw - 12, 9, 16, .{ .r = 150, .g = 150, .b = 156, .a = 255 });

    if (count == 0) {
        c.DrawText("No JPEG/PNG images here. Press O to pick a folder.", 20, 60, 20, c.LIGHTGRAY);
    }
}
