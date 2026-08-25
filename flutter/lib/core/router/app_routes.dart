class AppRoutes {
  AppRoutes._();

  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const signIn = '/sign-in';
  static const home = '/home';
  static const surahs = '/surahs';
  static const ayahSelection = '/surahs/ayahs';
  static const recording = '/recite/:sura/:aya';
  static const aiAnalysis = '/recite/:sura/:aya/analysis';
  static const celebration = '/recite/:sura/:aya/celebration';
  static const stats = '/stats';
  static const settings = '/settings';
  static const emailSignIn = '/sign-in/email';
  static const learn = '/learn';
  static const placement = '/learn/placement';
  static const lesson = '/learn/lesson/:lessonId';
  static const lessonResult = '/learn/lesson/:lessonId/result';

  static String recordingPath(int sura, int aya) => '/recite/$sura/$aya';
  static String aiAnalysisPath(int sura, int aya) =>
      '/recite/$sura/$aya/analysis';
  static String celebrationPath(int sura, int aya) =>
      '/recite/$sura/$aya/celebration';
  static String lessonPath(String lessonId) => '/learn/lesson/$lessonId';
  static String lessonResultPath(String lessonId) =>
      '/learn/lesson/$lessonId/result';
}
