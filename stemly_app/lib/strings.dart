/// Centralized repository of all user-facing strings in the STEMLY application.
/// Strictly adheres to sentence case, verb-led actions, and no blamed/informal language.
class AppStrings {
  AppStrings._();

  // ---------------------------------------------------------------------------
  // APP BRANDING & GLOBAL
  // ---------------------------------------------------------------------------
  static const String appName = "STEMLY";
  static const String appTagline = "Scan, visualise, learn.";
  static const String back = "Back";
  static const String cancel = "Cancel";
  static const String done = "Done";
  static const String save = "Save";
  static const String delete = "Delete";
  static const String retry = "Retry";
  static const String continueAction = "Continue";
  static const String close = "Close";
  static const String ok = "OK";
  static const String error = "Error";
  static const String success = "Success";

  // ---------------------------------------------------------------------------
  // NAVIGATION BAR
  // ---------------------------------------------------------------------------
  static const String tabHome = "Home";
  static const String tabHistory = "History";
  static const String tabSettings = "Settings";
  static const String tabAccount = "Account";

  // ---------------------------------------------------------------------------
  // SPLASH SCREEN
  // ---------------------------------------------------------------------------
  static const String splashLoading = "Initializing STEMLY...";

  // ---------------------------------------------------------------------------
  // LOGIN SCREEN
  // ---------------------------------------------------------------------------
  static const String loginTitle = "Welcome to STEMLY";
  static const String loginSubtitle =
      "Scan problems, explore simulations, and keep your notes in sync.";
  static const String whySignInTitle = "Why sign in?";
  static const String benefitSync = "Sync across devices";
  static const String benefitPasswordFree = "Password-free sign-in";
  static const String benefitHistory = "Saved history";
  static const String continueWithGoogle = "Continue with Google";
  static const String continueWithApple = "Sign in with Apple";
  static const String continueAsGuest = "Continue as Guest";
  static const String guestFootnote = "Guest scans are not synced.";
  static const String legalPrefix = "By continuing you agree to the ";
  static const String termsOfService = "Terms";
  static const String legalAnd = " and ";
  static const String privacyPolicy = "Privacy Policy";
  static const String connectionError =
      "Unable to connect. Check your connection.";

  // ---------------------------------------------------------------------------
  // HOME SCREEN
  // ---------------------------------------------------------------------------
  static const String homeTitle = "Home";
  static const String scanCardTitle = "Scan a problem";
  static const String scanCardSubtitle = "Equations, diagrams, graphs";
  static const String chooseFromGallery = "Choose from gallery";
  static const String continueLastScan = "Continue last scan";
  static const String noRecentScansExplanation = "No previous scan to continue.";
  static const String recentScansSection = "Recent scans";
  static const String seeAll = "See all";
  static const String exploreTopics = "Explore topics";
  static const String emptyHomeTitle = "No scans yet";
  static const String emptyHomeMessage =
      "Scan an equation or diagram from your worksheet to get started.";
  static const String cameraPermissionRationale =
      "STEMLY uses the camera to scan problems you want to learn from.";

  // ---------------------------------------------------------------------------
  // IMAGE CROPPER SCREEN
  // ---------------------------------------------------------------------------
  static const String cropTitle = "Crop problem";
  static const String rotateLeft = "Rotate left";
  static const String rotateRight = "Rotate right";
  static const String resetCrop = "Reset";
  static const String usePhoto = "Use photo";
  static const String retake = "Retake";

  // ---------------------------------------------------------------------------
  // PROCESSING STATE
  // ---------------------------------------------------------------------------
  static const String processingTitle = "Analysing problem";
  static const String stepReadingImage = "Reading image";
  static const String stepIdentifyingTopic = "Identifying topic";
  static const String stepPreparingNotes = "Preparing notes";
  static const String processingFailedTitle = "Unable to analyse this image";
  static const String processingFailedBody =
      "Try a closer, brighter photo of the problem.";
  static const String tryAgain = "Try again";

  // ---------------------------------------------------------------------------
  // SCAN RESULTS (NOTES | VISUALISER | QUIZ)
  // ---------------------------------------------------------------------------
  static const String tabNotes = "Notes";
  static const String tabVisualiser = "Visualiser";
  static const String tabQuiz = "Quiz";

  // Visualiser Tab
  static const String simPlay = "Play";
  static const String simPause = "Pause";
  static const String simVelocityVector = "Velocity";
  static const String simComponents = "Components";
  static const String simGravity = "Gravity";
  static const String simTrail = "Trail";
  static const String simTelemetry = "Telemetry";
  static const String resetParameters = "Reset parameters";
  static const String simulationParameters = "Simulation parameters";
  static const String noParameters = "No adjustable parameters";
  static const String statRange = "Range";
  static const String statMaxHeight = "Max height";
  static const String statFlightTime = "Flight time";
  static const String problemTargetAndFormulas = "Problem target & formulas";
  static const String targetObjective = "Target objective";
  static const String governingEquation = "Governing equation";
  static const String physicalVariables = "Physical variables";
  static const String toFind = "To find";
  static const String knownFromProblem = "From your problem";

