# UI 독립 검수 3회차

## 후보와 실행 환경

- 검수자: 구현자와 다른 에이전트 `/root/ui_round3`.
- 승인 근거와 실행 전 계획: `docs/design/0.1.0/design.md`, `test-plan.json`, `docs/qa/ui-round3-plan.md`와 구현자의 최종 후보 실행 요청.
- 후보 SHA: `dffa027d7aa566b915ea0a0fe59a80af73922e01`.
- 실행일: 2026-10-18 KST.
- 환경: Apple M3, 24GB 메모리, arm64, macOS 26.6.2, 빌드 25G83. macOS 14와 15에서는 실행하지 않았다.
- Release 앱: `build/Leaflit-0.1.0/Leaflit.app`. 실행 파일 SHA-256은 `e8a08c1690631337f49801d039a4ee11d3c93f60d9eb371b7515578bae82cce7`이다.
- 격리 데이터: 읽기 전용 `Fixtures`와 검수자가 만든 `build/qa-round3`. 사용자 문서는 열지 않으며 Finder 기본 연결과 PATH를 바꾸지 않는다.

## 독립 자동 실행

다음 명령을 차례로 직접 실행했다. 구현자의 실행 결과를 복사하지 않았다.

```sh
./scripts/verify.sh > build/verify-independent.log 2>&1
./scripts/build.sh > build/build-independent.log 2>&1
python3 scripts/benchmark.py > build/benchmark-independent.log 2>&1
python3 scripts/measure-resources.py > build/resources-independent.log 2>&1
```

| 검사 | 실제 결과 |
| --- | --- |
| 웹 문법 | 4개 통과, 실패 0개 |
| Foundation 모듈 | 6개 통과, 실패 0개 |
| Xcode 테스트 | 18개 통과, 실패 0개. 문서 모듈 6개와 실제 WKWebView 통합 테스트 12개다. |
| 배포용 의존성 점검 | `npm audit --omit=dev` 취약점 0개 |
| 최종 Release 빌드 | `BUILD SUCCEEDED`. build-info와 verification에 같은 후보 SHA가 기록됐다. |

Xcode 결과는 `build/DerivedData/Logs/Test/Test-Leaflit-2026.10.18_22-02-35-+0900.xcresult`에 있다. 640pt, 200% 라이트와 다크 PNG를 `build/qa-screenshots`에 내보내 직접 봤다. 제목, 한글, 이모지, 수식과 Mermaid의 Open, Read 글자가 읽히며 본문 가로 넘침이 없다. 이 첨부는 개발 테스트 창에서 찍은 화면이며 Release 앱을 사람이 조작한 증거와 구분한다.

## 성능과 자원

100KiB 고정 문서는 102400바이트다. 본문 첫 표시와 수식, 다이어그램 표시 완료를 따로 측정했다. 새 앱 열기는 각 회차 새 프로세스로 실행했으며 OS 파일 캐시를 비우지 않았다. 문서 전환은 실제 WKWebView를 쓰는 통합 테스트에서 20회 실행했다. p95는 정렬한 20개 표본의 19번째 값이다.

| 작업 | 횟수 | 본문 중앙값 | 본문 p95 | 완료 중앙값 | 완료 p95 |
| --- | --- | --- | --- | --- | --- |
| 새 앱 열기 | 20 | 1169.9ms | 1288.9ms | 1508.2ms | 1622.7ms |
| 문서 전환 | 20 | 115.0ms | 121.5ms | 172.3ms | 192.7ms |

새 앱 열기 최대값은 본문 2033.6ms, 완료 2400.2ms다. 전환 최대값은 본문 152.0ms, 완료 253.9ms다. 100KiB 파일 교체 저장의 본문 반영은 252.3ms였다. 약 1MiB 문서는 880.7ms와 909.6ms, 약 5MiB 문서는 3074.3ms와 3107.4ms였다. 큰 문서는 각각 1048573바이트와 5242873바이트이며 열람 전후 내용이 같다는 자동 검증을 통과했다.

