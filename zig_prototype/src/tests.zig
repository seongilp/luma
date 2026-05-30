//! 모든 모듈의 테스트를 한데 모으는 루트.
test {
    _ = @import("scanner.zig");
    _ = @import("photo.zig");
    _ = @import("gallery.zig");
    _ = @import("viewer.zig");
}
