# Basic AI Flow — hướng dẫn

[English](README.en.md) · Tiếng Việt · Bản trực quan: [guide.vi.html](guide.vi.html)

Một quy trình do AI dẫn dắt cho **backend** (Go), **admin** (Next.js) và
**mobile-app** (Flutter). Khởi động Claude Code ở thư mục gốc của workspace
(`basic-ai-flow`), không phải bên trong một repo. Quy trình chạy từng giai đoạn một
và luôn dừng lại chờ bạn.

## Một lệnh duy nhất

| Bạn gõ | Điều gì xảy ra |
|---|---|
| `/aiflow PROJ-XXXX` | Chạy **giai đoạn tiếp theo** của ticket rồi dừng. Ticket mới bắt đầu từ giai đoạn 1. |
| `/aiflow` | Bảng tổng hợp mọi ticket: giai đoạn, route, repo, bước tiếp theo |
| `/aiflow PROJ-XXXX status` | Tiến độ, cùng thời gian / token / chi phí ước tính theo giai đoạn |
| `/aiflow PROJ-XXXX feature` | Ticket phát triển mới (branch `feature/…`) thay vì sửa lỗi |
| `/aiflow PROJ-XXXX redo <stage>` | Làm lại một giai đoạn (`ticket` `spec` `plan` `impl` `review` `deliver`) |
| `/aiflow analyze` | Làm mới knowledge graph liên repo (miễn phí) |
| `/aiflow wiki` | Viết/làm mới wiki dự án (dùng LLM, tốn token) |
| `/aiflow <PR/MR URL>` | Review một PR/MR có sẵn |

## Các giai đoạn

| # | Giai đoạn | Bạn | Kết quả trong `docs/aiflow/<ID>/` | light | full |
|---|---|---|---|---|---|
| 1 | Ticket: đọc Notion, bug hay feature, repo bị ảnh hưởng, phân loại, branch | duyệt | `ticket.md` `status.md` | ✅ | ✅ |
| 2 | Spec: nguyên nhân gốc hoặc thiết kế | duyệt | `spec.md` | ✅ | ✅ |
| 3 | Kế hoạch: các task TDD, mỗi task một repo | duyệt | `plan.md` | — | ✅ |
| 4 | Triển khai: mỗi task có người làm + review theo spec + review chất lượng | — | code, `reviews/` | ✅ | ✅ |
| 5 | Review tổng thể liên repo + test case thủ công | — | `reviews/final-review.md` `test-cases.md` | — | ✅ |
| 6 | Bàn giao: chạy test, cổng QA thủ công, mỗi git root một PR/MR **Draft**, sửa theo CI review, rồi chuyển Ready | QA, duyệt | link PR/MR | ✅ | ✅ |

**light** (1→2→4→6) chỉ khi: một repo, tối đa 3 file, không đổi API/schema/DB, đã
xác định nguyên nhân gốc, là bug, và không thuộc vùng nhạy cảm (thanh toán, xác thực,
migration). Khi đó giai đoạn 1 và 2 chạy trong một lượt với một lần duyệt. Mọi trường
hợp khác là **full**. Route chỉ được nâng lên, không bao giờ âm thầm hạ xuống.
`status.md` là điểm tiếp tục (tiến độ); `log.json` là mức sử dụng (thời gian, token,
chi phí) và không bao giờ ảnh hưởng định tuyến.

## Quy tắc bắt buộc

1. **Không bao giờ push thẳng vào `main`.** Thay đổi chỉ vào base branch qua PR/MR.
   Không commit vào `develop`/`main`, không force-push. Không bao giờ commit thông tin
   bí mật (key, token, `.env*`).
2. **Mọi thao tác ghi lên GitHub/GitLab đều hỏi trước.** `git push`, tạo hay sửa
   PR/MR, đăng comment: agent hiển thị hành động, đích và nội dung chính xác, và chỉ làm
   khi bạn đồng ý rõ ràng. Lần duyệt trước, câu trả lời QA hay một cờ cấu hình không
   bao giờ thay cho lần ghi sau. Agent không bao giờ tự merge, approve hay đóng PR/MR;
   chỉ merge khi bạn yêu cầu trong chat.
3. **Ghi tên người review.** Mọi lần review và duyệt đều ghi `human:<name>` hoặc
   `ai:<role> (<model>)` trong `reviews/*.md`, phần duyệt của `status.md` và comment
   PR/MR.
4. **Một ticket branch ở mọi nơi.** Khi một ticket đang mở, wrapper và mọi repo bị ảnh
   hưởng đều ở cùng branch `bug/PROJ-XXXX/…` hoặc `feature/PROJ-XXXX/…`.

## Template PR/MR

Tiêu đề chứa mã task, ví dụ `[PROJ-123] …`, để PR liên kết với task Notion. Nội dung
giữ các mục sau:

| Mục | Nội dung |
|---|---|
| Tổng quan | PR này thay đổi gì và vì sao; link tới các PR liên quan và spec/plan/review |
| Ảnh chụp màn hình (nếu có thay đổi UI) | Ảnh trước/sau nếu UI thay đổi, nếu không thì ghi rõ là không đổi UI |
| Điểm cần trao đổi (nếu có) | Những điểm cần hỏi người review, kể cả các phát hiện mức Minor; ghi "Không có" nếu không có |
| Các bước kiểm tra | Đã kiểm tra thế nào để người review làm lại được: thiết bị, các bước, kết quả; ghi rõ phần chưa test |

## Thứ tự bàn giao (giai đoạn 6)

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

Mỗi repo — kể cả wrapper — dùng `gh` (GitHub) hoặc `glab` (GitLab), tuỳ host đã chọn
cho nó trong `/aiflow setup` (`pr.tool` / `pr_tool` trong `aiflow/workflow.yaml`).
Base branch: backend/admin là `develop`, mobile và wrapper là `main`.

## Cập nhật quy trình

Skill và quy tắc đến từ bộ `harness-ai-flow` dùng chung. Hãy sửa ở đó (cùng README
của nó), rồi cài lại ở đây bằng `install.sh --force`; mọi chỉnh sửa trong
`.claude/skills/` sẽ bị ghi đè.

Tuỳ chọn: `aiflow-visual` là trợ lý trên trình duyệt (trang cục bộ cho mockup và sơ
đồ); các giai đoạn chỉ đề xuất nó cho câu hỏi về hình ảnh và chỉ khi bạn đồng ý.
Telemetry tắt; giữ `.superpowers/` ngoài git.
Thiết lập riêng của dự án chỉ nằm trong `aiflow/workflow.yaml`.
