package com.example.pdh

import io.flutter.embedding.android.FlutterActivity
import com.facebook.FacebookCallback
import com.facebook.FacebookException
import com.facebook.AccessToken
import com.facebook.login.LoginResult
import com.facebook.login.LoginManager
// import com.facebook.login.widget.LoginButton // No longer needed as UI is in Flutter
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

class MainActivity : FlutterActivity() {

    private lateinit var auth: FirebaseAuth
    private lateinit var callbackManager: CallbackManager

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // setContentView(R.layout.activity_main) // This line is likely not needed in FlutterActivity

        // Initialize Firebase Auth
        auth = FirebaseAuth.getInstance()

        // Initialize Facebook Login button - UI handled in Flutter
        callbackManager = CallbackManager.Factory.create()

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
}
