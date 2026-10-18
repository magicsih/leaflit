# UI 독립 검수 2회차

## 실행 전 계획

- 검수자: 구현자와 다른 에이전트 `/root/ui_round2`.
- 승인 근거: `docs/design/0.1.0/design.md`, `test-plan.json`의 L3, 독립 UI 검수 3회 계획과 구현자의 2회차 실행 요청.
- 후보 SHA: `737bacf46c7c594de8505c12a0bb49297ebf4358`.
- 앱: `build/Leaflit-0.1.0/Leaflit.app` Release 앱.
- 환경: Apple M3, arm64, macOS 26.6.2, 빌드 25G83. 이전 macOS에서의 실행을 의미하지 않는다.
- 격리 데이터: 저장소의 `Fixtures/Welcome.md`, `Fixtures/Next Page.markdown`, `Fixtures/Errors.mdown`. 사용자 문서는 열지 않는다.
- 범위: 1회차 실패 3건의 회복 확인, 작은 창 약 640pt, 200% 확대, 코드와 표 가로 이동, 오류 원문과 HTML 텍스트 표시, 키보드와 가능한 VoiceOver 실제 탐색.
- 기대 결과: Mermaid 노드 글자가 보이고, View 메뉴 Back이 이전 문서로 이동하며, 본문 복사 결과를 검색 필드에 붙여넣을 수 있다. 작은 창과 확대에서 내용이 읽히고 긴 코드와 표에 가로 이동 경로가 있다. 잘못된 다이어그램과 수식은 원문과 짧은 오류를 남기며 HTML을 실행하지 않고 텍스트로 보여야 한다. 메뉴, 검색과 본문이 키보드 및 보조기술에서 탐색 가능해야 한다.
- 증거: native `cua_repl` 실제 화면과 접근성 트리를 읽는다. 코드 열람으로 UI 통과를 추정하지 않는다. 화면 캡처는 도구 실행 기록에 남고 별도 PNG 저장 여부는 결과에 적는다.
- 제한: 코드 수정, Finder 기본 연결 변경, PATH 설치, 모바일 기기 접근을 하지 않는다. 시스템 설정을 바꾸면 원복한다. 종료 후 앱을 닫고 UI 제어를 반환한다.

## 실제 수행과 결과

- 실행일: 2026-10-18 KST. 종료 확인 시각 `2026-10-18T12:50:14Z`.
- 실행 파일 수정 시각은 시작과 종료 모두 `2026-10-18T21:43:45+0900`이었다. 실행 중 구현자가 소스를 수정했지만 이 회차의 Release 앱은 교체하지 않았다.
- 시스템 다크 모드에서 검수했다. 라이트 모드는 이 회차에서 실행하지 않았다.
- 모든 화면은 native `cua_repl`의 실제 스크린샷과 접근성 트리로 확인했다. 별도 PNG는 저장하지 않았다.

| 항목 | 실제 수행과 관찰 | 결과 |
| --- | --- | --- |
| 1회차 Mermaid 라벨 | Open 패널로 Welcome.md를 열고 다이어그램으로 스크롤했다. `Open a file`, `Read the page`, `Follow a link`가 각 사각형 안에 보였다. | 회복, 통과 |
| 1회차 View Back | Welcome의 `next page`로 이동한 뒤 View > Back의 활성 항목을 클릭했다. 메뉴는 닫혔으나 창 제목과 본문은 Next Page.markdown에 남았다. | 실패 재현 |
| 1회차 본문 Copy와 검색 Paste | 상대 문서의 복사 문장을 3중 클릭해 선택하고 ⌘C, ⌘F, ⌘V를 눌렀다. 검색 필드에 `Copy this sentence: Leaflit keeps the original file intact.`가 들어왔다. 뒤쪽 공백도 들어가 `Not found`가 표시됐다. 붙여넣기 성공을 문장 검색 일치 성공으로 기록하지 않는다. | 붙여넣기 회복, 통과 |
| 작은 창 | Next Page 창의 오른쪽 아래를 드래그해 스크린샷 기준 640pt 너비로 줄였다. 본문 줄바꿈과 도구 막대가 읽혔다. | 통과 |
| 200% 확대 | 초기 100%에서 도구 막대 Zoom In을 10번 눌렀다. 구현의 10% 단위 동작에 따른 200%이며 화면에서도 글자가 두 배로 확대됐다. 640pt에서 제목, 본문과 한글, 이모지가 읽혔고 세로 스크롤이 생겼다. UI 자체에 배율 숫자 표시는 없다. | 통과 |
| 긴 코드 | 별도 격리 문서를 새 창으로 열고 640pt, 200%에서 코드의 가로 스크롤 막대를 오른쪽으로 드래그했다. 처음의 `START-OF-LINE`에서 끝의 `END-OF-LINE`까지 화면으로 확인했다. 가로 scroll 도구 호출은 화면 변화가 없어 막대 드래그로 확인했다. | 통과 |
| 긴 표 | 같은 조건에서 표의 독립 가로 스크롤 막대를 끝까지 드래그했다. `Column10`, `FINAL-CELL`이 보였고 본문 가로 위치에는 영향이 없었다. | 통과 |
| 수식 오류 | Errors.mdown에 `Formula could not be rendered`와 `\definitelyUnknown{x}`가 보였다. | 내용 통과, 테두리 결함 아래 기록 |
| 다이어그램 오류 | 잘못된 Mermaid에 `Diagram could not be rendered`와 원문이 남았다. 설정 지시문이 있는 두 번째 Mermaid도 오류와 원문을 표시했다. | 통과 |
| 누락 이미지 | 로컬 누락 이미지와 원격 이미지 모두 대체 텍스트와 `image unavailable`로 표시됐다. 실제 네트워크 차단 검증을 뜻하지 않는다. | 표시 통과 |
| 원문 HTML과 위험 URL | script 태그 전체가 텍스트로 보였고 경고창은 나타나지 않았다. `javascript:` 링크는 링크가 아닌 Markdown 텍스트로 AX에 노출됐다. | 해당 원문 표시 통과 |
| Custom app link | 링크 클릭 때 도구가 `frontmostApplicationChanged`를 반환했고 재조회에서 Errors.mdown은 유지됐다. 앱 외부 이동 여부를 독립적으로 확인하지 못해 보안 통과로 기록하지 않는다. | 미확인 |
| 키보드 | ⌘O, 열기 패널의 ⌘⇧G와 경로 입력, Return, ⌘F, 검색어 입력, ⌘C, ⌘V, ⌘Q가 동작했다. Errors에서 `Diagram` 검색 후 첫 일치가 파란색으로 선택됐고 Return 뒤 AX Selected text가 `diagram`으로 바뀌었다. | 수행 범위 통과 |

