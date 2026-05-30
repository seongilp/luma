const std = @import("std");
const c = @import("c.zig").ray;
const Photo = @import("photo.zig").Photo;

/// 썸네일 한 변(픽셀)과 셀 간격.
pub const thumb_px: i32 = 200;
const pad: f32 = 12.0;
const cell: f32 = @as(f32, @floatFromInt(thumb_px)) + pad;

/// 순수 그리드 레이아웃 계산. 렌더링과 분리해 단위테스트 가능하게 둔다.
pub const Grid = struct {
    cols: usize,

    /// 뷰포트 너비에 맞춰 열 개수를 정한다 (최소 1열).
    pub fn init(viewport_w: f32) Grid {
        const usable = viewport_w - pad;
        const cols_f = @floor(usable / cell);
        const cols: usize = if (cols_f < 1) 1 else @intFromFloat(cols_f);
        return .{ .cols = cols };
    }

    /// 인덱스 셀의 좌상단 좌표 (스크롤 적용 전).
    pub fn cellOrigin(self: Grid, index: usize) struct { x: f32, y: f32 } {
        const row = index / self.cols;
        const col = index % self.cols;
        return .{
            .x = pad + @as(f32, @floatFromInt(col)) * cell,
            .y = pad + @as(f32, @floatFromInt(row)) * cell,
        };
    }

    /// 전체 콘텐츠 높이 (스크롤 범위 계산용).
    pub fn contentHeight(self: Grid, count: usize) f32 {
        if (count == 0) return 0;
        const rows = (count + self.cols - 1) / self.cols;
        return pad + @as(f32, @floatFromInt(rows)) * cell;
    }

    /// 현재 스크롤/뷰포트에서 보이는 인덱스 범위 [start, end).
    pub fn visibleRange(self: Grid, scroll_y: f32, viewport_h: f32, count: usize) struct { start: usize, end: usize } {
        if (count == 0) return .{ .start = 0, .end = 0 };
        const first_row_f = @floor((scroll_y - pad) / cell);
        const first_row: usize = if (first_row_f < 0) 0 else @intFromFloat(first_row_f);
        const last_row_f = @floor((scroll_y + viewport_h - pad) / cell);
        const last_row: usize = if (last_row_f < 0) 0 else @intFromFloat(last_row_f);

        const start = first_row * self.cols;
        const end = @min(count, (last_row + 1) * self.cols);
        return .{ .start = @min(start, count), .end = end };
    }

    /// 화면 좌표(스크롤 적용 후)에 해당하는 썸네일 인덱스. 없으면 null.
    pub fn indexAt(self: Grid, mx: f32, my: f32, scroll_y: f32, count: usize) ?usize {
        const doc_y = my + scroll_y;
        if (mx < pad or doc_y < pad) return null;
        const col_f = @floor((mx - pad) / cell);
        const row_f = @floor((doc_y - pad) / cell);
        if (col_f < 0 or row_f < 0) return null;
        const col: usize = @intFromFloat(col_f);
        const row: usize = @intFromFloat(row_f);
        if (col >= self.cols) return null;
        // 셀 내부 패딩 영역(이미지 밖) 클릭은 무시
        const cell_x = (mx - pad) - col_f * cell;
        const cell_y = (doc_y - pad) - row_f * cell;
        const tp: f32 = @floatFromInt(thumb_px);
        if (cell_x > tp or cell_y > tp) return null;
        const idx = row * self.cols + col;
        if (idx >= count) return null;
        return idx;
    }
};

/// 종횡비를 유지하며 thumb_px×thumb_px 칸 안에 들어가는 그리기 사각형.
fn fittedRect(origin_x: f32, origin_y: f32, aspect: f32) c.Rectangle {
    const box: f32 = @floatFromInt(thumb_px);
    var w = box;
    var h = box;
    if (aspect >= 1.0) {
        h = box / aspect;
    } else {
        w = box * aspect;
    }
    return .{
        .x = origin_x + (box - w) / 2.0,
        .y = origin_y + (box - h) / 2.0,
        .width = w,
        .height = h,
    };
}

