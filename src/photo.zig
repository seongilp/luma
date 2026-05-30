const std = @import("std");
const c = @import("c.zig").ray;

/// 한 장의 사진. 경로는 raylib C 호출을 위해 null 종료 문자열로 보관한다.
pub const Photo = struct {
    /// 원본 파일 경로 (소유; allocator로 해제).
    path: [:0]u8,
    /// 그리드용 썸네일 GPU 텍스처. null이면 아직 로드 전/해제됨.
    texture: ?c.Texture2D = null,
    state: State = .unloaded,
    /// 썸네일 가로/세로 비율 (그리기용). 1.0 = 정사각.
    aspect: f32 = 1.0,

    pub const State = enum { unloaded, loaded, failed };

    /// 텍스처가 올라가 있으면 GPU에서 내리고 unloaded로 되돌린다.
    pub fn unloadTexture(self: *Photo) void {
        if (self.texture) |tex| {
            c.UnloadTexture(tex);
            self.texture = null;
            if (self.state == .loaded) self.state = .unloaded;
        }
    }
};

/// 종횡비를 유지하며 가장 긴 변이 `max`가 되도록 축소 크기를 계산한다.
/// 원본이 max보다 작으면 그대로 둔다 (확대하지 않음).
pub fn fitDims(w: i32, h: i32, max: i32) struct { w: i32, h: i32 } {
    if (w <= 0 or h <= 0) return .{ .w = 1, .h = 1 };
    if (w <= max and h <= max) return .{ .w = w, .h = h };
    const wf: f32 = @floatFromInt(w);
    const hf: f32 = @floatFromInt(h);
    const scale = @as(f32, @floatFromInt(max)) / @max(wf, hf);
    const nw: i32 = @max(1, @as(i32, @intFromFloat(wf * scale)));
    const nh: i32 = @max(1, @as(i32, @intFromFloat(hf * scale)));
    return .{ .w = nw, .h = nh };
}

/// 디스크에서 이미지를 디코드해 썸네일 텍스처를 생성한다.
/// 실패(깨진/미지원 파일)하면 state를 .failed로 두고 크래시하지 않는다.
pub fn loadThumbnail(photo: *Photo, thumb_px: i32) void {
    var img = c.LoadImage(photo.path.ptr);
    if (!c.IsImageValid(img)) {
        std.log.warn("이미지 로드 실패: {s}", .{photo.path});
        photo.state = .failed;
        return;
    }
    defer c.UnloadImage(img);

    const dims = fitDims(img.width, img.height, thumb_px);
    c.ImageResize(&img, dims.w, dims.h);

    const tex = c.LoadTextureFromImage(img);
    if (!c.IsTextureValid(tex)) {
        photo.state = .failed;
        return;
    }
    photo.texture = tex;
    photo.aspect = @as(f32, @floatFromInt(dims.w)) / @as(f32, @floatFromInt(dims.h));
    photo.state = .loaded;
}

test "fitDims: 종횡비 유지 축소" {
    const r1 = fitDims(4000, 2000, 200);
    try std.testing.expectEqual(@as(i32, 200), r1.w);
    try std.testing.expectEqual(@as(i32, 100), r1.h);

    const r2 = fitDims(1000, 2000, 200);
    try std.testing.expectEqual(@as(i32, 100), r2.w);
    try std.testing.expectEqual(@as(i32, 200), r2.h);

    // 이미 작으면 그대로
    const r3 = fitDims(150, 100, 200);
    try std.testing.expectEqual(@as(i32, 150), r3.w);
    try std.testing.expectEqual(@as(i32, 100), r3.h);

    // 정사각
    const r4 = fitDims(500, 500, 200);
    try std.testing.expectEqual(@as(i32, 200), r4.w);
    try std.testing.expectEqual(@as(i32, 200), r4.h);
}
