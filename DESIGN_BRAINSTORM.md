# 🧠 EduApp — Tài Liệu Thiết Kế (Brainstorming Output)

> **Ngày tạo:** 26/04/2026  
> **Phương pháp:** Brainstorming Skill — Structured Design Facilitation  
> **Trạng thái:** ✅ Đã xác nhận — Sẵn sàng triển khai

---

## 1. Understanding Summary

- **Cái gì:** EduApp — ứng dụng Flutter giúp người Việt học tiếng Anh thông qua tài liệu PDF cá nhân, quiz AI, luyện phát âm, và hỏi đáp thông minh (RAG)
- **Tại sao:** Tạo công cụ học tập tích hợp AI, tận dụng tài liệu của chính người dùng
- **Cho ai:** Mọi người Việt có nhu cầu học tiếng Anh (sinh viên, người đi làm, tự học)
- **Platform:** Android only (hiện tại), Flutter cho khả năng mở rộng iOS sau
- **Ràng buộc:** Hoàn toàn miễn phí / free tier. Mọi phương án có chi phí phải được duyệt trước
- **Quy mô:** < 100 users, không cần scale lớn
- **Mục tiêu:** Hoàn thiện MVP + khám phá tính năng mới + cải thiện chất lượng

---

## 2. Assumptions

1. Gemini API free tier (15 RPM, 1M tokens/phút) đủ cho < 100 users
2. Firebase Spark plan (1GB Firestore, 50K reads/day) đủ cho quy mô hiện tại
3. Không cần backend server nặng — Cloudflare Workers free tier đủ làm proxy
4. App chủ yếu dùng để demo khả năng kỹ thuật, chưa phải sản phẩm thương mại
5. Người dùng tự cung cấp tài liệu PDF tiếng Anh để học
6. Giao diện tiếng Việt, nội dung học bằng tiếng Anh

---

## 3. Phương Án Đã Chọn

**B (Smart Expansion)** làm core + chọn lọc từ **C (Platform Evolution)**

### Learning Loop Architecture

```
Learn → Practice → Feedback → Review → Progress
  │         │          │         │          │
  ▼         ▼          ▼         ▼          ▼
PDF/TTS   Quiz/    AI Eval   Spaced    Dashboard
          Pronun.            Repetition  + XP
```

### Modules tổng quan

| # | Module | Loại | Ưu tiên |
|---|---|---|---|
| 1 | Spaced Repetition (SM-2) | 🆕 BẮT BUỘC | P0 |
| 2 | Vocabulary Builder | 🆕 Mới | P1 |
| 3 | Progress Dashboard + Gamification | 🆕 Mới | P1 |
| 4 | RAG cải tiến (TF-IDF) | 🔧 Nâng cấp | P2 |
| 5 | API Proxy (Cloudflare Workers) | 🔧 Bảo mật | P2 |
| 6 | Offline Mode (Hive) | 🆕 Mới | P3 |
| 7 | Cải thiện UX hiện có | 🔧 Nâng cấp | Xuyên suốt |

---

## 4. Chi Tiết Thiết Kế Từng Module

---

### 4.1. 🧠 Spaced Repetition Engine (P0 — BẮT BUỘC)

**Thuật toán: SM-2 (SuperMemo 2)**

| Tham số | Ý nghĩa | Giá trị mặc định |
|---|---|---|
| quality | User tự đánh giá | 0-5 |
| easeFactor | Độ dễ nhớ | 2.5 (min 1.3) |
| interval | Khoảng cách ôn tập (ngày) | 1 |
| repetition | Số lần ôn thành công liên tiếp | 0 |

**Công thức SM-2:**
- Lần 1: interval = 1 ngày
- Lần 2: interval = 6 ngày
- Lần 3+: interval = interval × easeFactor
- Nếu quality < 3 → reset repetition = 0, interval = 1

**Nguồn tạo Flashcard:**

