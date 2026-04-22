import 'package:flutter/material.dart';

/// Map-based localization — no .arb files needed.
class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('ar'),
  ];

  String t(String key) => _strings[locale.languageCode]?[key] ?? _strings['en']![key] ?? key;

  static const Map<String, Map<String, String>> _strings = {
    'en': {
      // General
      'app_name': 'Moov Editor',
      'ok': 'OK',
      'cancel': 'Cancel',
      'save': 'Save',
      'delete': 'Delete',
      'rename': 'Rename',
      'duplicate': 'Duplicate',
      'close': 'Close',
      'confirm': 'Confirm',
      'loading': 'Loading…',
      'error': 'Error',
      'success': 'Success',
      'retry': 'Retry',
      'share': 'Share',
      'upload': 'Upload to Cloud',

      // Auth
      'login': 'Log In',
      'signup': 'Sign Up',
      'logout': 'Log Out',
      'email': 'Email',
      'password': 'Password',
      'confirm_password': 'Confirm Password',
      'display_name': 'Display Name',
      'forgot_password': 'Forgot password?',
      'welcome_back': 'Welcome back',
      'welcome_subtitle': 'Pick up where you left off',
      'no_account': "Don't have an account? Sign Up",
      'have_account': 'Already have an account? Log In',
      'continue_google': 'Continue with Google',
      'password_reset_sent': 'Password reset email sent.',
      'invalid_email': 'Enter a valid email address.',
      'weak_password': 'Password must be at least 8 characters with a number.',
      'passwords_no_match': 'Passwords do not match.',
      'stay_signed_in': 'Stay signed in',
      'error_user_not_found': 'No account found with this email.',
      'error_wrong_password': 'Incorrect password. Please try again.',
      'error_invalid_email': 'Invalid email format.',
      'error_user_disabled': 'This account has been disabled.',
      'error_too_many_requests': 'Too many attempts. Please try again later.',
      'error_email_already_in_use': 'An account with this email already exists.',
      'error_weak_password': 'Password must be at least 8 characters.',
      'error_generic': 'Something went wrong. Please try again.',

      // Home
      'new_project': '+ New Project',
      'recent_projects': 'Recent Projects',
      'no_projects': 'Tap + to create your first video',
      'project_name': 'Project Name',
      'create_project': 'Create Project',
      'sync_cloud': 'Sync to Cloud',

      // Editor
      'auto_saved': 'Saved ✓',
      'saving': 'Saving…',
      'export': 'Export',
      'undo': 'Undo',
      'redo': 'Redo',
      'split': 'Split',
      'speed': 'Speed',
      'volume': 'Volume',
      'filters': 'Filters',
      'transitions': 'Transitions',
      'add_keyframe': 'Add Keyframe',
      'text_overlay': 'Text',
      'crop': 'Crop',
      'transform': 'Transform',
      'color': 'Color',
      'audio': 'Audio',
      'effects': 'Effects',
      'position_x': 'Position X',
      'position_y': 'Position Y',
      'scale': 'Scale',
      'rotation': 'Rotation',
      'opacity': 'Opacity',
      'brightness': 'Brightness',
      'contrast': 'Contrast',
      'saturation': 'Saturation',
      'hue': 'Hue',
      'fade_in': 'Fade In',
      'fade_out': 'Fade Out',
      'snap': 'Snap',

      // Export
      'start_export': 'Start Export',
      'aspect_ratio': 'Aspect Ratio',
      'resolution': 'Resolution',
      'frame_rate': 'Frame Rate',
      'quality': 'Quality',
      'format': 'Format',
      'estimated_size': 'Estimated Size',
      'exporting': 'Exporting…',
      'export_complete': 'Export Complete',
      'save_to_gallery': 'Save to Gallery',
      'cancel_export': 'Cancel Export',

      // Settings
      'settings': 'Settings',
      'appearance': 'Appearance',
      'theme': 'Theme',
      'language': 'Language',
      'preferences': 'Preferences',
      'auto_save': 'Auto-Save',
      'cloud_sync': 'Cloud Sync',
      'default_aspect_ratio': 'Default Aspect Ratio',
      'default_quality': 'Default Export Quality',
      'storage': 'Storage',
      'cache_size': 'Cache Size',
      'clear_cache': 'Clear Cache',
      'manage_projects': 'Manage Projects',
      'account': 'Account',
      'edit_profile': 'Edit Profile',
      'change_password': 'Change Password',
      'about': 'About',
      'version': 'Version',
      'terms': 'Terms of Service',
      'privacy': 'Privacy Policy',
      'rate_us': 'Rate Us',
      'theme_dark': 'Dark',
      'theme_light': 'Light',
      'theme_system': 'System',

      // Profile
      'profile': 'Profile',
      'projects_count': 'Projects',
      'total_minutes': 'Minutes Edited',
      'exports_count': 'Exports',
      'cloud_storage': 'Cloud Storage Used',
      'recent_activity': 'Recent Activity',
    },
    'ar': {
      // General
      'app_name': 'موف إديتور',
      'ok': 'موافق',
      'cancel': 'إلغاء',
      'save': 'حفظ',
      'delete': 'حذف',
      'rename': 'إعادة تسمية',
      'duplicate': 'تكرار',
      'close': 'إغلاق',
      'confirm': 'تأكيد',
      'loading': 'جارٍ التحميل…',
      'error': 'خطأ',
      'success': 'نجاح',
      'retry': 'إعادة المحاولة',
      'share': 'مشاركة',
      'upload': 'رفع إلى السحابة',

      // Auth
      'login': 'تسجيل الدخول',
      'signup': 'إنشاء حساب',
      'logout': 'تسجيل الخروج',
      'email': 'البريد الإلكتروني',
      'password': 'كلمة المرور',
      'confirm_password': 'تأكيد كلمة المرور',
      'display_name': 'الاسم',
      'forgot_password': 'نسيت كلمة المرور؟',
      'welcome_back': 'أهلاً بعودتك',
      'welcome_subtitle': 'تابع من حيث توقفت',
      'no_account': 'ليس لديك حساب؟ إنشاء حساب',
      'have_account': 'لديك حساب بالفعل؟ تسجيل الدخول',
      'continue_google': 'المتابعة مع Google',
      'password_reset_sent': 'تم إرسال بريد إعادة تعيين كلمة المرور.',
      'invalid_email': 'أدخل عنوان بريد إلكتروني صالحاً.',
      'weak_password': 'يجب أن تتكون كلمة المرور من 8 أحرف على الأقل مع رقم.',
      'passwords_no_match': 'كلمتا المرور غير متطابقتين.',
      'stay_signed_in': 'البقاء مسجلاً',
      'error_user_not_found': 'لم يتم العثور على حساب بهذا البريد الإلكتروني.',
      'error_wrong_password': 'كلمة المرور غير صحيحة. حاول مرة أخرى.',
      'error_invalid_email': 'صيغة البريد الإلكتروني غير صالحة.',
      'error_user_disabled': 'تم تعطيل هذا الحساب.',
      'error_too_many_requests': 'محاولات كثيرة جداً. حاول مجدداً لاحقاً.',
      'error_email_already_in_use': 'يوجد حساب بهذا البريد الإلكتروني بالفعل.',
      'error_weak_password': 'يجب أن تتكون كلمة المرور من 8 أحرف على الأقل.',
      'error_generic': 'حدث خطأ ما. حاول مرة أخرى.',

      // Home
      'new_project': '+ مشروع جديد',
      'recent_projects': 'المشاريع الأخيرة',
      'no_projects': 'اضغط + لإنشاء مقطعك الأول',
      'project_name': 'اسم المشروع',
      'create_project': 'إنشاء مشروع',
      'sync_cloud': 'مزامنة مع السحابة',

      // Editor
      'auto_saved': 'محفوظ ✓',
      'saving': 'جارٍ الحفظ…',
      'export': 'تصدير',
      'undo': 'تراجع',
      'redo': 'إعادة',
      'split': 'قص',
      'speed': 'السرعة',
      'volume': 'الصوت',
      'filters': 'فلاتر',
      'transitions': 'انتقالات',
      'add_keyframe': 'إضافة إطار رئيسي',
      'text_overlay': 'نص',
      'crop': 'اقتصاص',
      'transform': 'تحويل',
      'color': 'اللون',
      'audio': 'الصوت',
      'effects': 'تأثيرات',
      'position_x': 'الموضع X',
      'position_y': 'الموضع Y',
      'scale': 'الحجم',
      'rotation': 'الدوران',
      'opacity': 'الشفافية',
      'brightness': 'السطوع',
      'contrast': 'التباين',
      'saturation': 'التشبع',
      'hue': 'الصبغة',
      'fade_in': 'ظهور تدريجي',
      'fade_out': 'اختفاء تدريجي',
      'snap': 'محاذاة',

      // Export
      'start_export': 'بدء التصدير',
      'aspect_ratio': 'نسبة العرض إلى الارتفاع',
      'resolution': 'الدقة',
      'frame_rate': 'معدل الإطارات',
      'quality': 'الجودة',
      'format': 'الصيغة',
      'estimated_size': 'الحجم التقديري',
      'exporting': 'جارٍ التصدير…',
      'export_complete': 'اكتمل التصدير',
      'save_to_gallery': 'حفظ في المعرض',
      'cancel_export': 'إلغاء التصدير',

      // Settings
      'settings': 'الإعدادات',
      'appearance': 'المظهر',
      'theme': 'السمة',
      'language': 'اللغة',
      'preferences': 'التفضيلات',
      'auto_save': 'الحفظ التلقائي',
      'cloud_sync': 'المزامنة السحابية',
      'default_aspect_ratio': 'نسبة العرض الافتراضية',
      'default_quality': 'جودة التصدير الافتراضية',
      'storage': 'التخزين',
      'cache_size': 'حجم الذاكرة المؤقتة',
      'clear_cache': 'مسح الذاكرة المؤقتة',
      'manage_projects': 'إدارة المشاريع',
      'account': 'الحساب',
      'edit_profile': 'تعديل الملف الشخصي',
      'change_password': 'تغيير كلمة المرور',
      'about': 'حول',
      'version': 'الإصدار',
      'terms': 'شروط الخدمة',
      'privacy': 'سياسة الخصوصية',
      'rate_us': 'قيّمنا',
      'theme_dark': 'داكن',
      'theme_light': 'فاتح',
      'theme_system': 'النظام',

      // Profile
      'profile': 'الملف الشخصي',
      'projects_count': 'المشاريع',
      'total_minutes': 'دقائق التحرير',
      'exports_count': 'التصديرات',
      'cloud_storage': 'التخزين السحابي المستخدم',
      'recent_activity': 'النشاط الأخير',
    },
  };
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLocales.any((l) => l.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
