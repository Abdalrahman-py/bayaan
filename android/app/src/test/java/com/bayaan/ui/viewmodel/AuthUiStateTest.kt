package com.bayaan.ui.viewmodel

import io.github.jan.supabase.auth.status.RefreshFailureCause
import io.github.jan.supabase.auth.status.SessionStatus
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Guards the rule that keeps a user signed in across app restarts: only a status that
 * actually says "no session" may show the login screen.
 */
class AuthUiStateTest {

    @Test
    fun `a cold start still loading the stored session stays on the splash`() {
        assertEquals(
            AuthUiState.Checking,
            authUiState(SessionStatus.Initializing, AuthUiState.Checking),
        )
    }

    @Test
    fun `a refresh that failed offline keeps the user signed in`() {
        assertEquals(
            AuthUiState.LoggedIn,
            authUiState(
                SessionStatus.RefreshFailure(RefreshFailureCause.NetworkError(Exception("offline"))),
                AuthUiState.Checking,
            ),
        )
    }

    @Test
    fun `sign-out and a rejected token go to the login screen`() {
        assertEquals(
            AuthUiState.LoggedOut(),
            authUiState(SessionStatus.NotAuthenticated(isSignOut = true), AuthUiState.LoggedIn),
        )
        assertEquals(
            AuthUiState.LoggedOut(),
            authUiState(SessionStatus.NotAuthenticated(isSignOut = false), AuthUiState.Checking),
        )
    }
}
