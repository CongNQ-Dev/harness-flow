# Basic AI Flow

[English](README.md) · [日本語](README.ja.md) · Tiếng Việt

Một quy trình phát triển do AI dẫn dắt, dùng chung cho **backend**, **admin** và
**mobile-app**. Repo này chỉ chứa quy trình. Ba repo mã nguồn được clone vào bên
trong và bị git bỏ qua, nên repo này không bao giờ sửa chúng.

```
ai-flow/                      ← repo này: AI Flow (khởi động Claude Code ở đây)
├── backend/             ← repo mã nguồn (GitHub, không theo dõi ở đây)
├── admin/               ← repo mã nguồn (GitHub, không theo dõi ở đây)
└── mobile-app/          ← repo mã nguồn (GitHub, không theo dõi ở đây)
```

Repo này là mã nguồn gốc của AI Flow và tự đứng một mình: `install.sh` /
`install.ps1` cài nó vào bất kỳ project nào, cho Claude Code, Codex, GitHub
Copilot, Cursor, OpenCode, Kilo Code hoặc OpenClaw. Mọi thiết lập riêng của dự án
nằm trong `aiflow/workflow.yaml`.

## Cài vào project của bạn

```bash
git clone https://github.com/CongNQ-Dev/ai-flow.git
./ai-flow/install.sh --dir ~/code/my-app --agent codex     # macOS / Linux
.\ai-flow\install.ps1 -Dir C:\code\my-app -Agent codex     # Windows
```

| `--agent` | Skill đặt ở | `/aiflow` đến từ | File quy tắc |
|---|---|---|---|
| `claude` | `.claude/skills/` | skill `aiflow` | `CLAUDE.md` (+ hooks in `.claude/settings.json`) |
| `codex` | `.agents/skills/` | `$aiflow` | `AGENTS.md` |
| `copilot` | `.github/skills/` | `.github/prompts/aiflow.prompt.md` | `AGENTS.md` |
| `cursor` | `.cursor/skills/` | `.cursor/commands/aiflow.md` | `AGENTS.md` |
| `opencode` | `.opencode/skills/` | `.opencode/commands/aiflow.md` | `AGENTS.md` |
| `kilocode` | `.kilo/skills/` | `.kilo/commands/aiflow.md` | `AGENTS.md` |
| `openclaw` | `skills/` | skill `aiflow` | `AGENTS.md` |

Sau đó mở project bằng agent của bạn và chạy `/aiflow setup` (trong Codex là
`$aiflow setup`); lệnh này tạo `aiflow/workflow.yaml`. Muốn nâng cấp thì pull repo
này và chạy lại installer với `--force`: `aiflow/workflow.yaml`, nội dung riêng của
bạn trong `CLAUDE.md` / `AGENTS.md` (khối AI Flow nằm giữa hai dấu
`<!-- aiflow:start/end -->`) và các hook sẵn có đều được giữ nguyên. Skill được viết
theo tên công cụ của Claude Code; `aiflow/AGENTS-TOOLS.md` ánh xạ chúng cho các agent
khác. Chỉ Claude Code ghi log sử dụng (thời gian / token / chi phí theo giai đoạn).

## Bắt đầu nhanh (dùng chính repo này làm workspace)

```bash
git clone https://github.com/CongNQ-Dev/ai-flow.git
cd ai-flow
git clone https://github.com/<your-org>/backend.git
git clone https://github.com/<your-org>/admin.git
git clone https://github.com/<your-org>/mobile-app.git
gh auth login      # nếu có repo trên GitHub  ─┐ đăng nhập CLI của host
glab auth login    # nếu có repo trên GitLab  ─┘ bạn chọn trong /aiflow setup
claude
```

Trong Claude Code:

```text
/aiflow analyze        dựng knowledge graph một lần (cả 3 repo, vài giây nếu đã mới)
/aiflow PROJ-123       bắt đầu hoặc tiếp tục một ticket
```

Cần có: Claude Code, `python3`, `graphify`, `gh` và/hoặc `glab` (theo host bạn chọn
trong `/aiflow setup` — GitHub hoặc GitLab), cùng toolchain của từng repo
(Go · Node/yarn · FVM/Flutter). Ticket Notion được đọc qua Notion MCP, trình duyệt,
hoặc bằng cách dán nội dung ticket.

## Một lệnh duy nhất