### 실패

1. **View > Back 미작동**: 1회차와 같은 실패를 구현자에게 전달했다. 이 회차 앱에서는 수정하지 않았다. 다음 후보에서 재검증이 필요하다.
2. **수식 오류의 테두리 조각**: Errors.mdown의 수식 오류 메시지와 원문은 읽히지만, 왼쪽 테두리가 여러 조각으로 끊겨 원문 블록 아래에 빈 괄호 조각처럼 남는다. 900pt, 100% 화면에서 확인했다. 다이어그램 오류 상자는 정상 사각 테두리다.

### VoiceOver와 접근성

- 실제 음성 탐색은 **미실행**이다. Leaflit에서 ⌘F5를 두 번 시도했고 창 Raise 후에도 활성 UI 변화가 없었다. 앱 목록에 VoiceOver가 나타나지 않았으며 종료 전 `pgrep -x VoiceOver`도 결과가 없었다. Cua의 앱 대상 키 입력으로 시스템 단축키가 전달됐는지는 확인할 수 없다. 따라서 앱의 VoiceOver 실패로 단정하지 않는다.
- 구현자가 검수 중 다른 앱을 조작하지 말라고 지시했으므로 System Settings나 VoiceOver Utility를 열어 우회하지 않았다. VoiceOver를 켠 것으로 확인된 상태가 없고 시스템 설정은 변경하지 않았다.
- Welcome의 AX 트리에서 다이어그램은 `image Diagram` 한 개였으며 노드 라벨은 자식 텍스트로 나오지 않았다. 보이는 라벨 회복과 보조기술에 전달되는 이름은 다른 상태다. 실제 VoiceOver 읽기 결과는 미확인이다.
- 수식은 AX에서 적분 기호, 수, 지수와 식의 조각 텍스트로 노출됐다. 이를 자연스러운 수식 음성 읽기 통과로 바꾸지 않는다.
- 전체 메뉴 키보드 탐색, 뒤로 가기 단축키, VoiceOver 링크와 표 탐색은 통과 근거가 없다.

## 격리 데이터와 원문 보존

긴 코드와 표 검수용으로 `/tmp/leaflit-ui-round2/Wide Reading.md`를 만들었다. 10열 표와 한 줄 코드, 한글과 이모지 문단을 포함하며 사용자 문서가 아니다. 이 파일은 재현을 위해 종료 후 남겼다.

시작과 종료 SHA-256이 아래와 같아 열람한 네 문서의 내용이 바뀌지 않았다.

| 문서 | SHA-256 |
| --- | --- |
| Fixtures/Welcome.md | `41eceab164f37bcc04639ca4d7cf41a91831b699849b54ca011632e640dc4201` |
| Fixtures/Next Page.markdown | `af959c36eabbe02c4deac10651fa62be5fcaadbed1bd1cf9cbea4e7c1e6df451` |
| Fixtures/Errors.mdown | `4ea2141055ccf8f518f87da78ad0c9878d9c705394dd3d7782d9a3e32a7fcf19` |
| /tmp/leaflit-ui-round2/Wide Reading.md | `9edca12ebb6da47c43450deb8c7f0508603fc8989d6b0efac02f8683a116e39a` |

## 종료와 남은 범위

⌘Q 후 `pgrep -x Leaflit`와 `pgrep -x VoiceOver` 결과가 모두 비어 있었다. Finder 기본 연결, PATH, 시스템 appearance, 네트워크, 사용자 문서와 모바일 기기를 변경하거나 조작하지 않았다. 이 검수자는 제품 코드를 수정하지 않았다. UI 제어를 구현자에게 반환한다.

2회차만으로 라이트 모드, 실제 네트워크 차단, 파일 감시와 오류 복구, Finder 드롭, 성능, macOS 14 실행, VoiceOver 음성을 확인한 것으로 표시하지 않는다. View Back과 수식 오류 테두리는 다음 후보에서 확인해야 한다.
