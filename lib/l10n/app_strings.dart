/// Single source of truth for every user-facing Persian string in the app.
///
/// HMR is deliberately a Persian-only product (see CLAUDE.md invariant #1), so
/// this is a centralized copy deck — not a multi-locale i18n layer. Widgets and
/// services reference `AppStrings.x` instead of hardcoding literals, which keeps
/// copy consistent, reviewable in one place, and reachable from context-free
/// code (e.g. `ApiService`). Parameterized lines are exposed as functions.
///
/// Not included here on purpose: the Jalali month table (`utils/jalali.dart`)
/// and the Persian-digit map (`models/message_model.dart`) — those are locale
/// data tables, not copy.
abstract final class AppStrings {
  // ── Brand ────────────────────────────────────────────────────────────────
  static const String appTitle = 'همر | HMR';
  static const String brandSubtitle = 'مشاور هوشمند موبایل';
  static const String appVersionLabel = 'HMR · نسخهٔ ۱.۰.۲';

  // ── Fatal error screen (release crash fallback) ──────────────────────────
  static const String errorScreenTitle = 'خطایی رخ داد';
  static const String errorScreenBody = 'لطفاً برنامه را مجدداً باز کنید.';

  // ── Generic actions / labels ─────────────────────────────────────────────
  static const String cancel = 'انصراف';
  static const String delete = 'حذف';
  static const String back = 'بازگشت';
  static const String retry = 'تلاش مجدد';
  static const String copy = 'کپی';
  static const String copiedInline = 'کپی شد';
  static const String signInWithGoogle = 'ورود با گوگل';
  static const String signOut = 'خروج از حساب';

  // ── Welcome screen (skippable, first launch only) ────────────────────────
  static const String welcomePanelBody =
      'مشاور هوشمند سخت‌افزار موبایل شما.\n'
      'برای شروع وارد شو یا به‌عنوان مهمان ادامه بده.';
  static const String continueAsGuest = 'ورود به عنوان مهمان';
  static const String welcomeTerms = 'با ادامه، قوانین و حریم خصوصی HMR را می‌پذیری.';

  // ── Delete-conversation dialog ───────────────────────────────────────────
  static const String deleteConversationTitle = 'حذف گفت‌وگو';
  static const String deleteConversationBody = 'این گفت‌وگو برای همیشه حذف می‌شود.';

  // ── Clear-chat dialog ────────────────────────────────────────────────────
  static const String clearChatTitle = 'پاک‌کردن گفت‌وگو';
  static const String clearChatBody =
      'همهٔ پیام‌های این گفت‌وگو حذف می‌شوند. این کار قابل بازگشت نیست.';
  static const String clearChatConfirm = 'پاک کن';
  static const String clearChatLabel = 'پاک کردن گفتگو';

  // ── Delete-account dialog ────────────────────────────────────────────────
  static const String deleteAccount = 'حذف حساب';
  static const String deleteAccountBody =
      'تمام گفت‌وگوها از دستگاه پاک می‌شوند و از حساب گوگل خارج می‌شوید.\n\n'
      'برای حذف داده‌های سرور، یک ایمیل درخواست برای ما ارسال خواهد شد.';

  // ── Conversations list (mobile) ──────────────────────────────────────────
  static const String conversationsTitle = 'گفت‌وگوها';
  static const String recentConversations = 'گفت‌وگوهای اخیر';
  static const String newConversation = 'گفت‌وگوی جدید';
  static const String newConversationPlus = '+ گفت‌وگوی جدید';
  static const String noConversationsTitle = 'هنوز گفت‌وگویی ندارید';
  static const String noConversationsBody = 'یک گفت‌وگوی جدید شروع کنید';

  // ── Sidebar / drawer ─────────────────────────────────────────────────────
  static const String newChat = 'گفتگوی جدید';
  static const String newChatShort = 'گپ جدید';
  static const String chatHistory = 'تاریخچه گفتگو';
  static const String searchHint = 'جست‌وجو در گفت‌وگوها';
  static const String emptyHistorySidebar =
      'هنوز گفتگویی نداری.\nبرای شروع، سؤالت را بپرس.';
  static const String sidebar = 'نوار کناری';
  static const String closeSidebar = 'بستن نوار کناری';
  static const String moreSection = 'بیشتر';
  static const String downloadApp = 'دانلود اپلیکیشن';
  static const String about = 'درباره ما';
  static const String privacy = 'حریم خصوصی';
  static const String disclaimer = 'سلب مسئولیت';

  // ── Account card ─────────────────────────────────────────────────────────
  static const String createAccountTitle = 'حساب خود را بساز';
  static const String createAccountBody =
      'گفت‌وگوهای شما به‌صورت امن روی همین دستگاه ذخیره می‌شوند.';
  static const String defaultUserName = 'کاربر';
  static const String unknownInitial = '؟';

  // ── Relative date labels ─────────────────────────────────────────────────
  static const String today = 'امروز';
  static const String yesterday = 'دیروز';
  static String daysAgo(int days) => '$days روز پیش';

