const std = @import("std");
const c = @import("c.zig").ray;
const Photo = @import("photo.zig").Photo;

/// 단일 사진 큰 보기. 현재 인덱스의 풀해상도 텍스처를 따로 들고 있다가
/// 인덱스가 바뀌면 다시 로드한다.
pub const Viewer = struct {
    index: usize = 0,
    texture: ?c.Texture2D = null,
    loaded_index: ?usize = null,
    failed: bool = false,

    pub fn open(self: *Viewer, index: usize) void {
        self.index = index;
        self.invalidate();
    }

    fn invalidate(self: *Viewer) void {
        if (self.texture) |tex| c.UnloadTexture(tex);
        self.texture = null;
        self.loaded_index = null;
        self.failed = false;
    }

    pub fn close(self: *Viewer) void {
        self.invalidate();
    }

    /// 이전/다음 사진으로 이동 (범위 클램프).
    pub fn move(self: *Viewer, delta: i64, count: usize) void {
        if (count == 0) return;
        const cur: i64 = @intCast(self.index);
        var next = cur + delta;
        if (next < 0) next = 0;
        if (next >= @as(i64, @intCast(count))) next = @intCast(count - 1);
        const ni: usize = @intCast(next);
        if (ni != self.index) {
            self.index = ni;
            self.invalidate();
        }
    }

    /// 필요하면 현재 인덱스의 풀해상도 이미지를 로드한다.
    fn ensureLoaded(self: *Viewer, photos: []Photo) void {
        if (self.loaded_index != null and self.loaded_index.? == self.index) return;
        self.invalidate();
        if (self.index >= photos.len) {
            self.failed = true;
            return;
        }
        const img = c.LoadImage(photos[self.index].path.ptr);
        if (!c.IsImageValid(img)) {
            self.failed = true;
            self.loaded_index = self.index;
            return;
        }
        defer c.UnloadImage(img);
        const tex = c.LoadTextureFromImage(img);
        if (!c.IsTextureValid(tex)) {
            self.failed = true;
            self.loaded_index = self.index;
            return;
        }
        self.texture = tex;
        self.loaded_index = self.index;
    }

    pub fn draw(self: *Viewer, photos: []Photo, screen_w: i32, screen_h: i32) void {
        c.DrawRectangle(0, 0, screen_w, screen_h, c.BLACK);
        self.ensureLoaded(photos);

        if (self.texture) |tex| {
            const dst = fitToScreen(tex.width, tex.height, screen_w, screen_h);
            const src = c.Rectangle{
                .x = 0,
                .y = 0,
                .width = @floatFromInt(tex.width),
                .height = @floatFromInt(tex.height),
            };
            c.DrawTexturePro(tex, src, dst, .{ .x = 0, .y = 0 }, 0, c.WHITE);
        } else {
            c.DrawText("cannot display image", 40, 40, 24, c.RAYWHITE);
        }

        // 안내 + 위치 표시 (raylib 기본 폰트는 한글 미지원 → ASCII)
        var buf: [64]u8 = undefined;
        const info = std.fmt.bufPrintZ(&buf, "{d} / {d}   (left/right: move, Esc: grid)", .{ self.index + 1, photos.len }) catch "";
        c.DrawText(info.ptr, 20, screen_h - 36, 20, c.RAYWHITE);
    }
};

/// 화면 안에 종횡비를 유지하며 가운데 정렬로 꽉 채우는 사각형.
pub fn fitToScreen(iw: i32, ih: i32, sw: i32, sh: i32) c.Rectangle {
    const iwf: f32 = @floatFromInt(iw);
    const ihf: f32 = @floatFromInt(ih);
    const swf: f32 = @floatFromInt(sw);
    const shf: f32 = @floatFromInt(sh);
    const scale = @min(swf / iwf, shf / ihf);
    const w = iwf * scale;
    const h = ihf * scale;
    return .{ .x = (swf - w) / 2.0, .y = (shf - h) / 2.0, .width = w, .height = h };
}

test "fitToScreen: 가로로 긴 이미지 레터박스" {
    const r = fitToScreen(2000, 1000, 800, 600);
    // scale = min(0.4, 0.6) = 0.4 → 800x400, 세로 가운데
    try std.testing.expectApproxEqAbs(@as(f32, 800), r.width, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 400), r.height, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 100), r.y, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0), r.x, 0.01);
}

test "Viewer.move: 범위 클램프" {
    var v = Viewer{ .index = 0 };
    v.move(-1, 5); // 0에서 더 못감
    try std.testing.expectEqual(@as(usize, 0), v.index);
    v.move(3, 5);
    try std.testing.expectEqual(@as(usize, 3), v.index);
    v.move(10, 5); // 마지막으로 클램프
    try std.testing.expectEqual(@as(usize, 4), v.index);
}
