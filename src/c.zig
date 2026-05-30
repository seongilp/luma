//! raylib C API 단일 진입점.
//! @cImport는 파일마다 호출하면 별개의 타입을 만들어 충돌하므로,
//! 여기서 한 번만 import하고 다른 모듈은 이 `ray`를 재사용한다.
pub const ray = @cImport({
    @cInclude("raylib.h");
});
