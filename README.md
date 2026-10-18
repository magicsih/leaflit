# Leaflit

macOS용 읽기 전용 Markdown 뷰어. 파일을 열어 바로 읽고, 저장된 변경을 자동으로 반영한다. 영어 UI와 시스템 라이트, 다크 모드를 사용한다.

Swift, AppKit과 WKWebView로 만든 Apple Silicon 앱이다. macOS 14 이상을 대상으로 빌드한다. 실제 검증 환경은 Apple M3, macOS 26.6.2이며 이전 OS에서 실행한 결과는 아직 없다.

## 로컬 빌드

Xcode 27, Node.js 24와 npm 11에서 확인했다. 의존성 버전은 package-lock.json으로 고정한다. 일반 빌드에 Ruby나 프로젝트 생성 도구는 필요 없다.

```sh
./scripts/build.sh
open build/Leaflit-0.1.0/Leaflit.app
./build/Leaflit-0.1.0/leaflit Fixtures/Welcome.md
open -a "$PWD/build/Leaflit-0.1.0/Leaflit.app" "Fixtures/Next Page.markdown"
```

Xcode에서는 웹 자산을 먼저 만든 뒤 Leaflit.xcodeproj의 Leaflit scheme을 실행한다.

```sh
npm ci --ignore-scripts
npm run build
open Leaflit.xcodeproj
```

릴리스 후보 폴더에 앱과 leaflit 실행 도구가 함께 들어간다. 실행 도구는 옆의 앱을 사용하므로 폴더째 옮길 수 있다. PATH 설치와 Finder 기본 연결 변경은 직접 선택한다. 로컬 Apple Silicon 실행을 위한 임시 서명만 사용하며 Developer ID 서명과 공증은 하지 않았다.

## 읽기

Finder의 Open With, File의 Open 메뉴, 파일 드롭이나 `leaflit` 실행 도구로 `.md`, `.markdown`, `.mdown` 파일을 연다. UTF-8 문서를 지원한다. 같은 파일은 기존 창을 활성화하고, 별도로 연 파일은 새 창에 표시한다. 상대 문서 링크는 현재 창에서 이동하고 Back으로 돌아온다. 대상 파일이 이미 다른 창에 열려 있으면 그 창을 활성화한다.

| 동작 | 단축키 |
| --- | --- |
| 열기 | ⌘O |
| 검색 | ⌘F |
| 다음, 이전 검색 결과 | ⌘G, ⇧⌘G |
| 뒤로 이동 | ⌘[ |
| 선택 복사 | ⌘C |
| 확대, 축소, 기본 크기 | ⌘+, ⌘−, ⌘0 |

기본 문법, 표, 취소선, 읽기 전용 체크 목록과 코드 블록을 표시한다. Mermaid와 KaTeX 및 글꼴은 앱에 포함된다. 수식 구분자는 `$…$`, `$$…$$`, `\(…\)`, `\[…\]`를 지원한다. 잘못된 다이어그램과 수식에는 원문과 오류 표시를 남긴다.

로컬 PNG와 JPEG만 표시한다. 원문 HTML은 텍스트로 표시하고 원격 이미지, 스크립트, 위험한 링크와 Mermaid 문서 내 설정은 차단한다. 웹 링크는 사용자가 클릭할 때 기본 브라우저로 연다. 계정, 서버, 원격 분석과 원문 편집 기능은 없다. 코드 구문 색상, 목차, 인쇄, PDF, Obsidian 문법과 자동 업데이트는 이번 버전에 포함하지 않는다.

## 검증

```sh
./scripts/verify.sh
# 첫 표시 20회 측정과 자원 측정은 다른 앱 검수와 분리해 실행
python3 scripts/benchmark.py
python3 scripts/measure-resources.py
# 빈 창과 기능별 메모리 비교, 창 닫기 뒤 사용량 측정
python3 scripts/measure-memory-cases.py
# Foundation 문서 처리 모듈만 확인
swift test
# 웹 문법 처리만 확인
npm test
```

[실행 설계](docs/design/0.1.0/design.md), [테스트 계획](docs/design/0.1.0/test-plan.json)과 [검수 보고서](docs/qa/report.md)를 참고한다. 설치 크기와 성능은 실제 측정 결과를 보고하며 초기 목표 충족을 가정하지 않는다.

[메모리 분리 측정](docs/qa/memory-analysis.md)은 같은 Release 앱에서 빈 창, 일반 본문, 수식과 Mermaid의 사용량을 비교한다. 생성한 문서와 측정 원본은 `build/memory-cases`에 남는다.

프로젝트 구조를 바꿀 때만 `ruby scripts/generate-project.rb`로 프로젝트를 재생성한다. 이 명령에는 xcodeproj 1.27.0이 필요하다. 생성된 Xcode 프로젝트와 scheme은 저장소에 포함한다.

MIT License. 번들 내부 THIRD-PARTY-NOTICES.txt에 렌더러 의존성의 라이선스를 포함한다.