| Nguồn | Cách tạo |
|---|---|
| Từ vựng PDF | Gemini extract từ khó + định nghĩa từ document |
| Câu quiz sai | Tự động tạo card từ câu user trả lời sai |
| Pronunciation | Từ user phát âm sai → card luyện lại |
| User tự thêm | Thêm từ/cụm từ thủ công |

**Firestore Schema:**

```
users/{userId}/flashcards/{cardId}/
├── front: "abandon"
├── back: "từ bỏ, rời bỏ"
├── source: "document" | "quiz" | "pronunciation" | "manual"
├── sourceId: "docId_123"
├── sm2: {
│   easeFactor: 2.5,
│   interval: 1,
│   repetition: 0,
│   quality: 0
│ }
├── nextReviewAt: Timestamp
├── createdAt: Timestamp
└── lastReviewedAt: Timestamp
```

**Màn hình Review:**
- Hiển thị card front → user lật xem back
- User tự đánh giá: Quên (0-2) / Khó (3) / Tốt (4) / Dễ (5)
- SM-2 tính nextReviewAt → lưu Firestore
- Notification nhắc ôn qua `flutter_local_notifications`

**Files cần tạo:**
- `lib/core/algorithms/sm2_algorithm.dart` — Pure logic SM-2
- `lib/features/review/models/flashcard_model.dart` — Data model
- `lib/features/review/providers/review_provider.dart` — State management
- `lib/features/review/screens/review_screen.dart` — UI flashcard
- `lib/features/review/screens/review_summary_screen.dart` — Kết quả session
- `lib/features/review/services/flashcard_service.dart` — CRUD Firestore

---

### 4.2. 📝 Vocabulary Builder (P1)

**Auto-extract từ vựng từ PDF:**

```
Prompt → Gemini:
"Trích xuất 20 từ vựng khó nhất từ đoạn text sau.
Trả về JSON: [{word, definition_vi, definition_en, example_sentence, ipa}]"
```

**Tính năng:**

| Tính năng | Chi tiết |
|---|---|
| Danh sách từ vựng | Nhóm theo tài liệu, có search/filter |
| Chi tiết từ | Nghĩa VN/EN, IPA, câu ví dụ, nút phát âm (TTS) |
| Thêm thủ công | User tự nhập từ + nghĩa |
| Tích hợp SR | Mỗi từ tự động tạo flashcard → Spaced Repetition |
| Trạng thái | 🔴 Mới / 🟡 Đang học / 🟢 Đã thuộc (dựa theo SM-2) |

**Firestore Schema:**

```
users/{userId}/vocabulary/{wordId}/
├── word: "sophisticated"
├── definitionVi: "tinh vi, phức tạp"
├── definitionEn: "highly developed and complex"
├── ipa: "/səˈfɪstɪkeɪtɪd/"
├── exampleSentence: "She has sophisticated taste."
├── sourceDocId: "doc_123"
├── status: "new" | "learning" | "mastered"
├── flashcardId: "card_456"
└── createdAt: Timestamp
```

**Files cần tạo:**
- `lib/features/vocabulary/models/word_model.dart`
- `lib/features/vocabulary/providers/vocabulary_provider.dart`
- `lib/features/vocabulary/screens/vocabulary_list_screen.dart`
- `lib/features/vocabulary/screens/word_detail_screen.dart`
- `lib/features/vocabulary/services/vocabulary_service.dart`

---

### 4.3. 📊 Progress Dashboard + Gamification (P1)

**Gamification System:**

| Thành phần | Chi tiết |
|---|---|
| **Daily Streak** 🔥 | Số ngày liên tục hoàn thành ≥1 hoạt động |
| **XP System** | +10 đọc tài liệu, +20 quiz, +15 pronunciation, +25 review SR |
| **Level** | Mỗi 100 XP = 1 level. Progress bar hiển thị |
| **Streak Calendar** | Lịch tháng đánh dấu ngày đã học (kiểu GitHub contribution) |
| **Biểu đồ tiến bộ** | Line chart: số từ thuộc theo tuần (`fl_chart` package, miễn phí) |
| **Tóm tắt hôm nay** | "Hôm nay: 5 từ mới, 2 quiz, 12 cards ôn tập" |

