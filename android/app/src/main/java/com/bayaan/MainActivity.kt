package com.bayaan

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import androidx.core.content.ContextCompat
import androidx.lifecycle.ViewModelProvider
import com.bayaan.ui.navigation.BayaanNavGraph
import com.bayaan.ui.theme.BayaanTheme
import com.bayaan.ui.viewmodel.AuthViewModel
import com.bayaan.ui.viewmodel.RecitationViewModel

class MainActivity : ComponentActivity() {

    private lateinit var authViewModel: AuthViewModel
    private lateinit var viewModel: RecitationViewModel
    private var pendingRecord: Pair<Int, Int>? = null

    private val requestMicPermission = registerForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted ->
        val pending = pendingRecord ?: return@registerForActivityResult
        pendingRecord = null
        if (granted) viewModel.record(pending.first, pending.second)
        else viewModel.permissionDenied(pending.first, pending.second)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        authViewModel = ViewModelProvider(this)[AuthViewModel::class.java]
        viewModel = ViewModelProvider(
            this,
            RecitationViewModel.Factory(application, { authViewModel.currentAccessToken() })
        )[RecitationViewModel::class.java]

        setContent {
            BayaanTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background,
                ) {
                    BayaanNavGraph(
                        authViewModel = authViewModel,
                        currentScreenState = { sura, aya -> viewModel.stateFor(sura, aya) },
                        onRecord = { sura, aya -> onRecordTapped(sura, aya) },
                        onStop = { sura, aya -> viewModel.stop(sura, aya) },
                        onTryAgain = { sura, aya -> viewModel.retry(sura, aya) },
                        onNextAyah = { sura, aya, onNavigate -> viewModel.nextAyah(sura, aya, onNavigate) },
                        onRetry = { sura, aya -> viewModel.retry(sura, aya) },
                    )
                }
            }
        }
    }

    private fun onRecordTapped(sura: Int, aya: Int) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO)
            == PackageManager.PERMISSION_GRANTED
        ) {
            viewModel.record(sura, aya)
        } else {
            pendingRecord = sura to aya
            requestMicPermission.launch(Manifest.permission.RECORD_AUDIO)
        }
    }
}
