package com.bayaan.ui.navigation

import android.app.Application
import android.content.Context
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import androidx.lifecycle.viewmodel.compose.viewModel
import com.bayaan.ui.model.RecitationUiState
import com.bayaan.ui.screens.LearnScreen
import com.bayaan.ui.screens.LessonScreen
import com.bayaan.ui.screens.LoginScreen
import com.bayaan.ui.screens.MushafPagerScreen
import com.bayaan.ui.screens.OnboardingScreen
import com.bayaan.ui.screens.ProfileScreen
import com.bayaan.ui.screens.ProgressScreen
import com.bayaan.ui.screens.RecitationScreen
import com.bayaan.ui.screens.SettingsScreen
import com.bayaan.ui.screens.SignupScreen
import com.bayaan.ui.screens.SplashScreen
import com.bayaan.ui.screens.SurahIndexScreen
import com.bayaan.ui.viewmodel.AuthUiState
import com.bayaan.ui.viewmodel.AuthViewModel
import com.bayaan.ui.viewmodel.LessonViewModel

// Bottom-nav tabs (PRODUCTION_PLAN §6). Learn is the default landing.
private const val LEARN = "learn"
private const val MUSHAF = "mushaf"
private const val PROGRESS = "progress"
private const val PROFILE = "profile"