  // AI Assistant
  static const String aiAssistant = "AI assistant";
  static const String aiAssistantPlaceholder =
      "Ask a question or say 'Set velocity to 30'";
  static const String send = "Send";
  static const String chipExplainGravity = "Explain gravity";
  static const String chipSetVelocity = "Set velocity to 50";
  static const String undo = "Undo";

  // Notes Tab
  static const String accordionConcept = "Concept";
  static const String accordionDerivation = "Derivation";
  static const String accordionWorkedExample = "Worked example";
  static const String accordionMisconceptions = "Common misconceptions";
  static const String accordionPracticeProblems = "Practice problems";
  static const String accordionKeyFormulas = "Key formulas";
  static const String accordionResources = "Resources";

  // Quiz Setup Tab
  static const String quizSetupHeader = "Test your knowledge on ";
  static const String difficulty = "Difficulty";
  static const String difficultyEasy = "Easy";
  static const String difficultyMedium = "Medium";
  static const String difficultyHard = "Hard";
  static const String questionCount = "Questions";
  static const String generateQuiz = "Generate quiz";
  static const String quizDisclaimer =
      "Questions are AI-generated and may contain errors.";

  // ---------------------------------------------------------------------------
  // QUIZ PLAY & RESULTS
  // ---------------------------------------------------------------------------
  static const String exitQuizTitle = "Leave quiz?";
  static const String exitQuizMessage = "Your progress will be lost.";
  static const String leave = "Leave";
  static const String keepGoing = "Keep going";
  static const String question = "Question";
  static const String nextQuestion = "Next";
  static const String submitQuiz = "Submit";
  static const String retakeQuiz = "Retake quiz";
  static const String backToNotes = "Back to notes";
  static const String answerReview = "Answer review";
  static const String yourAnswer = "Your answer";
  static const String correctAnswer = "Correct answer";
  static const String explanation = "Explanation";
  static const String keyTakeaway = "Key takeaway";
  static const String correct = "Correct";
  static const String incorrect = "Incorrect";
  static const String mastery = "Mastery";
  static const String proficient = "Proficient";
  static const String needsReview = "Needs review";

  // ---------------------------------------------------------------------------
  // HISTORY SCREEN
  // ---------------------------------------------------------------------------
  static const String historyTitle = "History";
  static const String filterAll = "All";
  static const String filterPhysics = "Physics";
  static const String filterMathematics = "Mathematics";
  static const String filterChemistry = "Chemistry";
  static const String filterStarred = "Starred";
  static const String untitledScan = "Untitled scan";
  static const String addToStarred = "Add to starred";
  static const String removeFromStarred = "Remove from starred";
  static const String clearHistory = "Clear history...";
  static const String deleteScansConfirmTitle = "Delete unstarred scans?";
  static const String deleteScansConfirmBody =
      "This will remove unstarred scan records from this device.";
  static const String scanDeleted = "Scan deleted";

  // ---------------------------------------------------------------------------
  // SETTINGS SCREEN
  // ---------------------------------------------------------------------------
  static const String settingsTitle = "Settings";
  static const String sectionAppearance = "Appearance";
  static const String theme = "Theme";
  static const String themeSystem = "System default";
  static const String themeLight = "Light";
  static const String themeDark = "Dark";
  static const String sectionNotifications = "Notifications";
  static const String notificationExplanation =
      "Study reminders and product updates.";
  static const String sectionScanning = "Scanning";
  static const String wifiOnly = "Wi-Fi only";
  static const String wifiOnlyExplanation = "Scans upload only on Wi-Fi.";
  static const String sectionAI = "AI";
  static const String stemlyCloudAI = "STEMLY Cloud AI";
  static const String connected = "Connected";
  static const String sectionDataPrivacy = "Data & privacy";
  static const String clearLocalCache = "Clear local cache";
  static const String clearCacheConfirmTitle = "Clear local cache?";
  static const String clearCacheConfirmBody =
      "Cached diagrams and temporary calculation data will be cleared.";
  static const String sectionAbout = "About";
  static const String version = "Version";
  static const String licenses = "Licenses";

  // ---------------------------------------------------------------------------
  // ACCOUNT SCREEN
  // ---------------------------------------------------------------------------
  static const String accountTitle = "Account";
  static const String dailyAIUsage = "Daily AI usage";
  static const String leftToday = "left today";
  static const String resetsAtMidnight = "Resets at midnight UTC";
  static const String syncStatus = "Sync status";
  static const String synced = "Synced";
  static const String notSynced = "Not synced";
  static const String signInToSync = "Sign in to sync";
  static const String signOut = "Sign out";
  static const String signOutConfirmTitle = "Sign out?";
  static const String signOutConfirmBody =
      "Your scan history remains saved in your cloud account.";
  static const String deleteAccount = "Delete account and data";
  static const String deleteAccountStep1Title = "Delete account and data?";
  static const String deleteAccountStep1Body =
      "This will permanently erase your profile, scan history, notes, and quiz records from STEMLY cloud servers and this device.\n\nThis action cannot be undone.";
  static const String deleteAccountStep2Title = "Are you absolutely sure?";
  static const String deleteAccountStep2Body =
      "All your personal data will be completely deleted immediately.";
}