| Bạn gõ | Điều gì xảy ra |
|---|---|
| `/aiflow PROJ-XXXX` | Chạy **giai đoạn tiếp theo** của ticket rồi dừng. Ticket mới bắt đầu từ giai đoạn 1. |
| `/aiflow` | Bảng tổng hợp mọi ticket: giai đoạn, route, repo, bước tiếp theo |
| `/aiflow PROJ-XXXX status` | Tiến độ + thời gian / token / chi phí ước tính theo từng giai đoạn |
| `/aiflow PROJ-XXXX feature` | Bắt đầu ticket phát triển mới (branch `feature/…`) thay vì sửa lỗi |
| `/aiflow PROJ-XXXX redo spec` | Làm lại một giai đoạn (`ticket` `spec` `plan` `impl` `review` `deliver`) |
| `/aiflow analyze` | Làm mới knowledge graph liên repo |
| `/aiflow wiki` | Tạo/làm mới wiki dự án — tài liệu kiến trúc do LLM viết, tốn token |
| `/aiflow <PR URL>` | Review một PR có sẵn |

Xem kết quả của mỗi giai đoạn rồi chạy lại `/aiflow PROJ-XXXX`. Toàn bộ vòng lặp chỉ có vậy.

Nếu không ghi `feature`, việc ticket là bug hay feature được quyết định dựa trên bằng
chứng — trước hết là trường loại (Type) của ticket Notion, sau đó tới nội dung ticket
nếu thiếu trường này — chứ không đoán (thứ tự bằng chứng nằm trong skill `aiflow-spec`, §1.2).

## Các giai đoạn

| # | Giai đoạn | Bạn | Kết quả trong `docs/aiflow/<ID>/` | light | full |
|---|---|---|---|---|---|
| 1 | Chuẩn hoá ticket: repo bị ảnh hưởng, phân loại độ khó, branch cho từng repo | duyệt | `ticket.md` `status.md` | ✅ | ✅ |
| 2 | Spec: nguyên nhân gốc hoặc thiết kế | duyệt | `spec.md` | ✅ | ✅ |
| 3 | Kế hoạch sửa: các task TDD, mỗi task một repo | duyệt | `plan.md` | — | ✅ |
| 4 | Triển khai: mỗi task có người làm + review theo spec + review chất lượng | — | code, `reviews/` | ✅ | ✅ |
| 5 | Review tổng thể liên repo + test case thủ công | — | `reviews/final-review.md` `test-cases.md` | — | ✅ |
| 6 | Bàn giao: chạy test, cổng QA thủ công, mỗi repo một Draft PR, sửa theo CI review, rồi chuyển Ready | QA, duyệt | link PR | ✅ | ✅ |

Ở route light (lỗi nhỏ), giai đoạn 1 và 2 chạy trong **một** lượt chứ không phải hai:
`/aiflow-spec` phân loại, điều tra và viết `spec.md` ngay sau đó, chỉ cần một lần duyệt
chung — không dừng riêng cho phần trao đổi. Đó là đường tắt (phân loại + viết hướng sửa
thành một bước), không phải "cùng cuộc trao đổi nhưng có thêm cổng duyệt giai đoạn 1".
Route full, và mọi ticket không phải bug, luôn có phần trao đổi giai đoạn 2 riêng. Giai
đoạn 5 và 6 là hai phần của cùng một file skill `aiflow-review`, không phải hai lần chạy
cùng một quy trình — route light chỉ bỏ phần của giai đoạn 5.

**light** (1→2→4→6) chỉ dùng khi ticket chạm một repo, tối đa 3 file, không đổi
API/schema/DB, đã xác định được nguyên nhân gốc, là bug, và không thuộc vùng nhạy cảm
(thanh toán, xác thực, migration). Mọi trường hợp khác chạy **full**. Bạn là người xác
nhận route. Quy tắc nằm trong [`aiflow/workflow.yaml`](aiflow/workflow.yaml).

## Repo này có gì