**Firestore Schema:**

```
users/{userId}/
├── stats: {
│   totalXp: 1250,
│   level: 12,
│   currentStreak: 7,
│   longestStreak: 14,
│   lastActiveDate: "2026-04-26"
│ }
├── dailyLogs/{date}/
│   ├── xpEarned: 85
│   ├── wordsLearned: 5
│   ├── quizzesDone: 2
│   ├── cardsReviewed: 12
│   └── activities: [{type, timestamp, xp}]
```

**Files cần tạo:**
- `lib/features/progress/models/user_stats_model.dart`
- `lib/features/progress/models/daily_log_model.dart`
- `lib/features/progress/providers/progress_provider.dart`
- `lib/features/progress/screens/progress_dashboard_screen.dart`
- `lib/features/progress/widgets/streak_calendar.dart`
- `lib/features/progress/widgets/xp_progress_bar.dart`
- `lib/features/progress/services/gamification_service.dart`

---

### 4.4. 🔍 RAG Cải Tiến — TF-IDF (P2)

**Thay thế keyword matching hiện tại bằng TF-IDF:**

| So sánh | Keyword Matching (hiện tại) | TF-IDF (đề xuất) |
|---|---|---|
| Cách hoạt động | Đếm từ trùng khớp | Tính trọng số từ quan trọng |
| Chất lượng | ⭐⭐ | ⭐⭐⭐⭐ |
| Tốc độ | Rất nhanh | Nhanh (< 50ms cho 100 chunks) |
| Dependency | Không | Không — tự viết ~80 dòng Dart |

**Logic:**
- TF = số lần từ xuất hiện trong chunk / tổng từ trong chunk
- IDF = log(tổng chunks / số chunks chứa từ đó)
- Score = tổng (TF × IDF) cho mỗi từ trong câu hỏi
- Chọn top-3 chunks có score cao nhất → gửi cho Gemini

**Files cần sửa/tạo:**
- `lib/core/utils/tfidf_calculator.dart` — 🆕 TF-IDF logic
- `lib/core/services/gemini_service.dart` — Sửa `_findRelevantChunks()` dùng TF-IDF

---

### 4.5. 🔐 API Proxy — Cloudflare Workers (P2)

**Luồng hoạt động:**

```
Flutter App → Cloudflare Worker → Gemini API
                  │
                  ├── Verify Firebase Auth token
                  ├── Rate limiting (chống lạm dụng)
                  └── API key an toàn trên server
```

**Đặc điểm:**
- Miễn phí: 100,000 requests/ngày
- Không cần credit card
- Deploy bằng `wrangler` CLI
- Worker code ~50 dòng JavaScript

**Files cần tạo:**
- `proxy/wrangler.toml` — Cloudflare config
- `proxy/src/index.js` — Worker logic
- Sửa `lib/core/services/gemini_service.dart` — Gọi qua proxy thay vì direct

---

### 4.6. 📶 Offline Mode — Hive (P3)

**Package: `hive_flutter`** (miễn phí, NoSQL local, rất nhanh)

| Dữ liệu | Online | Offline |
|---|---|---|
| Tài liệu đã parse | Firestore | ✅ Cache Hive |
| Flashcards đến hạn | Firestore | ✅ Cache + sync khi có mạng |
| Từ vựng | Firestore | ✅ Cache Hive |
| Quiz mới | ❌ Cần Gemini | ❌ Không khả dụng |
| Q&A | ❌ Cần Gemini | ❌ Không khả dụng |
| Progress/Stats | Firestore | ✅ Ghi local → sync sau |

