package com.bayaan.ui.viewmodel

import android.app.Application
import androidx.compose.runtime.mutableStateOf
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.bayaan.BuildConfig
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.providers.builtin.Email
import io.ktor.client.HttpClient
import io.ktor.client.engine.cio.CIO
import io.ktor.client.plugins.HttpTimeout
import io.ktor.client.request.post
import io.ktor.client.request.header
import io.ktor.http.HttpHeaders
import io.ktor.http.isSuccess
import kotlinx.coroutines.launch

sealed interface AuthUiState {
    data object Checking : AuthUiState
    data class LoggedOut(
        val error: String? = null,
        val pendingConfirmation: Boolean = false,
        val submitting: Boolean = false,
    ) : AuthUiState
    data object LoggedIn : AuthUiState
}

class AuthViewModel(application: Application) : AndroidViewModel(application) {

    val state = mutableStateOf<AuthUiState>(AuthUiState.Checking)

    val supabaseClient = createSupabaseClient(
        supabaseUrl = BuildConfig.SUPABASE_URL,
        supabaseKey = BuildConfig.SUPABASE_ANON_KEY
    ) {
        install(Auth)
    }

    private val httpClient = HttpClient(CIO) {
        // Render free tier can cold-start for tens of seconds after idling (see
        // backend/AGENTS.md — same reasoning as the Muaalem 60s client timeout).
        // /auth/sync itself is fire-and-forget (see below), so this timeout only
        // bounds how long the background sync coroutine can run, not the UI.
        install(HttpTimeout) { requestTimeoutMillis = 60_000 }
    }

    // Source of truth for LoggedIn/LoggedOut is the Supabase session alone.
    // /auth/sync (UserRepository.upsert, idempotent) is best-effort: a cold Render
    // backend must never undo a valid login/session — it used to, and that's the
    // "re-enter password every time I reopen the app" bug this replaces.
    fun checkSession() {
        viewModelScope.launch {
            try {
                val session = supabaseClient.auth.currentSessionOrNull()
                if (session != null) {
                    persistToken(session.accessToken)
                    state.value = AuthUiState.LoggedIn
                    syncUserWithBackend(session.accessToken)
                } else {
                    state.value = AuthUiState.LoggedOut()
                }
            } catch (e: Exception) {
                state.value = AuthUiState.LoggedOut(error = friendlyAuthError(e, "Couldn't restore your session."))
            }
        }
    }

    fun login(email: String, password: String) {
        val currentState = state.value as? AuthUiState.LoggedOut ?: AuthUiState.LoggedOut()
        state.value = currentState.copy(submitting = true, error = null)
        viewModelScope.launch {
            try {
                supabaseClient.auth.signInWith(Email) {
                    this.email = email
                    this.password = password
                }
                val session = supabaseClient.auth.currentSessionOrNull()
                if (session != null) {
                    persistToken(session.accessToken)
                    state.value = AuthUiState.LoggedIn
                    syncUserWithBackend(session.accessToken)
                } else {
                    state.value = AuthUiState.LoggedOut(error = "Session failed to initialize.")
                }
            } catch (e: Exception) {
                state.value = AuthUiState.LoggedOut(error = friendlyAuthError(e, "Couldn't log in. Please try again."))
            }
        }
    }

    fun signup(email: String, password: String) {
        val currentState = state.value as? AuthUiState.LoggedOut ?: AuthUiState.LoggedOut()
        state.value = currentState.copy(submitting = true, error = null)
        viewModelScope.launch {
            try {
                supabaseClient.auth.signUpWith(Email) {
                    this.email = email
                    this.password = password
                }
                // With email confirmation OFF, signUp returns an active session → log straight in.
                // With it ON, there's no session yet → show the confirm-your-email state.
                val session = supabaseClient.auth.currentSessionOrNull()
                if (session != null) {
                    persistToken(session.accessToken)
                    state.value = AuthUiState.LoggedIn
                    syncUserWithBackend(session.accessToken)
                } else {
                    state.value = AuthUiState.LoggedOut(pendingConfirmation = true)
                }
            } catch (e: Exception) {
                state.value = AuthUiState.LoggedOut(error = friendlyAuthError(e, "Couldn't sign up. Please try again."))
            }
        }
    }

    // State flips before the network call so nav (which reads `state` right after
    // calling this) never observes a stale LoggedIn and bounces back to home — that
    // was the "logout then instantly signed back in" bug.
    fun signOut() {
        clearPersistedToken()
        state.value = AuthUiState.LoggedOut()
        viewModelScope.launch {
            try {
                supabaseClient.auth.signOut()
            } catch (e: Exception) {
                // ignore
            }
        }
    }

    fun currentAccessToken(): String? {
        return supabaseClient.auth.currentSessionOrNull()?.accessToken
    }

    fun currentEmail(): String? {
        return supabaseClient.auth.currentSessionOrNull()?.user?.email
    }

    private suspend fun syncUserWithBackend(token: String): Boolean {
        return try {
            val response = httpClient.post("${BuildConfig.BACKEND_URL}/auth/sync") {
                header(HttpHeaders.Authorization, "Bearer $token")
            }
            response.status.isSuccess()
        } catch (e: Exception) {
            false
        }
    }

    // Supabase's AuthRestException.localizedMessage includes the request URL, headers
    // and method — a wall of text in the UI. Surface the known short cases and fall back
    // to a clean generic message instead of dumping the raw exception.
    // ponytail: substring match on stable server strings; if Supabase changes the
    // wording, the generic fallback still shows — extend the when-branches as needed.
    private fun friendlyAuthError(e: Throwable, fallback: String): String {
        val raw = e.message ?: return fallback
        return when {
            raw.contains("Invalid login credentials", ignoreCase = true) -> "Incorrect email or password."
            raw.contains("Email not confirmed", ignoreCase = true) -> "Please confirm your email before logging in."
            raw.contains("User already registered", ignoreCase = true) -> "An account with this email already exists."
            raw.contains("Password should be", ignoreCase = true) -> "Password is too weak (use at least 6 characters)."
            raw.contains("Unable to validate email", ignoreCase = true) -> "That email address looks invalid."
            else -> fallback
        }
    }

    // ponytail: plain SharedPreferences, not EncryptedSharedPreferences — allowBackup=false
    // (AndroidManifest.xml) closes the adb-backup/cloud-restore exfil path, which was the
    // concrete risk found; a rooted/compromised device can still read this file. Upgrade
    // path: androidx.security:security-crypto's EncryptedSharedPreferences if that threat
    // model becomes real.
    private fun persistToken(token: String) {
        getApplication<Application>()
            .getSharedPreferences("supabase_session", 0)
            .edit().putString("access_token", token).apply()
    }

    private fun clearPersistedToken() {
        getApplication<Application>()
            .getSharedPreferences("supabase_session", 0)
            .edit().remove("access_token").apply()
    }

    override fun onCleared() {
        super.onCleared()
        httpClient.close()
    }
}
