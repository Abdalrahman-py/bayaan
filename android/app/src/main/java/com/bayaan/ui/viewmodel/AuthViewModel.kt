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

    private val httpClient = HttpClient(CIO)

    fun checkSession() {
        viewModelScope.launch {
            try {
                val session = supabaseClient.auth.currentSessionOrNull()
                if (session != null) {
                    val synced = syncUserWithBackend(session.accessToken)
                    if (synced) {
                        state.value = AuthUiState.LoggedIn
                    } else {
                        state.value = AuthUiState.LoggedOut(error = "Sync with backend failed.")
                    }
                } else {
                    state.value = AuthUiState.LoggedOut()
                }
            } catch (e: Exception) {
                state.value = AuthUiState.LoggedOut(error = e.localizedMessage)
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
                    val synced = syncUserWithBackend(session.accessToken)
                    if (synced) {
                        state.value = AuthUiState.LoggedIn
                    } else {
                        supabaseClient.auth.signOut()
                        state.value = AuthUiState.LoggedOut(error = "Database sync failed. Please try again.")
                    }
                } else {
                    state.value = AuthUiState.LoggedOut(error = "Session failed to initialize.")
                }
            } catch (e: Exception) {
                state.value = AuthUiState.LoggedOut(error = e.localizedMessage ?: "Invalid credentials.")
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
                    val synced = syncUserWithBackend(session.accessToken)
                    state.value = if (synced) AuthUiState.LoggedIn
                        else AuthUiState.LoggedOut(error = "Database sync failed. Please try again.")
                } else {
                    state.value = AuthUiState.LoggedOut(pendingConfirmation = true)
                }
            } catch (e: Exception) {
                state.value = AuthUiState.LoggedOut(error = e.localizedMessage ?: "Signup failed.")
            }
        }
    }

    fun signOut() {
        viewModelScope.launch {
            try {
                supabaseClient.auth.signOut()
            } catch (e: java.lang.Exception) {
                // ignore
            }
            state.value = AuthUiState.LoggedOut()
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

    override fun onCleared() {
        super.onCleared()
        httpClient.close()
    }
}
