package com.example.pdh

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.util.Log
import android.widget.Button
import android.widget.EditText
import androidx.appcompat.app.AppCompatActivity
import com.example.pdh.R
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.ActionCodeSettings

class AuthActivity : AppCompatActivity() {

    private lateinit var auth: FirebaseAuth
    private lateinit var emailEditText: EditText
    private lateinit var sendLinkButton: Button
    private val TAG = "AuthActivity"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_auth) // You'll need to create this layout file

        auth = FirebaseAuth.getInstance()

        emailEditText = findViewById(R.id.emailEditText)
        sendLinkButton = findViewById(R.id.sendLinkButton)

        sendLinkButton.setOnClickListener {
            val email = emailEditText.text.toString()
            if (email.isNotEmpty()) {
                sendSignInLink(email)
                // Save email for later use if the user completes sign-in on the same device
                getPreferences(MODE_PRIVATE).edit().putString("emailForSignIn", email).apply()
            } else {
                emailEditText.error = "Email cannot be empty"
            }
        }

        // You would typically have a UI element here to get the user's email
        // For demonstration, let's assume we have an email variable
        // val email = "test@example.com" // Replace with actual user input

        // sendSignInLink(email)
    }

    private fun sendSignInLink(email: String) {
        val actionCodeSettings = ActionCodeSettings.newBuilder()
            .setUrl("https://pdh-fe6eb.firebaseapp.com/finishSignUp?cartId=1234") // Replace with your whitelisted domain
            .setHandleCodeInApp(true)
            .setIOSBundleId("com.example.ios") // Optional, if you have an iOS app
            .setAndroidPackageName(
                "com.example.pdh", // Replace with your Android package name
                true, // installIfNotAvailable
                "12", // minimumVersion
            )
            .build()

        auth.sendSignInLinkToEmail(email, actionCodeSettings)
            .addOnCompleteListener { task ->
                if (task.isSuccessful) {
                    Log.d(TAG, "Email sent.")
                    // Save the email for later use, e.g., in SharedPreferences
                    // SharedPreferences.Editor editor = getPreferences(MODE_PRIVATE).edit();
                    // editor.putString("emailForSignIn", email);
                    // editor.apply();
                } else {
                    Log.e(TAG, "Error sending email link", task.exception)
                }
            }
    }

    override fun onResume() {
        super.onResume()

        val intent = intent
        val emailLink = intent.data.toString()

        if (auth.isSignInWithEmailLink(emailLink)) {
            // Retrieve this from wherever you stored it
            val email = getPreferences(MODE_PRIVATE).getString("emailForSignIn", null)

            if (email != null) {
                auth.signInWithEmailLink(email, emailLink)
                    .addOnCompleteListener { task ->
                        if (task.isSuccessful) {
                            Log.d(TAG, "Successfully signed in with email link!")
                            val result = task.result
                            // You can access the new user via result.getUser()
                            // Additional user info profile *not* available via:
                            // result.getAdditionalUserInfo().getProfile() == null
                            // You can check if the user is new or existing:
                            // result.getAdditionalUserInfo().isNewUser()
                        } else {
                            Log.e(TAG, "Error signing in with email link", task.exception)
                        }
                    }
            } else {
                Log.e(TAG, "No email found in SharedPreferences for sign-in link.")
            }
        }
    }
}
