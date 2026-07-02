package com.bayaan.ui.navigation

import android.content.Context
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.List
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
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.bayaan.ui.model.RecitationUiState
import com.bayaan.ui.screens.HomeScreen
import com.bayaan.ui.screens.LoginScreen
import com.bayaan.ui.screens.MushafPagerScreen
import com.bayaan.ui.screens.SurahIndexScreen
import com.bayaan.ui.screens.OnboardingScreen
import com.bayaan.ui.screens.ProfileScreen
import com.bayaan.ui.screens.RecitationScreen
import com.bayaan.ui.screens.SettingsScreen
import com.bayaan.ui.screens.SignupScreen
import com.bayaan.ui.screens.SplashScreen
import com.bayaan.ui.screens.VersePickerScreen
import com.bayaan.ui.viewmodel.AuthUiState
import com.bayaan.ui.viewmodel.AuthViewModel

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

    val showBottomBar = currentRoute in listOf("home", "mushaf", "profile", "settings")

    Scaffold(
        modifier = modifier,
        bottomBar = {
            if (showBottomBar) {
                NavigationBar(
                    containerColor = MaterialTheme.colorScheme.surface
                ) {
                    NavigationBarItem(
                        icon = { Icon(Icons.Default.Home, contentDescription = "Home") },
                        label = { Text("Home") },
                        selected = currentRoute == "home",
                        onClick = {
                            if (currentRoute != "home") {
                                navController.navigate("home") {
                                    popUpTo("home") { inclusive = true }
                                }
                            }
                        }
                    )
                    NavigationBarItem(
                        icon = { Icon(Icons.Default.List, contentDescription = "Qur'an") },
                        label = { Text("Qur'an") },
                        selected = currentRoute == "mushaf",
                        onClick = {
                            if (currentRoute != "mushaf") {
                                navController.navigate("mushaf") {
                                    popUpTo("home") { saveState = true }
                                    launchSingleTop = true
                                    restoreState = true
                                }
                            }
                        }
                    )
                    NavigationBarItem(
                        icon = { Icon(Icons.Default.Person, contentDescription = "Profile") },
                        label = { Text("Profile") },
                        selected = currentRoute == "profile" || currentRoute == "settings",
                        onClick = {
                            if (currentRoute != "profile") {
                                navController.navigate("profile") {
                                    popUpTo("home") { saveState = true }
                                    launchSingleTop = true
                                    restoreState = true
                                }
                            }
                        }
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
                SplashScreen(
                    onLoad = {
                        authViewModel.checkSession()
                    }
                )

                LaunchedEffect(authState) {
                    if (authState is AuthUiState.LoggedIn) {
                        navController.navigate("home") {
                            popUpTo("splash") { inclusive = true }
                        }
                    } else if (authState is AuthUiState.LoggedOut) {
                        val isFirstLaunch = prefs.getBoolean("first_launch", true)
                        if (isFirstLaunch) {
                            navController.navigate("onboarding") {
                                popUpTo("splash") { inclusive = true }
                            }
                        } else {
                            navController.navigate("login") {
                                popUpTo("splash") { inclusive = true }
                            }
                        }
                    }
                }
            }

            composable("onboarding") {
                OnboardingScreen(
                    onFinish = {
                        prefs.edit().putBoolean("first_launch", false).apply()
                        navController.navigate("login") {
                            popUpTo("onboarding") { inclusive = true }
                        }
                    }
                )
            }

            composable("login") {
                val loggedOutState = authState as? AuthUiState.LoggedOut ?: AuthUiState.LoggedOut()
                LoginScreen(
                    state = loggedOutState,
                    onLogin = { email, password ->
                        authViewModel.login(email, password)
                    },
                    onGoToSignup = {
                        navController.navigate("signup")
                    }
                )

                LaunchedEffect(authState) {
                    if (authState is AuthUiState.LoggedIn) {
                        navController.navigate("home") {
                            popUpTo("login") { inclusive = true }
                        }
                    }
                }
            }

            composable("signup") {
                val loggedOutState = authState as? AuthUiState.LoggedOut ?: AuthUiState.LoggedOut()
                SignupScreen(
                    state = loggedOutState,
                    onSignup = { email, password ->
                        authViewModel.signup(email, password)
                    },
                    onGoToLogin = {
                        navController.navigate("login") {
                            popUpTo("signup") { inclusive = true }
                        }
                    }
                )
            }

            composable("home") {
                HomeScreen(
                    onOpenMushaf = {
                        navController.navigate("mushaf")
                    }
                )
            }

            composable("mushaf") {
                SurahIndexScreen(
                    onSurahSelected = { startPage ->
                        navController.navigate("mushaf_page/$startPage")
                    }
                )
            }

            composable(
                route = "mushaf_page/{page}",
                arguments = listOf(
                    navArgument("page") { type = NavType.IntType }
                )
            ) { backStackEntry ->
                val startPage = backStackEntry.arguments?.getInt("page") ?: 1
                MushafPagerScreen(
                    startPage = startPage,
                    onAyahSelected = { sura, aya ->
                        navController.navigate("recitation/$sura/$aya")
                    }
                )
            }

            composable("profile") {
                val email = if (authState is AuthUiState.LoggedIn) {
                    authViewModel.currentEmail() ?: ""
                } else ""
                ProfileScreen(
                    email = email,
                    onLogout = {
                        authViewModel.signOut()
                        navController.navigate("login") {
                            popUpTo(0) { inclusive = true }
                        }
                    },
                    onOpenSettings = {
                        navController.navigate("settings")
                    }
                )
            }

            composable("settings") {
                SettingsScreen(
                    onBack = {
                        navController.popBackStack()
                    }
                )
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
                                popUpTo("mushaf") { saveState = true }
                                launchSingleTop = true
                                restoreState = true
                            }
                        }
                    },
                    onRetry = { onRetry(sura, aya) },
                    onPickAyah = { navController.popBackStack() }
                )
            }
        }
    }
}