  // ── Chat surface ─────────────────────────────────────────────────────────
  static const String welcomeBody =
      'من همر هستم، مشاور هوشمند سخت‌افزار شما.\nچه کمکی از دستم برمی‌آید؟';
  static const String heroTitle = 'امروز چطور می‌تونم کمکتون کنم؟';
  static const String composerHint = 'پیام خود را بنویسید…';
  static const String heroComposerHint = 'هر سوالی درباره موبایل دارید بپرسید';
  static const String sendMessage = 'ارسال پیام';
  static const String messageCopied = 'پیام کپی شد';
  static const String reportLabel = 'گزارش پاسخ نامناسب';

  // ── Empty-state category cards ───────────────────────────────────────────
  static const String catNewPhoneTitle = 'گوشی نو';
  static const String catNewPhonePrompt =
      'راهنمای خرید گوشی نو می‌خوام. بهترین گوشی‌های بازار الان چیا هستن؟';
  static const String catUsedPhoneTitle = 'گوشی دست دوم';
  static const String catUsedPhonePrompt =
      'چک‌لیست خرید گوشی دست دوم رو بهم بگو. چطور گوشی سالم رو تشخیص بدم؟';
  static const String catTroubleshootTitle = 'عیب‌یابی';
  static const String catTroubleshootPrompt = 'گوشیم مشکل داره. چطور عیب‌یابیش کنم؟';
  static const String catEducationTitle = 'آموزش سخت‌افزار';
  static const String catEducationPrompt =
      'می‌خوام درباره سخت‌افزار گوشی بیشتر بدونم. از کجا شروع کنم؟';
  static const String catAccessoriesTitle = 'لوازم جانبی';
  static const String catAccessoriesPrompt =
      'بهترین لوازم جانبی برای گوشی من چیه؟ راهنمایی می‌خوام.';

  // ── Report-answer email ──────────────────────────────────────────────────
  static const String reportEmailSubject = 'گزارش پاسخ نامناسب — HMR';
  static const String reportEmailBody = 'سلام،\n'
      'می‌خواهم این پاسخ هوش مصنوعی را گزارش کنم:\n\n';
  static const String reportEmailReasonPrompt = 'دلیل گزارش (لطفاً توضیح دهید): ';
  static String noEmailApp(String email) =>
      'برنامه ایمیلی یافت نشد. آدرس پشتیبانی کپی شد: $email';

  // ── Price disclaimer ─────────────────────────────────────────────────────
  static const String priceDisclaimer =
      'قیمت‌ها از منابع ایرانی جست‌وجو می‌شوند. صحت قیمت را پیش از خرید تأیید کنید.';

  // ── Auth state ───────────────────────────────────────────────────────────
  static const String signInCancelled = 'ورود لغو شد.';
  static const String signInFailed = 'ورود با گوگل ناموفق بود. لطفاً دوباره تلاش کنید.';

  // ── Chat validation / generic failure ────────────────────────────────────
  static String tooLong(int maxLength) =>
      'پیام شما بیش از $maxLength کاراکتر است. لطفاً آن را کوتاه‌تر کنید.';
  static const String unexpectedError =
      'خطای غیرمنتظره‌ای رخ داد. لطفاً دوباره تلاش کنید.';

  // ── API layer (all safe to show directly in the chat UI) ─────────────────
  static const String apiConfigError =
      'خطای پیکربندی برنامه. لطفاً با پشتیبانی تماس بگیرید.';
  static const String apiNoInternet =
      'اتصال اینترنت برقرار نیست. لطفاً اتصال خود را بررسی کنید.';
  static String apiServerUnavailable(int statusCode) =>
      'سرور همر در دسترس نیست ($statusCode). لطفاً لحظاتی دیگر تلاش کنید.';
  static const String apiServerNotResponding =
      'سرور همر پاسخ نمی‌دهد. اتصال اینترنت یا فیلترینگ را بررسی کنید.';
  static const String apiConnectFailed =
      'اتصال به سرور برقرار نشد. لطفاً اتصال اینترنت خود را بررسی کنید.';
  static const String apiEmptyResponse =
      'متأسفانه پاسخی از سرور دریافت نشد. لطفاً دوباره تلاش کنید.';
  static const String apiAuthError =
      'خطای احراز هویت. لطفاً با پشتیبانی تماس بگیرید.';
  static String apiServerError(int statusCode) =>
      'خطای سرور ($statusCode). لطفاً لحظاتی دیگر تلاش کنید.';
  static const String apiInternalError =
      'خطای داخلی سرور. لطفاً لحظاتی دیگر تلاش کنید.';
  static const String apiTimeout =
      'زمان اتصال به پایان رسید. لطفاً اتصال اینترنت خود را بررسی کنید.';
  static const String apiConnectionError =
      'خطا در برقراری ارتباط با سرور. لطفاً اتصال اینترنت خود را بررسی کنید.';
  static const String apiInvalidResponse =
      'پاسخ دریافتی از سرور نامعتبر است. لطفاً دوباره تلاش کنید.';
}