실제 표본은 `build/benchmarks/cold-opens.json`, `build/qa-screenshots/24D0381D-E377-49F7-AADE-40317D8B1AF1.json`과 `build/qa-round3/timing-summary.json`에 있다. 앱 설치 폴더 크기는 `du -sh` 기준 5.5MiB다.

새 앱과 새 WebKit WebContent, GPU, Networking 프로세스를 실행 전 PID 목록과 비교해 측정했다. 60개 유휴 표본의 실제 경과 시간은 70.34초였으며 네 프로세스의 CPU 합계는 0.142%였다. 종료 시점 RSS 합계는 142.375MiB, 앱만의 RSS는 약 74.45MiB다. 시작 직후 `footprint` 합계는 155749664바이트로 약 148.53MiB이며 이 가운데 앱은 약 32.99MiB다. RSS와 footprint는 측정 시점과 정의가 다르다. 앱과 WebKit을 합친 60MiB 목표는 충족하지 못했다. 원본은 `build/benchmarks/resources.json`, `footprint.json`, `footprint.txt`에 있다.

## 실제 UI 실행

자동 검증과 자원 측정 뒤 최종 Release 앱을 열었다. 실제 화면과 접근성 트리를 `cua_repl`에서 읽었다. 아래 화면 캡처는 도구 실행 기록에 남아 있으며 별도 PNG로 저장하지 않았다.

| 항목 | 실제 행동과 관찰 | 결과 |
| --- | --- | --- |
| 빈 상태 | 최종 앱을 열자 문서 아이콘, `Open a Markdown file`, 드롭 안내와 Open 버튼이 보였다. | 통과 |
| Open 메뉴 | Cmd+O로 표준 Open 패널이 열렸다. Go to Folder에서 경로 입력과 완료가 안정적으로 전달되지 않아 경로를 선택해 여는 단계까지 확인하지 못했다. | 패널 열기 통과, 파일 선택 미확인 |
| 실행 도구와 경로 | 함께 빌드된 `leaflit` 도구로 `build/qa-round3/한글 live file.md`를 열었다. 공백과 한글 파일명, 한글과 이모지 본문이 보였다. 같은 경로를 다시 열었을 때 같은 문서 창이 활성화됐다. | 통과 |
| 중복 제목 앵커 | `Repeated heading`을 클릭했다. 스크롤 막대가 0에서 1로 바뀌고 두 번째 Repeat 제목과 `Second repeated heading target.`이 화면에 보였다. | 통과 |
| 일반 저장 | 문서 중간 스크롤 값 0.500073에서 일반 파일 쓰기를 했다. 화면 첫 문장의 `Read marker 20`이 `Read marker 20 UPDATED`로 바뀌고 화면의 같은 높이에 남았다. | 통과 |
| 파일 교체와 연속 갱신 | 같은 문서를 임시 파일과 rename으로 20회 연속 교체했다. 화면 첫 문장이 `Read marker 20 FINAL 20`으로 바뀌었고 읽던 위치가 유지됐다. | 통과 |
| 동일 내용과 주변 파일 변경 | 최종 내용과 같은 바이트로 파일을 교체하고 같은 폴더에 관계없는 txt 파일을 썼다. 화면의 Next document 링크를 눌러 next page.markdown과 Target 제목을 같은 창에서 열었다. | 통과 |
| 도구 막대 Back | 상대 문서에서 Back 버튼을 눌렀다. 이전 문서와 스크롤 값 0.500073, marker 20이 복원됐다. | 통과 |
| View 메뉴 | 상대 문서에서 도구 막대 Back은 활성인데 View 메뉴 Back은 비활성이었다. Zoom In, Zoom Out, Actual Size도 비활성이었다. 구현자 요청으로 CLI 전면 활성화 직후 한 번 더 열었고 Zoom 세 항목이 계속 비활성이었다. 이후 새 연결의 한정 확인 결과는 아래에 기록했다. | 초기 실패 관찰, 최종 확인 통과 |
| 파일 삭제 | 검수자가 만든 문서를 삭제했다. 이전 본문과 `This file could not be refreshed. The previous content is still shown.`, Retry와 Open 버튼을 확인했다. Retry 뒤에도 본문이 남고 읽기 실패 문구가 보였다. | 통과 |
| 삭제 복구 | 해당 경로에 문서를 다시 썼다. 오류 행이 사라지고 `Read marker 20 RECOVERED`가 이전 위치에서 보였다. | 통과 |
| 잘못된 UTF-8 | 검수용 파일을 잘못된 바이트로 바꿨다. 이전 본문을 유지한 상태에서 갱신 실패와 Retry, Open을 확인했다. 이후 파일을 유효한 UTF-8로 되돌렸으나 복구된 본문을 이 회차에서 다시 관찰하지는 않았다. | 오류 표시 통과, 이 사례의 복구 화면 미확인 |
| 수식 오류 테두리 | Render and safety.md를 열었다. 수식 오류의 원문과 짧은 메시지가 하나로 이어진 사각형 테두리 안에 보였다. 2회차의 분절된 테두리가 사라졌다. | 회복, 통과 |
| 오류와 악성 원문 | script 태그와 javascript 링크는 원문 텍스트로 보였고 경고창이 생기지 않았다. 잘못된 수식과 Mermaid는 짧은 오류와 원문을 남겼다. | 해당 원문 표시 통과 |
| Mermaid 접근성 | Open과 Read 글자가 사각형 안에 보였다. AX에는 `image Diagram: Open. Read`가 노출됐다. | 통과 |
| 로컬 이미지 | 검수용 PNG와 JPEG의 초록색 사각형이 보였다. 누락 파일, PNG 확장자의 잘못된 내용과 원격 이미지는 각각 대체 텍스트와 `image unavailable`로 보였다. | 통과 |
| 검색 | 도구 막대 Find로 행을 열고 Leaflit을 입력했다. 본문에서 해당 단어가 선택됐다. 전면 활성화 직후 Cmd+F를 보냈을 때는 검색 행이 열리지 않았다. 이후 새 연결의 한정 확인 결과는 아래에 기록했다. | 도구 막대 검색 통과, Cmd+F 최종 확인 통과 |
| 복사 | 본문 3중 클릭과 Cmd+C, 검색 행에서 Cmd+V를 시도했으나 검색 필드에 복사 결과가 나타나지 않았다. 클립보드 내용을 읽지 않았으므로 복사 자체를 실패로 단정하지 않는다. | 이 회차 미확인 |
| Finder | Finder에서 Fixtures/Welcome.md 우클릭, 다음으로 열기, Leaflit을 선택했다. 최종 앱에서 Welcome의 본문이 보였다. 당시 Finder 기본 연결은 Visual Studio Code였으며 변경하지 않았다. 실행 중 Leaflit은 최종 Release 경로의 프로세스 하나였다. | 통과 |

