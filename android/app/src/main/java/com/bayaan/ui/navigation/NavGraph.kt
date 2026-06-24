package com.bayaan.ui.navigation

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.bayaan.ui.model.RecitationUiState
import com.bayaan.ui.screens.RecitationScreen
import com.bayaan.ui.screens.VersePickerScreen

@Composable
fun BayaanNavGraph(
    currentScreenState: (sura: Int, aya: Int) -> RecitationUiState,
    onRecord: (sura: Int, aya: Int) -> Unit,
    onStop: (sura: Int, aya: Int) -> Unit,
    onTryAgain: (sura: Int, aya: Int) -> Unit,
    onNextAyah: (sura: Int, aya: Int, onNavigate: (Int, Int) -> Unit) -> Unit,
    onRetry: (sura: Int, aya: Int) -> Unit,
    modifier: Modifier = Modifier
) {
    val navController = rememberNavController()

    NavHost(
        navController = navController,
        startDestination = "picker",
        modifier = modifier
    ) {
        composable("picker") {
            VersePickerScreen(
                onPickAyah = { sura, aya ->
                    navController.navigate("recitation/$sura/$aya")
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
                            popUpTo("picker") { saveState = true }
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