| Đường dẫn | Mục đích |
|---|---|
| `install.sh` · `install.ps1` | Cài AI Flow vào project khác, cho mọi agent được hỗ trợ |
| `CLAUDE.md` | Quy tắc workspace mà Claude Code nạp khi khởi động |
| `.claude/skills/aiflow*/` | Quy trình: router `aiflow` cùng các skill giai đoạn, template và prompt cho subagent |
| `.claude/skills/*` (còn lại) | Các kỷ luật kỹ thuật dùng nội bộ (TDD, debug, kiểm chứng, review code), ẩn khỏi menu `/` |
| `.claude/settings.json` | Hook: nhắc dùng knowledge graph, ghi log mức sử dụng |
| `aiflow/workflow.yaml` | **Cấu hình**: repo, base branch, lệnh test, hợp đồng giữa các repo, quy tắc phân loại, model |
| `aiflow/scripts/` | `aiflow_status.py` (bảng tổng hợp và giai đoạn tiếp theo) · `aiflow_log.py` (log sử dụng) · `kg_build.py` (knowledge graph) |
| `aiflow/pricing.json` | Bảng giá dùng để ước tính chi phí |
| `aiflow/selected-bugs/` | Danh sách ticket Notion |
| `wiki/` | Tài liệu kiến trúc do `/aiflow-wiki` tạo ra — xem `aiflow-wiki/SKILL.md` |
| `docs/aiflow/<ID>/status.md` | Mỗi ticket một file. Điểm tiếp tục — file duy nhất `/aiflow` đọc để quyết định chạy gì tiếp |
| `docs/aiflow/<ID>/log.json` | Mỗi ticket một file. Mức sử dụng theo giai đoạn — thời gian, token, chi phí ước tính |

Chỉ các skill có tiền tố `aiflow-` là giai đoạn (`/aiflow` gọi chúng). Những skill
còn lại cố ý không có tiền tố: đó là các skill kỷ luật kỹ thuật chung mà mỗi giai đoạn
tự nạp tuỳ tình huống (`description` của chúng bắt đầu bằng "Use when…", quy ước
tự kích hoạt chuẩn) — `user-invocable: false` giữ chúng ngoài menu `/` và tránh trùng
với `/aiflow-*`. Bạn không bao giờ gọi trực tiếp chúng.

`aiflow-visual` là skill `aiflow-` duy nhất không phải giai đoạn: một trợ lý tuỳ chọn
trên trình duyệt (trang cục bộ có mockup, sơ đồ và lựa chọn bấm để chọn). Các giai
đoạn chỉ đề xuất nó cho câu hỏi về hình ảnh và chỉ khi bạn đồng ý; telemetry tắt và thư
mục `.superpowers/` phải nằm ngoài git.

**`status.md` và `log.json` không trùng nhau — chúng theo dõi hai trục khác nhau.**
`status.md` là *tiến độ* (giai đoạn nào xong, ai duyệt) và là thứ duy nhất `/aiflow`
đọc để định tuyến. `log.json` là *mức sử dụng* (thời gian, token, chi phí ước tính theo
giai đoạn) và không bao giờ ảnh hưởng định tuyến. Mỗi file trả lời câu hỏi mà file kia
không trả lời được: "route light có thật sự rẻ hơn full không", "giai đoạn nào tốn
nhất" — yêu cầu tối ưu chi phí, thứ mà chỉ theo dõi tiến độ không trả lời được.

## Quy tắc quy trình luôn giữ

**Giai đoạn**
- Mỗi giai đoạn dừng khi xong. Không có gì đi tiếp nếu bạn chưa cho phép.
- Mọi thứ trong `docs/aiflow/`, cùng nội dung PR, được viết bằng ngôn ngữ ở
  `language:` trong `workflow.yaml` (hiện là `en`).
- Knowledge graph được truy vấn trước khi đọc bất kỳ file mã nguồn nào.
- Hướng dẫn riêng của từng team repo được ưu tiên cho phần code, ví dụ `CLAUDE.md`,
  `docs/ai/` và các skill riêng của dự án trong mobile-app.

**Git và branch**
- Git luôn chạy dạng `git -C <repo>`. Không bao giờ commit vào `develop`/`main`,
  không push thẳng vào `main` (chỉ qua PR/MR) và không force-push.
- **Không bao giờ commit hay push thông tin bí mật.** API key, token, mật khẩu,
  private key, `.env*` và file credential không bao giờ được stage: file được thêm theo
  đường dẫn cụ thể, `git diff --cached` được đọc trước mỗi commit, và agent dừng lại
  cảnh báo nếu thấy gì đáng ngờ. Tài liệu ticket dùng placeholder.