/// 보이는 범위의 썸네일을 그린다. 로드 전/실패는 placeholder로 표시한다.
pub fn draw(grid: Grid, photos: []Photo, scroll_y: f32, viewport_h: f32, hovered: ?usize) void {
    const range = grid.visibleRange(scroll_y, viewport_h, photos.len);
    var i = range.start;
    while (i < range.end) : (i += 1) {
        const o = grid.cellOrigin(i);
        const x = o.x;
        const y = o.y - scroll_y;
        const box: f32 = @floatFromInt(thumb_px);

        const photo = &photos[i];
        switch (photo.state) {
            .loaded => if (photo.texture) |tex| {
                const dst = fittedRect(x, y, photo.aspect);
                const src = c.Rectangle{
                    .x = 0,
                    .y = 0,
                    .width = @floatFromInt(tex.width),
                    .height = @floatFromInt(tex.height),
                };
                c.DrawTexturePro(tex, src, dst, .{ .x = 0, .y = 0 }, 0, c.WHITE);
            },
            .failed => drawPlaceholder(x, y, box, photo.path, c.MAROON),
            .unloaded => drawPlaceholder(x, y, box, "", c.LIGHTGRAY),
        }

        if (hovered != null and hovered.? == i) {
            c.DrawRectangleLinesEx(.{ .x = x, .y = y, .width = box, .height = box }, 3, c.SKYBLUE);
        }
    }
}

fn drawPlaceholder(x: f32, y: f32, box: f32, label: []const u8, color: c.Color) void {
    c.DrawRectangle(@intFromFloat(x), @intFromFloat(y), @intFromFloat(box), @intFromFloat(box), color);
    if (label.len > 0) {
        const base = std.fs.path.basename(label);
        var buf: [256]u8 = undefined;
        const n = @min(base.len, buf.len - 1);
        @memcpy(buf[0..n], base[0..n]);
        buf[n] = 0;
        c.DrawText(&buf, @intFromFloat(x + 8), @intFromFloat(y + 8), 14, c.RAYWHITE);
    }
}

test "Grid.init: 열 개수" {
    // cell = 212. 너비 900 → usable 888 → floor(888/212)=4
    try std.testing.expectEqual(@as(usize, 4), Grid.init(900).cols);
    // 아주 좁아도 최소 1열
    try std.testing.expectEqual(@as(usize, 1), Grid.init(50).cols);
}

test "Grid.contentHeight / visibleRange" {
    const g = Grid{ .cols = 4 };
    // 10장 → 3행 → pad + 3*cell
    const h = g.contentHeight(10);
    try std.testing.expectApproxEqAbs(@as(f32, 12 + 3 * 212), h, 0.01);

    // 스크롤 0, 뷰포트 1행만 보이는 높이 → 첫 행 인덱스
    const r = g.visibleRange(0, 100, 10);
    try std.testing.expectEqual(@as(usize, 0), r.start);
    // 첫 행(0..3) + 둘째 행 일부까지: end는 cols 배수, 최소 첫 행 포함
    try std.testing.expect(r.end >= 4);
}

test "Grid.indexAt: 히트 테스트" {
    const g = Grid{ .cols = 4 };
    // 첫 셀 중앙 (pad+100, pad+100), scroll 0 → index 0
    try std.testing.expectEqual(@as(?usize, 0), g.indexAt(112, 112, 0, 10));
    // 둘째 열 (pad + cell + 100)
    try std.testing.expectEqual(@as(?usize, 1), g.indexAt(12 + 212 + 100, 112, 0, 10));
    // 패딩 영역(셀 사이 빈틈) → null
    try std.testing.expectEqual(@as(?usize, null), g.indexAt(12 + 205, 112, 0, 10));
    // 범위 밖
    try std.testing.expectEqual(@as(?usize, null), g.indexAt(5000, 112, 0, 10));
}
