# LUMA

**온디바이스 AI 사진 관리자 (macOS)**

비슷한 컷 자동 묶기, 위치·인물 분류, RAW·EXIF 편집까지 — 전부 당신의 맥 안에서.
핵심 분석은 Apple Vision으로 기기 안에서 처리하고, 사진은 단 한 장도 밖으로 나가지 않습니다.

🔗 **랜딩 페이지**: https://seongilp.github.io/luma/

---

## ✨ 기능

**AI / 분석 (온디바이스)**
- **유사 사진** — Apple Vision 의미 기반 묶기 / 해시(빠름) 모드, "1장만 남기고 정리"
- **지도** — EXIF GPS 핀(OpenStreetMap), 위치 없는 사진은 Vision 시각 매칭으로 추정
- **Claude 위치 찾기** — 못 찾은 사진만, 비슷한 건 묶어 대표만 전송(토큰 절약)
- **인물** — 얼굴 인식 기반 사람별 분류
- **날짜별 앨범 · 통계** — 요일별 촬영 패턴을 이번 주·지난달·작년과 라인 차트로 비교
- **AI Quick Check** — Claude가 구도·노출·초점 즉석 점검
- **온디바이스 OCR** — 사진 속 한·영 텍스트 인식·복사
- **분석 캐시** — 다시 열어도 즉시, 재계산·재과금 0

**관리 / 워크플로우**
- 그리드 · 탐색기식 리스트 · 필름스트립 · 폴더 트리
- 다중 선택, 삭제(휴지통)·이름변경·이동/복사, 즐겨찾기·별점
- 2~4장 동기화 비교 + 기준(Reference) 비교
- RAW+JPG 페어링, 동영상(MP4/MOV/M4V) 재생, 히스토그램
- 무손실 EXIF 날짜·GPS 보정, Finder 태그, Lightroom XMP 연동
- 내보내기(JPEG/PNG) + SNS 프리셋, ZIP 바로 열기, Finder식 자연 정렬
- 접근성 확대(⌘ +/−/0), 마지막 폴더 자동 열기

## 🧱 스택

- **Flutter** (macOS desktop) + `macos_ui`
- **Apple Vision** (Swift 브리지): 특징벡터·얼굴 검출·OCR·무손실 메타데이터 쓰기
- **Claude** (Anthropic API, 선택): 위치 추정·Quick Check — 자격증명은 설정/환경변수로만

## 🚀 실행

```bash
cd flutter_app
flutter run -d macos                 # 디버그
flutter build macos --release        # 릴리즈 빌드 (build/macos/.../LUMA.app)
```

Claude 기능을 쓰려면 설정창에 API 키(또는 `ANTHROPIC_API_KEY` / Cloudflare AI Gateway) 입력.
비밀은 코드에 없으며 `~/Library/Application Support/photo_manager/`에 저장됩니다.

## 📁 구조

```
flutter_app/     LUMA 앱 (Flutter + Swift 브리지)
landing/         랜딩 페이지 (GitHub Pages, 네오브루탈리즘)
zig_prototype/   초기 Zig+raylib 프로토타입 (보존)
docs/            설계 스펙
```

## 라이선스

개인 프로젝트. 랜딩 데모 이미지는 picsum.photos / unsplash.com 출처.