- Khi một ticket đang mở, **repo wrapper này và mọi repo bị ảnh hưởng đều ở cùng một
  ticket branch** (`bug/PROJ-XXXX/…` / `feature/PROJ-XXXX/…`). Tài liệu ticket được
  commit trên ticket branch của wrapper, không bao giờ trên `main`; khi bàn giao,
  wrapper có MR riêng chỉ chứa tài liệu, song song với PR của các repo.
  `/aiflow PROJ-XXXX` tự chuyển về các branch của ticket; bảng `/aiflow` hiển thị các
  ticket thấy được trên branch hiện tại của wrapper.
- PR đi vào base branch của từng repo (backend/admin là `develop`, mobile là `main`).
  PR/MR của wrapper đi vào `main` của repo này. Mỗi repo dùng `gh` (GitHub) hoặc
  `glab` (GitLab) — tuỳ host bạn chọn cho nó trong `/aiflow setup` (`pr.tool` /
  `pr_tool` trong `aiflow/workflow.yaml`).

**Bàn giao (giai đoạn 6) — không có gì tự động**
- Mọi thao tác ghi lên GitHub/GitLab — `git push`, tạo hay sửa PR/MR, đăng comment —
  đều hỏi xác nhận mới (hành động, đích, nội dung). Lần duyệt trước, câu trả lời QA hay
  một cờ cấu hình không bao giờ thay cho việc đó. Quy trình không bao giờ tự merge,
  approve hay đóng PR/MR; chỉ merge khi bạn yêu cầu trong chat.
- **Draft → CI review → Ready → khách hàng.** PR/MR mở ở dạng **Draft**; CI review
  chạy; mọi comment của CI được sửa hoặc trả lời (mỗi lần push đều hỏi bạn); chỉ sau
  đó, và sau khi hỏi bạn, PR/MR mới được chuyển **Ready for review** để khách hàng
  review. Chạy lại `/aiflow PROJ-XXXX` sau khi CI review xong (`delivery:` trong
  `status.md`: `draft` → `ready`). Không bao giờ chuyển Ready khi còn comment CI mở.
- Tiêu đề PR/MR chứa mã task (ví dụ `[PROJ-123]`). Nội dung giữ nguyên các mục template
  của team bằng tiếng Nhật: 概要 (Tổng quan) / スクリーンショット (Ảnh chụp màn hình) /
  相談項目 (Điểm cần trao đổi) / 動作確認手順 (Các bước kiểm tra).
- Mọi lần review và duyệt đều ghi tên người review — `human:<name>` hoặc
  `ai:<role> (<model>)` trong `reviews/*.md`, phần duyệt của `status.md` và comment PR.

### Thứ tự bàn giao (giai đoạn 6)

**PR/MR Draft → CI review chạy → xử lý mọi comment CI → Ready for review →
khách hàng review.**

1. Chạy test của từng repo.
2. Cổng QA: "đã kiểm tra, tạo PR đi" — câu này **không** có nghĩa là đồng ý push.
3. Xác nhận → push `<branch>` của `<repo>` lên `origin`.
4. Xác nhận → tạo PR/MR **ở dạng Draft** (hiển thị tiêu đề, base ← head và toàn bộ
   nội dung). Quy trình dừng; `status.md` ghi `delivery: draft`.
5. Khi CI review chạy xong, chạy lại `/aiflow <ID>`. Agent đọc comment và check của CI
   (chỉ đọc), ghi vào `reviews/ci-review.md` kèm tên người review, rồi sửa hoặc trả lời
   từng comment. Mỗi lần push, trả lời hay resolve đều hỏi bạn trước. Lặp lại tới khi
   không còn comment CI nào mở và các check đều xanh.
6. Xác nhận → chuyển PR/MR sang **Ready for review** (không bao giờ khi còn comment CI
   mở). `delivery: ready`; khách hàng review, và comment của họ được xử lý tương tự ở
   lần `/aiflow <ID>` tiếp theo.
7. Chỉ merge khi bạn yêu cầu trong chat.

Quy tắc của quy trình nằm trong `conventions.md` (trong skill `aiflow`) và
`aiflow/AIFLOW.md`; project đã cài AI Flow nhận thay đổi bằng cách chạy lại installer
với `--force`. Bản trực quan (tiếng Anh / tiếng Nhật / tiếng Việt): [aiflow/guide.en.html](aiflow/guide.en.html) · [aiflow/guide.ja.html](aiflow/guide.ja.html) · [aiflow/guide.vi.html](aiflow/guide.vi.html).
