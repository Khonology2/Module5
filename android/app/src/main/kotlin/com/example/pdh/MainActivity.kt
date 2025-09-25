package com.example.pdh

import io.flutter.embedding.android.FlutterActivity
<<<<<<< HEAD
=======
import io.flutter.plugin.common.MethodChannel
>>>>>>> bc7f62408f42e40cea0e0f8310c6097320415358
import com.facebook.FacebookCallback
import com.facebook.FacebookException
import com.facebook.AccessToken
import com.facebook.login.LoginResult
import com.facebook.login.LoginManager
// import com.facebook.login.widget.LoginButton // No longer needed as UI is in Flutter
<<<<<<< HEAD
=======
import com.google.mlkit.nl.proofreader.Proofreading
import com.google.mlkit.nl.proofreader.Proofreader
import com.google.mlkit.nl.proofreader.ProofreaderOptions
import com.google.mlkit.nl.proofreader.ProofreadingRequest
import com.google.mlkit.nl.proofreader.ProofreadingResult
>>>>>>> bc7f62408f42e40cea0e0f8310c6097320415358
import com.google.firebase.auth.FacebookAuthProvider
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.FirebaseUser
// import com.google.firebase.auth.ktx.auth // No longer needed
// import com.google.firebase.ktx.Firebase // No longer needed
import android.content.Intent
import android.util.Log
import android.widget.Toast
import android.os.Bundle
import com.facebook.CallbackManager
<<<<<<< HEAD
=======
import com.google.mlkit.nl.proofreader.FeatureStatus
import com.google.mlkit.nl.proofreader.GenAiException
import com.google.mlkit.nl.proofreader.DownloadCallback
import com.google.android.gms.tasks.Tasks.await
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.launch
import org.json.JSONObject // Import for JSON object handling
>>>>>>> bc7f62408f42e40cea0e0f8310c6097320415358

class MainActivity : FlutterActivity() {

    private lateinit var auth: FirebaseAuth
    private lateinit var callbackManager: CallbackManager
<<<<<<< HEAD
=======
    private lateinit var proofreader: Proofreader
    private val CHANNEL = "com.example.khonopal/proofreading"
>>>>>>> bc7f62408f42e40cea0e0f8310c6097320415358

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // setContentView(R.layout.activity_main) // This line is likely not needed in FlutterActivity

<<<<<<< HEAD
=======
        // Set up MethodChannel
        MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            if (call.method == "proofreadText") {
                val text = call.argument<String>("text")
                if (text != null) {
                    lifecycleScope.launch {
                        try {
                            val proofreadResultJson = startProofreading(text)
                            result.success(proofreadResultJson)
                        } catch (e: Exception) {
                            val errorJson = JSONObject().apply {
                                put("status", "ERROR")
                                put("message", "Proofreading failed: ${e.message}")
                            }.toString()
                            result.success(errorJson)
                        }
                    }
                } else {
                    val errorJson = JSONObject().apply {
                        put("status", "ERROR")
                        put("message", "Text to proofread cannot be null")
                    }.toString()
                    result.success(errorJson)
                }
            } else {
                result.notImplemented()
            }
        }

>>>>>>> bc7f62408f42e40cea0e0f8310c6097320415358
        // Initialize Firebase Auth
        auth = FirebaseAuth.getInstance()

        // Initialize Facebook Login button - UI handled in Flutter
        callbackManager = CallbackManager.Factory.create()

<<<<<<< HEAD
=======
        val options = ProofreaderOptions.builder(this)
            .setInputType(ProofreaderOptions.InputType.KEYBOARD)
            .setLanguage(ProofreaderOptions.Language.ENGLISH)
            .build()
        proofreader = Proofreading.getClient(options)

        // Call prepareProofreader in a coroutine
        lifecycleScope.launch { prepareProofreader() }
