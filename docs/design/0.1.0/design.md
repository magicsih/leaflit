# Leaflit 0.1.0 실행 설계

2026-10-18 사용자가 전달한 구현 계획을 승인 근거로 삼는다. 범위는 Apple Silicon macOS 14 이상에서 실행할 읽기 전용 Markdown 뷰어의 로컬 후보다. 원격 저장소, push, 공개 배포, 공증은 포함하지 않는다. 구현 이력은 로컬 main에 기능별로 남긴다.

## 화면과 흐름

```text
┌────────────────────────────────────────────────────┐
│ ● ● ●  ←  Open       document.md        Find   − + │
├────────────────────────────────────────────────────┤
│              Heading                               │
│              Paragraph, links and math              │
│              ┌──────────────────────┐              │
│              │ code / table         │              │
│              └──────────────────────┘              │
└────────────────────────────────────────────────────┘
```

900×700 기본 창, 16pt 본문, 760pt 최대 폭과 시스템 색상을 사용한다. 빈 상태의 주 행동은 Open Markdown File이다. 본문, 검색, 오류 영역만 두고 사이드바는 만들지 않는다. 오류 때 이전 본문과 최신 상태가 아님을 알리는 문구, Retry와 Open 버튼을 유지한다. 도구 막대와 메뉴에 키보드 동작과 접근성 이름을 둔다.

Finder, Open, 드롭과 실행 도구는 동일한 파일 열기 경로를 쓴다. 파일 URL을 정규화해 중복 창을 피한다. 상대 Markdown 링크는 같은 창에서 열고 읽던 위치를 기록해 Back으로 돌아온다. 외부 링크는 사용자 클릭에 한해 기본 브라우저에서 연다.

## 구조와 보안

LeaflitCore는 Foundation만 사용하며 URL 분류, UTF-8 읽기, 갱신 번호와 이미지 허용 목록을 담당한다. AppKit 앱은 창과 메뉴, 파일 감시, 검색과 WKWebView를 담당한다. 웹 렌더러는 markdown-it, Mermaid 11, KaTeX를 앱에 포함한다. esbuild가 Safari 17용 모듈과 지연 로딩 묶음을 만든다. macOS 14 실제 실행은 별도 확인 상태로 둔다.

문서 내용은 WKWebView.callAsyncJavaScript의 arguments로 전달한다. 실행 코드 문자열에 문서를 삽입하지 않는다. 렌더러는 문서 번호를 확인하고 오래된 비동기 결과를 폐기한다. 파일과 상위 디렉터리 감시를 함께 사용해 파일 교체 저장을 처리한다. 보이던 블록의 원문 줄과 화면 내 위치로 스크롤을 복원한다.

HTML은 이스케이프하며 원격 자원은 CSP와 WebKit 규칙으로 차단한다. 로컬 PNG, JPEG는 원문에 있는 이미지 참조만 허용하고 실제 파일 형식도 확인한다. 번들 자원은 별도 URL 스킴에서 경로를 제한해 제공한다. Mermaid는 strict 보안 모드와 SVG 정화를 사용하고 문서 내 Mermaid 설정 지시문은 허용하지 않는다. KaTeX는 trust=false다. 서버, 원격 분석, 파일 쓰기, 전체 디스크 접근 요구를 넣지 않는다. 이 로컬 후보는 App Sandbox와 배포용 서명을 사용하지 않으며 운영체제의 기존 파일 접근 권한을 따른다.

## 검증과 복구

테스트 계획은 같은 폴더의 test-plan.json에 둔다. 문서 모듈은 자동 테스트를 먼저 작성한다. 화면 표현은 실제 WKWebView 통합 테스트와 독립 UI 검수 3회로 확인한다. 성능 수치는 비교 목표이며 합격을 가정하지 않는다. 지원 환경, 실행 여부, 후보 SHA와 남은 항목을 docs/qa에 기록한다. 실패 시 원문을 보존하고 앱을 종료하면 된다. PATH 설치와 Finder 기본 연결 변경은 하지 않는다.

## 공식 자료

- [markdown-it](https://github.com/markdown-it/markdown-it)
- [수식 파서와 혼합 구분자](https://mdit-plugins.github.io/tex.html)
- [Mermaid API](https://mermaid.js.org/config/usage.html)
- [Apple WKWebView](https://developer.apple.com/documentation/webkit/wkwebview)