@Composable
fun BayaanNavGraph(
    authViewModel: AuthViewModel,
    currentScreenState: (sura: Int, aya: Int) -> RecitationUiState,
    onRecord: (sura: Int, aya: Int) -> Unit,
    onStop: (sura: Int, aya: Int) -> Unit,
    onTryAgain: (sura: Int, aya: Int) -> Unit,
    onNextAyah: (sura: Int, aya: Int, onNavigate: (Int, Int) -> Unit) -> Unit,
    onRetry: (sura: Int, aya: Int) -> Unit,
    modifier: Modifier = Modifier
) {
    val navController = rememberNavController()
    val authState by authViewModel.state
    val context = LocalContext.current
    val prefs = remember { context.getSharedPreferences("bayaan_prefs", Context.MODE_PRIVATE) }

    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = navBackStackEntry?.destination?.route

    val showBottomBar = currentRoute in listOf(LEARN, MUSHAF, PROGRESS, PROFILE, "settings")

    Scaffold(
        modifier = modifier,
        bottomBar = {
            if (showBottomBar) {
                NavigationBar(containerColor = MaterialTheme.colorScheme.surface) {
                    NavigationBarItem(
                        icon = { Icon(Icons.Default.Home, contentDescription = "Learn") },
                        label = { Text("Learn") },
                        selected = currentRoute == LEARN,
                        onClick = { if (currentRoute != LEARN) navController.navigateTab(LEARN, reselectRoot = true) },
                    )
                    NavigationBarItem(
                        icon = { Icon(Icons.AutoMirrored.Filled.List, contentDescription = "Qur'an") },
                        label = { Text("Qur'an") },
                        selected = currentRoute == MUSHAF,
                        onClick = { if (currentRoute != MUSHAF) navController.navigateTab(MUSHAF) },
                    )
                    NavigationBarItem(
                        icon = { Icon(Icons.Default.DateRange, contentDescription = "Progress") },
                        label = { Text("Progress") },
                        selected = currentRoute == PROGRESS,
                        onClick = { if (currentRoute != PROGRESS) navController.navigateTab(PROGRESS) },
                    )
                    NavigationBarItem(
                        icon = { Icon(Icons.Default.Person, contentDescription = "Profile") },
                        label = { Text("Profile") },
                        selected = currentRoute == PROFILE || currentRoute == "settings",
                        onClick = { if (currentRoute != PROFILE) navController.navigateTab(PROFILE) },
                    )
                }
            }
        }
    ) { paddingValues ->
        NavHost(
            navController = navController,
            startDestination = "splash",
            modifier = Modifier.padding(paddingValues)
        ) {
            composable("splash") {
                SplashScreen(onLoad = { authViewModel.checkSession() })

                LaunchedEffect(authState) {
                    if (authState is AuthUiState.LoggedIn) {
                        navController.navigate(LEARN) { popUpTo("splash") { inclusive = true } }
                    } else if (authState is AuthUiState.LoggedOut) {
                        val isFirstLaunch = prefs.getBoolean("first_launch", true)
                        val dest = if (isFirstLaunch) "onboarding" else "login"
                        navController.navigate(dest) { popUpTo("splash") { inclusive = true } }
                    }
                }
            }

            composable("onboarding") {
                OnboardingScreen(
                    onFinish = {
                        prefs.edit().putBoolean("first_launch", false).apply()
                        navController.navigate("login") { popUpTo("onboarding") { inclusive = true } }
                    }
                )
            }

            composable("login") {
                val loggedOutState = authState as? AuthUiState.LoggedOut ?: AuthUiState.LoggedOut()
                LoginScreen(
                    state = loggedOutState,
                    onLogin = { email, password -> authViewModel.login(email, password) },
                    onGoToSignup = { navController.navigate("signup") },
                )

                LaunchedEffect(authState) {
                    if (authState is AuthUiState.LoggedIn) {
                        navController.navigate(LEARN) { popUpTo("login") { inclusive = true } }
                    }
                }
            }

            composable("signup") {
                val loggedOutState = authState as? AuthUiState.LoggedOut ?: AuthUiState.LoggedOut()
                SignupScreen(
                    state = loggedOutState,
                    onSignup = { email, password -> authViewModel.signup(email, password) },
                    onGoToLogin = { navController.navigate("login") { popUpTo("signup") { inclusive = true } } },
                )
            }

            composable(LEARN) {
                LearnScreen(onOpenLesson = { lessonId -> navController.navigate("lesson/$lessonId") }, tokenProvider = authViewModel::currentAccessToken)
            }

            composable(PROGRESS) {
                ProgressScreen(tokenProvider = authViewModel::currentAccessToken)
            }

            composable(
                route = "lesson/{lessonId}",
                arguments = listOf(navArgument("lessonId") { type = NavType.StringType })
            ) { backStackEntry ->
                val lessonId = backStackEntry.arguments?.getString("lessonId") ?: return@composable
                val application = context.applicationContext as Application
                val lessonViewModel: LessonViewModel = viewModel(factory = LessonViewModel.Factory(application))
                LaunchedEffect(lessonId) { lessonViewModel.load(lessonId, authViewModel::currentAccessToken) }
                
                val permissionLauncher = androidx.activity.compose.rememberLauncherForActivityResult(
                    contract = androidx.activity.result.contract.ActivityResultContracts.RequestPermission()
                ) { isGranted ->
                    if (isGranted) {
                        lessonViewModel.startRecording()
                    } else {
                        android.widget.Toast.makeText(
                            context,
                            "Microphone permission is required to record your recitation.",
                            android.widget.Toast.LENGTH_LONG
                        ).show()
                    }
                }

                LessonScreen(
                    state = lessonViewModel.state,
                    onStartDrill = lessonViewModel::startDrill,
                    onAnswer = lessonViewModel::answer,
                    onCompleteSpoken = {}, // deprecated M2 stub, now handled via onStartRecording
                    onStartRecording = {
                        val hasMicPermission = androidx.core.content.ContextCompat.checkSelfPermission(
                            context,
                            android.Manifest.permission.RECORD_AUDIO
                        ) == android.content.pm.PackageManager.PERMISSION_GRANTED
                        if (hasMicPermission) {
                            lessonViewModel.startRecording()
                        } else {
                            permissionLauncher.launch(android.Manifest.permission.RECORD_AUDIO)
                        }
                    },
                    onStopRecording = lessonViewModel::stopRecording,
                    onReplay = lessonViewModel::replayPrompt,
                    onNext = lessonViewModel::next,
                    onStartPractice = lessonViewModel::startPractice,
                    onExit = { navController.popBackStack() },
                )
            }

            composable(MUSHAF) {
                SurahIndexScreen(
                    onSurahSelected = { startPage -> navController.navigate("mushaf_page/$startPage") }
                )
            }

            composable(
                route = "mushaf_page/{page}",
                arguments = listOf(navArgument("page") { type = NavType.IntType })
            ) { backStackEntry ->
                val startPage = backStackEntry.arguments?.getInt("page") ?: 1
                MushafPagerScreen(
                    startPage = startPage,
                    onAyahSelected = { sura, aya -> navController.navigate("recitation/$sura/$aya") },
                )
            }

            composable(PROFILE) {
                val email = if (authState is AuthUiState.LoggedIn) authViewModel.currentEmail() ?: "" else ""
                ProfileScreen(
                    email = email,
                    onLogout = {
                        authViewModel.signOut()
                        navController.navigate("login") { popUpTo(0) { inclusive = true } }
                    },
                    onOpenSettings = { navController.navigate("settings") },
                )
            }

            composable("settings") {
                SettingsScreen(onBack = { navController.popBackStack() })
            }

            composable(
                route = "recitation/{sura}/{aya}",
                arguments = listOf(
                    navArgument("sura") { type = NavType.IntType },
                    navArgument("aya") { type = NavType.IntType }
                )
            ) { backStackEntry ->
                val sura = backStackEntry.arguments?.getInt("sura") ?: 1
                val aya = backStackEntry.arguments?.getInt("aya") ?: 1
                val state = currentScreenState(sura, aya)

                RecitationScreen(
                    state = state,
                    onRecord = { onRecord(sura, aya) },
                    onStop = { onStop(sura, aya) },
                    onTryAgain = { onTryAgain(sura, aya) },
                    onNextAyah = {
                        onNextAyah(sura, aya) { nextSura, nextAya ->
                            navController.navigate("recitation/$nextSura/$nextAya") {
                                popUpTo(MUSHAF) { saveState = true }
                                launchSingleTop = true
                                restoreState = true
                            }
                        }
                    },
                    onRetry = { onRetry(sura, aya) },
                    onPickAyah = { navController.popBackStack() },
                )
            }
        }
    }
}

/** Tab navigation with multi-back-stack save/restore, anchored on the Learn root. */
private fun NavHostController.navigateTab(route: String, reselectRoot: Boolean = false) {
    navigate(route) {
        if (reselectRoot) {
            popUpTo(LEARN) { inclusive = true }
        } else {
            popUpTo(LEARN) { saveState = true }
            launchSingleTop = true
            restoreState = true
        }
    }
}