>>>>>>> bc7f62408f42e40cea0e0f8310c6097320415358
        // The following lines are removed as the Facebook Login button UI is in Flutter
        // val buttonFacebookLogin = findViewById<LoginButton>(R.id.buttonFacebookLogin)
        // buttonFacebookLogin.setReadPermissions(listOf("email", "public_profile"))
        
        // buttonFacebookLogin.registerCallback(callbackManager, object : FacebookCallback<LoginResult> {
        //     override fun onSuccess(loginResult: LoginResult) {
        //         Log.d("FB_LOGIN", "facebook:onSuccess:$loginResult")
        //         handleFacebookAccessToken(loginResult.accessToken)
        //     }

        //     override fun onCancel() {
        //         Log.d("FB_LOGIN", "facebook:onCancel")
        //     }

        //     override fun onError(error: FacebookException) {
        //         Log.d("FB_LOGIN", "facebook:onError", error)
        //     }
        // })
    }

    private fun handleFacebookAccessToken(token: AccessToken) {
        Log.d("FB_LOGIN", "handleFacebookAccessToken:$token")

        val credential = FacebookAuthProvider.getCredential(token.token)
        auth.signInWithCredential(credential)
            .addOnCompleteListener(this) { task ->
                if (task.isSuccessful) {
                    // Sign in success
                    Log.d("FB_LOGIN", "signInWithCredential:success")
                    val user = auth.currentUser
                    updateUI(user)
                } else {
                    // Sign in failed
                    Log.w("FB_LOGIN", "signInWithCredential:failure", task.exception)
                    Toast.makeText(this, "Authentication failed.", Toast.LENGTH_SHORT).show()
                    updateUI(null)
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        callbackManager.onActivityResult(requestCode, resultCode, data)
    }

    override fun onStart() {
        super.onStart()
        val currentUser = auth.currentUser
        updateUI(currentUser)
    }

    private fun updateUI(user: FirebaseUser?) {
        if (user != null) {
            // User is signed in
            Log.d("FB_LOGIN", "User: ${user.displayName} - ${user.email}")
        } else {
            // User is signed out
            Log.d("FB_LOGIN", "No user signed in")
        }
    }

    // Sign Out function placeholder
    fun signOut() {
        FirebaseAuth.getInstance().signOut()
        LoginManager.getInstance().logOut()
        updateUI(null)
    }
<<<<<<< HEAD
=======

    override fun onDestroy() {
        super.onDestroy()
        proofreader.close()
    }

    suspend fun prepareProofreader() {
        val featureStatus = proofreader.checkFeatureStatus().await()

        when (featureStatus) {
            FeatureStatus.DOWNLOADABLE -> {
                proofreader.downloadFeature(object : DownloadCallback {
                    override fun onDownloadCompleted() {
                        lifecycleScope.launch {
                            // The result of startProofreading is now a JSON string, but we don't need it here.
                            startProofreading("The praject is compleet but needs too be reviewd")
                            Log.d("Proofreading", "Download completed. Ready to proofread.")
                        }
                    }
                    override fun onDownloadFailed(e: GenAiException) {
                        Log.e("Proofreading", "Download failed", e)
                    }
                    override fun onDownloadStarted(bytesToDownload: Long) {}
                    override fun onDownloadProgress(totalBytesDownloaded: Long) {}
                })
            }
            FeatureStatus.AVAILABLE -> {
                Log.d("Proofreading", "Feature available. Ready to proofread.")
                lifecycleScope.launch {
                    // The result of startProofreading is now a JSON string, but we don't need it here.
                    startProofreading("The praject is compleet but needs too be reviewd")
                }
            }
            else -> Log.w("Proofreading", "Feature not ready: $featureStatus")
        }
    }

    suspend fun startProofreading(text: String): String {
        val jsonResponse = JSONObject()
        try {
            val request = ProofreadingRequest.builder(text).build()
            val results = proofreader.runInference(request).await().results

            val suggestedTexts = results.map { it.suggestedText }
            if (suggestedTexts.isNotEmpty()) {
                jsonResponse.put("status", "SUCCESS")
                jsonResponse.put("text", suggestedTexts.first())
                Log.d("Proofreading", "Suggestion: ${suggestedTexts.first()}")
            } else {
                jsonResponse.put("status", "NO_SUGGESTIONS")
                jsonResponse.put("text", text)
                Log.d("Proofreading", "No suggestions found for: $text")
            }
        } catch (e: Exception) {
            jsonResponse.put("status", "ERROR")
            jsonResponse.put("message", "Proofreading API error: ${e.message}")
            Log.e("Proofreading", "Error during proofreading: ", e)
        }
        return jsonResponse.toString()
    }
>>>>>>> bc7f62408f42e40cea0e0f8310c6097320415358
}
