# Registration 400 Error (identitytoolkit signUp)

## Why clicking the error link shows 404

When you click the failed request in Developer Tools (Network tab), the link often opens only the **path** of the request, e.g.:

- `/v1/accounts:signInWithPassword?key=...`
- or `/v1/accounts:signUp?key=...`

Your browser then loads that path on **your current origin** (e.g. `http://localhost:xxxx`), so you get:

- `http://localhost:xxxx/v1/accounts:signInWithPassword?key=...`

Your app’s server doesn’t have that path, so it returns **404. That’s an error. The requested URL ... was not found on this server.**

The **real** request from your app is sent to **Google’s server**:

- `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=...`

So the 404 you see when clicking the link is from your dev server, not from Firebase. To inspect the actual error:

1. In the **Network** tab, click the failed request (don’t rely on opening its URL in a new tab).
2. Open the **Headers** (or **Request URL**) and confirm the full URL starts with `https://identitytoolkit.googleapis.com/`.
3. Open the **Response** (or **Preview**) tab for that request to see the body Firebase returned (e.g. the 400 error message).

---

If you see in the browser console:

```text
identitytoolkit.googleapis.com/v1/accounts:signUp?key=...:1 Failed to load resource: the server responded with a status of 400 ()
```

the **Firebase Authentication** server is rejecting the sign-up request. The app may show a generic error; the checklist below fixes the most common causes.

## Checklist (do these in order)

### 1. Enable Email/Password sign-in (most common)

- Open [Firebase Console](https://console.firebase.google.com/) → your project (**pdh-v2**).
- Go to **Authentication** → **Sign-in method**.
- Click **Email/Password**.
- Turn **Enable** ON and save.

If this was off, sign-up will return **400** and often the SDK surfaces it as `operation-not-allowed`.

### 2. Authorized domains (web only)

For **Flutter web**, the domain you use must be allowed:

- In Firebase Console: **Authentication** → **Settings** → **Authorized domains**.
- Add:
  - `localhost` (for local dev).
  - Your production domain (e.g. `yourapp.web.app` or your custom domain) when you deploy.

Requests from a domain not in this list can result in **400** or auth errors.

### 3. API key restrictions (web)

If you restricted the web API key in **Google Cloud Console**:

- **APIs & Services** → **Credentials** → open the key used by the web app.
- Under **Application restrictions**, if you use “HTTP referrers”, ensure your app’s origin is listed (e.g. `http://localhost:*`, `https://your-domain.com`).

Overly strict restrictions can block the signUp request and lead to **400**.

### 4. Already signed in

If a user is already signed in and tries to register again, some flows can fail. Ensure you’re on the registration screen while **signed out**, or sign out first then try again.

### 5. Email / password rules

- Use a valid email format.
- Password must be at least **6 characters** (Firebase requirement); this app enforces 8+.

---

After changing **Sign-in method** or **Authorized domains**, wait a minute and try registration again. If it still fails, check the in-app error message and the browser console for the exact Firebase error code/message.

---

## "API key not valid. Please pass a valid API key." (400 / INVALID_ARGUMENT)

If the response body contains `API_KEY_INVALID` or "API key not valid", the **web API key** used by your app is rejected by Google. Your app uses the key in `lib/firebase_options.dart` (e.g. for web: `AIzaSyAjg19Ej8fbUOfa6WYlEX-b4CNi-y0Lozc`).

### Fix options (in order)

**1. Check API key restrictions (most common)**  
In [Google Cloud Console](https://console.cloud.google.com/) → select your Firebase project (e.g. **PDH-v2**) → **APIs & Services** → **Credentials**:

- Open the **API key** that matches the web key (the one in `firebase_options.dart`).
- **Application restrictions**
  - If set to "HTTP referrers", add your app’s origins, for example:
    - `http://localhost:*`
    - `http://127.0.0.1:*`
    - Your production URL, e.g. `https://your-app.web.app/*`
  - For local testing you can temporarily set to "None" to confirm the key works, then set referrers again.
- **API restrictions**
  - If "Restrict key" is on, ensure the key is allowed to call **Identity Toolkit API** (and any other APIs your app uses, e.g. Firestore).  
  - Or temporarily set to "Don't restrict key" to test, then restrict again.

Save and wait a minute, then try sign-in/registration again.

**2. Confirm Identity Toolkit API is enabled**  
In Google Cloud Console → **APIs & Services** → **Enabled APIs & services**:

- Search for **Identity Toolkit API**.
- If it’s not enabled, click **Enable**.

**3. Use a valid key from Firebase**  
If the key was deleted or regenerated, your `firebase_options.dart` may be outdated:

- In [Firebase Console](https://console.firebase.google.com/) → your project (**pdh-v2**) → **Project settings** (gear) → **General** → **Your apps** → select the **Web** app.
- Copy the **Web API Key** (or create a new web app to get a new key).
- Update `lib/firebase_options.dart` with that key for the `web` (and `windows` if you use the same key there), or run FlutterFire to regenerate the file (see below).

**4. Regenerate Flutter Firebase config**  
To refresh all keys and options from your Firebase project:

```bash
dart run flutterfire configure
```

This updates `lib/firebase_options.dart` with the current keys from Firebase. Then rebuild and test again.
