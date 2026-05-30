const std = @import("std");

// tinyfiledialogs는 raylib와 타입을 공유하지 않으므로 별도 cImport로 둔다.
const tfd = @cImport({
    @cInclude("tinyfiledialogs.h");
});

/// 네이티브 폴더 선택 다이얼로그를 띄운다. 취소하면 null.
/// 선택 경로를 allocator로 복제해 돌려준다 (tinyfd 내부 버퍼는 임시이므로).
/// 호출자가 반환 슬라이스를 해제해야 한다.
pub fn pickFolder(allocator: std.mem.Allocator, title: [*:0]const u8) !?[]u8 {
    const res = tfd.tinyfd_selectFolderDialog(title, "");
    if (res == null) return null;
    return try allocator.dupe(u8, std.mem.span(res));
}