네이티브 스크롤 도구 호출은 화면 변화가 없었으며 읽기 위치는 화면에 보이는 스크롤 막대의 접근성 값을 조작해 이동했다. 이 도구 차이를 앱의 스크롤 실패로 바꾸지 않는다. 원격 이미지를 대체 텍스트로 표시한 UI 관찰과 자동 테스트의 외부 fetch 차단은 서로 다른 근거다. OS 전체 네트워크를 끈 실행은 하지 않았다.

### VoiceOver

VoiceOver 앱의 직접 실행은 `timeoutReached`를 반환했고 실행 상태가 남지 않았다. VoiceOver Utility를 열었으나 활성화 행동이 없어 시스템 설정의 손쉬운 사용, VoiceOver 화면으로 이동했다. 시작 값 off를 기록하고 on으로 바꿨다. 시작 대화상자의 VoiceOver 사용을 눌렀고 튜토리얼 창을 닫은 뒤 실제 `/System/Library/CoreServices/VoiceOver.app/Contents/MacOS/VoiceOver` 프로세스를 확인했다.

Leaflit에서 Ctrl+Option+Right를 보냈지만 도구에서 VoiceOver 커서 이동 결과와 음성 출력을 확인하지 못했다. 따라서 VoiceOver 활성화는 확인했으며 문서, 링크, 표와 수식의 실제 음성 탐색은 미확인이다. AX 트리에 이름이 있다는 사실로 음성 탐색을 통과 처리하지 않는다.

