# 📊 EduApp - Phân Tích Dự Án & Tiến Độ Phát Triển

> **Ngày cập nhật:** 26/04/2026  
> **Tác giả:** dinhhuy194  
> **Repository:** [github.com/dinhhuy194/Eng_App_](https://github.com/dinhhuy194/Eng_App_.git)  
> **Branch hiện tại:** `dev/direct-ai`

---

## 1. Tổng Quan Dự Án

**EduApp** là ứng dụng học tập thông minh tích hợp AI, được xây dựng bằng **Flutter** + **Firebase** + **Google Gemini AI**. Ứng dụng hướng tới việc giúp người dùng học tiếng Anh hiệu quả thông qua tài liệu cá nhân hóa, quiz AI, luyện phát âm và hỏi đáp thông minh.

### Công nghệ sử dụng

| Thành phần | Công nghệ |
|---|---|
| **Frontend** | Flutter (Dart SDK ≥3.3.0) |
| **State Management** | Riverpod (flutter_riverpod 2.5.1) |
| **Routing** | GoRouter 14.2.0 |
| **Backend** | Firebase (Auth, Firestore) |
| **AI Engine** | Google Gemini AI (gọi trực tiếp, không qua Cloud Functions) |
| **Xử lý tài liệu** | Syncfusion Flutter PDF (parse trên device) |
| **TTS / STT** | flutter_tts, speech_to_text |
| **Bảo mật** | flutter_dotenv (quản lý API key) |

---

## 2. Kiến Trúc Dự Án

### 2.1. Cấu trúc thư mục

```
lib/
├── main.dart                          # Entry point
├── firebase_options.dart              # Firebase config (gitignored)
├── core/
│   ├── constants/
│   │   ├── api_constants.dart         # API keys, collection names
│   │   └── app_colors.dart            # Bảng màu ứng dụng
│   ├── router/
│   │   └── app_router.dart            # GoRouter config (12 routes)
│   ├── services/
│   │   ├── firebase_service.dart      # Firebase CRUD (Singleton)
│   │   └── gemini_service.dart        # Gemini AI service (Singleton)
│   ├── theme/
│   │   └── app_theme.dart             # Light/Dark theme
│   └── utils/
│       ├── text_chunker.dart          # Chia text thành chunks
│       └── similarity_calculator.dart # Tính tương đồng văn bản
├── features/
│   ├── auth/
│   │   ├── providers/auth_provider.dart
│   │   └── screens/login_screen.dart
│   ├── documents/
│   │   ├── providers/document_provider.dart
│   │   ├── screens/
│   │   │   ├── document_list_screen.dart
│   │   │   └── document_detail_screen.dart
│   │   └── services/pdf_parser.dart
│   ├── home/
│   │   └── screens/home_screen.dart
│   ├── quiz/
│   │   ├── providers/quiz_provider.dart
│   │   └── screens/
│   │       ├── quiz_setup_screen.dart
│   │       ├── quiz_screen.dart
│   │       └── quiz_result_screen.dart
│   ├── tts/
│   │   ├── controllers/tts_controller.dart
│   │   └── screens/reading_screen.dart
│   ├── pronunciation/
│   │   ├── screens/pronunciation_screen.dart
│   │   └── services/pronunciation_checker.dart
│   ├── qa/
│   │   ├── providers/qa_provider.dart
│   │   └── screens/qa_screen.dart
│   ├── profile/
│   │   └── screens/profile_screen.dart
│   └── splash/
│       └── screens/splash_screen.dart
└── shared/
    ├── models/
    │   ├── document_model.dart
    │   ├── quiz_model.dart
    │   └── session_model.dart
    └── widgets/
        ├── error_widget.dart
        ├── loading_indicator.dart
        └── score_badge.dart
```

**Tổng cộng: 35 file Dart**

### 2.2. Kiến trúc tổng thể

```
┌─────────────────────────────────────────────────────┐
│                    Flutter App                       │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────┐  │
│  │ Screens  │──│ Providers│──│ Services          │  │
│  │ (UI)     │  │ (State)  │  │ (Business Logic)  │  │
│  └──────────┘  └──────────┘  └────────┬─────────┘  │
│                                       │             │
│  ┌──────────────────────────────────┐ │             │
│  │  Shared Models & Widgets        │ │             │
│  └──────────────────────────────────┘ │             │
└───────────────────────────────────────┼─────────────┘
                                        │
        ┌───────────────────────────────┼──────────┐
        │                               │          │
   ┌────▼────┐     ┌───────────┐   ┌────▼─────┐
   │Firebase │     │ Firestore │   │ Gemini   │
   │  Auth   │     │ Database  │   │ AI API   │
   └─────────┘     └───────────┘   └──────────┘
```

### 2.3. Luồng dữ liệu Firestore

```
users/{userId}/
├── name, email, avatarUrl, createdAt, dailyApiUsage
├── documents/{docId}/
│   ├── title, fileType, fileName, status, pageCount, chunkCount, createdAt
│   └── chunks/{chunkId}/
│       └── text, index
├── quizzes/{quizId}/
│   └── documentId, questions, score, createdAt
└── sessions/{sessionId}/
    └── type, documentId, data, createdAt
```

---

## 3. Lịch Sử Phát Triển (Git Log)

| # | Ngày | Commit | Nội dung |
|---|---|---|---|
| 1 | 25/04/2026 | `8fc8216` | **feat:** Init EduApp - Ứng dụng học tập thông minh với AI (Flutter + Firebase + Gemini) |
| 2 | 25/04/2026 | `2257b38` | **chore:** Thêm file tài liệu vào .gitignore |
| 3 | 25/04/2026 | `a2dd4b0` | **feat:** Chuyển sang gọi Gemini trực tiếp (bỏ Cloud Functions) - Viết lại GeminiService, tích hợp RAG client-side |
| 4 | 25/04/2026 | `3054e65` | **fix:** Sửa lỗi build - xóa dependency Cloud Functions, update record 5.x → 6.x |
| 5 | 25/04/2026 | `f595865` | **feat:** Bổ sung file còn thiếu - TtsController, PronunciationChecker, QAProvider, ProfileScreen, SplashScreen |
| 6 | 25/04/2026 | `0d5f5c6` | **fix:** Sửa ClassNotFoundException - di chuyển MainActivity khớp namespace |
| 7 | 26/04/2026 | `fd16cc6` | **fix(auth):** Tắt reCAPTCHA trên emulator, cải thiện error handling, Firestore rules & indexes |

### Thay đổi chưa commit (Working directory)

| File | Thay đổi |
|---|---|
| `firebase.json` | Thêm cấu hình Storage rules |
| `firebase_service.dart` | Refactor: loại bỏ code Storage (cần Blaze plan), giữ Firestore-only |
| `document_provider.dart` | Refactor: chuyển từ upload-to-Storage sang parse-on-device → lưu text chunks vào Firestore |
| `storage.rules` | File mới (untracked) |

---

## 4. Các Tính Năng & Trạng Thái

### ✅ Đã hoàn thành

| # | Tính năng | Chi tiết |
|---|---|---|
| 1 | **Nền tảng kỹ thuật** | Flutter project, Firebase init, .env config, theme system (Light/Dark), GoRouter (12 routes) |
| 2 | **Xác thực người dùng** | Email/Password Auth, auth redirect, Firestore user profile, SplashScreen animated |
| 3 | **Quản lý tài liệu** | Upload PDF → parse on-device (Syncfusion) → chunk text → lưu Firestore. CRUD đầy đủ |
| 4 | **Gemini AI Service** | Singleton service gọi API trực tiếp (không qua Cloud Functions), hỗ trợ: generateQuiz, getPronunciationFeedback, askQuestion (RAG) |
| 5 | **Tạo Quiz AI** | Setup quiz (số câu, độ khó) → Gemini generate → hiển thị quiz → kết quả + giải thích |
| 6 | **Text-to-Speech** | TtsController tách riêng, ReadingScreen đọc tài liệu |
| 7 | **Luyện phát âm** | PronunciationChecker (STT + AI feedback), PronunciationScreen |
| 8 | **Hỏi đáp thông minh (RAG)** | QAProvider + QAScreen, tìm chunks liên quan (keyword matching), trả lời dựa trên tài liệu, hỗ trợ lịch sử hội thoại |
| 9 | **Hồ sơ người dùng** | ProfileScreen (hiển thị thông tin + cài đặt + đăng xuất) |
| 10 | **Bảo mật** | Firestore rules (user-scoped), API key trong .env (gitignored), firebase_options.dart gitignored |
| 11 | **Shared Components** | DocumentModel, QuizModel, SessionModel, ErrorWidget, LoadingIndicator, ScoreBadge |

### 🔄 Đang phát triển / Cần hoàn thiện

| # | Tính năng | Trạng thái | Ghi chú |
|---|---|---|---|
| 1 | **Google Sign-In** | 🔶 Code có sẵn package | Chưa tích hợp OAuth brand vào LoginScreen |
| 2 | **DOCX Parser** | ❌ Đã loại bỏ | Syncfusion chưa hỗ trợ DOCX trên mobile. Chỉ hỗ trợ PDF |
| 3 | **Firebase Storage** | ❌ Đã loại bỏ | Cần Blaze plan (trả phí). Đã chuyển sang parse-on-device |
| 4 | **Cloud Functions** | ❌ Đã loại bỏ | Cần Blaze plan. Đã chuyển sang gọi Gemini trực tiếp |
| 5 | **Commit thay đổi mới nhất** | ⏳ Chưa commit | 3 file modified + 1 untracked (storage.rules) |

---

## 5. Các Quyết Định Kiến Trúc Quan Trọng

### 5.1. Bỏ Cloud Functions → Gọi Gemini trực tiếp
- **Lý do:** Firebase Cloud Functions yêu cầu Blaze plan (trả phí)
- **Giải pháp:** Dùng package `google_generative_ai` gọi API Gemini trực tiếp từ Flutter
- **Trade-off:** API key nằm trong app (bảo vệ bằng .env, nhưng có thể bị decompile)

### 5.2. Bỏ Firebase Storage → Parse on-device
- **Lý do:** Firebase Storage cũng yêu cầu Blaze plan
- **Giải pháp:** Parse PDF ngay trên device bằng Syncfusion, chỉ lưu text chunks vào Firestore
- **Lợi ích:** Miễn phí hoàn toàn, xử lý nhanh hơn, không phụ thuộc network cho bước parse

### 5.3. RAG trên client-side
- **Giải pháp:** Keyword matching để tìm chunks liên quan, sau đó gửi context cho Gemini
- **Trade-off:** Chất lượng search không bằng vector embedding, nhưng đơn giản và không cần thêm service

---

## 6. Firebase Configuration

| Service | Trạng thái | Ghi chú |
|---|---|---|
| **Firebase Auth** | ✅ Active | Email/Password |
| **Cloud Firestore** | ✅ Active | Database `(default)`, region `nam5` |
| **Firebase Storage** | ⚠️ Rules defined | Không sử dụng (cần Blaze plan) |
| **Cloud Functions** | ⚠️ Code tồn tại | Không deploy (cần Blaze plan) |

### Firestore Security Rules
- User-scoped: mỗi user chỉ truy cập dữ liệu của mình (`request.auth.uid == userId`)
- Áp dụng cho tất cả subcollections (documents, quizzes, sessions, chunks)

---

## 7. Dependencies (pubspec.yaml)

| Nhóm | Package | Version |
|---|---|---|
| **State** | flutter_riverpod | ^2.5.1 |
| **Routing** | go_router | ^14.2.0 |
| **Firebase** | firebase_core | ^3.6.0 |
| | firebase_auth | ^5.3.1 |
| | cloud_firestore | ^5.4.4 |
| | firebase_storage | ^12.3.7 |
| **AI** | google_generative_ai | ^0.4.6 |
| **Auth** | google_sign_in | ^6.2.2 |
| **Document** | file_picker | ^8.1.2 |
| | syncfusion_flutter_pdf | ^27.1.48 |
| **Voice** | flutter_tts | ^4.2.0 |
| | speech_to_text | ^7.0.0 |
| | record | ^6.0.0 |
| **UI** | google_fonts | ^6.2.1 |
| | cached_network_image | ^3.4.1 |
| **Utils** | http, intl, uuid, path | latest |

---

## 8. Routing Map

| Route | Screen | Mô tả |
|---|---|---|
| `/splash` | SplashScreen | Animated splash → auto redirect |
| `/` | HomeScreen | Dashboard chính |
| `/login` | LoginScreen | Đăng nhập/Đăng ký |
| `/documents` | DocumentListScreen | Danh sách tài liệu |
| `/documents/:docId` | DocumentDetailScreen | Chi tiết tài liệu |
| `/quiz/setup/:docId` | QuizSetupScreen | Cấu hình quiz |
| `/quiz/play/:quizId` | QuizPlayScreen | Làm quiz |
| `/quiz/result/:quizId` | QuizResultScreen | Kết quả quiz |
| `/reading/:docId` | ReadingScreen | Đọc + TTS |
| `/pronunciation/:docId` | PronunciationScreen | Luyện phát âm |
| `/qa/:docId` | QAScreen | Hỏi đáp AI (RAG) |
| `/profile` | ProfileScreen | Hồ sơ + cài đặt |

---

## 9. Thống Kê

| Metric | Giá trị |
|---|---|
| Tổng số file Dart | 35 |
| Tổng số features | 10 modules |
| Tổng số routes | 12 |
| Tổng số commits | 7 |
| Branch chính | `dev/direct-ai` |
| Ngày bắt đầu | 25/04/2026 |
| Ngày cập nhật cuối | 26/04/2026 |

---

## 10. Kế Hoạch Tiếp Theo

1. **Commit các thay đổi pending** (refactor Storage → on-device parse)
2. **Testing end-to-end** trên device thật (upload PDF → quiz → QA)
3. **Google Sign-In integration** vào LoginScreen
4. **Cải thiện UI/UX** - animations, responsive design
5. **Vector embedding** cho RAG (thay keyword matching)
6. **Offline support** - cache tài liệu đã parse
7. **Analytics & monitoring** - Firebase Analytics, Crashlytics

---

*Tài liệu này được tạo tự động từ phân tích mã nguồn dự án.*
