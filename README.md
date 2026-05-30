# zig_photo

macOS용 사진 관리 앱 (Zig + raylib). 폴더의 사진을 썸네일 그리드로 둘러보고 큰 화면으로 보는 MVP.

## 현재 기능 (MVP)

- **GUI 폴더 선택** — 시작 시(인자 없으면) 또는 `O` 키로 네이티브 폴더 다이얼로그
- 폴더 **재귀 스캔** (JPEG/PNG)
- **정사각 cover 썸네일 그리드** — 가운데 크롭으로 균일 정렬, GPU 렌더, 휠 스크롤, 창 크기 대응
- 썸네일 클릭 → **큰 이미지 뷰어** (← → 이동, Esc/우클릭으로 그리드 복귀)
- **지연 로딩 + 캐시 퇴출** — 보이는 썸네일만 디코드/업로드하고 멀어지면 GPU에서 내림 (수천 장 대비)
- 깨진/미지원 파일은 placeholder로 표시하고 크래시하지 않음

지원 포맷은 현재 JPEG/PNG. HEIC·메타데이터·검색·정리·DB는 다음 단계 (스펙: `docs/superpowers/specs/`).

## 요구 사항

- macOS (Apple Silicon 기준)
- [Zig](https://ziglang.org) **0.16.x** (`brew install zig`)
- raylib 5.5 (`brew install raylib`)

> 참고: zig 0.15.x는 현재 macOS(Tahoe)의 SDK와 링크가 깨져 0.16을 사용합니다.
> raylib 경로는 `build.zig`의 `raylib_prefix`에 하드코딩돼 있습니다 (`/opt/homebrew/opt/raylib`).

## 빌드 & 실행

```sh
# 빌드
zig build

# 인자 없이 실행하면 폴더 선택 다이얼로그가 뜬다
zig build run

# 폴더를 바로 지정할 수도 있다
zig build run -- /path/to/photos
./zig-out/bin/zig_photo /path/to/photos

# 테스트
zig build test --summary all
```

## 조작

| 입력 | 동작 |
|------|------|
| **O** | **폴더 선택 다이얼로그 열기** |
| 마우스 휠 | 그리드 스크롤 |
| 썸네일 클릭 | 큰 보기 진입 |
| ← / → | 이전 / 다음 사진 |
| Esc / 우클릭 | 그리드로 복귀 |

## 구조

| 파일 | 책임 |
|------|------|
| `src/main.zig` | 앱 루프, 입력 처리, 모드 전환, 조립 |
| `src/scanner.zig` | 폴더 재귀 스캔 + 확장자 필터 |
| `src/photo.zig` | Photo 모델, 썸네일 디코드/축소/텍스처화 |
| `src/library.zig` | 사진 목록 소유, 지연 로딩 예산, 캐시 퇴출 |
| `src/gallery.zig` | 그리드 레이아웃 계산(순수) + 렌더 |
| `src/viewer.zig` | 단일 이미지 큰 보기 + 탐색 |
| `src/c.zig` | raylib `@cImport` 단일 진입점 |
| `src/dialog.zig` | tinyfiledialogs 기반 네이티브 폴더 선택 |
| `vendor/tinyfiledialogs/` | 폴더 다이얼로그용 벤더 C 라이브러리 (zlib 라이선스) |

순수 로직(스캔 필터, 축소 비율, 그리드 좌표↔인덱스, 화면 맞춤)은 `zig build test`로 단위 검증.
화면 텍스트는 raylib 기본 폰트에 한글 글리프가 없어 ASCII로 표기.