시스템 설정의 VoiceOver를 off로 되돌린 뒤 값 off를 직접 읽었다. 설정 창을 닫고 검수자가 띄운 VoiceOver Quickstart 보조 프로세스는 정확한 실행 경로와 PID를 확인해 종료했다. 최종 VoiceOver 프로세스 조회는 비어 있었다.

### 수행하지 않은 범위

실제 Finder 파일 드롭은 실행하지 않았다. CUA가 제공하는 앱별 화면 좌표만으로 Finder에서 Leaflit으로 교차 앱 드래그를 재현할 근거를 확보하지 못했다. 제품의 드롭 실패로 단정하지 않는다.

작은 창, 200% 확대와 라이트 및 다크 모드는 위 자동 통합 테스트와 실제 첨부 PNG로 확인했다. 이 회차의 Release 앱은 시스템 다크 모드에서 조작했고 Release 창의 라이트 전환은 하지 않았다. 키보드 전체 메뉴 탐색, 실제 웹 링크를 기본 브라우저로 여는 동작, 음성 읽기와 이전 OS는 통과 근거가 없다.

### 메뉴와 검색의 한정 최종 확인

초기 결과를 전달한 뒤 구현자는 제품 소스를 바꾸지 않고 실제 NSMenu 활성 조건과 명령 전달을 확인하는 테스트를 추가해 실행했다. 해당 실행은 구현자의 결과이며 위 독립 자동 실행 18개에 포함하지 않는다. 구현자가 같은 앱에서 메뉴가 활성인 상태를 확인해, 초기 관찰과 결과가 다른 두 항목만 새 화면 제어 연결로 한 번 확인하도록 요청했다. 다른 UI 회귀는 반복하지 않았다.

정확한 Release 앱 경로로 `getApp`을 새로 호출하고 Welcome의 상대 링크로 Next Page에 이동했다. 첫 View 메뉴 클릭은 앱의 메뉴 상태를 반환하기 전에 `originalApplicationActivationFailed`라는 화면 제어 도구 오류로 끝났다. 연결을 한 번 다시 받은 뒤 View 메뉴를 열자 Back, Zoom In, Zoom Out과 Actual Size가 모두 활성으로 노출됐다. Back 메뉴를 클릭해 같은 창에서 Welcome.md로 실제 복귀했다. 이어 Cmd+F를 누르자 검색 행이 열리고 Find in Document에 입력 포커스가 생겼다.

최종 실제 확인에서 Back 메뉴와 검색 단축키는 통과했다. 초기 비활성과 키 무반응은 기록으로 보존한다. 제품 소스를 바꾸지 않고 결과가 달라졌으며 중간에 도구의 활성화 오류가 있었으므로 앞선 관찰만으로 제품 결함을 확정하지 않는다. 실행 파일 해시도 최초 Release 빌드의 값과 같다. Cmd+Q로 종료한 뒤 Leaflit와 VoiceOver 프로세스 조회가 비어 있음을 확인하고 UI를 다시 반환했다.

## 원문과 종료 상태

시작 전 `Fixtures` 네 파일의 SHA-256을 `build/qa-round3/source-hashes-before.json`에 기록했고 종료 후 `source-hashes-after.json`과 비교해 모두 같았다.

| 문서 | 시작 및 종료 SHA-256 |
| --- | --- |
| Benchmark100KiB.md | `55464dacf92db737fbec845a17723c38da683d0fcef0b52d994a0040edff7f61` |
| Welcome.md | `41eceab164f37bcc04639ca4d7cf41a91831b699849b54ca011632e640dc4201` |
| Next Page.markdown | `af959c36eabbe02c4deac10651fa62be5fcaadbed1bd1cf9cbea4e7c1e6df451` |
| Errors.mdown | `4ea2141055ccf8f518f87da78ad0c9878d9c705394dd3d7782d9a3e32a7fcf19` |

제품 소스는 수정하지 않았다. 초기 검수와 위 한정 확인 모두 종료 후 UI 제어를 구현자에게 반환했다. View 메뉴와 Cmd+F는 최종 확인에서 통과했다. 모바일 기기, 사용자 문서, PATH와 Finder 기본 연결은 조작하지 않았다.
