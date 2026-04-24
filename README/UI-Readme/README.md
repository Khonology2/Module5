# Flutter Profile Screen UI Elements and Design Patterns

To ensure your new profile screen matches the existing app's UI, adhere to the following elements and design patterns, primarily referenced from `dashboard_screen.dart` and `settings_screen.dart`.

## 1. Overall Structure and Theming

*   **`Scaffold` with transparent background and `extendBodyBehindAppBar`**: This is a consistent pattern for full-bleed background images or gradients.

    ```dart
    Scaffold(
      backgroundColor: Colors.transparent, // Set Scaffold background to transparent
      extendBodyBehindAppBar: true, // Extend the body behind the AppBar
    )
    ```

*   **Transparent `AppBar` with white, bold title**: The app bar is minimal and integrates with the background.

    ```dart
    AppBar(
      backgroundColor: Colors.transparent, // Make AppBar transparent
      elevation: 0,
      title: const Text(
        'Dashboard',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    )
    ```

*   **Background with `Positioned.fill` `Image.asset` and `BackdropFilter` with `LinearGradient`/`RadialGradient`**: This is a prominent visual style for the app. The blurred background image with a semi-transparent gradient overlay creates a sleek, futuristic look.

    ```dart
    Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/20250919_1033_Futuristic Red Patterns_remix_01k5ghm3a8e39bxbzcpw8sgg6v.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0), // Apply stronger blur effect
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [
                    Color(0x880A0F1F), // More opaque semi-transparent overlay (alpha 0x88)
                    Color(0x88040610), // More opaque semi-transparent overlay (alpha 0x88)
                  ],
                  stops: [0.0, 1.0],
                ),
              ),
            ),
          ),
        ),
      ],
    )
    ```

*   **Primary color**: The app frequently uses `0xFFC10D00` (a shade of red) for accents, buttons, and active states.

    ```dart
    Color(0xFFC10D00)
    ```

*   **Dark background containers**: Many sections are enclosed in containers with a dark background color like `0xFF1F2840` and `borderRadius` for a card-like appearance.

    ```dart
    Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F2840),
        borderRadius: BorderRadius.circular(10),
      ),
    )
    ```

## 2. Text Styles

*   **White text for main content, `white70` for secondary text**:

    ```dart
    Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12))
    ```

*   **Bold text for titles and important values**:

    ```dart
    Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))
    ```

## 3. Buttons

*   **`ElevatedButton`**: Used for primary actions, often with the `0xFFC10D00` background color and `RoundedRectangleBorder` or `StadiumBorder`.

    ```dart
    ElevatedButton.icon(
      onPressed: () {},
      icon: Icon(icon, color: Colors.white, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    )
    ```

*   **`TextButton`**: Used for secondary actions, often with a `0xFFC10D00` background.

    ```dart
    TextButton(
      onPressed: () {},
      style: TextButton.styleFrom(backgroundColor: const Color(0xFFC10D00)),
      child: const Text('Nudge', style: TextStyle(color: Colors.white)),
    )
    ```

## 4. Input Fields (from `settings_screen.dart`)

*   **`TextFormField` within `ClipRRect` and `BackdropFilter`**: This creates a blurred, rounded input field with a semi-transparent white fill and a `0xFFC10D00` border on focus.

    ```dart
    ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
        child: TextFormField(
          controller: controller,
          obscureText: obscureText,
          decoration: _inputDecoration(hintText: hintText), // Pass hintText to decoration
          style: const TextStyle(color: Colors.white),
          validator: validator,
          onChanged: onChanged,
          keyboardType: keyboardType,
        ),
      ),
    )
    ```

*   **`InputDecoration`**: Defines the styling for `TextFormField`, including `filled`, `fillColor` (semi-transparent white), `enabledBorder` (no border), `focusedBorder` (red border), `hintText` with `0xFFC10D00` color.

    ```dart
    InputDecoration _inputDecoration({String? hintText}) {
      return InputDecoration(
        filled: true,
        fillColor: Colors.white.withAlpha(25), // Semi-transparent white for blurred effect
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFC10D00), width: 1.0),
        ),
        hintText: hintText, // Add hintText
        hintStyle: const TextStyle(color: Color(0xFFC10D00)), // Remove const
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      );
    }
    ```

## 5. Cards and Sections

*   **`_buildSettingsCard` (from `settings_screen.dart`):** A reusable container with a dark background `0xFF2C3E50` and rounded corners, used to group related settings.

    ```dart
    Widget _buildSettingsCard({required List<Widget> children}) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: const Color(0xFF2C3E50),
          borderRadius: BorderRadius.circular(15.0),
        ),
        child: Column(children: children),
      );
    }
    ```

*   **`Container` with `Color(0xFF1F2840)` background and `borderRadius`**: This is a very common pattern for distinct sections.

    ```dart
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1F2840), borderRadius: BorderRadius.circular(10)),
    )
    ```

*   **Cards with left-side colored stripe**: Used for status sections, like "At Risk" or "Upcoming."

    ```dart
    Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2840),
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: stripe, width: 3)),
      ),
    )
    ```

## 6. Icons

*   **White or colored icons**: Icons are used frequently, often with `Colors.white` or the accent `Color(0xFFC10D00)`.

    ```dart
    Icon(Icons.filter_list, color: Colors.white70)
    Icon(Icons.lightbulb_outline, color: Color(0xFFC10D00), size: 20)
    ```

## 7. Spacing and Layout

*   **`SizedBox`**: Used extensively for vertical and horizontal spacing.
*   **`Padding`**: Used for internal spacing within containers and widgets.
*   **`Row` and `Column`**: Basic layout widgets.
*   **`Expanded`**: Used to make widgets take up available space within `Row` or `Column`.

By using these elements and following these design patterns, your new profile screen will seamlessly integrate with the existing application's UI.