**Chiến lược:** Offline-first cho Review & Vocabulary. Online-only cho AI features.

**Files cần tạo:**
- `lib/core/services/local_storage_service.dart` — Hive wrapper
- `lib/core/services/sync_service.dart` — Sync local ↔ Firestore

---

## 5. Decision Log

| # | Quyết định | Lựa chọn khác | Lý do chọn |
|---|---|---|---|
| D1 | Chọn phương án B (Smart Expansion) + chọn lọc C | A (Deep MVP only), C (Full evolution) | Cân bằng giữa chất lượng và tính hấp dẫn, không overkill |
| D2 | SM-2 cho Spaced Repetition | SM-5, Leitner, FSRS | SM-2 đơn giản, chứng minh hiệu quả, dễ implement, Anki dùng biến thể |
| D3 | TF-IDF cho RAG | Vector embedding, BM25 | Không cần server, tự viết ~80 dòng, đủ tốt cho < 100 chunks |
| D4 | Cloudflare Workers cho API proxy | Vercel Edge, AWS Lambda | Free 100K req/ngày, không cần credit card, dễ deploy |
| D5 | Hive cho offline storage | Isar, SQLite, ObjectBox | Hive nhẹ, nhanh, NoSQL phù hợp với Firestore schema |
| D6 | `fl_chart` cho biểu đồ | charts_flutter, syncfusion | Miễn phí, đẹp, đủ tính năng cho dashboard |
| D7 | `flutter_local_notifications` cho nhắc ôn | Firebase Cloud Messaging | Hoạt động offline, không cần server, miễn phí |
| D8 | Auto-extract vocabulary bằng Gemini | NLP on-device, dictionary API | Gemini hiểu context tốt hơn, trả về cả ví dụ & IPA |
| D9 | Learning Loop 5 giai đoạn | Linear flow, free-form | Tạo vòng lặp khép kín, user luôn có hành động tiếp theo |
| D10 | Offline-first cho Review, Online-only cho AI | Full offline, Full online | Thực tế: AI cần API, nhưng ôn tập nên hoạt động mọi lúc |

---

## 6. Dependencies Mới Cần Thêm

| Package | Mục đích | Chi phí |
|---|---|---|
| `fl_chart` | Biểu đồ tiến bộ | Miễn phí |
| `hive_flutter` | Local storage offline | Miễn phí |
| `flutter_local_notifications` | Nhắc ôn tập | Miễn phí |
| `table_calendar` | Streak calendar UI | Miễn phí |

**Tất cả đều miễn phí ✅**

---

## 7. Routes Mới Cần Thêm

| Route | Screen | Module |
|---|---|---|
| `/review` | ReviewScreen | Spaced Repetition |
| `/review/summary` | ReviewSummaryScreen | Spaced Repetition |
| `/vocabulary` | VocabularyListScreen | Vocabulary Builder |
| `/vocabulary/:wordId` | WordDetailScreen | Vocabulary Builder |
| `/progress` | ProgressDashboardScreen | Progress Dashboard |

**Tổng routes sau cải tiến: 17 (từ 12)**

---

## 8. Thứ Tự Triển Khai Đề Xuất

```
Phase 1 (P0): Spaced Repetition Engine
  └── SM-2 algorithm → Flashcard model → Review screen → Notification

Phase 2 (P1): Vocabulary + Progress  
  ├── Vocabulary Builder (auto-extract + manual + tích hợp SR)
  └── Progress Dashboard (XP, streak, charts)

Phase 3 (P2): Nâng cấp kỹ thuật
  ├── TF-IDF cho RAG
  └── API Proxy (Cloudflare Workers)

Phase 4 (P3): Offline Mode
  └── Hive cache + sync service

Xuyên suốt: Cải thiện UX/UI các màn hình hiện có
```

---

*Tài liệu này là output của phiên Brainstorming ngày 26/04/2026.*  
*Mọi quyết định đã được xác nhận bởi product owner.*
